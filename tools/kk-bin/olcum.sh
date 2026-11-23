set +e
date -u '+%F %T UTC'; uptime
dev() { for u in /sys/class/block/mmcblk0p*/uevent; do grep -qx "PARTNAME=$1" $u && sed -n 's/^DEVNAME=//p' $u; done; }
for p in kernel erecovery_kernel misc rrecord nvme bootfail_info dfx vendor oeminfo; do d=$(dev $p); echo "$p /dev/$d $(sha256sum /dev/$d | cut -c1-64)"; done
for b in mmcblk0boot0 mmcblk0boot1; do echo "$b /dev/$b $(sha256sum /dev/$b | cut -c1-64)"; done
echo "misc ilk14: $(head -c 14 /dev/$(dev misc) | tr -c '[:print:]' '.')"
echo "rrecord ilk14: $(head -c 14 /dev/$(dev rrecord) | tr -c '[:print:]' '.')"
echo "ext_csd: $(cat /sys/kernel/debug/mmc0/mmc0:0001/ext_csd)"
for f in os-tries wifi-fails boot-count next-os; do echo "$f=$(cat /data/kk/state/$f)"; done
grep -o 'reboot_reason=[^ ]*\|last_bootup_keypoint=[^ ]*\|normal_reset_type=[^ ]*' /proc/cmdline
echo "failed=$(systemctl --failed --no-legend | wc -l)"; ip -br a show wlan0
