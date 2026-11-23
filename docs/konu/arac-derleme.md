# Konu: araçlar, derleme ve ölçüm yöntemi tuzakları


## Araçlar
- `work/tools/avbinfo.py` (AVB/boot imajı çözücü), `work/tools/mktest.py` (boot imajı üretici, `id` hesabı), `work/tools/updateapp.py` (UPDATE.APP), `work/tools/bfiinfo.py` (BFI), `work/tools/blkdiff.py`, `work/recon/tools/erofs_ro.py` (EROFS okuyucu).
- QEMU: betikler `work/g47/qemu-yuva.sh` ile (≤ 3 VM, yük ≥ 10'da bekler); gerileme takımı `work/gNN/qemu/hepsi.sh` (38 koşu). Cihaz denetleyicileri `work/g45/b/denetleyici-uret.py` ile üretilir (≤ 1000 karakter, `sh -n`).

## Araç ve derleme tuzakları
- Ubuntu'nun `mkbootimg`'si GKI import hatası veriyor (`unpack_bootimg` çalışıyor).
- `fastboot flash` bölüm boyutunu okuyamadığı için `skip copying … avb footer` uyarısı verir; tam boyutlu imajlarda zararsız.
- Load average ~45-6 anlamsız. Gerçek yük için CPU yüzdesine bak.
- Uyarı tarayıcısı küçük harfli "failed" mmc satırlarını kaçırır; cihaz pstore'unu ayrıca elle incele.
- mke2fs 1.47 normal dosyada ZERO_RANGE kullanır (extent'ler yeniden unwritten olur); önlemek için `UNIX_IO_NOZEROOUT=1`.
- 4.9'da `wpa_cli` kk'ın PATH'inde yok (`/usr/sbin/wpa_cli`; `sudo -n` ile bulunur) (G56).
- busybox `chattr` hata verse de 0 döner; sonucu `lsattr` ile doğrula.
- `kk-anahat-ssh` komut sınırı 1000 karakter.
- Reddedilen discard istekleri de diskstats `discard_io`'ya sayılır; "discard 0" ölçütü her discard girişimini yakalar (G50).
- Derleme damgası (sürüm dizgesindeki #n + saat, GNU build-id, initramfs mtime) imaj sha'sını değiştirir; build.sh `KBUILD_BUILD_TIMESTAMP/VERSION/USER/HOST` ve initramfs zaman damgasını sabitler (G51).
- **Disk temizliği (G55):** silmeden önce yalnız betik metinleri değil sembolik bağlar da denetlenir (`find work -lname '*<silinecek yol>*'`); G55'te kalan turların 10 `sd-debian*.img` bağı silinen dosyaya düştü (onarıldı, `work/g55/disk/SILME-LISTESI.md`).
- **busybox applet tuzağı (G58):** `busybox sh` gömülü applet'leri (`reboot`, `umount`, `mount` …) PATH'teki stub'lardan önce çalıştırır; cihaz betiklerinin yerel sınamasında busybox kullanılmaz. `dash` + komutun önüne sh fonksiyonu stub'ları + `env -i PATH=<yalnız gerekli araçlar>` (gerçek reboot erişilemez) (`work/g58/kurtarma/sina.sh`).
