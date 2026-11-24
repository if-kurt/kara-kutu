#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
#
# fetch-hi1102-files.sh - copy the Hi1102 Wi-Fi firmware and its config INI
# from YOUR OWN device's vendor partition, read-only.
#
# The linux-kirin710 kernel embeds these files at build time
# (CONFIG_KK_HI1102_FW_DIR for the directory, CONFIG_KK_HI1102_INI for the
# INI file). They are vendor files and are not shipped in
# either repository; take them from your own phone.
#
# Usage (as root):
#   fetch-hi1102-files.sh <source> <output-dir>
#
#   <source>      one of:
#                 - a directory where the vendor partition is already mounted
#                   (for example /vendor on the 4.9 system),
#                 - the vendor block device (PARTNAME vendor or vendor_a),
#                 - a vendor partition image file from your own backup.
#   <output-dir>  a new directory (must not exist yet).
#
# What it does: mounts the source read-only (EROFS, "-o ro"; image files via
# a read-only loop device), copies four files, unmounts, checks the sizes and
# writes SHA256SUMS. Nothing is ever written to the source. The source must
# be EROFS with LZ4 support in the running kernel (the 4.9 vendor kernel has
# it; on a host, use a kernel with CONFIG_EROFS_FS and CONFIG_EROFS_FS_ZIP).
#
# Exit codes: 0 ok, 3 copied but sha256 differs from the tested firmware
# build (files kept, check before use), 1 error, 64 usage.

set -eu

FILES='firmware/cr4_asic.bin|396012|8cf0e9aaebb95802c1028f1c35e563d283a772a19e88eac99e3febe8c32a08fc
firmware/CPU_RAM_SCHED.bin|362008|d7f10bf984c341951d768dab91b7789263c53de200eed24f92397dd91ce0b557
firmware/CPU_RAM_WBS.bin|40436|67220c16ab4af69c5783a206eff2e6a7a49b5985a1d17325260d0e86048c7c42
etc/cfg_marie_lx1a_hisi.ini|10785|c3c2a41a32766aa4fa014d92f278f7afe38c5c3fd3ec4182b82b2d5d3e2fa846'

die() { echo "fetch-hi1102-files: $*" >&2; exit 1; }

[ $# -eq 2 ] || { sed -n '4,20p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 64; }
SRC=$1
OUT=$2
[ -e "$OUT" ] && die "output already exists: $OUT"
[ -d "$(dirname -- "$OUT")" ] || die "parent directory missing: $(dirname -- "$OUT")"

MNT=
cleanup() {
	if [ -n "$MNT" ]; then
		umount "$MNT" 2>/dev/null || true
		rmdir "$MNT" 2>/dev/null || true
	fi
}
trap cleanup EXIT

if [ -d "$SRC" ]; then
	ROOT=$SRC
else
	[ "$(id -u)" -eq 0 ] || die "mounting needs root"
	if [ -b "$SRC" ]; then
		dev=$(basename -- "$(readlink -f -- "$SRC")")
		name=$(sed -n 's/^PARTNAME=//p' "/sys/class/block/$dev/uevent" 2>/dev/null || true)
		case $name in
		vendor|vendor_a) ;;
		*) die "$SRC is not the vendor partition (PARTNAME='$name')" ;;
		esac
		grep -q "^$(readlink -f -- "$SRC") " /proc/mounts &&
			die "$SRC is already mounted; pass its mount directory instead"
		opts=ro,nodev,nosuid,noexec
	elif [ -f "$SRC" ]; then
		opts=ro,loop,nodev,nosuid,noexec
	else
		die "source not found: $SRC"
	fi
	MNT=$(mktemp -d)
	mount -t erofs -o "$opts" "$SRC" "$MNT" ||
		die "read-only EROFS mount failed (kernel without EROFS/LZ4?)"
	ROOT=$MNT
fi

mkdir -- "$OUT"
rc=0
while IFS='|' read -r rel size sha; do
	f=$ROOT/$rel
	[ -f "$f" ] || die "missing in source: $rel"
	have=$(stat -c %s -- "$f")
	[ "$have" = "$size" ] || echo "warning: $rel is $have bytes, tested build has $size" >&2
	cp -- "$f" "$OUT/$(basename -- "$rel")"
	chmod 0444 -- "$OUT/$(basename -- "$rel")"
	got=$(sha256sum -- "$OUT/$(basename -- "$rel")" | cut -d' ' -f1)
	if [ "$got" != "$sha" ]; then
		echo "warning: $rel sha256 differs from the tested firmware build" >&2
		rc=3
	fi
done <<EOF
$FILES
EOF

(cd -- "$OUT" && sha256sum -- cr4_asic.bin CPU_RAM_SCHED.bin CPU_RAM_WBS.bin cfg_marie_lx1a_hisi.ini > SHA256SUMS)
cat -- "$OUT/SHA256SUMS"
[ $rc -eq 0 ] && echo "ok: files match the tested firmware build" ||
	echo "done with warnings (exit $rc)"
exit $rc
