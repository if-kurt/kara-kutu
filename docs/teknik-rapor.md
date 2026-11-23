> Bu belge projenin iç teknik raporundan, kişisel ve ortama özgü veriler (kimlikler, adresler, yollar) arındırılarak yayına hazırlanmıştır.
> Cihaz seri numarası, MAC adresleri, NV/oeminfo içeriği ve ofsetleri, Wi-Fi bilgileri bilerek yer almaz; bölüm adları ve genel yöntemler yer alır.
> Metin Türkçedir; İngilizce özet için kökteki README'ye bakın. `work/gNN/...` biçimindeki yollar iç çalışma dizinine aittir ve depoda bulunmaz; ilgili kod `initramfs/`, `tools/` ve `wifi/` altındadır, çekirdek değişiklikleri ayrı depodadır (linux-kirin710).

# KARA KUTU — Kernel & Boot Raporu

**Sürüm:** v5  
**Son güncelleme:** 18 Kasım 2026 (Görev 36-48 işlendi; verim aşaması kapanışı)  
**Cihaz:** Huawei P30 Lite (Marie / Kirin 710)  
**Doküman amacı:** Android'siz OS araç setinin kernel ve boot tarafının teknik referansı. Eski sürümlerdeki hatalı ya da eskimiş bilgiler §0'da düzeltildi.

> Bu rapor [cihaz-ozeti.md](cihaz-ozeti.md) ile birlikte okunur.

---

## 0. DÜZELTMELER (ÖNCE BUNU OKU)

### v4 → v5
| Konu | v4'te (ya da RECON'da) yazan | Gerçek | Kaynak |
|---|---|---|---|
| Ana hatta şarj | "Ana hatta şarja dokunulmaz" | hi6523'e onaylı üç yazma (0x90 yalnız CHG_EN, 0xE9 yalnız WDT[1:0], 0xE8 besleme) + i2c6 kapısı (CRG + pinmux). Politika, WDT katmanı ve kapanış kancası cihazda sınandı (§10 Şarj) | G39-G43 |
| Ana hatta PMIC/çevre yazmaları | "PMIC, şarj IC'si, Type-C, LPM3'e yazma yok; tek istisna iki okuma" | Onaylı istisnalar eklendi: hi6523 (yukarıda), PMIC 0x3E b0 (Wi-Fi 32 kHz; açılış başına 1, sysfs tetikle), i2c3 kapısı + LM36274 0x04/0x05 ← 0 (arka ışık), `scaling_governor` / cpuidle sysfs. LPM3'e yeni komut ve Type-C yok | G42-G48 |
| Ana hat donarsa | RECON G38.P4: "sp805 60 sn'de reboot eder → bootloader" | SP805 reset'i AWDT sayılır → BFR → **eRecovery (bizim kurtarma)**, döngü yok; fastboot'a dönmez. Ana hatta donanım watchdog'u G25'ten beri var (§10 Reset) | G48.4 |
| Ana hatta cpufreq/cpuidle | "cpuidle/cpufreq yok" (§10 sensörler) | cpufreq hw_vote (G36), thermal 200 ms (G37), schedutil + cpuidle (bekçiyle aşamalı) P1 imajında | G36-G48 |
| Ana hat Debian'da chrony | 15 maske içinde | G37'den beri maskesiz; NTP ana makine NAT üzerinden | G37-G38 |
| "4.9'da ~41-70 mA şarj" (G12.3) | ana makine SDP'de 4.9 şarjı küçük | 4.9 boşta ekran kapalıyken +321 mA; ana hatta fark sistem tüketimi | G42, G46 |

### v3 → v4
| Konu | v3'te yazan | Gerçek | Kaynak |
|---|---|---|---|
| Mainline | "Kirin 710 için mainline destek yok; tek kernel 4.9" | Ana hat 6.12.117, kendi DT'miz ve küçük yamalarla açılıyor. SMP, bellek, pstore, SPMI, watchdog, eMMC (HS200), USB NCM ve Debian çalışıyor (§10) | G25-G34 |
| Port kernel + P30 DTB | denenmedi, "asıl risk" | 4.9.337 fork stok DTB ile açılıyor; iki uyumluluk yaması gerekti (thermal, coul) | G8-G10 |
| Bootloader logu | dmesg'de `fastbootlog` | Kendi 4.9 kernel'imizde dmesg'e dökülmüyor; `/proc/balong/log/{fastboot_log,last_fastboot_log}` (root; oeminfo ofsetleri içerir, paylaşılmaz) | G9, G20 |
| Recovery modu | `kernel` + TWRP ramdisk | Recovery de `kernel` bölümünü kullanıyor (bizim kernel). TWRP ramdisk'i bizim `/init`'i eziyor; recovery = TWRP güvenilir değil | G17 |
| eRecovery | test yuvası olarak kullanılmadı | `erecovery_kernel`'de bizim kurtarma ortamımız v5.1e var; `systemctl reboot erecovery` ile tuşsuz giriş | G17, G20 |
| `erecovery_*` yazma | fastboot ile | FB kilidi kapalı → `Command not allowed`. Yalnız Debian'dan `dd` | G20 |
| Watchdog | "büyük ihtimalle kernel besliyor (doğrulanmadı)" | 4.9: sp805 sürücüsü besliyor, kullanıcı alanı gerekmez. Ana hat: SP805'in ilk kesmesi Kirin'de reset → `irq-is-reset` yaması | G9, G24 |
| Reset yolu | – | Reset LPM3 NMI ile yapılıyor (SCTRL +0x510 bit2); PSCI reset değil. Reboot nedeni PMIC `0x1E1` | G23, G27 |
| Rootfs yeri | karar bekliyor | userdata ext4 `kkdata`, `/data/kk/{os,state,logs}` | G13-G14 |
| Şarj | "init şarja dokunmaz" | v4'ten beri şarj limiti (4.9). Ana hatta şarja dokunulmaz | G13 |

### v2 → v3 ve v1 → v2
- Normal açılışta bootloader `kernel` bölümündeki ramdisk'i okumuyor (DT initrd uzunluğu 0).
- AVB her açılışta `vbmeta` başlığında düşüyor, orange durumda tolere ediliyor.
- Fork + Ubuntu GCC 13.3 doğrudan derleniyor.
- `boot` bölümü yok; hedef `kernel`.
- Header: base `0x00078000`, kernel `0x00080000`, ramdisk `0x07c00000`, tags `0x07a00000`, second `0x00f00000`, v1, page 2048.
- Nisan'daki `halium-boot.img` geçersiz.

---

## 1. BOOT MİMARİSİ (doğrulandı)

### Açılış yolları
| Yol | Nasıl girilir | Yüklenen |
|---|---|---|
| Normal (mod 1) | Power, `fastboot reboot`, `systemctl reboot` | `kernel` gövdesi; **ramdisk yok**; cmdline'a `skip_initramfs` eklenir |
| Recovery (mod 2) | Vol Up + Power, USB yok | **`kernel`** + `recovery_ramdisk` + `recovery_vendor`; AVB yalnız bu modda atlanıyor. Bizim kernel'le güvenilir değil |
| eRecovery (mod 3) | Vol Up + Power USB takılı; **`systemctl reboot erecovery`** (tek seferlik); BFR | `erecovery_kernel` + ramdisk'ler; cmdline `enter_recovery=1 enter_erecovery=1`. AVB düşüyor, açılış sürüyor (ölçüldü) |
| Fastboot | `systemctl reboot bootloader` / reboot nedeni `bootloader`; Vol Down + Power | bootloader |

- **SAR:** stok cmdline `skip_initramfs root=PARTUUID=… init=/init`. Fork `skip_initramfs`'i cmdline'dan siliyor, böylece gömülü initramfs açılıyor.
- **DTB:** bootloader kendi DT'sini (`dts` + `dto`, P30 board overlay `boardid=0x1e78` = dto girdi 46) veriyor. Boot imajındaki DTB'yi kullanmıyor. Ana hat imajı bunu bir **shim** ile aşıyor (§10).
- **`fastboot boot` işleyicisi yok.** fastboot istemcisi flaştan önce kendiliğinden getvar gönderiyor (zararsız).
- **Reboot nedeni:** PMIC `0x1E1` (alt 8 bit). Bootloader açılışta okuyup 0x10'a sıfırlıyor, flaştan sonra 0x13 yazıyor, kernel'e geçmeden 0xff yazıyor. `bootloader` = 0x01.
- **Watchdog:** bootloader SP805'i normal açılışta 60 sn ile açık bırakıyor (LOAD = 60<<15, kilit `0x1ACCE551`), fastboot modunda kapatıyor.

### Bootloader'ın normal açılışta yaptığı (Görev 5)
```
hisi_avb: read data from parition vbmeta offset 0 → Magic is incorrect → avb verify failed: 3
load_kernel: kernel load @ 0x00080000 (<Image.gz boyutu>), read from emmc kernel @ 0x00000800
load_kernel: ramdisk body load @ 0x07c00000 (0x00000000 bytes) … (her ramdisk bölümünden 0 bayt)
```
- Kernel gövdesi 0x800 ofsetinden `kernel_size` kadar okunuyor. `ramdisk` adlı bölüm yok.
- Fastboot flaşında `kernel vrl copy error` görülüyor; kilit açık olduğu için yazma kabul ediliyor.
- Sonuç: initramfs **kernel Image'ının içine gömülmeli** (`CONFIG_INITRAMFS_SOURCE`).

### Bootloader logunu okuma
- Stok kernel'de dmesg'e aktarılıyordu (`fastbootlog`).
- **Kendi 4.9 kernel'imizde:** `sudo cat /proc/balong/log/fastboot_log` (bu açılış) ve `last_fastboot_log` (bir önceki).
- Ana hatta bu arayüz yok.
- **Loglar oeminfo ofsetleri içerir; paylaşılmaz.**

### Gerçek cmdline (stok, önemli parçalar)
Tam metin: `<stok-yedek>/stock-cmdline.txt`.
```
loglevel=4 initcall_debug=n page_tracker=on unmovable_isolate1=2:192M,3:224M,4:256M
printktimer=0xfff0a000,0x534,0x538 androidboot.selinux=enforcing buildvariant=user
... bootlock=unlocked hw_bfm_enable=1 hw_bfr_enable=1 ... androidboot.hardware=kirin710 ...
skip_initramfs root=PARTUUID=<GUID> ... devmodel=MAR-L21A ... init=/init ... console=ttyS0
```
- `loglevel=4` yüzünden `dfx`'e yalnız err/crit gider ve `initcall_debug` görünmez. v2'den itibaren header cmdline'ımıza `log_buf_len=4M initcall_debug ignore_loglevel` eklendi.
- `console=ttyS0` var olmayan bir aygıt (ttyS0 = `uart@fdf02000`; UART `ttyAMA*`). `/dev/console` açılamıyor (v5 dersi, §9).

---

## 2. PARTITION HARİTASI

Tam liste: `<stok-yedek>/partitions.txt` (68 GPT bölümü). xloader eMMC boot alanında (`mmcblk0boot0/1`). **`ramdisk` ya da `boot` adlı bölüm yok.** Ana hatta GPT adları ham gelir (`kernel_a`, `erecovery_kernel_a`, `vendor_a`); 4.9 `_a` ekini gizliyor.

| Kategori | Bölümler | Kural |
|---|---|---|
| Bootloader / firmware | xloader (`mmcblk0boot0/1`), fastboot (p33), vector (p34), teeos (p38), trustfirmware (p49), hhee (p31), fw_lpm3 (p27), hisee_encos/img/fs (p17, p30, p32), sensorhub (p39), isp_boot/isp_firmware (p35, p36), fw_hifi (p37), hdcp (p29) | **ASLA yazılmaz.** boot0/1 yalnız `olcum.sh` ile okunur |
| Kimlik / kalibrasyon | nvme (p8, 10 240 sektör), oeminfo (p10), modemnvm_factory/backup/img (p13-15), modemnvm_update/cust (p57-58), modem_secure (p7), secure_storage (p11), certification (p9), persist (p2), frp (p1), veritykey (p18), ddr_para (p19), vrl/vrl_backup (p5-6) | **ASLA yazılmaz.** nvme referans sha `c32a697e…` |
| Modem | modem_fw (p50), modem_driver (p20), modem_om (p12), modem_patch_nv (p52) | Dokunulmaz |
| Boot-fail / kayıt / Huawei özel | bootfail_info (p23), rrecord (p26), misc (p24), dfx (p25), splash2 (p22), version (p66), patch (p59), eng_system (p44), eng_vendor (p51) | Dokunulmaz. bootfail_info/dfx'i BFR kendisi yazar. misc/rrecord'daki BFR bayrağını yalnız onaylı `bfr-temizle-g23.sh` temizler |
| Reserved | reserved1/2/3/4/6/7 | Dokunulmaz |
| DTB / AVB | dts (p47), dto (p48), vbmeta (p56), recovery_vbmeta (p54), erecovery_vbmeta (p55) | Stok kalır |
| **Boot imajları** | **kernel (p43, 25 165 824 B)**: v5.1 / test imajları; recovery_ramdisk (p45), recovery_vendor (p46); **erecovery_kernel (p40)**: v5.1e, fastboot'tan yazılamaz; erecovery_ramdisk/vendor (p41-42) | `kernel` kk-flash-kernel ile |
| Android OS (kullanılmıyor) | system (p64), product (p65), preload (p67), cust (p63), cache (p60) | Yazma yalnız açık onayla |
| Vendor | vendor (p61, Huawei EROFS), odm (p62) | Korunur (Hi1102 firmware'i burada; kk-wifi ro bağlar) |
| Veri | **userdata (p68): ext4 `kkdata`**, 28 431 360 × 4K, 512 MB journal | Rootfs + durum + log |

- **Port tuzağı:** Mate 20 Lite'ta p65 = cache, **P30'da p65 = `product`**.
- **AVB zincirleri:** `vbmeta` → kernel, system, vendor, odm, version, product, eng_*, cust, preload; `recovery_vbmeta` → kernel, recovery_ramdisk, recovery_vendor; `erecovery_vbmeta` → erecovery_*.

---

## 3. STOK KERNEL

- `Linux version 4.9.111 (üretici derleme ortamı) (gcc 4.9.x 20150123) #1 SMP PREEMPT Tue May 14 12:17:56 CST 2019`. Config `<stok-yedek>/stock-kernel.config`.
- Yamasız stok `kernel` = `<ek-yedek>/stok/stok-kernel.img`. `<stok-yedek>/kernel.img` Magisk'li (artık Android'i açamaz; userdata ext4).
- Stok kernel `ipa_sensors_info` düğümünü aramıyor; sabit tablolar kullanıyor. Coul adı `hi6555v200`. Fork'un EMUI 10 kodu EMUI 9 DT'siyle bu noktalarda uyumsuz (§9).
- `LOG_BUF_SHIFT`: stok 20, port 17.

