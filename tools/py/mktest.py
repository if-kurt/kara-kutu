#!/usr/bin/env python3
"""Test boot imajlari: stok kernel + kucuk test ramdisk'i. FLASH ETMEZ, sadece dosya uretir.
V1: AVB footer + vbmeta (hash descriptor image_size/digest guncel; imza eski = gecersiz, Magisk'li kernel gibi)
V2: footer'siz, 24 MiB'a sifirla dolu."""
import gzip, hashlib, io, struct, sys
PART = 25165824

def boot_id(kernel, ramdisk, second=b'', dtbo=b''):
    """mkbootimg (header v1) id: SHA1(kernel,len, ramdisk,len, second,len, recovery_dtbo,len)."""
    s = hashlib.sha1()
    for blob in (kernel, ramdisk, second, dtbo):
        s.update(blob); s.update(struct.pack('<I', len(blob)))
    return s.digest() + b'\0' * 12

if len(sys.argv) > 1 and sys.argv[1] == 'kernel':
    # Görev 6B: mktest.py kernel STOK_IMG IMAGE_GZ OUT_IMG ["EK CMDLINE"]
    # Stok header (v1, adresler, cmdline, os_version) + yeni kernel, ramdisk YOK, bölüm boyutuna sıfır dolgu.
    # Görev 8: isteğe bağlı 5. argüman stok header cmdline'ının SONUNA eklenir (stok kısım korunur).
    stok = open(sys.argv[2], 'rb').read()
    kern = open(sys.argv[3], 'rb').read()
    out = sys.argv[4]
    extra = sys.argv[5].encode() if len(sys.argv) > 5 else b''
    ps = struct.unpack_from('<I', stok, 36)[0]
    assert stok[:8] == b'ANDROID!' and ps == 2048
    assert struct.unpack_from('<I', stok, 40)[0] == 1, 'header v1 bekleniyor'
    assert kern[:3] == b'\x1f\x8b\x08', 'kernel gzip (Image.gz) olmali'
    hdr = bytearray(stok[:ps])
    if extra:
        cl = bytes(hdr[64:576]).split(b'\0')[0]
        assert all(32 < c < 127 or c == 32 for c in extra), 'cmdline ASCII olmali'
        new = cl + b' ' + extra
        assert len(new) < 512, 'cmdline 512 bayta sigmali'
        assert hdr[608:609] == b'\0', 'extra_cmdline alani bos bekleniyor'
        hdr[64:576] = new + b'\0' * (512 - len(new))
        print('cmdline:', new.decode())
    struct.pack_into('<I', hdr, 8, len(kern))      # kernel_size
    struct.pack_into('<I', hdr, 16, 0)             # ramdisk_size
    struct.pack_into('<I', hdr, 24, 0)             # second_size
    hdr[576:608] = boot_id(kern, b'')
    img = bytes(hdr) + kern + b'\0' * ((-len(kern)) % ps)
    assert len(img) <= PART, 'imaj bolumden buyuk'
    img += b'\0' * (PART - len(img))
    open(out, 'wb').write(img)
    print('kernel', len(kern), 'imaj', len(img), 'id', hdr[576:596].hex(), 'sha256', hashlib.sha256(img).hexdigest())
    sys.exit(0)

stok = open(sys.argv[1], 'rb').read()          # kk-ek/stok/stok-kernel.img
out = sys.argv[2]                               # cikti dizini
ps = 2048; pg = lambda n: (n + ps - 1) // ps * ps

def newc(entries):
    b = io.BytesIO(); ino = 1
    for name, mode, data in entries + [('TRAILER!!!', 0, b'')]:
        nm = name.encode() + b'\0'
        hdr = '070701' + ''.join('%08X' % v for v in (ino, mode, 0, 0, 1, 0, len(data), 0, 0, 0, 0, len(nm), 0))
        b.write(hdr.encode() + nm); b.write(b'\0' * ((4 - b.tell() % 4) % 4))
        b.write(data); b.write(b'\0' * ((4 - b.tell() % 4) % 4)); ino += 1
    return b.getvalue()

marker = (b'KARA KUTU TEST RAMDISK v1 - 2026-11-09\n'
          b'Bu ramdisk sadece bootloaderin initrd yukleyip yuklemedigini test eder.\n'
          b'Stok kernel skip_initramfs gordugu icin bu ramdisk acilmaz; Android normal acilir.\n')
pad = b''.join(b'satir %05d: kk-test-dolgu 0123456789abcdef\n' % i for i in range(90))
cpio = newc([('.', 0o40755, b''), ('KK_TEST_RAMDISK', 0o100644, marker + pad)])
rd = gzip.compress(cpio, compresslevel=9, mtime=0)

ks, = struct.unpack_from('<I', stok, 8)
kernel = stok[ps:ps + ks]
hdr = bytearray(stok[:ps])
struct.pack_into('<I', hdr, 16, len(rd))                     # ramdisk_size
s = hashlib.sha1()
for blob in (kernel, rd, b''):
    if blob: s.update(blob); s.update(struct.pack('<I', len(blob)))
    else: s.update(struct.pack('<I', 0))
s.update(struct.pack('<I', 0))                                # recovery_dtbo (hv1)
hdr[576:608] = s.digest() + b'\0' * 12
img = bytes(hdr) + kernel + b'\0' * (pg(ks) - ks) + rd + b'\0' * (pg(len(rd)) - len(rd))
assert img[:8] == b'ANDROID!' and len(img) < PART

# V2
v2 = img + b'\0' * (PART - len(img))
# V1: stok vbmeta'yi kopyala, hash descriptor'u guncelle
fo = stok[-64:]; assert fo[:4] == b'AVBf'
_, _, orig, vo, vsz = struct.unpack_from('>IIQQQ', fo, 4)
vb = bytearray(stok[vo:vo + vsz])
auth, aux = struct.unpack_from('>QQ', vb, 12)
doff, dsz = struct.unpack_from('>QQ', vb, 96)
base = 256 + auth; p = base + doff; done = False
while p < base + doff + dsz:
    tag, n = struct.unpack_from('>QQ', vb, p)
    if tag == 2:
        b = p + 16
        nl, sl, dl, _ = struct.unpack_from('>IIII', vb, b + 40)
        q = b + 116; name = bytes(vb[q:q + nl]); salt = bytes(vb[q + nl:q + nl + sl])
        assert name == b'kernel' and dl == 32
        struct.pack_into('>Q', vb, b, len(img))
        vb[q + nl + sl:q + nl + sl + dl] = hashlib.sha256(salt + img).digest()
        done = True
    p += 16 + n
assert done
vofs = (len(img) + 4095) // 4096 * 4096
v1 = bytearray(PART)
v1[:len(img)] = img; v1[vofs:vofs + vsz] = vb
footer = b'AVBf' + struct.pack('>IIQQQ', 1, 0, len(img), vofs, vsz) + b'\0' * 28
v1[-64:] = footer
open(f'{out}/test-kernel-V1-avb.img', 'wb').write(v1)
open(f'{out}/test-kernel-V2-noavb.img', 'wb').write(v2)
open(f'{out}/test-ramdisk.cpio.gz', 'wb').write(rd)
print('kernel', ks, 'ramdisk', len(rd), 'cpio', len(cpio), 'image_end', len(img), 'vbmeta_ofs', vofs)
