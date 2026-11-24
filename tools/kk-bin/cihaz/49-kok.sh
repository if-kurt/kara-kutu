#!/bin/sh
# Kara Kutu kk-bin ÖNERİSİ (G60-6; kaynak: work/g60/e7/b/oneri/kk-49-kok; ONAY BEKLİYOR, kk-bin'e KONMADI).
# Cihaz betiği: 4.9 Debian'da (v5.1, p68 = /data) E7 hazırlığı. kk-49-kok sarmalayıcısı bunu /run/kk-49-kok.sh olarak
# systemd-run birimiyle (root, /bin/sh = dash) çalıştırır; çıktı /run/kk-49-kok.log'a gider, son satır "SONUC tamam|dur".
#   49-kok.sh denetle        YALNIZ OKUMA: uname 4.9, /data = p68 ext4 'kkdata', boş alan, os/debian + os/debian-anahat var mı,
#                            dumpe2fs -h (state clean, needs_recovery yok), os/debian-anahat/var/lib/kk-kok/{kirli,acik,kapandi,saat}
#   49-kok.sh kopya          os/debian -> os/debian-anahat (YALNIZ debian-anahat'a yazar; os/debian'a dokunmaz): boş alan >= 1,3 x boyut;
#                            rsync -aHAXx varsa o, yoksa tar --xattrs --one-file-system; sonra dosya sayısı + toplam bayt denetimi.
#                            Hedef zaten varsa DUR (silmek bu betiğin işi değil). Hedef yarım kalırsa UYARI satırı yazılır.
#   49-kok.sh kirli-sifirla  os/debian-anahat/var/lib/kk-kok/kirli <- 0 (kk-kok'un kirli kapanış eşiği sonrası kökü yeniden rw'ye açmak için)
# Değişmez: p68 dışına yazmaz; sudo -n (root'ta zararsız); KK_KURU=1 ise yazan komutları yalnız yazdırır (yerel sınama).
# G60-6 uyarlamaları (oneri/kk-49-kok'a göre): (1) çıktı /run/kk-49-kok.log'a + EXIT tuzağı SONUC satırı; (2) KURU'da boş alan
#   sahte değeri hatalıydı (a=2 < gereken -> kuru koşu hep DUR) -> düzeltildi; (3) rsync/tar yalnız tek dosya sistemi (-x; find -xdev ile tutarlı);
#   (4) canlı kaynak (4.9 Debian çalışırken journal/log değişir): dosya sayısı farkı max(50, n/200)'e kadar, bayt farkı %1'e kadar kabul.
set -u
KURU=${KK_KURU:-0}
D=${KK_E7_DATA:-/data}; SRC=$D/kk/os/debian; DST=$D/kk/os/debian-anahat; ST=$DST/var/lib/kk-kok   # G60-3: /data/kk/state ve os/debian ana hatta BAĞLANMAZ; durum yalniz debian-anahat altinda
L=${KK_LOG:-/run/kk-49-kok.log}
MOD=${1:-}
: > "$L"; exec > "$L" 2>&1
BITTI=0; KISMI=0
cikis() {
	rc=$?
	if [ $BITTI = 1 ] && [ $rc = 0 ]; then echo "$(date -u +%T) SONUC tamam mod=$MOD"; return; fi
	[ $KISMI = 1 ] && echo "UYARI: hedef $DST yarim kalmis olabilir; ELLE denetle; E7 imajini flaslama (silmek ayri onay)"
	echo "$(date -u +%T) SONUC dur rc=$rc mod=$MOD"
}
trap cikis EXIT; trap 'exit 4' INT TERM HUP
dur() { echo "DUR: $*"; exit 3; }
run() { if [ "$KURU" = 1 ]; then echo "KURU: $*"; else "$@"; fi; }
temel() {
	[ "$KURU" = 1 ] && return 0
	case $(uname -r) in 4.9.*) ;; *) dur "uname 4.9 degil: $(uname -r)";; esac
	mountpoint -q $D || dur "$D bagli degil"
	[ "$(blkid -s LABEL -o value "$(findmnt -n -o SOURCE $D)")" = kkdata ] || dur "etiket kkdata degil"
}
case $MOD in
denetle)
	temel
	echo "uname=$(uname -r)"; findmnt -n -o SOURCE,FSTYPE,OPTIONS $D; df -B1 --output=size,used,avail $D | tail -n 1
	for d in $SRC $DST; do [ -d $d ] && echo "var: $d ($(sudo -n du -sb $d 2>/dev/null | cut -f1) bayt)" || echo "yok: $d"; done
	sudo -n dumpe2fs -h "$(findmnt -n -o SOURCE $D)" 2>/dev/null | grep -E '^(Filesystem (state|features)|Last mount time|Mount count|Journal features)'
	sudo -n dumpe2fs -h "$(findmnt -n -o SOURCE $D)" 2>/dev/null | grep -q 'needs_recovery' && echo "UYARI: needs_recovery var (mount'lu fs'te journal'da bekleyen kayit olabilir; kapanista yeniden bak)"
	for f in kirli acik kapandi saat; do printf '%s=' $f; sudo -n head -n 1 $ST/$f 2>/dev/null || echo yok; done
	echo "NOT: mount'lu fs'te e2fsck -fn yanlis hata verir; temiz olcut = State clean + ana hat acilisindaki e2fsck -p rc<=1 (kk: dmesg satiri)."
	;;