### Kritik config değerleri
| Ayar | Stok | Anlamı |
|---|---|---|
| `CONFIG_FHANDLE` / `NAMESPACES` | kapalı | stok kernel'le systemd olmaz (fork'ta açık) |
| `CONFIG_MODULE_SIG_FORCE` | açık | stok kernel'e kendi modülümüz yüklenemez |
| `CONFIG_EROFS_FS_HUAWEI_EXTENSION` | açık | vendor bu varyantla bağlanıyor |
| `CONFIG_HI1102_*` | `=m` ama fiilen gömülü | |
| `CONFIG_USB_CONFIGFS_NCM` / `RNDIS` | açık | |
| `CONFIG_HUAWEI_BFM`, `HW_BFMR_HISI` | açık | §4 |

### Kernel yaşının sınırı
- systemd 258 en az 5.4, systemd 260 en az 5.10 istiyor. Debian 12 (systemd 252) 4.9'da sorunsuz.
- Daha yeni dağıtımlar için ana hat (§10).

---

## 4. HUAWEI BOOT-FAIL MEKANİZMASI (BFM/BFR)

- Kaynak: Iceows kernel `drivers/hwbfm/`. Kayıtlar `bootfail_info` (p23) ve `rrecord` (p26).
- `/dev/hw_bfm` ioctl'leri: `BFMR_SET_BOOT_STAGE` `0x40044207`, `BFMR_DISABLE_TIMER` `0x40044203`, `BFMR_ENABLE_CTRL` `0x4004420A`. "Açılış başarılı" = `0x7FFFFFFF`.
- Fork'un headless dalında kernel BFM'i kapalı. Başarılı açılış BFM kaydı oluşturmuyor.
- **Bootloader tarafı (BFR):**
  - Kernel aşamasında bir LPM3 istisnasında (panik, AWDT) BFR **ilk hatada** eRecovery'e gidiyor; döngü yok.
  - BFI: magic `XIFB`, 20 yuvalı halka. Çözücü `work/tools/bfiinfo.py`. G7 kaydı: `bfmErrNo 0x03010006`, `stage 0x02000004`, `rcvMethod 7`.
  - BFR kararı `check_and_save_log2dfx`. Keypoint PMU yazmacı `0x1E2`'de; 250 = `STAGE_BOOTUP_END`. Keypoint 250 ise BFR çağrılmaz (AP watchdog ve xloader/eMMC istisnaları hariç). Bizim kernel'de keypoint 32 kalıyor (v5.2'de 250 planlı).
  - **Kalıcı bayrak:** misc + rrecord'a `boot-erecovery` yazılıyor; temizlenene kadar her açılış eRecovery'e gidiyor. Temizleme `bfr-temizle-g23.sh` (`920d748e…`, `kk-kurtarma bfr`).
  - Bootloader, önceki kernel'in pstore konsolunu bir sonraki açılışta `dfx`'e kaydediyor.
  - cmdline'daki `hw_bfr_enable` bootloader kararını değiştirmiyor.
- G21: Debian'da `sysrq c` → BFR → **bizim kurtarma** (v5.1e). sysrq s + u önceden verilirse ext4 temiz kalıyor.

---

## 5. REFERANS PORT: jglasovic/droidian-kirin710

- `refs/droidian-kirin710` @ `3306469`. Kernel fork `refs/android_kernel_huawei_kirin710`, dal `headless-kirin710` @ `3ca6a91`, 4.9.337. Mate 20 Lite (SNE-LX1).
- Fork `skip_initramfs`'i siliyor (üç dalda). Port Halium initramfs'ini `kernel` bölümünde ramdisk olarak kullanıyor; **P30'da çalışmaz** (§1).
- Config farkları: tam liste `work/port/config-compare.txt` (348 fark). Önemlileri: FHANDLE/NAMESPACES açık, MODULE_SIG kapalı, HI1102 =y, BFM kapalı, DEVTMPFS_MOUNT, DRM=y.
- **Port script'leri asla çalıştırılmaz:**
  - p65'i "cache" diye rw bağlıyor (P30'da product);
  - "overwrite" yolu `rm -rf /tmpmnt/*` (userdata gider);
  - `disable-charger` şarjı kalıcı kapatıyor;
  - `-s` yok, "latest" indirmeler sha256'sız.
  - Wi-Fi sırası (`/sys/hisys/boot/{plat,wifi}`) ve USB gadget yöntemi okunup uyarlandı.

---

## 6. ANDROID'SİZ OS YOLLARI

### Araç seti katmanları
```
Huawei firmware          dokunulmaz
Kernel                   4.9.337 v5.1 (bugün) | ana hat 6.12.117 (aşama aşama)
Gömülü initramfs         kurtarma kabuğu (USB NCM + telnet), OS seçimi, switch_root
Rootfs                   /data/kk/os/<dağıtım> (kkdata ext4)
Ops                      kk-bin (ana makine), kk-* servisleri (cihaz)
```

### Durum (18 Kasım)
- **4.9 hattı:** v5.1 kernel bölümünde; Debian 12 native çalışıyor. v5.1e eRecovery yuvasında kurtarma (§9).
- **Ana hat:** Aşama 1-4, Tur 1-5 ve verim aşaması tamam (§10). Debian salt okunur açılıyor; eMMC HS200, USB NCM + ana makine NAT, SSH 2222, cpufreq + thermal, şarj politikası, schedutil + cpuidle + arka ışık kapatma (P1).
  - eMMC'ye yazma: pencere hazır ve doğrulandı (E2); ilk yazma (E4) onay bekliyor.
  - Wi-Fi: Hi1102 kartı SDIO'da görüldü (Faz B); firmware indirme (M2) sürüyor.
- **Yedek yol (stok kernel + system `/init`):** gerek kalmadı.

---

## 7. ARAÇLAR

