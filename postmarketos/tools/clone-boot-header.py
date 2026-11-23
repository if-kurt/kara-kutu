#!/usr/bin/env python3
"""Build a P30 Lite "kernel" partition image: clone the header of the
device's own stock kernel image and put a new gzip payload behind it.

usage: clone-boot-header.py STOCK_KERNEL_IMG PAYLOAD_GZ OUT_IMG

- STOCK_KERNEL_IMG: your own backup of the stock kernel partition (never shipped here).
- PAYLOAD_GZ: gzip of [shim + DTB + Image] (see pack-kernel-partition.sh).
- Header v1, page size, addresses, os_version and the stock cmdline are kept;
  ramdisk and second sizes are set to 0; the image is zero padded to the
  partition size. It only writes OUT_IMG; flashing is a separate, explicit step.
"""
import hashlib
import struct
import sys

PART = 25165824  # size of the kernel partition in bytes


def boot_id(kernel, ramdisk=b"", second=b"", dtbo=b""):
    # mkbootimg id for header v1: SHA1 over (blob, little endian length) pairs
    s = hashlib.sha1()
    for blob in (kernel, ramdisk, second, dtbo):
        s.update(blob)
        s.update(struct.pack("<I", len(blob)))
    return s.digest() + b"\0" * 12


def main():
    stock = open(sys.argv[1], "rb").read()
    kern = open(sys.argv[2], "rb").read()
    out = sys.argv[3]
    ps = struct.unpack_from("<I", stock, 36)[0]
    assert stock[:8] == b"ANDROID!" and ps == 2048, "stock image: wrong magic or page size"
    assert struct.unpack_from("<I", stock, 40)[0] == 1, "header version 1 expected"
    assert kern[:3] == b"\x1f\x8b\x08", "payload must be gzip"
    hdr = bytearray(stock[:ps])
    struct.pack_into("<I", hdr, 8, len(kern))   # kernel_size
    struct.pack_into("<I", hdr, 16, 0)          # ramdisk_size
    struct.pack_into("<I", hdr, 24, 0)          # second_size
    hdr[576:608] = boot_id(kern)
    img = bytes(hdr) + kern + b"\0" * ((-len(kern)) % ps)
    assert len(img) <= PART, "image larger than the partition"
    img += b"\0" * (PART - len(img))
    open(out, "wb").write(img)
    print("payload", len(kern), "image", len(img), "sha256", hashlib.sha256(img).hexdigest())


if __name__ == "__main__":
    main()
