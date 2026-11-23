# Konu: günlük (dmesg / kmsg / journald / pstore) okuma tuzakları


- Ana hat dmesg halkası ≈ 15 dk'da taşar: çekirdek açılış satırları için `journalctl -k`. Kullanıcı alanından `/dev/kmsg`'ye yazılan satırlar (bekçi `kk-idle:` vb.) ana hat journald'ında görünmüyor; dmesg'den, halka taşmadan okunur (G48).
- initramfs çekirdeğin mmc satırlarını `kk: dmesg:` önekiyle yansıtır; dmesg'de `write blocked` 10–11 satır görünür (5 asıl). Sayan komutlar `kk: dmesg:` satırlarını süzer.
- sudo ve systemd, cihazda çalışan denetleyicinin komut satırını kmsg'ye loglar; hata sayaçları `grep -v -e sudo -e systemd` ile süzülür.
- journald'ın döndürme iletisi (`… corrupted or uncleanly shut down, renaming and replacing`) yalnız kmsg'de görünür, journal'da yok; sayım dmesg'den yapılır (G56).
- Kısa (oneshot) birimlerde `systemctl show -p ConditionResult` birim boşaltıldıktan sonra varsayılan değer döner; koşunun kanıtı için journal'a bakılır (G56).
- `grep -i oops` `ramoops` satırlarını da eşler.
