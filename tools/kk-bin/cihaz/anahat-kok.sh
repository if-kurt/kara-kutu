#!/bin/sh
# Kara Kutu kk-bin ÖNERİSİ (G60-6; kaynak: work/g60/e7/b/oneri/kk-anahat-kok; ONAY BEKLİYOR, kk-bin'e KONMADI).
# Cihaz betiği: ana hat Debian'ında (kk_kok=rw E7 imajı, SSH 2222). kk-anahat-kok sarmalayıcısı bunu /run/kk-anahat-kok.sh olarak
# systemd-run birimiyle (root, /bin/sh = dash) çalıştırır; çıktı /run/kk-anahat-kok.log'a gider, son satır "SONUC tamam|dur".
#   anahat-kok.sh denetle          YALNIZ OKUMA: uname 6.12, kök rw ext4 (kkdata, errors=remount-ro), kk_yazma/kk_kacak, bekçi durumu,
#                                  /tmp /var/tmp tmpfs, journald kalıcı mı + boyut, kirli sayaç, dmesg'de e2fsck/kok/kacak satırları
#   anahat-kok.sh yaz-sina <MiB>   1..1536: kök fs'te /kk-deneme/y.bin altına belirlenimci desen yaz (O_DIRECT dd), fsync, kendi
#                                  sha256'sı ile ÖNCE-SONRA karşılaştır (direct okuma), dosyayı SİL, sync; bekçi/kacak sayaç farkı +
#                                  yazılan sektör farkı (diskstats) raporlanır. Bekçi UYARI/eylem (önce ya da sonra) -> DUR.
#   anahat-kok.sh dosya-sina       küçük dosya oluştur/yeniden adlandır/sil + `logger` + `journalctl --sync`; kalıcı journal'da satırın
#                                  göründüğü doğrulanır
# Değişmez: yalnız / altında /kk-deneme/ ve logger; KK_KURU=1 yalnız yazdırır (yerel sınama).
# G60-6 uyarlamaları (oneri/kk-anahat-kok'a göre): (1) çıktı /run/kk-anahat-kok.log'a + EXIT tuzağı SONUC satırı; (2) tuzak (EXIT/TERM) yarım
#   y.bin'i siler (birim RuntimeMaxSec'le öldürülürse 1,5 GiB artık kalmaz); (3) yaz-sina'dan ÖNCE bekçi uyari/eylem yok olmalı, SONRA da
#   (sözlü "bekçi UYARI/eylem tetiklenirse DUR" mekanik oldu); (4) MiB ondalık-olmayan (08 sekizlik tuzağı yok): [1-9][0-9]{0,3};
#   (5) "sha ESIT" ölçütü ve yazılan-sektör kanıtı satırları ayrı etiketli (SHA, SEKTOR); (6) iş bitince boş /kk-deneme kaldırılır.
set -u
KURU=${KK_KURU:-0}
L=${KK_LOG:-/run/kk-anahat-kok.log}; DIR=${KK_DIR:-/kk-deneme}; F=$DIR/y.bin
BEK=${KK_BEKCI:-/usr/local/sbin/kk-yazma-bekci}; KOK=${KK_KOKBIN:-/usr/local/sbin/kk-kok}
SYSB=${KK_SYSB:-/sys/block/mmcblk0}; DSTAT=${KK_DSTAT:-/proc/diskstats}
MOD=${1:-}
: > "$L"; exec > "$L" 2>&1
BITTI=0
cikis() {
	rc=$?
	[ -n "${F:-}" ] && [ "$KURU" != 1 ] && [ -e "$F" ] && { rm -f "$F"; sync; echo "geri: $F silindi (rc=$rc)"; }
	if [ $BITTI = 1 ] && [ $rc = 0 ]; then echo "$(date -u +%T) SONUC tamam mod=$MOD"; return; fi
	echo "$(date -u +%T) SONUC dur rc=$rc mod=$MOD"
}
trap cikis EXIT; trap 'exit 4' INT TERM HUP
run() { if [ "$KURU" = 1 ]; then echo "KURU: $*"; else "$@"; fi; }
dur() { echo "DUR: $*"; exit 3; }
temel() {
	[ "$KURU" = 1 ] && return 0
	case $(uname -r) in 6.12.*-kk-g*) ;; *) dur "uname 6.12 kk degil: $(uname -r)";; esac
	[ "$(findmnt -n -o FSTYPE /)" = ext4 ] || dur "kok ext4 degil (overlay/ro yolu): $(findmnt -n -o FSTYPE,OPTIONS /)"
	case $(findmnt -n -o OPTIONS /) in rw,*|*,rw,*|rw) ;; *) dur "kok rw degil";; esac
}
# bekci_ok: kk-yazma-bekci durum "uyari=yok; eylem=yok" olmali (okunamazsa DUR: bekcisiz 1,5 GiB yazilmaz)
bekci_ok() {
	[ "$KURU" = 1 ] && return 0
	bd=$("$BEK" durum 2>&1)
	echo "bekci($1): $bd"
	case $bd in *"uyari=yok"*"eylem=yok"*) ;; *) dur "bekci uyari/eylem var ya da durum okunamadi ($1)";; esac
}
case $MOD in
denetle)
	temel
	echo "uname=$(uname -r)"; findmnt -n -o SOURCE,FSTYPE,OPTIONS /; findmnt -n -o FSTYPE,SIZE /tmp /var/tmp
	echo "bagli /data=$(grep -c ' /data ' /proc/mounts) /kk/os/debian=$(grep -c ' /kk/os/debian ' /proc/mounts) state=$(grep -c 'kk/state' /proc/mounts) (hepsi 0 beklenir; G60-3 kosul 5)"
	for f in kk_yazma kk_kacak; do printf '%s: ' $f; cat $SYSB/$f 2>&1; done
	"$BEK" durum 2>&1 | tail -n 3; "$KOK" durum 2>&1
	ls -d /var/log/journal 2>&1; journalctl --disk-usage 2>&1
	dmesg | grep -E 'kk: (kok|kacak|yazma)|e2fsck|EXT4-fs' | tail -n 12
	;;
