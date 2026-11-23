#!/usr/bin/env python3
"""Huawei UPDATE.APP salt okunur ayristirici (kendi kodumuz).
Kullanim: updateapp.py UPDATE.APP list            -> bolum listesi
          updateapp.py UPDATE.APP extract OUTDIR [ADLAR...] -> secili (veya tum) bolumleri cikarir
Format: her girdi 0x55AA5AA5 (LE) ile baslar; header_len, ..., hardware_id[8], seq, file_size,
date[16]@28, time[16]@44, type[16]@60, blank[16]@76, hdr_crc u16@92, block_size u16@94, block_size u16, blank u16, crc tablosu, veri (4'e hizali)."""
import struct, sys, os, re
MAGIC = 0xA55AAA55
def entries(path):
    with open(path, 'rb') as f:
        size = os.fstat(f.fileno()).st_size
        off = 0
        # ilk magic'i bul (basta 92 bayt sifir bekleniyor)
        head = f.read(1 << 20); m = head.find(struct.pack('<I', MAGIC))
        if m < 0: raise SystemExit('magic bulunamadi')
        off = m
        while off + 98 <= size:
            f.seek(off); h = f.read(98)
            mg, hlen, unk, hwid, seq, fsz = struct.unpack_from('<III8sII', h, 0)
            if mg != MAGIC: break
            date = h[28:44].split(b'\0')[0].decode(errors='replace')
            tim = h[44:60].split(b'\0')[0].decode(errors='replace')
            name = h[60:76].split(b'\0')[0].decode(errors='replace')
            crc, bsz = struct.unpack_from('<HH', h, 92)
            data_off = off + hlen
            yield dict(hdr_crc=crc, block_size=bsz, name=name, seq=seq, size=fsz, hwid=hwid.rstrip(b'\0').decode(errors='replace'),
                       date=date, time=tim, data_off=data_off)
            off = data_off + fsz
            off = (off + 3) & ~3
if __name__ == '__main__':
    p, cmd = sys.argv[1], sys.argv[2]
    es = list(entries(p))
    if cmd == 'list':
        for e in es:
            print('%-24s seq=0x%08x size=%12d off=0x%x %s %s hw=%s' % (e['name'], e['seq'], e['size'], e['data_off'], e['date'], e['time'], e['hwid']))
        print('toplam', len(es))
    elif cmd == 'extract':
        out = sys.argv[3]; want = set(n.upper() for n in sys.argv[4:]); os.makedirs(out, exist_ok=True)
        with open(p, 'rb') as f:
            for e in es:
                if want and e['name'].upper() not in want: continue
                safe = re.sub(r'[^A-Za-z0-9_.-]', '_', e['name']) or 'bos'
                f.seek(e['data_off']); left = e['size']
                with open(os.path.join(out, safe + '.img'), 'wb') as o:
                    while left:
                        b = f.read(min(left, 1 << 24)); o.write(b); left -= len(b)
                print('cikti', safe, e['size'])
