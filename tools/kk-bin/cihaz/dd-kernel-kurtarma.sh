#!/bin/sh
# G23 (KURTARMA ORTAMINDA, busybox sh, root): kernel bölümüne v5.1'i dd ile geri yaz. HAZIRLIK — onaysız çalıştırma.
#   dd-kernel-kurtarma.sh /tmp/kk-rescue-kernel-v5.1.img
# Denetimler (biri tutmazsa YAZMAZ): PARTNAME=kernel tam 1 eşleşme, bölüm 25 165 824 B, imaj boyutu eşit,
# ANDROID! magic, imaj sha = v5.1 (d27b3d73…). Sonra bölümü geri okuyup sha karşılaştırır.
IMG=$1; WANT=d27b3d736ed1110586f948f1c27bc6b21a5ac45ae8ef5894c29e9bba6d65b449; BOY=25165824
P=; n=0
for u in /sys/class/block/mmcblk0p*/uevent; do
	if grep -qx PARTNAME=kernel "$u"; then n=$((n+1)); P=$(sed -n 's/^DEVNAME=//p' "$u"); fi
done
[ "$n" -eq 1 ] && [ -n "$P" ] || { echo "DUR: kernel bolumu bulunamadi (n=$n)"; exit 10; }
PB=$(( $(cat /sys/class/block/$P/size) * 512 ))
[ "$PB" -eq $BOY ] || { echo "DUR: /dev/$P boyutu $PB"; exit 11; }
IB=$(wc -c < "$IMG"); [ "$IB" -eq $BOY ] || { echo "DUR: imaj boyutu $IB"; exit 12; }
[ "$(dd if="$IMG" bs=8 count=1 2>/dev/null)" = 'ANDROID!' ] || { echo "DUR: ANDROID! yok"; exit 13; }
IS=$(sha256sum "$IMG" | cut -c1-64); [ "$IS" = $WANT ] || { echo "DUR: imaj sha $IS"; exit 14; }
echo "hedef /dev/$P (kernel); ONCE sha=$(dd if=/dev/$P bs=4M 2>/dev/null | sha256sum | cut -c1-64)"
dd if="$IMG" of=/dev/$P bs=4M conv=fsync 2>&1; R=$?; echo "dd cikis=$R"; [ $R -eq 0 ] || { echo "DUR: dd hata"; exit 20; }
sync; echo 3 > /proc/sys/vm/drop_caches
SON=$(dd if=/dev/$P bs=4M 2>/dev/null | sha256sum | cut -c1-64); echo "SONRA sha=$SON"
[ "$SON" = $WANT ] && echo "kernel = v5.1: OK" || { echo "UYARI: kernel sha v5.1 DEGIL"; exit 21; }
