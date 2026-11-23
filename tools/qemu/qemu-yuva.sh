#!/bin/bash
# G47: ortak QEMU yuvası. Bütün betikler her QEMU koşusunu bununla başlatır:
#   /opt/kara-kutu/work/g47/qemu-yuva.sh <komut> [arg...]
# - Aynı anda en çok 3 QEMU (3 flock yuvası; tasarım kuralı G47).
# - 1 dk yük ortalaması >= KK_YUVA_YUK (varsayılan 10; ana makine 8 çekirdek) iken yeni VM başlatmaz, bekler
#   (G46'da yük 16-19 iken QEMU'da RCU stall görüldü).
# - Bekleme döngüsü: sleep 15 + kesin üst süre KK_YUVA_UST (varsayılan 5400 sn) -> çıkış 124 (kural 16).
# - Komutun çıkış kodu aynen döner. Komutun kendi süresi komutun işidir (timeout içinde koşulmalı).
set -u
D=/opt/kara-kutu/work/g47/qemu-yuva; mkdir -p "$D"
[ $# -ge 1 ] || { echo "kullanim: qemu-yuva.sh <komut> [arg...]" >&2; exit 64; }
UST=${KK_YUVA_UST:-5400}; ESIK=${KK_YUVA_YUK:-10}; bas=$(date +%s)
while :; do
	yuk=$(cut -d' ' -f1 /proc/loadavg)
	if awk -v y="$yuk" -v e="$ESIK" 'BEGIN{exit !(y < e)}'; then
		for i in 1 2 3; do
			flock -n -E 199 "$D/yuva$i" "$@"; rc=$?
			[ $rc -ne 199 ] && { echo "$(date -u +%T) yuva$i bitti rc=$rc: $*" >> "$D/kayit.log"; exit $rc; }
		done
	fi
	[ $(( $(date +%s) - bas )) -ge "$UST" ] && { echo "qemu-yuva: ${UST} sn icinde yuva/yuk uygun olmadi" >&2; exit 124; }
	sleep 15
done
