#!/bin/sh
# G63 tasarım, G64 bakımcı onayı 2026-11-24 (kk-bin/cihaz/; Debian'da, root, v5.2 çalışırken; busybox/dash uyumlu):
# erecovery_kernel (p40) bölümüne v5.2e kurtarma çekirdeğini dd ile yazar. KURAL 18: yalnız p43'te doğrulanmış v5.2 çalışırken
# (kapı durumu ACIK, profil 1) ve ayrı onayla çalıştırılır; bu betik p43'e DOKUNMAZ.
#   dd-erec-v52e.sh /tmp/kk-erecovery-kernel-v5.2e45.img
# Denetimler (biri tutmazsa YAZMAZ): çalışan çekirdekte kapı ACIK + profil 1; PARTNAME=erecovery_kernel tam 1 eşleşme;
# bölüm 25 165 824 B; imaj boyutu <= bölüm; ANDROID! magic; imaj sha = v5.2e (aşağı); yazmadan önce bölümün sha'sı = v5.1e
# (d34af993…) ya da zaten v5.2e (yeniden çalıştırma). Sonra geri okuma sha'sı karşılaştırılır.
IMG=$1
WANT=31149ae04255d11f1b296d54a6b529d76421dd7599a9012a1b668e39e08461e0   # G64 v5.2e (45 dk; work/g64/v52e45/kk-erecovery-kernel-v5.2e45.img)
ESKI_V51E=d34af993776ad265ebb45d36677bb2182742ecd5f388b65beefb10102faa5ecb
BOY=25165824
K=/sys/kernel/kk_emmc_kapi
[ "$(cut -d' ' -f1 $K/durum 2>/dev/null)" = ACIK ] || { echo "DUR: eMMC kapisi ACIK degil ($(cat $K/durum 2>/dev/null))"; exit 9; }
[ "$(cat $K/profil 2>/dev/null)" = 1 ] || { echo "DUR: kapi profili 1 degil"; exit 9; }
P=; n=0
for u in /sys/class/block/mmcblk0p*/uevent; do
	if grep -qx PARTNAME=erecovery_kernel "$u"; then n=$((n+1)); P=$(sed -n 's/^DEVNAME=//p' "$u"); fi
done
[ "$n" -eq 1 ] && [ -n "$P" ] || { echo "DUR: erecovery_kernel bolumu bulunamadi (n=$n)"; exit 10; }
PB=$(( $(cat /sys/class/block/$P/size) * 512 ))
[ "$PB" -eq $BOY ] || { echo "DUR: /dev/$P boyutu $PB"; exit 11; }
IB=$(wc -c < "$IMG"); [ "$IB" -gt 0 ] && [ "$IB" -le $BOY ] || { echo "DUR: imaj boyutu $IB"; exit 12; }
[ "$(dd if="$IMG" bs=8 count=1 2>/dev/null)" = 'ANDROID!' ] || { echo "DUR: ANDROID! yok"; exit 13; }
IS=$(sha256sum "$IMG" | cut -c1-64); [ "$IS" = $WANT ] || { echo "DUR: imaj sha $IS"; exit 14; }
ONCE=$(dd if=/dev/$P bs=4M 2>/dev/null | sha256sum | cut -c1-64)
echo "hedef /dev/$P (erecovery_kernel); ONCE sha=$ONCE"
case $ONCE in
	$ESKI_V51E|$WANT) ;;
	*) echo "DUR: bolum beklenen v5.1e/v5.2e degil (ONCE=$ONCE)"; exit 15;;
esac
[ "$IB" -eq $BOY ] || { echo "DUR: imaj tam $BOY B degil ($IB)"; exit 16; }
dd if="$IMG" of=/dev/$P bs=4M conv=fsync 2>&1; R=$?; echo "dd cikis=$R"; [ $R -eq 0 ] || { echo "DUR: dd hata"; exit 20; }
sync; echo 3 > /proc/sys/vm/drop_caches
SON=$(dd if=/dev/$P bs=4M 2>/dev/null | sha256sum | cut -c1-64); echo "SONRA sha=$SON"
[ "$SON" = $WANT ] && echo "erecovery_kernel = v5.2e: OK" || { echo "UYARI: erecovery_kernel sha v5.2e DEGIL"; exit 21; }
echo "kapi sayaclari: bio=$(cat $K/red_bio) mmc=$(cat $K/red_mmc) cmd6=$(cat $K/red_cmd6) ioctl=$(cat $K/red_ioctl)"
