#!/usr/bin/env python3
"""bootfail_info (BFI, magic XIFB) kayıt çözücü. Kullanım: bfiinfo.py img [img2]. Kodlar: include/chipset_common/bfmr/public/bfmr_public.h, reboot_type: mntn_public_interface.h, rcvMethod: bfr_core.h"""
import struct,sys
for fn in sys.argv[1:]:
    d=open(fn,'rb').read(); print('==',fn, 'hdr', [hex(x) for x in struct.unpack_from('<4I',d,0)])
    for i in range(20):
        o=0x1000*(i+1); r=d[o:o+0x1000]
        if r.strip(b'\0')==b'': continue
        rtc,err,stg,root,perc,rm,rr,dmd=struct.unpack_from('<Q7I',r,0)
        exc=r[36:164].split(b'\0')[0]
        bt,saved,sugg,ok,rt=struct.unpack_from('<5I',r,164)
        print(f'#{i} rtc={rtc:#x} err={err:#x} stage={stg:#x} rooted={root} perc={perc} rcvMethod={rm} rcvResult={rr} dmd={dmd:#x} exc={exc!r} bootup={bt} saved={saved} sugg={sugg} ok={ok} reboot_type={rt:#x}')
