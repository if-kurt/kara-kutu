#!/bin/sh
# G23 (KURTARMA ORTAMINDA, busybox sh, root): BFR kalıcı "boot-erecovery" bayrağını temizle. HAZIRLIK — onaysız çalıştırma.
# G21 bfr-temizle.sh'in genelleştirilmiş hâli: "önce" sha'sı sabit değil (rrecord kayıtları her olayda değişir).
#   misc ofset 0-1087 ve rrecord ofset 0-1023 sıfırlanır; başka bayta dokunulmaz.
# Denetim: PARTNAME misc=p24 / rrecord=p26 ve ikisi de "boot-erecovery" ile başlamalı; yoksa YAZMAZ.
# Önce iki bölümün ilk 4 KiB'ı stdout'a hexdump olarak dökülür (ana makinede kayda girer).
M=/dev/mmcblk0p24; R=/dev/mmcblk0p26
M_HEDEF=5647f05ec18958947d32874eeb788fa396a05d0bab7c1b71f112ceb7e9b31eee
sha() { dd if=$1 bs=4M 2>/dev/null | sha256sum | cut -c1-64; }
date
grep -qx PARTNAME=misc /sys/class/block/mmcblk0p24/uevent && grep -qx PARTNAME=rrecord /sys/class/block/mmcblk0p26/uevent || { echo "DUR: bolum adlari"; exit 10; }
[ "$(dd if=$M bs=14 count=1 2>/dev/null)" = boot-erecovery ] || { echo "DUR: misc boot-erecovery degil"; exit 11; }
[ "$(dd if=$R bs=14 count=1 2>/dev/null)" = boot-erecovery ] || { echo "DUR: rrecord boot-erecovery degil"; exit 12; }
echo "ONCE misc=$(sha $M) rrecord=$(sha $R)"
echo "--- misc ilk 4K"; dd if=$M bs=4096 count=1 2>/dev/null | hexdump -C | head -80
echo "--- rrecord ilk 4K"; dd if=$R bs=4096 count=1 2>/dev/null | hexdump -C | head -80
dd if=/dev/zero of=$M bs=1088 count=1 conv=notrunc,fsync 2>&1; echo "misc dd=$?"
dd if=/dev/zero of=$R bs=1024 count=1 conv=notrunc,fsync 2>&1; echo "rrecord dd=$?"
sync; echo 3 > /proc/sys/vm/drop_caches
A=$(sha $M); echo "SONRA misc=$A rrecord=$(sha $R)"
[ "$A" = $M_HEDEF ] && echo "misc = temel deger: OK" || echo "UYARI: misc temel degere donmedi"
Z=$(dd if=$R bs=1024 count=1 2>/dev/null | hexdump -C | head -3 | tr -s ' ')
echo "rrecord ilk 1024: $Z"
