# Kara Kutu G57 G-8: ana hat olcumu (kk-olcum/olcum.sh karsiligi; boot0/1 YOK). kk-anahat-olcum gonderir: `sudo -n sh -s` (stdin).
# YALNIZ OKUMA: bolum sha'lari (ana hatta GPT adi ham: once tam ad, yoksa <ad>_a), misc/rrecord ilk 14 bayt, eMMC omur
# (onbellekteki ext_csd alanlari; karta komut yok), 4.9 sayaclari (/data salt okunur), E6 kk-alan durum, yazma sayaclari,
# Ş2 wb, Ş12 suzulmus hata sayimlari, sicaklik/sigorta, failed. Dosyaya/sysfs'e yazma yok. Degisirse sha yeniden onay.
set +e
date -u '+%F %T UTC'; uptime
echo "uname $(uname -r) boot $(cat /proc/sys/kernel/random/boot_id)"
dev() { for n in "$1" "${1}_a"; do for u in /sys/class/block/mmcblk0p*/uevent; do grep -qx "PARTNAME=$n" "$u" && { sed -n 's/^DEVNAME=//p' "$u"; return 0; }; done; done; return 1; }
for p in kernel erecovery_kernel misc rrecord nvme bootfail_info dfx vendor oeminfo; do
	d=$(dev $p)
	if [ -n "$d" ]; then echo "$p /dev/$d $(sed -n 's/^PARTNAME=//p' /sys/class/block/$d/uevent) $(sha256sum /dev/$d | cut -c1-64)"; else echo "$p YOK"; fi
done
d=$(dev misc) && echo "misc ilk14: $(head -c 14 /dev/$d | tr -c '[:print:]' '.')"
d=$(dev rrecord) && echo "rrecord ilk14: $(head -c 14 /dev/$d | tr -c '[:print:]' '.')"
for c in /sys/class/mmc_host/mmc0/mmc0:*; do [ -f $c/life_time ] && echo "emmc ${c##*/} life_time=$(cat $c/life_time) pre_eol=$(cat $c/pre_eol_info)"; done
for f in os-tries wifi-fails boot-count next-os; do echo "$f=$(cat /data/kk/state/$f 2>&1)"; done
grep -oE 'reboot_reason=[^ ]*|last_bootup_keypoint=[^ ]*|normal_reset_type=[^ ]*' /proc/cmdline
journalctl -k -b 0 -o cat --no-pager 2>/dev/null | grep -m 2 -E "kk: reset-nedeni: (PMIC|reboot-mode)" | cut -c1-260
echo "kk_yazma: $(cat /sys/block/mmcblk0/kk_yazma 2>&1)"
echo "kk_a12: $(cat /sys/block/mmcblk0/kk_a12 2>&1)"
set -- $(cat /sys/block/mmcblk0/stat)
echo "mmcblk0 ro=$(cat /sys/block/mmcblk0/ro) w_io=$5 w_sec=$7 d_io=${12} f_io=${16}"
if [ -x /usr/local/sbin/kk-alan ]; then /usr/local/sbin/kk-alan durum 2>&1 | cut -c1-260; else echo "kk-alan: yok (bu imajda E6 yok)"; fi
D=$(dmesg | grep -v "kk: dmesg:" | grep -v -e sudo -e systemd)
s() { printf '%s\n' "$D" | grep -cE "$1"; }
echo "wb=$(s 'mmc write blocked: ') cmd2x=$(s 'write blocked: CMD2')"
echo "sigorta=$(s 'kk: sigorta: (pil|SoC) [0-9]')"
echo "hata oops=$(s 'Oops|SError|Internal error|Call trace|BUG:') lockup=$(s 'soft lockup|hard LOCKUP|blocked for more than|Kernel panic|rcu.*stall|RCU.*stall') blok_red=$(s 'kk: blok yazma reddedildi|kk: a12 bdev yazma reddedildi') ext4=$(s 'EXT4-fs (error|warning)') io=$(s 'I/O error|Buffer I/O')"
printf '%s\n' "$D" | grep "kk: sensor: vbat" | tail -n 1 | cut -c1-330
echo "sarj: $(cut -c1-200 /sys/bus/i2c/devices/0-006b/sarj/durum 2>&1)"
echo "failed=$(systemctl --failed --no-legend | wc -l) sistem=$(systemctl is-system-running)"
ip -br a
echo "OLCUM-SON"
