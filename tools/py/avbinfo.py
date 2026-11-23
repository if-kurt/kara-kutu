#!/usr/bin/env python3
"""Salt okunur AVB footer + vbmeta + Android boot header cozucu (kendi kodumuz)."""
import sys, struct, hashlib, json

def boot_layout(d):
    if d[:8] != b'ANDROID!': return None
    ks, ka, rs, ra, ss, sa, ta, ps, hv = struct.unpack_from('<9I', d, 8)
    pg = lambda n: (n + ps - 1) // ps * ps
    out = dict(kernel_size=ks, ramdisk_size=rs, second_size=ss, page=ps, header_version=hv,
               ramdisk_addr=hex(ra))
    off = ps  # header page
    out['kernel_off'] = off; off += pg(ks)
    out['ramdisk_off'] = off; off += pg(rs)
    out['second_off'] = off; off += pg(ss)
    if hv >= 1:
        rdo_size, = struct.unpack_from('<I', d, 1632)
        off += pg(rdo_size); out['recovery_dtbo_size'] = rdo_size
    out['layout_end'] = off
    out['last_nonzero_before_footer'] = None
    return out

def parse(path):
    d = open(path, 'rb').read()
    r = dict(file=path, size=len(d), boot=boot_layout(d))
    f = d[-64:]
    if f[:4] != b'AVBf':
        r['footer'] = None
    else:
        maj, mnr, orig, vo, vs = struct.unpack_from('>IIQQQ', f, 4)
        r['footer'] = dict(version=f'{maj}.{mnr}', original_image_size=orig, vbmeta_offset=vo, vbmeta_size=vs)
        vb = d[vo:vo + vs]
        r['vbmeta'] = vbmeta(vb)
        # hash dogrulama
        for h in r['vbmeta'].get('hash_descriptors', []):
            algo = h['hash_algorithm']
            if algo in ('sha256', 'sha512'):
                hh = hashlib.new(algo); hh.update(bytes.fromhex(h['salt'])); hh.update(d[:h['image_size']])
                h['digest_matches_image'] = hh.hexdigest() == h['digest']
    # son sifir olmayan bayt (footer haric)
    end = len(d) - (64 if r['footer'] else 0)
    if r['footer']: end = r['footer']['vbmeta_offset'] + r['footer']['vbmeta_size']
    body_end = r['footer']['original_image_size'] if r['footer'] else end
    i = (r['footer']['vbmeta_offset'] if r['footer'] else len(d))
    while i > 0 and d[i - 1] == 0: i -= 1
    r['last_nonzero_before_vbmeta'] = i
    return r

def vbmeta(vb):
    if vb[:4] != b'AVB0': return dict(error='AVB0 magic yok', head=vb[:16].hex())
    (rmaj, rmin, auth_sz, aux_sz, algo, hoff, hsz, soff, ssz, koff, ksz, pmoff, pmsz,
     doff, dsz, rbi, flags, rlo) = struct.unpack_from('>IIQQIQQQQQQQQQQQII', vb, 4)
    rel = vb[0x80:0x80 + 48].split(b'\0')[0].decode(errors='replace')
    aux = vb[256 + auth_sz: 256 + auth_sz + aux_sz]
    out = dict(required_libavb=f'{rmaj}.{rmin}', algorithm_type=algo, auth_block=auth_sz, aux_block=aux_sz,
               rollback_index=rbi, flags=flags, release_string=rel, hash_descriptors=[], other_descriptors=[])
    p = doff; endd = doff + dsz
    while p + 16 <= endd:
        tag, nbf = struct.unpack_from('>QQ', aux, p)
        body = aux[p + 16:p + 16 + nbf]
        if tag == 2:
            isz, = struct.unpack_from('>Q', body, 0)
            halg = body[8:40].split(b'\0')[0].decode()
            nlen, slen, dlen, fl = struct.unpack_from('>IIII', body, 40)
            q = 40 + 16 + 60
            name = body[q:q + nlen].decode(); q += nlen
            salt = body[q:q + slen].hex(); q += slen
            dig = body[q:q + dlen].hex()
            out['hash_descriptors'].append(dict(partition=name, image_size=isz, hash_algorithm=halg,
                                                salt=salt, digest=dig, flags=fl))
        elif tag == 0:
            k = body[:].split(b'\0')
            out['other_descriptors'].append(dict(tag='property', raw=body[16:16+64].decode(errors='replace')))
        else:
            out['other_descriptors'].append(dict(tag=tag, len=nbf))
        p += 16 + nbf
    return out

if __name__ == '__main__':
    for p in sys.argv[1:]:
        print(json.dumps(parse(p), indent=1))