kopya)
	temel
	[ -d $SRC ] || dur "kaynak yok: $SRC"
	[ -e $DST ] && dur "hedef zaten var: $DST (silmek bu betigin isi degil)"
	b=$(sudo -n du -sb $SRC | cut -f1); a=$(df -B1 --output=avail $D | tail -n 1 | tr -d ' ')
	[ "$KURU" = 1 ] && { b=1; a=1099511627776; }
	[ "$a" -ge $((b + b / 3 + 536870912)) ] || dur "bos alan yetersiz: avail=$a gerek>=$((b + b / 3 + 536870912))"
	KISMI=1
	run sudo -n mkdir -p $DST
	if [ "$KURU" = 1 ] || command -v rsync > /dev/null; then run sudo -n rsync -aHAXx --numeric-ids $SRC/ $DST/
	else run sudo -n sh -c "tar --one-file-system -C $SRC -cf - . | tar -C $DST -xpf - --numeric-owner --xattrs"; fi
	run sync
	if [ "$KURU" != 1 ]; then
		n1=$(sudo -n find $SRC -xdev | wc -l); n2=$(sudo -n find $DST -xdev | wc -l)
		s1=$(sudo -n du -sb $SRC | cut -f1); s2=$(sudo -n du -sb $DST | cut -f1)
		echo "dosya $n1 / $n2; bayt $s1 / $s2"
		fk=$((n1 - n2)); [ $fk -lt 0 ] && fk=$((0 - fk)); tol=$((n1 / 200)); [ $tol -lt 50 ] && tol=50
		[ $fk -le $tol ] || dur "dosya sayisi farki $fk > $tol"
		[ "$s1" -le $((s2 + s2 / 100)) ] && [ "$s2" -le $((s1 + s1 / 100)) ] || dur "boyut farki > %1"
	fi
	KISMI=0
	echo "TAMAM: $DST"
	;;
kirli-sifirla)
	temel
	[ -d $DST ] || dur "hedef agac yok: $DST (once kopya)"
	run sudo -n mkdir -p $ST
	run sudo -n sh -c "printf '0\n' > $ST/kirli.yeni && mv -f $ST/kirli.yeni $ST/kirli && sync"
	echo "kirli=0"
	;;
*) echo "kullanim: 49-kok.sh denetle|kopya|kirli-sifirla"; exit 64;;
esac
BITTI=1
