#!/usr/bin/env python3
"""Salt okunur, minimal EROFS okuyucu (eski Huawei EMUI9 formati, '.'/'..' eksik dizinler).
Sadece sikistirilmamis layout 0 (FLAT_PLAIN) ve 2 (FLAT_INLINE) desteklenir.
Kullanim: erofs_ro.py IMAGE walk            -> tum agaci listeler (tip boyut layout yol)
          erofs_ro.py IMAGE get PATH OUTFILE -> dosyayi cikarir
"""
import sys, struct, os, stat



class Erofs:
    def __init__(self, path):
        self.f = open(path, 'rb')
        sb = self.read(1024, 128)
        magic, = struct.unpack_from('<I', sb, 0)
        assert magic == 0xE0F5E1E2, hex(magic)
        self.blkszbits = sb[12]
        self.bs = 1 << self.blkszbits
        self.root_nid, = struct.unpack_from('<H', sb, 14)
        self.meta_blkaddr, = struct.unpack_from('<I', sb, 40)

    def read(self, off, n):
        self.f.seek(off); return self.f.read(n)

    def inode(self, nid):
        off = self.meta_blkaddr * self.bs + nid * 32
        h = self.read(off, 64)
        fmt, xic, mode = struct.unpack_from('<HHH', h, 0)
        ext = fmt & 1
        layout = (fmt >> 1) & 7
        if ext:
            size, = struct.unpack_from('<Q', h, 8)
            raw, = struct.unpack_from('<I', h, 16)
            isz = 64
        else:
            size, = struct.unpack_from('<I', h, 8)
            raw, = struct.unpack_from('<I', h, 16)
            isz = 32
        xsz = 12 + (xic - 1) * 4 if xic else 0
        return dict(off=off, mode=mode, size=size, raw=raw, layout=layout, isz=isz, xsz=xsz)

    def data(self, ino):
        size, lay = ino['size'], ino['layout']
        if lay == 0:
            return self.read(ino['raw'] * self.bs, size)
        if lay == 2:
            nblk = size // self.bs
            body = self.read(ino['raw'] * self.bs, nblk * self.bs) if nblk else b''
            tail = size - nblk * self.bs
            tailoff = ino['off'] + ino['isz'] + ino['xsz']
            return body + self.read(tailoff, tail)
        # layout 1: Huawei EMUI9 erken EROFS sikistirma varyanti; standart legacy LZ4 ile ACILAMIYOR (RECON.md)
        raise ValueError('desteklenmeyen layout %d' % lay)

    def readdir(self, ino):
        d = self.data(ino); out = []
        for b in range(0, len(d), self.bs):
            blk = d[b:b + self.bs]
            nameoff0, = struct.unpack_from('<H', blk, 8)
            cnt = nameoff0 // 12
            ents = [struct.unpack_from('<QHBB', blk, i * 12) for i in range(cnt)]
            for i, (nid, no, ft, _) in enumerate(ents):
                end = ents[i + 1][1] if i + 1 < cnt else len(blk)
                name = blk[no:end].split(b'\0', 1)[0].decode('utf-8', 'replace')
                if name not in ('.', '..'):
                    out.append((name, nid, ft))
        return out

    def lookup(self, path):
        nid = self.root_nid
        for part in [p for p in path.split('/') if p]:
            m = [n for (nm, n, ft) in self.readdir(self.inode(nid)) if nm == part]
            if not m: raise FileNotFoundError(path)
            nid = m[0]
        return nid

    def walk(self, nid=None, prefix=''):
        nid = self.root_nid if nid is None else nid
        for name, cnid, ft in sorted(self.readdir(self.inode(nid))):
            ino = self.inode(cnid); p = prefix + '/' + name
            t = 'd' if stat.S_ISDIR(ino['mode']) else 'l' if stat.S_ISLNK(ino['mode']) else 'f'
            yield t, ino['size'], ino['layout'], p
            if t == 'd':
                yield from self.walk(cnid, p)

if __name__ == '__main__':
    fs = Erofs(sys.argv[1])
    if sys.argv[2] == 'walk':
        for t, s, l, p in fs.walk():
            print(t, s, l, p)
    elif sys.argv[2] == 'get':
        ino = fs.inode(fs.lookup(sys.argv[3]))
        data = fs.data(ino)
        assert len(data) == ino['size']
        os.makedirs(os.path.dirname(sys.argv[4]) or '.', exist_ok=True)
        open(sys.argv[4], 'wb').write(data)
        print(len(data), sys.argv[3])