yaz-sina)
	[ $# -eq 2 ] || { echo "kullanim: yaz-sina <MiB 1..1536> (tek arguman)"; exit 64; }
	mb=${2:-}
	case $mb in [1-9]|[1-9][0-9]|[1-9][0-9][0-9]|[1-9][0-9][0-9][0-9]) ;; *) echo "kullanim: yaz-sina <MiB 1..1536>"; exit 64;; esac
	[ "$mb" -le 1536 ] || { echo "MiB 1..1536"; exit 64; }
	temel
	bekci_ok once
	run mkdir -p $DIR
	a0=$(awk '$3=="mmcblk0p68"{print $10}' $DSTAT 2>/dev/null)
	[ "$KURU" = 1 ] || e1=$(yes KK-E7-DESEN | head -c $((mb * 1048576)) | sha256sum | cut -c1-64)
	run sh -c "yes KK-E7-DESEN | head -c $((mb * 1048576)) | dd of=$F bs=1M iflag=fullblock oflag=direct conv=fsync status=none"
	[ "$KURU" = 1 ] || e2=$(dd if=$F bs=1M iflag=direct status=none | sha256sum | cut -c1-64)
	run rm -f $F; run sync
	a1=$(awk '$3=="mmcblk0p68"{print $10}' $DSTAT 2>/dev/null)
	ds=$(( ${a1:-0} - ${a0:-0} ))
	echo "SEKTOR yazilan sektor farki=$ds (>= $((mb * 2048)) beklenir)"
	[ "$ds" -ge $((mb * 2048)) ] || echo "UYARI: sektor farki beklenenden az (diskstats yok/ayri sayim); sha esitligi asil olcut"
	[ "$KURU" = 1 ] && { echo KURU-TAMAM; BITTI=1; exit 0; }
	echo "SHA ref=$e1 okunan=$e2"; [ "$e1" = "$e2" ] && echo "SHA ESIT" || dur "sha farkli"
	cat $SYSB/kk_kacak; bekci_ok sonra
	rmdir $DIR 2>/dev/null
	;;
dosya-sina)
	temel
	run sh -c "mkdir -p $DIR && echo a > $DIR/a && mv $DIR/a $DIR/b && rm -f $DIR/b && sync"
	run logger -t kk-e7 "dosya-sina $(date +%s)"; run journalctl --sync
	[ "$KURU" = 1 ] || { journalctl -t kk-e7 -n 1 --no-pager | tail -n 1 | grep -q 'dosya-sina' || dur "journal satiri gorunmuyor"; journalctl --disk-usage; }
	rmdir $DIR 2>/dev/null
	;;
*) echo "kullanim: anahat-kok.sh denetle|yaz-sina <MiB 1..1536>|dosya-sina"; exit 64;;
esac
BITTI=1
