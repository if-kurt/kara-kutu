#!/bin/sh
# Pack a mainline Image + DTB into a P30 Lite "kernel" partition image.
# usage: pack-kernel-partition.sh IMAGE DTB STOCK_KERNEL_IMG OUT_IMG [CMDLINE_CONF]
#
# Needs: aarch64-linux-gnu-{gcc,ld,objcopy}, fdtput (device-tree-compiler), gzip, python3.
# It only writes files. It never touches a device; flashing is a separate step
# that needs its own explicit approval (see README).
#
# Why this exists: the bootloader loads the payload at 0x80000 with ITS OWN
# device tree and ignores the DTB of the boot image, and CONFIG_CMDLINE of the
# shipped config is empty. So the command line is injected into the DTB
# (/chosen/bootargs) and a small shim carries DTB + Image.
set -eu
[ $# -ge 4 ] || { echo "usage: $0 IMAGE DTB STOCK_KERNEL_IMG OUT_IMG [CMDLINE_CONF]" >&2; exit 64; }
HERE=$(cd "$(dirname "$0")" && pwd)
IMG=$(readlink -f "$1"); DTB=$(readlink -f "$2"); STOCK=$(readlink -f "$3"); OUT=$4
CONF=${5:-$HERE/../device-huawei-marie/kernel-cmdline.conf}
SHIM=$HERE/../linux-huawei-marie/shim.S
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

# one parameter per line, '#' comments, joined with spaces
ARGS=$(grep -v '^[[:space:]]*#' "$CONF" | grep -v '^[[:space:]]*$' | tr '\n' ' ' | sed 's/ *$//')
cp "$DTB" "$T/boot.dtb"
fdtput -t s "$T/boot.dtb" /chosen bootargs "$ARGS"

aarch64-linux-gnu-gcc -c -nostdlib -DDTB_PATH="\"$T/boot.dtb\"" -DIMAGE_PATH="\"$IMG\"" \
	-o "$T/shim.o" "$SHIM"
aarch64-linux-gnu-ld -nostdlib -Ttext=0x80000 -e _start -o "$T/shim.elf" "$T/shim.o"
aarch64-linux-gnu-objcopy -O binary "$T/shim.elf" "$T/blob.bin"

# placement checks: the Image is copied to 0x04000000 and must stay below the
# stock ramdisk address 0x07c00000 and the first no-map region at 0x10000000
python3 -I - "$IMG" "$T/blob.bin" <<'PY'
import os, struct, sys
img, blob = sys.argv[1:3]
isz = struct.unpack('<Q', open(img, 'rb').read(64)[16:24])[0]
bsz = os.path.getsize(blob)
DEST, LOAD = 0x04000000, 0x80000
assert LOAD + bsz <= DEST, "blob overlaps the copy destination"
assert DEST + isz <= 0x07c00000, "kernel crosses 0x07c00000"
assert DEST + isz <= 0x10000000, "kernel crosses 0x10000000"
print("placement OK: image_size %d, blob %d" % (isz, bsz))
PY

gzip -9 -n -c "$T/blob.bin" > "$T/blob.bin.gz"
python3 -I "$HERE/clone-boot-header.py" "$STOCK" "$T/blob.bin.gz" "$OUT"
