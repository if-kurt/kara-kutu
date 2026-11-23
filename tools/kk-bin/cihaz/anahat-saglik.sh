# Kara Kutu G57 G-8 (G58: kova alani): ana hat saglik ozeti. kk-anahat-saglik gonderir: `sudo -n sh -s` (stdin). YALNIZ OKUMA.
# D1 guvenlik agi (sinir ya da gunluk kip + kk-saglik, hi6523 WDT satiri, SP805), G-4 sysctl, G-6 pil, sarj, sicaklik, sigorta,
# E6 kk-alan, yazma sayaclari, Ş2 wb, Ş12 suzulmus hata sayimlari, systemd, ust katman doluluk, ag. Son satir "OZET k=v ...".
# Ş1: watchdog status/timeleft OKUNMAZ. Ş5: D1 dmesg'den (+ journal -k; kullanici alani kmsg satirlari journald'da yok).
# Dosyaya/sysfs'e yazma yok. Degisirse sha yeniden onay.
set +e
U=$(cut -d" " -f1 /proc/uptime)
echo "zaman $(date -u '+%F %T UTC') up $U uname $(uname -r) boot $(cut -c1-8 /proc/sys/kernel/random/boot_id)"
echo "cmdline: $(tr ' ' '\n' </proc/cmdline | grep -E '^(kk_|ignore_loglevel|nmi_watchdog|panic=)' | tr '\n' ' ')"
TS=$(systemctl is-active kk-anahat-sinir.timer); TG=$(systemctl is-active kk-saglik.timer)
KIP=sinir; grep -qw kk_gunluk=1 /proc/cmdline && KIP=gunluk
echo "kip=$KIP sinir_timer=$TS saglik_timer=$TG"
{ dmesg | sed 's/^\[[ 0-9.]*\] //'; journalctl -k -b 0 -o cat --no-pager 2>/dev/null; } | grep -E "debian oturumu|irq-is-reset|WDT katmani ACIK|kk: sarj: WDT kurulamadi|reboot-mode DT|kk-saglik: (BASLADI|KOTU|EYLEM|SINIR)" | awk '!g[$0]++' | cut -c1-240 | tail -n 10
WD=yok
for w in /sys/class/watchdog/watchdog*; do
	[ -d $w ] || continue
	echo "wd ${w##*/} $(cat $w/identity) $(cat $w/state) $(cat $w/timeout) $(cat $w/nowayout) $(cat $w/bootstatus)"
	[ "$(cat $w/identity)" = sp805-wdt ] && WD=$(cat $w/state)
done
echo "systemd RuntimeWatchdogUSec=$(systemctl show -p RuntimeWatchdogUSec --value)"
echo "g4 $(for s in hardlockup_panic softlockup_panic hung_task_panic panic nmi_watchdog; do printf '%s=%s ' $s $(cat /proc/sys/kernel/$s); done)"
P=/sys/bus/platform/devices/kk-pil-koruma/pil
[ -d $P ] && echo "g6 kritik_eylem=$(cat $P/kritik_eylem) durum: $(cut -c1-260 $P/durum)"
echo "sarj: $(cut -c1-200 /sys/bus/i2c/devices/0-006b/sarj/durum 2>&1)"
D=$(dmesg | grep -v "kk: dmesg:" | grep -v -e sudo -e systemd)
s() { printf '%s\n' "$D" | grep -cE "$1"; }
SN=$(printf '%s\n' "$D" | grep "kk: sensor: vbat" | tail -n 1)
echo "$SN" | sed 's/^.*kk: sensor: //' | cut -c1-300
PC=$(echo "$SN" | grep -oE 'pil: adc=[0-9]+ [0-9.]+ C' | cut -d' ' -f3); SC=$(echo "$SN" | grep -oE ' max=[0-9.]+' | cut -d= -f2)
VB=$(echo "$SN" | grep -oE 'vbat=[0-9]+' | cut -d= -f2); IB=$(echo "$SN" | grep -oE 'ibat=-?[0-9]+' | cut -d= -f2)
SG=$(s 'kk: sigorta: (pil|SoC) [0-9]')
AL=yok; KV=
# G58: G-1 kova seviyesi (kk-alan durum; bicim G58-A'da) yalniz bilgi: ilk "kova=N"/"kova: N", yoksa kova satirinda "seviye=N"; bulunmazsa yok
kova_al() { printf '%s\n' "$1" | grep -i kova | grep -oE '(kova|seviye)[=:] *[0-9]+' | head -n 1 | grep -oE '[0-9]+$'; }
if [ -x /usr/local/sbin/kk-alan ]; then AD=$(/usr/local/sbin/kk-alan durum 2>&1); printf '%s\n' "$AD" | grep -E '^(durum|sayac|loop|kk_a12|kova):' | cut -c1-220; AL=$(cut -d' ' -f1 /run/kk-alan/durum 2>/dev/null | cut -d= -f2); KV=$(kova_al "$AD"); fi
set -- $(cat /sys/block/mmcblk0/stat)
WS=$7; DIO=${12}
echo "mmcblk0 ro=$(cat /sys/block/mmcblk0/ro) w_io=$5 w_sec=$WS d_io=$DIO kk_yazma: $(cut -d' ' -f1 /sys/block/mmcblk0/kk_yazma 2>&1)"
WB=$(s 'mmc write blocked: '); C2=$(s 'write blocked: CMD2')
OO=$(s 'Oops|SError|Internal error|Call trace|BUG:'); LK=$(s 'soft lockup|hard LOCKUP|blocked for more than|Kernel panic|rcu.*stall|RCU.*stall')
BR=$(s 'kk: blok yazma reddedildi|kk: a12 bdev yazma reddedildi'); E4=$(s 'EXT4-fs (error|warning)'); IO=$(s 'I/O error|Buffer I/O')
echo "sayim wb=$WB cmd2x=$C2 oops=$OO lockup=$LK blok_red=$BR ext4=$E4 io=$IO sigorta=$SG"
SIS=$(systemctl is-system-running); F=$(systemctl --failed --no-legend --plain | wc -l)
echo "sistem=$SIS failed=$F $(systemctl --failed --no-legend --plain | cut -d' ' -f1 | tr '\n' ' ')"
[ -x /usr/local/sbin/kk-saglik ] && /usr/local/sbin/kk-saglik durum 2>&1 | cut -c1-300
UK=$(df -P / | tail -n 1 | awk '{sub("%","",$5); print $5}'); RK=$(df -P /run | tail -n 1 | awk '{sub("%","",$5); print $5}')
echo "ust_katman=${UK}% run=${RK}% $(grep MemAvailable /proc/meminfo | tr -s ' ')"
ip -br a | grep -E '^(usb0|wlan0)'
echo "OZET up=${U%.*} kip=$KIP sistem=${SIS:-yok} failed=$F hata=$((OO + LK + BR + E4 + IO)) sigorta=$SG wb=$WB cmd2x=$C2 d_io=${DIO:-x} w_sec=${WS:-x} wd=$WD ust=${UK:-x} alan=${AL:-x} kova=${KV:-yok} pil_c=${PC:-x} soc_c=${SC:-x} vbat=${VB:-x} ibat=${IB:-x} sinir_timer=$TS saglik_timer=$TG"