| Araç | İş |
|---|---|
| `work/tools/avbinfo.py` | AVB footer/vbmeta/boot imajı çözücü |
| `work/tools/mktest.py` | Boot imajı üretici (stok header, `id`; 5. argüman header cmdline eki). Sonuç `unpack_bootimg` ile doğrulanır |
| `work/tools/updateapp.py` | UPDATE.APP ayrıştırıcı |
| `work/tools/bfiinfo.py` | BFI (bootfail_info) çözücü |
| `work/tools/blkdiff.py` | 4K blok fark bulucu |
| `work/recon/tools/erofs_ro.py` | EROFS okuyucu (sıkıştırmasız) |
| `work/rescue/e2fs/` | statik e2fsprogs 1.47.2 (initramfs için) |
| `kk-reboot2` | statik `reboot(RESTART2,"bootloader")` (ana hat initramfs) |
| `ramoops49.py`, `fb2png.py` | RAM dökümünden ramoops çözümü; QEMU framebuffer → PNG |
| `work/g29/sertlestirme/harness.c`, `work/g34/birim/` | mmc filtre/beyaz liste birim testleri (fonksiyonlar kaynaktan otomatik çıkarılır) |
| `work/g33/qemu/kos.sh`, `uyari-tara.sh` | QEMU koşucusu ve uyarı tarayıcısı (izin listesi dışındaki her uyarı = BAŞARISIZ) |
| `work/g47/qemu-yuva.sh` | ortak QEMU yuvası (3 flock yuvası, yük ≥ 10'da bekler, üst süre 5400 sn) |
| `work/g44/teshis/saat-haritasi.py`, `work/g47/emmc/alan/model49.py` | CRG/SCTRL kapı biti → saat adı; 4.9 ext4 fallocate yerleşim modeli |
| `work/g45/b/denetleyici-uret.py`, `b/analiz.py` | cihaz denetleyicisi üretici (uzunluk ≤ 1000, `sh -n`, tırnak sınaması) ve pencere analizi |
| `tools/kk-bin/*` | cihaz betikleri (cihaz-ozeti.md, tools/kk-bin) |

- `mkbootimg` (Ubuntu 24.04) GKI hatası veriyor; `unpack_bootimg` çalışıyor.
- İndirilen her dosya boyut/tip/sha256 doğrulanmadan kullanılmaz.

---

## 8. GEÇMİŞ HATALAR VE DERSLER

| Hata | Kök sebep | Ders |
|---|---|---|
| "9 byte ramdisk", `mkbootimg.py` SyntaxError | 404 HTML'i imaj/script sanıldı | Her imaja otomatik boyut/tip/sha kontrolü |
| Yanlış boot parametreleri, olmayan `boot` bölümü | Değerler doğrulanmadan yazıldı | Her değer cihazdan ya da stok imajdan doğrulanır |
| "Halium ramdisk'i `kernel` bölümüne" | Mate 20 Lite davranışı genellendi | Bootloader davranışı her cihazda ölçülür (önce bootloader logu) |
| v1 initcall kilitlenmesi (G7) | EMUI 10 kodu ↔ EMUI 9 DT uyumsuzluğu | DT ↔ kod ↔ stok Image `strings` karşılaştırması |
| Stok config ile derleme (G8 B) | 412 sembol yok, headless stub'lar | Fork'un config'i kullanılır |
| v5 `/dev/console` → PID 1 öldü | Taklit sınamada yönlendirme sahte yapılmıştı | `/init`'te PID 1'i öldürebilecek her komut gerçek koşulda denenir; taklitler yönlendirmeyi sahte yapmaz |
| shrp "yok" sanıldı | Ada göre karşılaştırma | Dosyalar hash'le karşılaştırılır |
| Sahte komut ~32 000 süreç | Taklit kendini çağırdı | Sınama PATH'i dikkatle kurulur |
| Ölü adam reboot'u (G18.0) | İptal ayrı komuta bırakıldı | İptal aynı betikte `trap EXIT` ile yapılır ve doğrulanır |
| P2P RCU stall (G16) | Hi1102 P2P_DEVICE kusuru | `p2p_disabled=1` |
| `echo` → NVE `-ENOENT` | Satır sonu | Sysfs yollarında `printf %s` (hipriv'de ise satır sonu ŞART) |
| SP805 → AWDT → eRecovery (G24) | Ana hat "ilk kesme zararsız" sanıyor; Kirin'de reset | Platform watchdog semantiği kaynaktan doğrulanır |
| G28 filtresi H1/H2 açıkları | QEMU testi SD kartla yapıldı, eMMC'ye özgü yollar görünmedi | Gerçek EXT_CSD ile `mmc_init_card` yürütmesi + birim testi |
| G29 kart init olmadı | Libra'nın strobe kapısı ana hatta yoktu | Vendor sürücünün her yazmacı taşınmadan önce listelenir |
| `pgrep -f` kendini buldu | Kendi komut satırıyla eşleşme | Süreç aramada dar desen |
| G33-B SSH yok | `CONFIG_PACKET` kapalı; virtio QEMU yakalamadı | QEMU geçmesi cihazı garanti etmez (AF_PACKET, entropi örnekleri) |
| journald `ForwardToKmsg` | Yazım hatası (doğrusu `ForwardToKMsg`, büyük M) | Uyarı tarayıcısı (`Unknown key`) |
| kmsg satırı kesildi | Satır sınırı 1024 bayt | Uzun satırlar 900'de kesilir |
| `kk-anahat` reboot'ta 120 sn bekledi | Cihaz FIN göndermiyor | Sessizlik sınırı (5/20 sn) |
| Boot bölümü adı içeren komut deny'a takıldı (G34) | Kural metin eşleşmesi | Dolanılmaz; `diff` ile karşılaştırılır |
| Uyarı tarayıcısı küçük harfli "failed" mmc satırlarını kaçırıyor | Desen büyük harfli | Cihaz logları ayrıca elle incelenir |

### İçgörü
- **Ölç, tahmin etme:** bootloader kendi logunu bırakıyor; pstore kameradan iyidir; `ignore_loglevel` şart.
- **Güvenlik katmanları birim testiyle kanıtlanır:** her genişlemede "daralma 0, beklenmeyen genişleme 0".
- **Headless:** kurtarma kabuğu (USB NCM + telnet) + yazılımla fastboot'a dönüş + ölü adam.

---

## 9. KENDİ 4.9 KERNEL'İMİZ (v-serisi)

- **Kaynak:** fork `headless-kirin710` @ `3ca6a91` → yerel dal `kk/p30-thermal` (push yok):
  - `79d5300f` thermal;
  - `a3f057c7` coul compatible;
  - `d8bc7451` NV salt okunur;
  - (v5.1e) yama 0004 `CONFIG_KK_IGNORE_EXTERNAL_INITRD`.
  - Yamalar `work/g8/patches/`.
- **Derleme:**
  ```bash
  SRC=/opt/kara-kutu/refs/android_kernel_huawei_kirin710
  make -C $SRC O=<out> ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- kirin710_defconfig
  make -C $SRC O=<out> ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- "BALONG_INC=-I$SRC/kernel" \
    KCFLAGS="-Wno-error=maybe-uninitialized -Wno-error=address -Wno-error=sizeof-pointer-memaccess -Wno-error=misleading-indentation" -j8 Image.gz
  ```
  ~8 dk. Initramfs `CONFIG_INITRAMFS_SOURCE` ile gömülü.
- **İmajlar** (hepsi 25 165 824 B, header v1, ramdisk yok; `work/test2/SHA256SUMS`):

| Sürüm | Görev | İmaj sha | Değişiklik / durum |
|---|---|---|---|
| v1 | G6 | `3c796f86` | kurtarma initramfs'i; G7'de initcall'da kilitlendi |
| v2 | G8-G9 | `f9b9a8d1` | thermal yaması; header cmdline `log_buf_len=4M initcall_debug ignore_loglevel`; başarılı (1002 initcall, BUG 0) |
| v3 | G10 | `5b61d417` | coul compatible; kullanılmadı |
| v3.1 | G11-G12 | `67ef9ea0` | `hisi_nve.c` bütün yazmaları `-EROFS` (log sınırlı); 30 sn güç/sıcaklık logu |
| v4 | G13 | `d139129a` | initramfs 3,7 MB: statik e2fsprogs, `kk-format-data`, kalıcı `/data` + loglar, şarj limiti (≥60 kes, ≤50 aç, pil ≥42 °C kes), uyarı eşiği SoC 55 °C |
| v4.1 | G14 | `7fdeaec4` | bakım/kalıcı mod, üç sonuçlu `usb_setup` |
| v5 | G15 | `2c74aec7` | `choose_os`, `switch_to_debian`; **`/dev/console` hatası, kullanılmaz** |
| **v5.1** | G15 | **`d27b3d73`** | console yedeği `/dev/null`, PID 1 ön koşulu, `mount --move` hatasında `reboot -f`. **Kernel bölümünde.** v5.1-kurtarma `8f816b88` (`kk.rescue=1`) |
| **v5.1e** | G17-G20 | **`d34af993`** | eRecovery varyantı: bootloader initrd'sini yok sayar, `enter_erecovery=1` → hep kurtarma; `erecovery_kernel`'de (Debian'dan dd) |

- **v5.1 init:**
  - `choose_os` (öncelik cihaz-ozeti.md);
  - `os-tries` (+1 / `kk-bootok` 0);
  - gadget (cihaz MAC `02:4b:4b:00:00:01`, host `…:02`);
  - kurtarma telnet 23;
  - kmsg logu 20 MB.
- **Config notları (v5.1):** `RTC_SYSTOHC=y` (NV yazma denemeleri → v5.2'de n), `PANIC_TIMEOUT=0`, `PANIC_ON_OOPS=y`, sysrq=1, DEVMEM kapalı, BFM kapalı.
- **Sürücü bulguları:**
  - P30'da olmayan donanımın sürücüleri -19/-22 dönüyor, zararsız.
  - `hi6523 set_charge_enable` yalnız `CHG_EN` bitini yazıyor.
  - NV yazan çağıranların hiçbiri hata durumunda panik yapmıyor.
  - Hi1102 sırası: NVE → plat → wifi. INI `cfg_marie_lx1a_hisi.ini` (`country_code=US`). SDIO `0x296:0x5347`.
  - Hi1102 güç yönetimi iki katmanlı (cihaz-ozeti.md, tools/kk-bin).
  - NV: `current_id 6`, `valid_items 416`; RTC NV kaydı 272; MAC kaydı 193.
- **v5.2 planı (yapılmadı):** cihaz-ozeti.md.

---

## 10. ANA HAT KERNEL 6.12.117

### Kaynak ve derleme
- Ağaç `work/g17/ana-hat/linux-6.12.117`. Her görevin değişikliği `work/gNN/*.diff` + `orijinal/` kopyası.
- `work/gNN/build.sh`: tinyconfig + `kucuk.fragment` (config denetiminde eksik 0), ~1,5-2 dk. İki varyant:
  - **cihaz:** LOCALVERSION `-kk-gNN`;
  - **QEMU:** `-kk-gNNq`, INITRAMFS ve SOFT_WATCHDOG farklı; cihaza yazılmaz.
  - G42'den beri ek varyantlar (`build.sh cihaz|test|m0|qemu|qemu-m0|e2 …`): `test` = `KK_SARJ_TEST` + test cmdline (`kk_debian_sinir=1200`, dar şarj bandı) + model "[TEST IMAJI]"; `m0`/teşhis/E2 varyantları yalnız ilgili DT düğümünü dtc ile `okay` yapar. Kaynak DTS'te yeni düğümler `status = "disabled"`.
  - G47'den beri betikler QEMU'yu `work/g47/qemu-yuva.sh` ile koşar (3 flock yuvası, yük ≥ 10'da bekler, üst süre 5400 sn).
- **G36-G48 config ekleri** (ayrıntı ilgili alt bölümde):
  - CPU_FREQ + `kk-kirin710-cpufreq`, THERMAL (step_wise);
  - I2C + I2C_DESIGNWARE_PLATFORM, **`I2C_CHARDEV` kapalı**; `KK_I2C6_KAPI`, `KK_HI6523_OKU`, `KK_SARJ_POLITIKA` (`KK_SARJ_TEST`, `KK_HI6523_O1`, `KK_SARJ_SAHTE` yalnız test/QEMU);
  - P1 üretiminde: CPU_IDLE + ARM_PSCI_CPUIDLE + menu, NO_HZ_IDLE, HIGH_RES_TIMERS, `CPU_FREQ_DEFAULT_GOV_SCHEDUTIL`, PSTORE_PMSG, `kk-i2c3-kapi`, `kk-lm36274`, `kk-reset-nedeni`;
  - eMMC yazma: `KK_EMMC_YAZMA` (varsayılan n). E1/E2 imajlarında **LOOP ve DM yok**;
  - Wi-Fi: `KK_WIFI_M0`, `MMC_DW`/`MMC_DW_PLTFM`/`MMC_DW_K3` + `KK_SDIO_KAPI` (`_PMIC_YAZ` ayrı kilit). MODULES, CFG80211, FW_LOADER, SDIO fonksiyon sürücüsü yok.
- **Önemli config:**
  - SPMI, SPMI_HISI3670, MFD_SYSCON, MFD_KK_SPMI_SYSCON, POWER_RESET_SYSCON, SYSCON_REBOOT_MODE;
  - ARM_SP805 + WATCHDOG_SYSFS, `WATCHDOG_OPEN_TIMEOUT=180`, `WATCHDOG_NOWAYOUT`;
  - PSTORE_RAM/CONSOLE (sıkıştırmasız); KALLSYMS, `PANIC_TIMEOUT=0`, FONT_TER16x32;
  - MMC_SDHCI_OF_DWCMSHC, DEBUG_FS (yalnız ios için bağlanıp ayrılır);
  - USB_DWC3 + `USB_DWC3_KK_KIRIN710`, USB_CONFIGFS_NCM;
  - **PACKET**, overlayfs, ext4;
  - `KK_SENSOR_OKUMA`;
  - `DEVMEM=n`.
- **İmaj yapısı:**
  - blob = shim + DTB + Image, gzip'li;
  - boot imajı v1, `ANDROID!`, 25 165 824 B;
  - bootloader gzip yükünü `0x00080000`'a açıyor;
  - shim Image'ı `0x04000000`'a kopyalar, `ic iallu`, `x0 = DTB`;
  - yerleşim denetimi: `0x04000000` + Image < `0x07c00000`.
- **İmaj geçmişi (sha ilk 8):**

| İmaj | sha |
|---|---|
| nefes büyük (G17) | `a622b2a5` |
| nefes küçük (G18) | `226cfa84` |
| nefes-f (G23) | `26d30d2d` |
| nefes-g (G24) | `d52be8c1` |
| G26 | `3d04aabc` |
| G29 sertleştirme | `cbfc1be2` |
| G30 | `1158a03f` |
| G31 | `2e6eba45` |
| G32 | `e47d6853` |
| G33-B | `7106915f` (kullanılmaz) |
| **G33-B2** | **`3f69a32a`** |
| G34 | `e5aeede2` |
| **G35** | **`bd954f50`** |
| G36 (cpufreq + thermal) | `01808192` |
| **G37** (thermal 200 ms, chrony, gateway) | **`c0155e82`** (G38 ağ testi de bununla) |
| G39 (şarj Faz 1, kapı yalnız okur) | `4e9da46a` |
| G40 (Faz 1 tekrarı, kapı 4.9 gibi açar) | `b5709b0c` |
| G40 Faz 2 (gitmedi) | `5b8126d3` |
| G41 (Faz 2 CHG_EN deneyi) | `7d994701` |
| G42 üretim (gitmedi) / **test (Faz 3)** | `08519067` / **`d2ff3c45`** |
| G43 üretim + kanca (gitmedi) / m0 / test | `2cde4b56` / `a7adef2e` / `6facc86a` |
| G44 test (teşhis + O1) | `da5ba6b2` |
| G45 test (cpuidle + schedutil) / M1 Faz A | `f1ced79d` / `b17597d4` |
| G46 M1 birleşik / W1 Faz B / B0 (hiçbiri gitmedi) | `01fdd78a` / `d9c60f48` / `d72ce2c3` |
| G47 S1 (ekran) / D1 / D2 / S3 (Wi-Fi Faz B) | `4f27df99` / `cc475959` / `bd61ef1b` / `aff085c9` |
| G47 E1 (eMMC, pencere yok) | `62b4a755` (G48'de cihazda) |
| G48 E2 (pencere `hazir`) | `a35dece6` |
| **G48 P1 (verim kapanışı)** | **`6c2ca900`** |

### DT (`arch/arm64/boot/dts/hisilicon/kirin710-huawei-marie.dts`)
- 8 `cpu` düğümü (stok MPIDR), PSCI 0.2 smc, `cpu-map` iki küme.
- Bellek: 4 stok rezerv kaldırıldı → `Memory: 3783060K/4194304K`.
- `sctrl` syscon `fff0a000`; `pmctrl` syscon `fff31000` (G34); `crg`/`pctrl` syscon'ları (G32).
- `spmi@fff24000` (`hisilicon,kirin970-spmi-controller`, kanal 2) → `pmic@0` (`karakutu,spmi-syscon`) → `reboot-mode` (offset 0x1e1, `mode-bootloader = 0x01`).
- `reboot-nmi-lpm3`: `syscon-reboot`, sctrl +0x510, mask = value = 0x4, öncelik 192 (PSCI 129'dan önce).
- SP805 `e8a06000`: `timeout-sec = 60`, `karakutu,irq-is-reset`.
- `ramoops@2e200000` (stok yerleşim, 1 MB: dmesg 3×128 K, console 512 K, pmsg 128 K; `max-reason = 4`).
- simplefb `0x18c00000` 1080×2312, stride 4320.
- `mmc@ff3e6000` (`hisilicon,kirin710-dwcmshc`):
  - reg: SDHCI + mmc_phy `ff3e1000` + mmc_sys `ff3e2000`;
  - `emmc_xin` 192 MHz sabit; `emmc_vcc` 3,0 V sabit regülatör;
  - 8 bit, non-removable, no-sd, no-sdio;
  - G34: `mmc-hs200-1_8v`, `max-frequency = 200000000`, **vqmmc yok** (stok 4.9 DT gibi; VCCQ donanımda 1.8 V, PMIC'e yazma yok);
  - hw-reset ve cqe yok.
- `usb@ff200000` glue (`karakutu,kirin710-dwc3`) + dwc3 çocuğu: `dr_mode = peripheral`, `utmi`, `dis_u2_susphy`, `dis_enblslpm`.
- `sensor-okuma@e896b000` (G34; G35'te reg = IPC, `interrupts = <GIC_SPI 197 IRQ_TYPE_LEVEL_HIGH>` (mailbox-0), `karakutu,ipc-unlock = 0x1acce551`, `adc-pil-kanal = 10`).
- **bootargs (G35):** `fbcon=font:TER16x32 consoleblank=0 panic=0 printk.devkmsg=on ignore_loglevel … clk_ignore_unused fsck.mode=skip systemd.gpt_auto=0 kk_debian_sinir=720`. G34'teki `kk_hs200_dusus_testi` (gösterim tamam) çıkarıldı.
- **G36-G48 düğümleri** (ayrıntı alt bölümlerde):
  - `thermal-zones` (sensör `#thermal-sensor-cells = <1>`, 5 bölge; `soc-max-thermal` 200 ms);
  - `i2c6: i2c@ffd6a000` (`disabled`, 100 kHz; kapı sürücüsü oluşturur) → `sarj@6b` (`karakutu,hi6523-oku`, `karakutu,sarj-politika`);
  - `/cpus/idle-states` (4.9 birebir; `karakutu,cpu-suspend-hvc`, `karakutu,varsayilan-kapali`);
  - i2c3 kapısı + `lm36274@11` (P1); `kk-guc-teshis`, `kk-wifi-m0` (`disabled`);
  - M1: `kk-sdio-kapi` + dwmmc2 (`hi3660-dw-mshc`, SPI 140, 4 bit, ≤ 400 kHz, `karakutu,sdio-yalniz`);
  - E2: mmc düğümünde `yazma-araligi <0x144c000 0x200000>` + bölüm adı/no/aralık/PARTUUID/kart sektörü.

### Reset, watchdog, ramoops
- **Reset:** reboot-mode PMIC'e nedeni SPMI ile yazar (`kk-spmi-syscon.c`; probe'da SPMI trafiği yok) → LPM3 NMI.
  - G27.4'te kesinleşti: `Unable to restart system` yok, ekran ≤0,2 sn'de sönüyor.
  - NMI ve PSCI tutmazsa watchdog reset yapar (`irq-is-reset` modunda `stop_on_reboot` yok).
- **SP805 (`sp805.diff`, `karakutu,irq-is-reset`):**
  - `load = rate × timeout` (tek aşama), `max_hw_heartbeat_ms = timeout/2`, kernel timeout/4'te (15 sn) besliyor;
  - `WATCHDOG_OPEN_TIMEOUT=180`: kullanıcı alanı açmazsa kernel +180 sn'e kadar besliyor (takılmada reset ~210 sn);
  - init besleyicisi 15 sn'de bir, sert sınır 900 sn;
  - Debian'a geçişte systemd devralıyor (`RuntimeWatchdogSec=60s`, `RebootWatchdogSec=2min`; QEMU T9b: PID 1 donunca 60 sn'de reset).
- **Gerçek durum ve donma davranışı (G48.4, `work/g48/wdt/TASARIM-WDT.md`):**
  - Bootloader normal açılışta SP805'i açar (`0xE8A06000`, SPI 44, LOAD 60<<15, CONTROL 3), fastboot'ta kapatır. Saat 32 764 Hz, saat kapısı yok.
  - Ana hat `sp805_wdt` + `irq-is-reset` devralır: tek aşama 60 sn, besleme 15 sn, reboot'ta durdurulmaz, NOWAYOUT. Besleme sırası çekirdek → initramfs `/init` → systemd.
  - **Ana hat donarsa:** SP805 reset'i AWDT sayılır → BFR (keypoint 70) → **eRecovery (bizim kurtarma, telnet 23)**; fastboot'a dönmez. Açılış döngüsüne karşı tek koruma bu BFR; keypoint 250 yazılırsa ya da `panic > 0` olursa çalışmayabilir.
  - 4.9 farkları (taşınmıyor): süre 24 (kesme 12 sn), besleme 3 sn, FIQ dökümü, LPM3 posta kutusu, belgesiz 0x018 yazması.
  - `timeleft` ≈ 2 kat fazla gösterir (`sp805_wdt.c:137-150`).
  - Öneri (onay O1-O11 bekliyor): düzen korunur, yeni donanım yazması yok; sp805 yazma beyaz listesi {0x000, 0x008, 0x00C, 0xC00} + yazma kanıtı; geri okuma + probe görüntüsü; soft/hard lockup + hung_task (önce yalnız uyarı).
- **Reset nedeni (G47, `kk-reset-nedeni`, P1'de):** PMIC 0x1E1 + SCTRL SCSYSSTAT 0x004 yalnız okunur (regmap; nesnede 2 `regmap_read`). Ana hat açılışında `0x1e1 = 0xff` (bootloader `set_reboot_type`), SCSYSSTAT 0.
- **Ramoops:** imza `DBGC`, 4.9 ile birebir uyumlu.
  - İki yönde çalışıyor: 4.9 ana hattın kaydını okuyor, ana hat 4.9'unkini okuyor.
  - Paniksiz watchdog reset'inde dmesg dökümü yok; console kaydı var.
  - 4.9 Debian'da `systemd-pstore` taşıyor; `kk-pstore-al` alıyor.

### Initramfs (`work/gNN/nefes/init`)
- Satırlar `<4>kk:` önekiyle kmsg'ye gider; ekranda ve pstore console'da görünür. Karşılama `KK-ANAHAT G<n> | uname=…`.
- **Sıra:**
  1. Ön bilgi (CPU, bellek, önceki pstore, watchdog).
  2. USB gadget (NCM, `lo up`), telnetd yalnız 2323.
  3. **eMMC salt okuma ölçümleri:** kart bilgisi, bölüm tablosu, ios, `vendor_a`'dan ≤256 MiB O_DIRECT hız, 5 bölümün sha'sı (kernel, erecovery_kernel, nvme, misc, vendor); `bul X → X_a`.
  4. (bootarg varsa) HS200 geri düşüş gösterimi.
  5. Red sayısı.
  6. **Debian:** kkdata süperbloktan `needs_recovery` okunur (+0x460 bit 0x4) → `ro,noload` bağlanır.
     - overlay: alt `/kk/data/kk/os/debian`, üst + work 256 MiB tmpfs;
     - üst katmana yapılandırma yazılır;
     - watchdog devri → `switch_root`.
- **Üst katman (Debian):**
  - maskeler: kk-wifi, kk-charge, kk-clock(-save), kk-ekran, kk-bootok, timesyncd, hwclock, systemd-pstore, apt-daily, man-db, dpkg-db-backup, e2scrub, fstrim, wpa_supplicant. **chrony/chronyd G37'den beri maskesiz** (drift ve log tmpfs'te; ana hatta RTC sürücüsü yok);
  - usb0 drop-in `zz-kk-anahat.conf`: `Gateway=172.16.42.2` (ana makine NAT, §10 Ağ). `kk-anahat-ip-yedek` gateway eklemez (karar: yalnız erişim yedeği);
  - sshd yalnız 2222 (drop-in `TimeoutStartSec=300`); hostname `kk-anahat-debian`;
  - journald volatile + `ForwardToKMsg`/`MaxLevelKMsg`; sysrq=0; `/run/systemd/reboot-param = bootloader`;
  - `kk-anahat-sinir` (`kk_debian_sinir`, şu an 720 sn → reboot bootloader); `kk-anahat-ip-yedek` (usb0 adresi yoksa ekler); `kk-anahat-isaret` (durum → kmsg).
- **Oturum sınırları:** initramfs oturumu 840 sn, Debian 720 sn; ikisi de `reboot bootloader` ile biter.
  - Test imajlarında `kk_debian_sinir=1200` (G42'den beri). init yalnız kısaltmaya izin verir (varsayılan 1740).
  - Sınır `OnBootSec` (monotonik); chrony'nin ilk açılıştaki ~201 günlük adımı etkilemez (G38).
- initramfs çekirdeğin mmc satırlarını `kk: dmesg:` önekiyle yansıtır; dmesg'de `write blocked` 10-11 satır görünür (5 asıl + 5 yansı + özet). Sayan komutlar süzmeli (G48).
- **Ölçülen (G34):** telnet 2323 T0+19 sn; SSH 2222 T0+116 sn; `systemctl reboot` → fastboot 15 sn.

### eMMC sürücüsü (`sdhci-of-dwcmshc.c`, Kirin bölümü)
- **Denetleyici:** DWC MSHC. Her RESET_ALL'da `CARD_IS_EMMC`, MSHC_CTRL, MBIU WRITE_OSRC_LMT=3 (4.9 Libra'dan).
- **Strobe kapısı (G30):** `EMMC_SYS_CTRL0` bit0 `GT_STROBE_RX_CLK`. `set_uhs_signaling` başında HS400'de 0, diğerlerinde 1. Bootloader 0 bırakıyordu (G29'un nedeni). Cihazda `0x2aaa → 0x2aab`.
- **Bootloader'ın bıraktığı PHY:** `DLY_CTL = 0xb006e371`, `DLY_CTL1 = 0x9600dc01`, `IMPSTAT 0x17171515`. PHY reset/init/ZQ, gecikme ölçümü ve `GT_CLK_EMMC` taşınmadı (gerekçe RECON G30). Teşhis dökümleri salt okuma.
- **HS200 (G34), 4.9 tuning'inin birebir portu:**
  - `sdhci_execute_tuning` + `kk_kirin710_soft_tuning`: 64 faz, `SW_TUNE_EN` (AT_CTRL bit4), sys CTRL1 TUNING_SEL/EXTEND, AT_STAT CENTER_PH_CODE; en uzun pencerenin ortası;
  - standart başarısızsa yazılım fazı, başarılıysa donanım fazı; sonra TUNED_CLK;
  - sapma: 4.9'un 4 baytlık `memcmp` hatası yerine bloğun tamamı karşılaştırılıyor.
  - **Cihazda:** ana hattın standart tuning'i başarısız (`tuning_err = -11`, "falling back to fixed sampling clock"); yazılım tuning'i 37/64 faz geçti, faz 44 (sonraki init'te 36/64, faz 45).
  - Sonuç: **192 MHz, 8 bit, 1.8 V, 161,7 MB/s** (HS 44 MB/s; 4.9 HS400 226 MB/s).
  - HS400/ES ve CQE kapalı.
- **Geri düşüş:** `mmc.c` `kk_hs200_vazgec()`: HS200 seçimi ya da tuning başarısızsa HS200/HS400 yeteneği kaldırılır, init hata döner, `mmc_rescan` kartı CMD0'dan HS ile açar.
  - `sdhci_of_dwcmshc.kk_tuning_hata` (0644) tuning'i zorla başarısız yapar.
  - G34'te cihazda gösterildi: HS200 → (zorla) HS 48 MHz 3.3 V → HS200.

### eMMC salt okuma güvenlik katmanları
1. **Tek geçit filtresi** (`core.c` `__mmc_start_request` + `mmc_cqe_start_req`, `kk_mmc_neden`): red `-EPERM`, yeniden deneme yok, log `kk: mmc write blocked: …`.
2. **Katı mod** (`host->kk_strict`, hiç kapanmaz):
   - DT `no-sd` ya da kart CMD1'e yanıt verince açılır; log `kk: kati mod acik` (her probe'da).
   - `mmc_core.kk_kati=1` yalnız sıkılaştırır.
   - Karar yalnız opcode + argümana bakar; veri yönü sabittir.
   - **İzin tablosu** (listede olmayan her şey kapalı):
     - CMD0 arg=0; CMD1, 2;
     - CMD3/7/9/10/12/13 arg[15:0]=0; CMD5 arg[14:0]=0;
     - CMD8 okuma arg=0; CMD16 arg=512; CMD17/18 okuma;
     - CMD23 yalnız 17/18'in sbc'si; CMD12 stop;
     - **CMD21 okuma arg=0 (G34)**;
     - CMD6 yalnız beyaz listeyle.
   - CMD55/ACMD, veri taşıyan CMD6, CMD11/15/52 yasak.
3. **CMD6 beyaz listesi** (`kk_switch_izinli`, WRITE_BYTE, set NORMAL; diğerleri karta gitmeden `-EBADMSG`):
   - `HS_TIMING` ∈ {0x00, 0x01, **0x02** (G34)};
   - `BUS_WIDTH` ∈ {0, 1, 2};
   - `PART_CONFIG` = ham & ~7 (boot bitleri değişmez).
4. `MMC_IOC_CMD` / `MULTI_CMD` katı modda tümden `-EPERM` (RPMB dahil).

- **Belgelenmiş istisna (G34), filtreyi atlayan tek yol:** ana hattın standart tuning'i (`sdhci_execute_tuning` → `sdhci_send_tuning`) CMD21'i (SEND_TUNING_BLOCK_HS200) mmc core'dan geçirmeden, denetleyiciye doğrudan yazar.
  - Komut sabit: opcode 21, okuma (64/128 baytlık desen bloğu), arg 0. Çağıran yalnız HS200 tuning'i.
  - Katı modun bu komut için izin verdiği şeyle aynı (CMD21 okuma, arg=0). Yazma ya da başka opcode taşımaz.
  - Yazılım tuning'inin (`kk_kirin710_soft_tuning` → `mmc_send_tuning`) CMD21'leri ise filtreden geçer.
5. Ek savunma: `mmc_blk_readonly() = 1`, `BOOTPART_NOACC` (boot0/1 aygıtı yok). Reboot yolunda cache flush ve power-off bildirimi yok.

- **A.2 tablosu (gerçek EXT_CSD ile init):**
  - 5 CMD6 reddedilir: 175 ERASE_GROUP_DEF, 34 POWER_OFF_NOTIFICATION, 187 POWER_CLASS (HS'de 0x09, HS200'de 0x0e), 161 HPI_MGMT, 33 CACHE_CTRL.
  - Yan etkiler: `power class selection … failed`, `Enabling HPI failed`, `Cache … failed to turn on (-74)`.
- **EXT_CSD:**
  - rev 8, DEVICE_TYPE 0x57, PART_CONFIG 0x08, HS_TIMING 3 (4.9 HS400);
  - CACHE 4 MB açık, BKOPS otomatik, CMDQ destekli ama kapalı;
  - SEC_COUNT 244 277 248.
  - Döküm `work/g29/ext_csd-4.9.bin`.
- **Birim testleri:**
  - G29: 691 200 durum.
  - G34: filtre 783 360 durum, beyaz liste 83 886 080 üçlü. Daralma 0, beklenmeyen genişleme 0.

### USB (G32)
- DWC_usb3 3.20a (GSNPSID `0x5533320a`), yalnız USB2, IRQ SPI 161. Ana hatta uygun PHY sürücüsü yok (`phy-hi3660-usb3` bit yerleşimi farklı).
- **Sargı `dwc3-kk-kirin710.c`:** 4.9 `dwc3_release` sırası, her yazma loglanır:
  - CRG PEREN0/PERRSTDIS0, ISODIS;
  - PCTRL PERI_CTRL3/24;
  - otg_bc sahte VBUS;
  - eye `0x07ff66df`.
- Reset'ten çıkmadan dwc3 probe edilmez (GSNPSID okuması veri yolunu kilitleyebilir).
- PMIC 0x37 (`clk_abb_192`) yalnız okunur; bootloader açık bırakıyor. BC algılaması koşulmuyor.
- Gadget `1d6b:0104` "Kara Kutu", NCM, HS 480 Mbps.

### Sensörler ve sıcaklık sigortası (G34-G35, `drivers/misc/kk-sensor-okuma.c`)
- **Sınıflar (4.9 kaynağından):**

  | Değer | Yol | Sınıf |
  |---|---|---|
  | Pil V/I | coul SPMI 0x2D2-0x2D5 | **A** (saf okuma) |
  | CPU frekans oyu | PMCTRL 0x2DC | **A** |
  | Pil sıcaklığı, kart NTC'leri | HKADC, LPM3 mailbox 16 `{0x000B020C, ch}` | **C** (LPM3 mesajı) |
  | SoC tsensor | ATF SMC `0xC5009900` | **S** |
  | Şarj IC ADC | hi6523, yazma gerekir | B |

- **A (G34):** 30 sn'de bir `kk: sensor:` satırı + sysfs `durum`.
  - Gerilim `kod & 0x7fff × 2400000/10661`. G35'te ×1,014 kaldırıldı; 4.9'la fark 2-5 mV.
  - Akım `s16 × 5e6/10661 × 10/r_mohm`; + = deşarj.
- **C, pil sıcaklığı (G35):** 4.9 `hisi_adc` + `hisi_mailbox_dev` ile birebir.
  - IPC `0xE896B000`; TX mailbox-16 (AP bit0 → LPM3 bit3), AUTO_ACK.
  - Sıra: ensure_channel/bırak → LOCK `0xA00` ← `0x1ACCE551` → işgal (SRC ← BIT0) → IMASK, DSET, MODE = 1, DATA0 = `0x000B020C`, DATA1 = 10, SEND = BIT0.
  - RX mailbox-0 (SPI 197): DATA[0..7] oku → sıfırla → ICLR (GIC_1|GIC_2 & ~IMASK) → gerekirse SEND.
  - Yanıt `0x080B020C`, ham ADC DATA1[31:16].
  - **30 sn'de en fazla bir istek, 1500 ms zaman aşımı, tekrar yok.** Dönüşüm coul `T_V_TABLE` (doğrusal, m°C).
  - Cihazda 157 sn'de 6/6 yanıt, zaman aşımı 0; ADC 1457-1463 ≈ 25,0 °C.
- **S, SoC sıcaklığı (G35):** `arm_smccc_smc(0xC5009900, 0..3, 0, 0)` (cluster0, cluster1, gpu, modem), 5 sn'de bir. `T = (kod − 116) × 165/806 − 40`. Kod 116-922 dışı = geçersiz.
  - Cihazda ana hat aynı uptime'da 4.9'dan ~1-3 °C sıcak (G35; o zaman cpuidle/cpufreq yoktu).
  - G36: `get_temp` aynı SMC, önbellek 500 ms → **G37: 100 ms**. En çok ~10 SMC turu/sn (tur = 4 SMC).
  - G42: `kk_sensor_pil()` = coul V/I + önbellekteki pil sıcaklığı (yeni LPM3 isteği yok; 75 sn'den eskiyse geçersiz). Şarj politikası bunu kullanır.
- **Sigorta (G35, çekirdek içinde):** pil > 45 000 / en sıcak SoC > 70 000 m°C, aynı kaynakta 2 ardışık geçerli okuma → `KERN_EMERG kk: sigorta:` → `kernel_restart("bootloader")`.
  - Anlamsız değerler (< 0, > 150 °C, tablo uçları, aralık dışı kod, zaman aşımı) tetiklemez, log'a düşer.
  - sysfs `pil_esik_mc` / `soc_esik_mc` yalnız düşürülebilir.
  - Cihazda: SoC eşiği 30 000'e çekildi → 5 sn arayla 1/2, 2/2 → bootloader; eşik düşürüldükten 21 sn sonra fastboot.
  - G39'dan beri sigorta reboot'tan önce `kk_sarj_sigorta(300)` çağırır: ayrı işte CHG_EN=0 + geri okuma, en çok 300 ms, reboot geciktirilmez. Cihazda (G42) yazma + geri okuma 0 ms, işlem 36 ms.
  - Karar (G39): günlük sistemde sigorta hedefi eRecovery olacak (henüz uygulanmadı).
- **QEMU sahte kaynak:** DT `karakutu,sahte-kaynak` (yalnız `virt-g35.dts`). T20-T25: normal, pil sıcak, SoC sıcak, anlamsız, sysfs SoC/pil eşiği.
- tsensor MMIO'yu normal dünyadan doğrudan okumak yasak.

### cpufreq ve thermal (Tur 3-4, G36-G37)
- **`drivers/cpufreq/kk-kirin710-cpufreq.c`:** 4.9 hw_vote birebir.
  - Yalnız oy yazmaçları 0x270 (big) / 0x280 (little): `writel(wr_mask | (MHz/16) << shift)`. GPU 0x290'a ve vote-src-2'ye yazmaz; başka adresi reddeder.
  - Her oydan sonra 0x2DC en çok 20 ms yoklanır; oy yazmacı da geri okunur (geri okumada `0x0000ff6a`: vote-src-2 alanı 0xff, "oy yok" [çıkarım]).
  - Tablolar DT'den (§11). En yakın frekans araması elle yazıldı (çekirdeğin `cpufreq_table_find_index_c`'si sıralanmamış tabloda 0 kHz için 1709 MHz seçti; QEMU T30).
  - Governor performance (P1'de schedutil).
  - **G37 log sınırı:** satır yalnız kümenin ilk 64 oyunda, her FARKLI'da ve her 50. oyda. Toplamlar `/sys/module/kk_kirin710_cpufreq/parameters/{oy_toplam,uyusmaz_toplam,en_uzun_us}`. Gerekçe: 200 ms yoklamayla her oy loglansa pstore konsolu (512 KiB) açılış kanıtını taşırırdı.
- **Thermal:** `soc-max-thermal` (bölge 4 = en sıcak sensör), governor **step_wise** (güç modeli istemez, deterministik).

  | Trip | Kısıt |
  |---|---|
  | `kisma` 55 °C | iki küme, tüm aralık |
  | `sert` 60 °C | little ≤ 1440, big ≤ 1460 MHz |
  | `taban` 63 °C | little 480, big 807 MHz |

  - 2 °C histerezis; sigorta 70 °C'de ayrı.
  - Yoklama G36'da 2000 / pasif 1000 ms → **G37: 200 / 200 ms** (4.9 IPA 200 ms). Diğer 4 bölge (yalnız 125 °C `hot`) 5000 ms.
  - Big tavanı 2189 MHz'de kalıyor (karar G37). Sonuçlar §11.

### Ağ: USB NCM + ana makine NAT (Tur 4, G37-G38)
- Ana hat Debian: usb0 `Gateway=172.16.42.2`; DNS alt katmanın `resolv.conf`'u (<LAN_ADRESI>, 1.1.1.1); chrony açık.
- **ana makine (bakımcı uyguladı, G38):**
  - `05-kk-p30.network`'e `IPMasquerade=ipv4` (sha `99032fc7…`; önceki `1d4c2b75…`, `work/g37/ana-makine/`);
  - `ufw route allow in on enx024b4b000002 out on wlp3s0 from 172.16.42.0/24 comment 'kara-kutu G37 P30 NAT'` (ufw `DEFAULT_FORWARD_POLICY="DROP"` olduğu için masquerade tek başına yetmez);
  - nft: `io.systemd.nat`, `masq_saddr = { 172.16.42.0/24 }`.
  - Geri alma: `.oncesi` dosyası + reload/reconfigure + `ufw route delete …`. `ip_forward`, netplan ve diğer ağ arayüzleri değişmedi.
- Sonuçlar §11.

### Şarj kontrolü (Tur 5, G38-G43)
- **Çip ve yol:** hi6523 = 4.9 `schargerV300` (V200 dizini hi6522 içindir). i2c6 `0xffd6a000` (designware, SPI 117), adres 0x6B.
  - Yazmaçlar: CHG_REG0..5 0x90..0x95 (0x90 b5 CHG_EN, b4 BATFET), BUCK_REG0 (IIN) 0x60, STATUS0 0x06, STATUS1 0x07, HiZ 0xA3 b0, OTG 0x80, WDT besleme 0xE8 b0, WDT_CTRL 0xE9[1:0] (0/10/20/40 sn).
  - Kod çözümü `kk-hi6523.h` (4.9 tabloları: IIN kod 2 = 470 mA; ICHG 100 + 100k; VTERM 3800 + 50k mV).
- **`kk-i2c6-kapi.c`** (G39 yalnız okur → G40 4.9 gibi açar):
  - Okur: CRG `0xffd7e000` +0x18 b27 (kapı durumu), +0x28 b27 (reset), pinmux `0xfff11000` +0x710/+0x714, pinconf `0xfff11800` +0x710/+0x714.
  - Reset aktifse hiç yazmaz → DUR. Eksik adımları sırayla yapar, her yazmadan sonra geri okur:
    1. CRG +0x10 ← BIT(27) (tek yazma); durum = önceki | BIT(27) olmalı, başka bit değişirse DUR;
    2. pinmux 0 → 1 (1 ise yazmaz, başka değer DUR);
    3. pinconf `(v & 0x73) == 0x10` değilse 4.9 değeri.
  - Geri okuma tutmazsa geri alma denenmez, i2c6 aygıtı oluşturulmaz.
- **`kk-hi6523-oku.c`:** yalnız `i2c_smbus_read_byte_data`. Okunanlar 0x07, 0x60, 0x80, 0x90-0x95, 0xA3, 0xE9; `CONFIG_KK_HI6523_O1` ile 0x06 ve 0x8E (G44; 0x62 olağan okuma doğrulanamadığı için okunmaz). Kesme yazmaçları ve ADC okunmaz.
  - Probe'da 1 tur → 60 sn I2C yok → 30 sn'de bir (`kk_hi6523_oku.periyot_sn`, en az 5). 3 ardışık hatada durur.
- **Politika `kk-sarj.c`** (çekirdekte; initramfs'te ve kullanıcı alanı düşse de sürer):
  - Durumlar: BASLA → DINLENME (CHG_EN=0; dinlenme süresi + |ibat| ≤ 30 mA → OCV) → OCV ≥ üst: BEKLE; ≤ alt: SARJ; bant içi: dolduruyorsa SARJ. Yük altında yüklü vbat ≤ alt ise erken SARJ.
  - **Bant 3844 / 3929 mV:** 4.9 pil profili `desaysony_3240_110k_4400_25`, 25 °C'de %50 = 3844 mV; üst = 4.9'un ölçülen "%60"ı (profilde ≈ %62).
  - Sıcaklık 42 / 38 °C; geçersizse kapalı. Şarj altında vbat tavanı 4150 mV.
  - Pencere 1200 sn. OCV üst eşiğe 45 mV'tan (`yakin_mv`) yakınsa ya da taze OCV yoksa kısa pencere 300 sn (en kötü taşma ≈ %1,27). Dinlenme 180 sn, tik 5 sn.
  - Parametre kapısı: CHG_EN=1'den hemen önce taze 0x60/0x91/0x92 → VTERM ≤ 4400, ICHG ≤ 500, IIN ≤ 470 mA.
  - Engeller (her tikte önce): etkin değil, sıcaklık, parametre, 3 ardışık okuma hatası, 3 ardışık yazma hatası (kalıcı).
  - Tutarlılık: SARJ dışında CHG_EN=1 → kapat ("beklenmedik"); SARJ'da CHG_EN=0 → `DONANIM KESTI` → DINLENME.
  - sysfs (`…/sarj/`) yalnız daraltır: `ust_mv`↓, `alt_mv`↑ (arada ≥ 20 mV), `sicak_mc`↓, `soguk_mc`↓, `pencere_sn`↓, `kisa_pencere_sn`↓, `yakin_mv`↑, `dinlenme_sn`↑, `etkin` yalnız 0. Ret EPERM; her değişiklik loglanır.
- **WDT katmanı (G42, "açık + besleme"):**
  - Pencere başı: 0xE9 ← 3 (oku-değiştir-yaz + geri okuma; kurulamazsa `ENGEL:wdt-kurulamadi`, CHG_EN yazılmaz) → CHG_EN=1 + geri okuma → hemen ilk besleme.
  - Besleme `kk_besle` = 4.9 `hi6523_reset_watchdog_timer` birebir (0xE8 oku → b0=1 → yaz; geri okuma yok, darbe biti). 10 sn'de bir (DT; en çok 20).
  - Besleme yalnız sağlıklıyken: SARJ, geçerli ve eşik altı sıcaklık, parametre kapısı, son tur I2C hatasız, vbat tavan altı, pencere içi.
  - Sağlıksızlıkta `kk_kapat`: CHG_EN=0 + geri okuma; tutmazsa son bilinen 0x90 ile bir doğrudan yazma. Pencere sonunda 0xE9'a 0 yazılmaz; çip ≤ 40 sn'de kendisi keser.
  - Kalıcı engel: 3 ardışık WDT kurma ya da 3 ardışık besleme hatası. Sigorta atınca süren tik artık CHG_EN=1 yazamaz ve besleyemez (atomik bayrak).
- **Kapanış kancası (G43):** `register_reboot_notifier` (öncelik 200). Bayrağı atomik kaldırır; SARJ'daysa sigortayla aynı yol (`kk_zamanli_kes`, 300 ms, reboot geciktirilmez); değilse yazma yok. Panikte çalışmaz (`emergency_restart` notifier çağırmaz); orada çip WDT'si ≤ 40 sn'de keser.
- **Yazma kümesi ve kanıtı:** `i2c_smbus_write_byte_data`'yı yalnız `kk_d_chg0_yaz` / `kk_d_wdt_yaz` / `kk_d_besle_yaz` çağırır; register argümanı sabit (`mov w1, #0x90/#0xe9/#0xe8`). `.detect` yapan sürücü yok. Her imajda objdump/nm ile `yazma-kaniti.txt`.
- **Yalnız test/QEMU:**
  - `KK_SARJ_TEST`: cmdline `kk_sarj.test_{alt_mv,ust_mv,pencere_sn,dinlenme_sn}` (sınır dışıysa REDDEDILDI, üretim değerleri), sysfs `test_besleme_kes`;
  - `KK_HI6523_DENEY` (G40-G41 tek seferlik CHG_EN deneyi; sonraki imajlarda yok);
  - `kk-sarj-sahte.c`: 256 baytlık sahte çip, WDT/besleme modeli, hata enjeksiyonu.
- **Üretim imajı** (kanca dahil) `2cde4b56…` hazır, cihaza gitmedi; uzun koşu günlük sistem turunda.
- **Faz 4 tasarımı** (G43, `work/g43/faz4/TASARIM-faz4.md`; uygulama Wi-Fi M3'e kadar bekler, onaylar O2-O9):
  - takma/çıkarma: PMIC 0x06 b1 + hi6523 0x06 b7, 1 sn yoklama;
  - BC1.2 4.9 birebir (0xFF200000 +0x24/+0x28/+0x2C yazma, +0x44 durum; dwc3 çocuğu oluşmadan önce);
  - IIN SDP 470 / CDP 1500 / DCP 2000 mA (belirsizlikte 470); ICHG 500 yazılmaz; IIN > 470 için aşırı akım koruması.

### Verim (G44-G48)
- **`kk-guc-teshis.c` (G44, salt okuma, M0 deseni):**
  - CRG PERCLKEN/PERSTAT 0,1,2,4,7; PERRSTSTAT 0,1,2,4; PERPWRSTAT 0x158; PERPWRACK 0x15C. SCTRL SCPERCLKEN0/SCPERSTAT0, SCPERRSTSTAT0 0x208, SCBAKDATA4 0x41C. PMCTRL 0x2DC, 0x350 PERI_CTRL4, 0x354 PERI_CTRL5 (G47 S1'de + 0x2A0-0x2BC, 0x2E0).
  - Kanıt sınıfları: A = bizim 4.9 olağan okuyor; B = yalnız hata dökümü; C = yalnız stok 4.9; D = okuyucu yok. Yalnız A okunur; B sınıfı (ISOSTAT, PERSTAT3/5/6, NoC idle…) karar bekliyor.
  - Dar bölgeler (CRG 0x430, SCTRL 0x420, PMCTRL 0x358), NS sınırı (CRG < 0xC00, SCTRL < 0x800), tek `readl` yolu `kk_rd`. lpmcu, DDRC/DMSS, PMIC yok. İki döküm: probe ve `ikinci_sn` (300) sonra.
  - Araç `work/g44/teshis/saat-haritasi.py`: 4.9 canlı DT'den CRG/SCTRL kapı biti → saat adı (147 bit).
- **cpuidle (G45):**
  - `psci.c`: `/cpus/idle-states`'te `karakutu,cpu-suspend-hvc` varsa **yalnız CPU_SUSPEND** hvc ile (4.9 `method = "hvc"`, v0.1 `cpu_suspend = <0xc4000001>`). CPU_ON, SYSTEM_RESET, FEATURES smc'de kalır (tümden hvc PSCI kurulumunu HHEE'ye yollar). `FEATURES(CPU_SUSPEND)` loglanır; genişletilmiş biçimse cpuidle kaydolmaz. Cihazda `0x0 -> orijinal bicim`.
  - `dt_idle_states.c`: `karakutu,varsayilan-kapali` → `CPUIDLE_FLAG_OFF`; her açılış kapalı, sysfs `disable=0` ile açılır.
  - DTS 4.9 canlı DT birebir: cpu-sleep-0 0x10000 (40/70/3000 µs), cluster-sleep-0 (A53) 0x1010000 (500/5000/20000), cluster-sleep-1 (A73) 0x1010000 (1000/5000/20000); local-timer-stop. cpu-nap-0 alınmadı (4.9'da bağlı CPU yok). sp804 yok, broadcast `bc_hrtimer`. LPM3 koordinasyonu yok (4.9'da da doğrudan PSCI).
- **schedutil (G45 → P1):** `CPU_FREQ_DEFAULT_GOV_SCHEDUTIL=y`; geri alma kolu cmdline `cpufreq.default_governor=performance`.
- **`kk-idle-bekci` (G47 D1/D2, P1'de):**
  - initramfs `karar` + Debian timer: açılıştan 120 sn sonra A1 (çekirdek durumları) → A2 (A53 küme) → A3 (A73 küme). Her aşamada geri okuma + 60 sn sağlık; hata → hepsi kapalı. 10 dk'lık durum timer'ı.
  - Döngü koruması önceki açılışın `console-ramoops-0` ve pmsg kaydından (PSTORE_PMSG): son satır `reboot: Restarting/Power down/System halted` değilse ya da panic/SError/Oops/BUG/stall/lockup/hung_task varsa anormal (`writing error (-28)` yok sayılır). Bir anormal → bir seviye geri, iki → kapalı, bilinmiyor → açılmaz. Sayaç eMMC'siz.
  - 4.9 her açılışta console/pmsg bölgelerini siler (`ram.c:496, 665`); ana hatta systemd-pstore maskeli.
  - Test bayrağı (D2): DTB `/chosen`'a `kk_idle_test_onceki=anormal` + `karakutu,idle-test`.
  - Bekçi satırları (`kk-idle:`) kullanıcı alanından `/dev/kmsg`'ye yazılıyor; bu imajlarda journald'da (`-k`'lı ya da `-k`'sız) görünmedi, **dmesg'den okunur** (G47-G48) [çıkarım].
- **Arka ışık (G47 S1 → P1):**
  - `kk-i2c3-kapi`: açılışta yalnız okur. Yazma beyaz listesi 4 girdi (PEREN2/PERRSTDIS2 ← 0x80, iomg 0x700/0x704 ← 1). i2c3 reset yazmaçları PERRSTEN2/DIS2/STAT2 (0x78/0x7C/0x80).
  - `kk-lm36274` (i2c3 0x11) **üretim kipi (P1):** probe yalnız okur; **0x0F hiçbir yolda okunmaz**; beyaz liste {0x04 ← 0, 0x05 ← 0}, açılış başına ≤ 2 yazma; `geri` derlenmez (ışığı yeniden açan yol yok; reboot 1252/2047'ye döndürür).
  - Bekçide **A0** (her AC kararında A1'den önce): kapı → `3-0011` (≤ 30 sn) → kimlik → `kapat` → canlı geri okuma. A0 hatası → bütün cpuidle kapalı, LM'ye başka yazma yok. A0 yazmalı DUR → izin 0; yazmasız DUR → ceza yok (ceza kuralı tasarım onayı bekliyor).
  - `kk-ddr-oy` (S1; 0x2B8 ← 4.9 değeri, yalnız koşul varsa) P1'de yok.
- **4.9 tarafı ölçümü (G46):** kk-bin `kk-49-ekran-olcum` (`bb6fcdcd…`): kendi sha'sını manifestle, `uname ^4\.9\.`'u ve uzak betik sha'sını denetler; cihazda `systemd-run` (RuntimeMaxSec 600), trap EXIT/INT/TERM/HUP ile geri alma (blank=4, enable_charger=0, kk-charge/kk-ekran), ölü adam 660 sn aynı betikte iptal + doğrulama. Yalnız 15a dosyalarını okur. Yerel sınama 6/6.
- **Ölçüm düzeni:** ölçer = hi6523 şarj penceresi (ACL rejiminde giriş gücü sabit; ibat farkı = sistem tüketim farkı). Cihazda tek satırlık `systemd-run` denetleyicileri (`kk-verim-deney`, `kk-verim-kararlilik`, `kk-frekans-deney`), trap ile geri alma. Üretici `work/g45/b/denetleyici-uret.py`, analiz `b/analiz.py`. Sonuçlar §11.

### eMMC yazma penceresi (G45-G48)
- **Kod** (G45 tasarım, G46 uygulama `emmc-yazma-g46.diff` +559/−0, G47'de M1 ağacına yeniden tabanlandı): `CONFIG_KK_EMMC_YAZMA` varsayılan n; kapalıyken 21 nesnenin 18'i bayt bayt aynı (3'ünde yalnız `__bug_table`).
  - Pencere DT'de mutlak sektör. Açılışta GPT (ad, no, başlangıç, boy, PARTUUID, kesişme) ve EXT_CSD (SEC_COUNT, PART_CONFIG erişimi 0, CACHE_CTRL 0, WR_REL_SET) ile çapraz denetim; tutmazsa pencere hazırlanmaz.
  - İki bağımsız katman: blok (`kk_blk_istek_neden`: yalnız pencere içi; discard/erase/write-zeroes red) + core filtresi (CMD24/25 yalnız açık pencerede, eMMC kartta, kullanıcı alanında; CMD23 = blok sayısı; sbc yoksa CMD12).
  - Durum: yok → hazır → açık → kilitli; varsayılan kapalı, `kapat` geri alınamaz. sysfs `/sys/block/mmcblk0/kk_yazma`.
  - CMD6 beyaz listesi değişmedi; önbellek kapalı; REL_WR (b31) ve veri etiketi (b29) kapalı (aksi hâlde FUA'lı ext4 commit'leri EIO); silme ailesi kapalı. Asla: boot0/1, RPMB, GP, write-protect, kilit.
  - Pencere istek başına: aşan yazmanın içteki kısmı yazılır, dışı EIO (atomiklik yok). Pencere yalnız katı host'ta okunur, SDIO-yalnız host'ta okunmaz.
  - Birim: P0K-P9 + E2E fark/ihlal 0 (CMD6 67 108 864 vaka, izinli 28); mutasyon 47/48 (m13 eşdeğer). QEMU 13 senaryo / 190 denetim, beklenmeyen 0 (dm-linear, loop, kirli reset dahil).
  - **Açık (G48):** çekirdek doğrulaması 8 sektör hizasını ve uzunluğu denetlemiyor (QEMU q-hiza/q-say pencereyi `HAZIR` yaptı). Koruma bugün kullanıcı alanında (build.sh, kk-49-alan, E2 denetimleri). E4'ten önce çekirdeğe eklenmesi önerildi.
- **Alan dosyası (seçenek C):** kkdata içinde 4.9'da oluşturulmuş 1 GiB, fiziksel ardışık, `chattr +i` `alan.img`. Ana hat penceresi onun LBA aralığı; kkdata ana hatta `ro,noload`. kkdata asla küçültülmez; onarımdan sonra FIEMAP yeniden denetlenir (immutable, resize2fs ve `e2fsck -y` klonlamasını engellemez).
  - kk-bin **`kk-49-alan`** (G47 `2ff09e47…` → G48 `81c95e4f…`): `denetle|prova|olustur`. Cihaz parçası `systemd-run` (RuntimeMaxSec 900); `trap` BITTI değilse dosyayı ve açılan dizinleri siler. Denetimler: p68 başlangıç/boy/ad/PARTUUID, ext4 rw ve data=journal değil, boş alan ≥ 2 × boy, dosya varsa DUR.
  - `olustur` (G48, b2): 6 GiB fallocate → FIEMAP'te mantıksal + fiziksel ardışık ilk 1 GiB (`sec`) → `fallocate --collapse-range` + `truncate 1G` → sıfır yazma (`dd bs=4M conv=notrunc,fsync oflag=direct`) → `UNIX_IO_NOZEROOUT=1 mke2fs -t ext4 -b 4096 -L kk-anahat -E nodiscard,lazy_itable_init=0,lazy_journal_init=0` → `chattr +i` + lsattr + yazma denemesi başarısız olmalı → `e2fsck -fn` → FIEMAP 1 = 2 = 3.
  - `prova`: 512 MiB dosyada collapse 128 MiB + truncate 256 MiB; birleştirilmiş fiziksel harita önce = sonra.
  - **Nokta kaydı:** 6 noktanın (0, 128, 384, 640, 896 MiB, son 4 KiB) 4 KiB sha'sı dosyadan ve p68'den ham (`iflag=direct`) eşit olmalı; en az 2 sıfır dışı; W_BAS 8'in katı ve p68 içinde; unwritten 0.
  - Yerel sınama 15 senaryo + 8 birim GECTI.
- **E1/E2 imajları:** E1 `62b4a755…` (pencere yok); E2 `a35dece6…` (E1 Image aynen + DTB'de 6 özellik; `build.sh e2 <W_BAS> 2097152 <etiket>`). E2 QEMU 12/12 senaryo, 157 denetim (10 olumsuz: PARTUUID/ad/no/aralık, kapasite, GPT kaydırma, W_BAS +4, taşma, W_SAY −8); `ac` yokken 13/13 yazma girişimi reddedildi.
  - Cihazda E2 denetimleri S1-S9: DT ↔ sysfs GPT ↔ kapasite ↔ ham GPT (LBA1), EXT_CSD, pencere aygıtı ve dosya nokta okumaları, diskstats.
- **E4 onay paketi (G48, kurulmadı):** `work/g48/emmc/E4-ONAY-PAKETI.md`. Yeni betik önerisi `kk-anahat-pencere` (`denetle`/`yaz`) + `kk-49-alan oku` modu (kk-bin, bakımcı onayı). E1/E2 çekirdeğinde LOOP/DM olmadığından öneri: E2 imajıyla ham tek O_DIRECT yazma (alan.img 1022 MiB ofseti, iç fs'te boş 1 MiB) → `kapat`; alternatif LOOP=y yeni çekirdek. QEMU provası 4/4 senaryo, 16 denetim.

### Wi-Fi Hi1102 (G36-G48)
- **Port hattı (masa başı; `work/g41/wifi/`, `work/g42/wifi/`, `work/g43/wifi/` raporları):**
  - STA alt kümesi 81 dosya / 122 301 satır (4.9 derlemesi 190 206); 41 `_PRE_WLAN_FEATURE_*` makrosu firmware ABI'si yüzünden değişmez.
  - 6.12'ye karşı derleme: hata yeri 62 → 45 (ortak başlıklar, G42) → **0** (G43, 81/81 birim). modpost 220 çözülmeyen → 0 (**199 stub**; kritik: `get_ec_version` = V120, `store_efuse_info` boş, `bfgx_is_shutdown` true).
  - NVE yerine MAC modül parametresi (yoksa rastgele; yazma `-EACCES`); `sdio_reinit` → `mmc_hw_reset`; `sched_setscheduler`/`vfs_*`/`kallsyms_lookup_name` kaldırıldı.
  - Aşamalar M0 salt okuma → M1 kart görünür → M2 firmware → M3 tarama → M4 bağlantı/DHCP (`p2p_disabled=1`) → M5 SDR104 (isteğe bağlı). Efor M0-M4 ≈ 18-34 kişi-günü (G42 tahmini).
  - Cihaz çekirdeği tam sürücü için hazır değil: `MODULES`, `CFG80211`, `GPIOLIB` kapalı; kullanılan 245 sembolün 47'si cihaz vmlinux'unda yok (G43).
- **M0 (G42 kod, G43 cihaz):** `kk-wifi-m0.c` salt okuma. Önce CRG/SCTRL durum yazmaçları; blok yalnız kapısı açık (PERCLKEN ve PERSTAT) ve reset bırakılmışsa okunur, değilse `OKUNMADI: neden`. PMIC 0x3E yalnız SPMI regmap okuması.
  - Adres düzeltmeleri: CLKDIV19 (0xf4) SDIO kapıları b6 (sys) ve b8; SCTRL gerçek durum 0x16C SCPERSTAT0; iomg/iocg-mmc1 kapısı PERSTAT7 b21, reset PERRSTSTAT4 b10.
- **M1 (G44 tasarım, G45 kod, G46 Faz A cihazda salt okuma):**
  - Filtre "SDIO-yalnız host" (`karakutu,sdio-yalniz` + `no-sd` + `no-mmc` + `non-removable`): izin CMD0/3/5/7/52/53 spec sınırlarıyla, CMD53 yalnız SDIO kartta; katı mod önce gelir. Birim 324 403 200 karar, eMMC daralma 0, beklenmeyen genişleme 0 (`filtre-g44.diff`).
  - `kk-sdio-kapi.c` (G40 deseni; `kk_sdio_kapi.ac=1` yoksa 0 erişim): bütün MMIO yazmaları tek işlevde (`kk_sdio_yaz`), 11 girdilik derlenmiş izin tablosu; her adım koşullu ve geri okumalı.
  - Sıra: PMIC 0x3E → CLKDIV19 b6 → PEREN0 b21 (hclk_sdio) → PEREN4 b19 (clk_sdio) → PERRSTDIS4 b20 → GPIO3_6 wlan_en → iomg-mmc1 ×6 ← 1 → dwmmc2.
  - G45'te ayrı ağaçta (`work/g45/wifi/linux-m1`); G46'da ana hatla (G45 cpuidle/PSCI) birleştirildi (`work/g46/wifi/linux-m1-g46`; fark yalnız 9 M1 dosyası). G47 eMMC yazma kodu bu ağaca tabanlandı.
- **W1 / Faz B (G46 imaj, G47 cihaz):**
  - İki kilit `CONFIG_KK_SDIO_KAPI_PMIC_YAZ` + cmdline `kk_sdio_kapi.pmic_yaz=1`; tek yazma yeri `kk_pmic_yaz_tek` (yazmaç sabit 0x3E, değer 0x01; geri alma 0x00). Önce taze 0x3D/0x3E/0x3F, sonra geri okuma.
  - G47 kararları: açılışta yalnız Faz A okumaları; dizi sysfs `fff35000.sdio-kapi/baslat` ile, açılış başına 1 (2. tetik `-EBUSY`); 0x3E geri alma yalnız P1'in kendi geri okuması tutmazsa (P1 sonrası DUR'da 0x3E=0x01 kalır).
  - 0x0296/0x5347 6.12'de `SDIO_VENDOR_ID_MICROCHIP_WILC` / `WILC1000` ile çakışıyor; `WILC1000_SDIO` açıkça kapalı. SDIO fonksiyon sürücüsü, cfg80211, BT, FW_LOADER imajda yok (`#error` + config + vmlinux denetimi).
- **M2 (G47 tasarım `work/g47/wifi-m2/TASARIM-M2.md`):** 4.9 sürücüsü taşınmaz (M3'e kalır). kk-sdio-kapi'ye küçük yükleyici `kk-hi1102-yukle`: `yukle` 1 = el sıkışma (READM V120 denetimi, VERSION), 2 = tam indirme (4.9 `bfgx_and_wifi_cfg` dizisi sabit tablo; firmware imaja gömülü, sha256 + CRC32; 400 kHz 4 bit, ~4-6 sn).
  - G44 filtresi değişmez (kartta CMD52/53 yazması zaten izinli; CMD53 fonksiyon/adres daraltması O9 önerisi).
  - Aşamalar M2-0 → M2a (kod + birim + QEMU sahte ROM) → M2b (cihazda el sıkışma) → M2c (tam indirme; beklenen CMD52 yazma 33, CMD53 yazma 28, 800 256 B). Onaylar O1-O10.
  - **M2-0 (G48):** kk-bin `kk-49-wifi-fw-al` (`e9fd149d…`; cihazda yalnız `uname`/`stat`/`sha256sum`/`cat`, 4 sabit yol) 4 dosyayı 4.9 vendor'dan aldı → `work/g48/wifi-fw/fw/` (uzak = yerel = gömülü sha; G16 kaydıyla aynı; yerel sınama 13/13).
  - **M2a tamam (G48, masa başı + QEMU):** `kk-hi1102-yukle` (kilitler: Kconfig + `kk_hi1102_yukle.ac=1` + kip 2 için `kip_azami=2`; tek yazma kapısı `kk_h_yaz`; komut tablosu derleme anında 4.9 kurallarıyla üretilip `cmp` edilir; firmware gömülü). O9 (mmc2 CMD52/53 yazma daraltması; eMMC case 1 değişmedi) ve W11 (PMIC regmap yazılabilir 0x1E1/0x3E) koda girdi. QEMU sahte ROM 31/31, S3 35/35, gerileme 38/38; 4.9 eşdeğerliği fark 0 (F3 hariç). M2b imajı `592402ef…` (gerçek fw; kip 2 kapalı), yer tutucu seçenek `f6f2f244…`. M2b onayları O2, O4–O7, O9, O11.

### Entropi
- Donanım RNG yok; CRNG 100-126. sn'de hazır oluyor. QEMU'da `rng-seed` olduğu için görünmez.
- (a) ssh `TimeoutStartSec=300` uygulandı.
- (b) `SYSTEMD_RANDOM_SEED_CREDIT` ve (c) TRNG (TEE arkasında) açık.

### QEMU test düzeni
- raspi3b: shim sınaması.
- virt + RAM'de syscon/reboot-mode, simplefb, ramoops.
  - İki süreç + `memory-backend-file share=on` (RAM reset'ten sonra korunur).
  - `sdhci-pci` + `sd-card` (QEMU 8.2'de eMMC taklidi yok).
  - dummy_hcd (USB gadget); virtio hostfwd (12323 → 2323, 12222 → 2222).
- **Testler:**
  - T1/T1a sha;
  - T2 yazma testleri (md5 `24d4c434…`; filtre reddi);
  - T3 open_timeout reset;
  - T7-T9b Debian (watchdog);
  - T12-T14 networkd, `needs_recovery` hayır/evet;
  - T15 denetleyici rebind.
  - G36-G48: T30 sahte sıcaklık (thermal kısma, sıçrama); T40 i2c6 kapısı (sahte CRG/pinmux RAM'de, `-device loader`); T41 şarj politikası ve pencere taşması; T42 sigortada CHG_EN=0 (takılan yazmada 300 ms); T43 CHG_EN deneyi; T44 WDT katmanı; T45 kapanış kancası; `qemu-idle`, `qemu-teshis`, M0/M1/W1, eMMC pencere (sdhci-pci + GPT'li SD) takımları.
  - Gerileme takımı `qemu/hepsi.sh` (G43'ten beri 38 koşu); her görevde "SD önce = sonra" ve uyarı taraması.
  - `uyari-tara.sh` her koşuda.
- **Sınanamayanlar:** SPMI, NMI, SP805, gerçek PHY/tuning, Kirin PSCI (QEMU'da cpuidle girişleri `rejected`), HS200, AF_PACKET/networkd LLDP farkları, entropi, gerçek I2C/hi6523 davranışı.
- QEMU `-dtb` ile verilen `/psci` düğümünü silip yeniden yazar; bu yüzden `karakutu,cpu-suspend-hvc` `/cpus/idle-states`'te (G45).

### Bilinen ilk-nefes bilgileri (G17-G18)
- Kirin 710 MMIO haritası büyük ölçüde hi3660/3670 ile aynı. Farklar: clk-hi6260, PMIC hi6555v200, eMMC dwcmshc, USB.
- En yakın ana hat şablonu Kirin 659 / hi3660.
- UART6 `fff32000`; UART pedi bulunamadı (konsol yok → ekran ve pstore).
- DSS v320 için ana hatta sürücü yok (simplefb kullanılıyor).

---

## 11. ÖLÇÜMLER VE BULGULAR (G22-G48)

### CPU / GPU frekansları (G22)

| Küme | Noktalar (MHz) |
|---|---|
| A53 (little) | 480 / 960 / 1152 / 1325 / 1440 / 1536 / 1709 |
| A73 (big) | 807 / 1037 / 1268 / 1460 / 1671 / 1824 / 1997 / 2189 |
| GPU Mali-G51 r1p1 | 413-999 (9 nokta) |
| DDR | 203-1622 (5 nokta) |

- 4.9 governor `performance`. Ölçülen: A53 1,7085 GHz, A73 2,1888 GHz (`kk-hz`).
- **Mekanizma:** PMCTRL `0xfff31000` oy yazmaçları 0x270 big, 0x280 little, 0x290 gpu; sonuç 0x2DC. Değer MHz/16.
  - LPM3 PLL'i ve voltajı ayarlıyor; kernel voltaja dokunmuyor.
  - Ana hatta okunan oy `0x00196a72` (big 1824, little 1696, GPU 400; bootloader/LPM3'ün son oyu).
- **LPM3 tavanı:** oy profil indeksine yuvarlanıyor; big kümede tam 8 profil. Tavan üstü gizli OPP yok. Tek ayar yolu NV lowpower (yasak). **Hız aşırtma bekletiliyor.**
- Isı: 8 çekirdek yükte 8 sn'de 63,3 °C; IPA 55 °C'de devreye giriyor.
- GPU: `e82c0000`; `g3d` güç IPC 0x30004 (aç) / 0x30104 (kapat). Panfrost ve hi3660-mbox ile uyumlu olabilir (denenmedi).

### Thermal ve yük (G36-G37; 8 × `yes`, 280 sn)
| | G36 (yoklama 2 sn) | G37 (200 ms) |
|---|---|---|
| Yük başında en yüksek | 71,2 °C (~1,4 sn; sigorta 1/2, atmadı) | **60,7 °C** (2,0 sn); kısma 0,28 sn'de başladı |
| Denge ort. / en düşük / en yüksek | 60,5 / 58,9 / 62,6 °C | 60,5 / 56,8 / 62,4 °C |
| Kısma durumu | 5/6 ↔ 6/7 | çoğunlukla 4/6 ve 5/7; 6/7 hiç |
| Tavana dönüş | ~20 sn | ~15 sn |
| Oy geri okuması | 568 AYNI, 0 FARKLI | 2765 oy, 0 uyuşmaz, en uzun 10 µs |

- 8 çekirdek big 2189 MHz'de sıcak nokta saniyede ~10 °C yükseliyor. "Big tavanı 1997 MHz" gerekmedi.
- Ana hat boşta en sıcak SoC ~49-51 °C (performance, G42); P1'de (schedutil + cpuidle) 43 °C.

### Ağ (G38)
- ping 172.16.42.2 ort. 4,6 ms; 1.1.1.1 ort. 98 ms (ana makine uplink'i Wi-Fi). DNS ve HTTPS (`HTTP/2 200`, 0,49 sn) çalışıyor.
- chrony ilk açılışta `stepped by 17383295.98 s` (~201 gün; systemd derleme zamanı tabanından) → normal. `Leap status : Normal`; cihaz–ana makine farkı < 43 ms.
- Dışarı çıkan tek servis chrony. Oturum sınırı ve watchdog monotonik; adımdan etkilenmedi.

### Pil ve şarj (G38-G46)
- **Ana hatta pil (SDP, IIN 470 mA; + = deşarj):** açılış +121…+218 mA; boşta ≈ 0 (ort. 5,2-5,5 mA); 8 × `yes` yükte ort. +183, en çok +278 mA. SDP sürekli ağır yükü karşılamıyor → düşük pil koruması günlük sistem turunda.
- **Bootloader i2c6'yı kapalı bırakıyor:** CRG kapısı (+0x18 b27) 0, pinmux 0 (GPIO), pinconf 0x10 (4.9 değeri), reset bırakılmış. 4.9'da kernel açıyor (`clk_i2c6_gt` always_on + pinctrl default). Okumak için CRG ve pinmux yazması gerekir (G40'ta onaylı).
- **hi6523'ün ana hat açılışındaki değerleri 4.9 `chip_init`'ten farklı** [çıkarım: bootloader `fastboot_charger` yazıyor]: VTERM 4350 (0x92 = 0x5d; 4.9 4400), güvenlik zamanlayıcısı kodu 1 (4.9 3), IR telafisi 0 (4.9 2), ön şarj voltaj kodu 1 (4.9 0). ICHG 500, IIN 470, HiZ 0, OTG 0, BATFET 1 aynı. VTERM 4350 parametre kapısından geçer.
- **Çip WDT'si (G40-G42):**
  - 4.9 reboot'ta WDT'yi 40 sn kurulu bırakıyor (probe `e9=03`; `charge_shutdown` CHG_EN/WDT/HiZ'e dokunmuyor). Ana hatta yazmasız ilk tikten önce 0'a iniyor.
  - Dolunca Default mod: **CHG_EN = 0**, 0xE9 = 0; VTERM, ICHG, IIN, BATFET, HiZ, OTG değişmez.
  - **CHG_EN yazması WDT'yi kurmuyor; 0x90 yazması WDT'yi beslemiyor.** Sayaç son 0xE8 beslemesinden (ya da 0xE9 kurulumundan) işliyor, ~40 sn. 4.9 başlığındaki "her yazma besler" yorumu 0x90 için geçerli değil. 0xE9'u aynı değerle yeniden yazmanın beslediği ölçülmedi.
  - STATUS1 b1 `wdt_time_out_n` Default moddan sonra da 1 kalıyor → dolumu göstermez.
- **Faz 2/3 cihaz sonuçları:**
  - G41: CHG_EN=1 ve 0xE9 0 → 3 geri okumada AYNI; ibat 0 → −11 mA (3,1 sn'de); 66. sn'de kendiliğinden 0.
  - G42 (test bandı 3935/3955, pencere 120 sn): 5 pencere, sıra 5/5. Beslemeyle CHG_EN 123 sn açık (12 besleme, en uzun aralık 10,4 sn). Pencere sonunda 0xE9 25,6-30,7 sn'de 0. Besleme kesilince donanım son beslemeden ≤ 40,96 sn'de kesti, politika `DONANIM KESTI` dedi. Sigortada CHG_EN=0 0 ms (işlem 36 ms). Yazmalar 0x90 ×9, 0xE9 ×5, 0xE8 ×41; USB kopmadı.
  - G43-G45: kapanış kancası pencere açıkken `CHG_EN=0 DOGRULANDI` 0 ms (işlem 24-36 ms). Üretim bandıyla (3844/3929) politika BEKLE'de kaldı, yazma 0.
- **Şarj tipi ve Type-C (4.9 kaynağı):**
  - Tipi hi6523 değil, USB PHY'nin BC1.2 bloğu algılar: fusb302 olayı → `hisi_usb_otg_event` → `dwc3-hisi` `detect_charger_type` → huawei_charger.
  - ana makine portu SDP: IIN 470, ICHG 500; 4.9 kmsg `hi6523_version is 0x200`, açılış yükünde `CHG_STATUS0_REG:0xa8 in acl state`.
  - CHG_EN Type-C'ye bağlı değil. **fusb302 (i2c4 0x22) gerçek çip**; rt1711h (0x4e) yok. Ana hattın fusb302'ye dokunması gerekmez.
  - schargerV300, charger_ap, dwc3-hisi, usb/pd'de NV erişimi yok (NV yalnız coul/ASW/SOH; ana hatta yok).
- **Şarj akımı farkı (G42-G46):**
  - Aynı SDP bağlantısında 4.9 şarj tabanı (ekran kapalı, enable_charger=1) **+321 mA** (Ö1; C3 kapandı). Ana hatta pencerede −4…−11 mA (G41-G44).
  - O1 (G44): pencerede STATUS0 68/68 = 0xA8 (buck_ok, ACL=1, DPM=0, termal=0), dışında 0x80; 0x8E = 0x48 (VDPM 4675 mV). VDPM politikası SDP'de çalışmıyor. → **Fark tamamen sistem tüketimi: ≈ 325 mA ≈ 1,28 W.**
  - C1 (G43): CPU en düşük frekansta (480/807 MHz) şarj yalnız −2 → −47 mA (SoC −3 °C).

### Güç teşhisi ve verim (G44-G48)
- **Ana hat ↔ 4.9 boşta (G44 SONUC-A; sonraki ölçümlerle):**

  | Kalem | Ana hat | 4.9 boşta | Pay |
  |---|---|---|---|
  | Arka ışık | açık (bootloader 1252/2047) | kapalı (kk-ekran) | **≈ 279 mA ≈ 1,1 W** (G47 E2) |
  | Panel + DSI + DSS taraması | açık | kapalı | ≈ 80 mA ≈ 0,32 W (4.9'da ölçüldü, Ö1) |
  | cpuidle + tick | yok | çekirdek/küme güç kesme | ≈ 19-22 mA (G45) |
  | Governor | performance | performance | schedutil ≈ 38 mA (G45) |
  | DDR | SCBAKDATA4 indeksi 5; taban oyu 1600 MHz | kesin değil | farkı açıklamıyor (G47) |
  | CRG/SCTRL kapıları | 54 adlı + USB açık | aynı | ≈ 0 |
  | ISP/venc/vdec/IVP/modem/GPU | kapalı | kapalı | 0 |

  - Teşhis değerleri (G44): PERPWRSTAT 0x0007fc20 (media1 = 1, cci = 1, çekirdekler 0xff), PERPWRACK g3d/modem 0, PERI_CTRL4 VDD = 2, **PERI_CTRL5 = 0** (DSS gerilim oyu yok), VOTE_RESULT0 big 2176 / little 1696 / GPU 400 MHz.
  - Yazmaç anlamları: SCBAKDATA4 0x41C = ddrfreq `cur_freq` indeksi (4.9 tablo dışı indeksi 0'a kırpar; "203 MHz" bir oy değil); PERI_CTRL4/5 = çevre gerilim oyları (edc0/DSS); PERPWRSTAT = güç alanları.
  - **4.9 `clk_disable_unused` hi3xxx kapılarını kapatmıyor:** `HISI_CLK_DEBUG` kapalı, kapılarda `.is_enabled` yok, `clk_core_is_enabled` sayaca düşüyor. Bootloader'ın açık bıraktığı CRG/SCTRL kapıları 4.9'da da açık; saatler farkı açıklamıyor.
- **Verim deneyleri (G45; yalnız oturum içi Δ anlamlı, taban oturumlar arası kayıyor):**

  | Deney | Δ ibat | Güç |
  |---|---|---|
  | schedutil (~1031/1330 MHz) | ≈ −38,5 mA | 0,15 W |
  | cpu-sleep-0 | ≈ −12 mA | 0,05 W |
  | + küme durumları | ek ≈ −8…−11 mA | cpuidle toplam ≈ 0,08 W |
  | birleşik (bütün idle + schedutil) | ≈ −49,7 mA | 0,195 W (1,28 W'ın ≈ %15'i) |

  - Firmware CPU_SUSPEND orijinal biçim; hvc ile çekirdek ve küme güç kesmesi kararlı (8 CPU, hata 0; A53 kümesi 60 sn'nin 45-57'sinde küme durumunda).
- **Arka ışık (G47 E2):** B A A B B A A B; A (kapalı) −340,3, B (açık) −60,9 mA → **≈ 279 mA**; ardışık çiftler −275…−282, gürültü ±5 mA. hi6523 `IIN=470 ICHG=500 ACL=1` → ibat farkı = sistem farkı. Beklenti 75-150 mA idi.
- **LM36274 bootloader dökümü:** `01=05 02=68 03=85 04=04 05=9c 06=00 07=00 08=17 09=99 0a=11 0b=00 0c=24 0d=20 0e=20 10=46 11=35` (kimlik tuttu, parlaklık 1252/2047). i2c3 açılışta: PERSTAT2 b7 = 0 (saat kapalı), reset 0, iomg 0x700/0x704 = 0, iocg 0x10/0x10.
- **4.9 karartma sırası (G46):** 0x04/0x05 ← 0 → BLPWM 0xFFD75100 ← 0 → DSI 0x28/0x10 → DSI kapat + CRG 0xFFF35084 reset → GPIO39 reset, VSN GPIO45 / VSP GPIO35 → iovcc LDO4 (PMIC) → çip 0x08 ← 0x80 → LDI_CTRL 0xE867D024 b0 ← 0 → DSS SMC 0xC500FFF0. Ö1'in A pencereleri "panel açık, parlaklık 0" durumu (arka ışık yanmadı).
- **D1/D2 (G47):** açılışta `kapali=16/16`; A1 sağlıklı (giriş 2850, red 20), A2 (648/5), A3 (548/0) → `acik=16/16`. D2 test bayrağıyla `onceki=anahat-anormal` → izin 2, A3 açılmadı (12/16). pmsg ve DTB `/chosen` bootloader'dan sağlam geçiyor.
- **P1 (G48, `6c2ca900…`):** A0 `04=0 05=0 lm_yazma=2`, kapı yazmaları G47 ile birebir; A1 (3372/17), A2 (958/4), A3 (448/0) sağlıklı → `seviye=3 acik=16/16 a0=1`; schedutil + psci_idle; SoC 43 °C; hata 0, sigorta 0, şarj yazması 0, eMMC write blocked 5. **Verim aşaması kapandı.** A0'dan sonra ekran karanlık; "A0'ı atla" cmdline kolu yok.
- **A3 (DSS LDI) ve A4 (DDR oyu), G45: yapılmadı.**
  - A3: 4.9'da ilk donanım yazması arka ışık, LDI b0 en sonlardan; "panel açık + arka ışık açık + LDI durmuş" durumu 4.9'da hiç oluşmuyor → eşdeğerlik gösterilemez.
  - A4: DDR oyu `writel((MHz>>4)|0x00FF0000, PMCTRL+0x2B0)` (IPC yok). 4.9 boşta oy yazmıyor (pm_qos yalnız istek değişince; tek istekçi Hi1102, 0 ile). Taban oyu DDR'ı düşüremez (tavan 0x2A0 gerekir).
- **PMCTRL DDR oy dökümü (G47, ana hat):** TOP_VOTE 0x2A0-0x2AC = 0x0000ffff ×4; **FLOOR_VOTE 0x2B0 = 0x64 (1600 MHz)**, 0x2B4 = 0x19, **0x2B8 = 0**, 0x2BC = 0; VOTE_RESULT1 0x2E0 = 0x000064ff. 4.9 memlat değeri kaynakta 0x65 (1616 MHz) → `kosul=0`, DDR deneyi yapılmadı. 0x2B0'ın kaynağı bootloader/LPM3 [çıkarım].
- **4.9 hw_vote okuma kümesi:** yalnız oy 0x270/0x280/0x290 ve sonuç 0x2DC. devbw 0x2B8'e yalnız yazar; 0x2E0'a hiç erişmez.

### eMMC (G45-G48)
- **userdata p68:** başlangıç 16 826 368, boy 227 450 880 sektör, diskin sonuna kadar (disk 244 277 248; yedek GPT geçersiz). PART_ENTRY_UUID `<GUID>`, tip Microsoft basic data.
- **kkdata ext4:** has_journal, ext_attr, resize_inode, dir_index, filetype, extent, 64bit, flex_bg (16), sparse_super, large_file, huge_file, dir_nlink, extra_isize, **metadata_csum**; 4 KiB blok, 28 431 360 blok, Reserved GDT 1024. orphan_file/large_dir/fast_commit yok (4.9 desteklemiyor).
- **EXT_CSD:** ana hatta **CACHE_CTRL[33] = 0x00** (CMD6[33] reddedildiği için), **4.9'da 0x01**; WR_REL_SET 0x1F; PART_CONFIG 0x08 (erişim 0); HS_TIMING 0x02; DATA_TAG_SUPPORT 1.
- **4.9 ext4 fallocate yerleşimi (G47):** 8 MiB'lık parçalarla ayırır; ilk parça `s_mb_last_group`'tan başlar (yeni dizin etkisiz). Koşu yedek süperbloklarda (sparse_super grupları 1, 3, 5, 7, 9, 25, 27, 49, 81…), flex_bg meta verisinde ve Debian verisinde kopar → doğrudan 1 GiB fallocate iki denemede de ardışık çıkmadı. Model `work/g47/emmc/alan/model49.py` iki denemeyi koşu koşu üretti.
- **alan.img (G48):** 6 GiB 55 extent; ilk ardışık 1 GiB mantıksal 512 MiB'ta → collapse + truncate. **Fiziksel blok 557 056..819 199** (8 extent, kesintisiz). **W_BAS = 21 282 816, W_SAY = 2 097 152, W_SON = 23 379 968** (p68 içi 4 456 448..6 553 599) = G47 model öngörüsü. Sıfır yazımı 9,2 sn (116 MB/s); unwritten 0; boş alan farkı 1 073 750 016 B; alan.img sha `5e02448d…`.
- **6 nokta zinciri:** 4.9 dosya = 4.9 ham p68 = ana hat ham `/dev/mmcblk0` (E1) = ana hat pencere aygıtı (p68 ve mmcblk0) = ana hat dosya (E2); 6/6 ve 12/12 birebir.
- **E1/E2:** E1 kuyruğu `discard_max_bytes=4194304 fua=1 write_cache=write back`. E1 ve E2'de diskstats **w_io = 0, w_sec = 0, d_io = 0, f_io = 0**. E2'de `kk_yazma=durum=hazir bas=21282816 son=23379968`, CMD24/25 0, write blocked 5 (A.2). Ana hat FIEMAP `ilk=557056 top=262144 uw=0 kes=0`.
- **QEMU bulguları (G46):** dm-linear kkdata bağlıyken EBUSY (→ loop); `fallocate` blokları unwritten (→ sıfır yazımı şart); mke2fs `-E nodiscard` şart; 1 GiB tek extent olamaz (ölçüt "fiziksel ardışık"); busybox chattr hata verse de 0 döner.

### Wi-Fi Hi1102 (G41-G48)
- **Ana hat açılışında bootloader durumu (M0 G43, Faz A G46) ↔ 4.9 Wi-Fi açık:**

  | | Ana hat (bootloader) | 4.9 Wi-Fi açık |
  |---|---|---|
  | hclk_sdio / clk_sdio | kapalı (PERSTAT0 b21 = 0, PERSTAT4 b19 = 0) | yazılım sayacı 0/0 |
  | sdio_hrst (PERRSTSTAT4 b20) | 1 (resette) | — |
  | iomg-mmc1 fc182000 ×6 | 0 (GPIO) | 1 (SDIO) |
  | GPIO3_6 (wlan_en) | GPIO, çıkış, 0 | GPIO |
  | PMIC 0x3E (32 kHz) | 0x00; 0x3D = 0x00, 0x3F = 0x01 | clk_pmu32kb sayaç 1, 32 764 Hz |
  | dwmmc2 | OKUNMADI (kapalı) | mmc2 180 MHz SDR104, 1,8 V, 4 bit |

  - Hi1102 RX veri kesmesi wake GPIO'dan (`fff0f000` pin 3; `hisdio_intr_mode=1`).
  - PERSTAT0 erken okumada 0x2ddfee2f, gadget kurulduktan sonra 0x2fdfee6f (USB2 OTG hclk/ref).
  - 0x3E = `OSC32K_BT_ONOFF_CTRL` (b0 en_32k_bt). 4.9 yalnız Wi-Fi kartı probe'unda oku-değiştir-yaz yapar, hiç kapatmaz; reboot'ta kalıcı değil. En büyük risk yanlış adres (0x3F sistem 32 kHz).
- **Faz B (G47):** `PMIC YAZMA #1 0x3e <- 0x01` AYNI (0x3D/0x3F değişmedi); 11 MMIO yazması AYNI (CLKDIV19 0x3681 → 0x36c1, PERSTAT0 → 0x2fffee6f, PERSTAT4 → 0x42683840, PERRSTSTAT4 → 0x684f11fc, GPIO3 DATA 0x20 → 0x60, iomg ×6). dwmmc2 Version ID 270a, 32 bit veri, FIFO 256.
  - **116,4 sn `mmc2: new SDIO card at address 0001`**; fn1 vendor 0x0296 device 0x5347 sınıf 0x07, sürücü yok, 400 kHz 4 bit, filtre reddi 0. Dönüşte 4.9 Wi-Fi olağan (ping 5/5).
- **Firmware girdileri (M2-0, G48):** `cr4_asic.bin` 396 012 B (`8cf0e9aa…`), `CPU_RAM_SCHED.bin` 362 008 (`d7f10bf9…`), `CPU_RAM_WBS.bin` 40 436 (`67220c16…`), `cfg_marie_lx1a_hisi.ini` 10 785 (`c3c2a41a…`). INI'de **`band_5g_enable=1`** (satır 105) → M2'de 4 ek WRITEM gerekmez.
- **4.9 indirme bulguları (G47):** 4.9 her açılışta çipi kapatıp açar ve indirmeyi 180 MHz SDR104'te yapar; dosya parçası 261 632 B; cali bloğu 0x30170000 WBS bölgesinin içinde (önce WBS sonra cali). 4.9 kodundaki üç kusur (cali gönderiminde 504 B taşan okuma, sınırsız `xfer_count`, uykusuz yoklama) taşınmaz.

### 4.9'da yan etkisiz okuma (kural 15a; G38-G47)
- **Okunur:** Battery `capacity/status/voltage_now/current_now/temp`; `charge_data/enable_charger`, `iin_thermal`, `iin_runningtest` (yazılım değişkenleri); thermal_zone `temp`; clk debugfs saat başına `clk_enable_count/clk_prepare_count/clk_rate`; pinctrl `pins` ve `pinconf-pins` (düz `readl`); mmc debugfs `ios`; ddrfreq `cur_freq` (tek readl); regulator `name`/`num_users`, ip regülatörlerinde `state`; lcd_backlight `brightness` (önbellek).
- **Okunmaz:** `Ibus`, `Vbus` (ADC yazmaçlarına yazar), `chargelog` (yazmaç dökümü), `voltage_sys`, `fcp_support`, `water_intrused` (okuyunca siler), clk `clk_summary` (toplu recalc), **lcd_backlight `self_test` (işleyicisi çipe yazar)**. hi6523 `iinlim` hep 0 döner (yanıltıcı).
- PMIC 0x3E ve PERRSTSTAT4 b20 için 4.9'da yan etkisiz yol yok. Gerçek IIN/ICHG kodu yalnız kmsg'de (`charge_set_input_current`, `input current reg is set`).

---

