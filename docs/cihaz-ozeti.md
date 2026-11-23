# Cihaz ve sistem özeti

Bu belge, Huawei P30 Lite (Kirin 710, kod adı Marie) üzerinde çalışan Kara Kutu sisteminin donanım, açılış ve yazılım katmanlarını özetler. Ayrıntılı teknik kayıt için [teknik-rapor.md](teknik-rapor.md), güvenlik kuralları için [guvenlik-tasarimi.md](guvenlik-tasarimi.md) belgesine bakın.

Notlar:
- Belgedeki `G<sayı>` ifadeleri proje çalışma turlarının numaralarıdır (zaman çizelgesi için geçmiş kaydı).
- Cihaza özgü kimlik verileri (seri numarası, MAC adresleri, ağ adresleri, anahtarlar) bu belgeye alınmamıştır.
- "ana makine" geliştirme makinesinin (Ubuntu Server) takma adıdır; cihaz ona USB NCM ile bağlanır (172.16.42.0/24).
- "Ana hat", Linux 6.12.117 çekirdeğidir; "4.9", üretici çekirdeğinden türetilen kendi çekirdek dalımızdır (günlük sistem).

## 1. Donanım

### Cihaz
- **Model:** Huawei P30 Lite. Yazılımın gösterdiği model **MAR-LX1A** (`product`, `oeminfo`); firmware kodu **MAR-L21A**, bölge `hw/eu`. "MAR-LX1M" etiketi **doğrulanmadı**.
- **Kurulu stok yazılım (bölümlerde kalan):** MAR-L21A 9.0.1.159 (C432E5R2P3), EMUI 9.0.1. Tam firmware paketi doğrulanabilir bir kaynakta bulunamadı.
- **Kod adı:** Marie. Android donanım adı `kirin710`.
- **SoC:** Kirin 710 (hi6260), aarch64:
  - 4× Cortex-A53 r0p4 (MPIDR 0x0-0x3) + 4× Cortex-A73 r0p2 (0x100-0x103);
  - PSCI v1.0, SMCCC v1.1; EL2'yi HHEE tutuyor, kernel EL1'de açılıyor.
- **CPU frekansları (G22):**
  - A53 480-1709 MHz (7 nokta), A73 807-2189 MHz (8 nokta);
  - GPU Mali-G51 r1p1, 413-999 MHz; DDR 203-1622 MHz;
  - frekansı LPM3 ayarlıyor (PMCTRL `0xfff31000` oy yazmaçları, MHz/16); tavan üstü gizli OPP yok;
  - 4.9'da governor `performance`.
  - Ayrıntı kernel raporu §11.
- **RAM:** 4 GiB fiziksel. 4.9'da MemTotal ~3,6 GiB, ana hatta 3 788 580 kB.
- **Depolama:** eMMC 5.1:
  - `128G32`, 116 GiB, üretici 0x11, 12/2018;
  - denetleyici DWC MSHC `0xff3e6000`; bootloader HS400'de bırakıyor;
  - SD yuvası `hi_mci.1` (kullanılmıyor).
- **PMIC:** hi6555v200. MMIO ile değil, SPMI ile erişiliyor (`spmi@fff24000`, kanal 2, sid 0).
  - Reboot nedeni yazmacı `0x1E1`: `bootloader` = 0x01.
- **Watchdog:** SP805 `0xe8a06000`. Bootloader normal açılışta 60 sn ile açık bırakıyor. **Kirin'de ilk kesme doğrudan reset'tir** (ana hatta `karakutu,irq-is-reset` yaması).
- **Reset yolu:** LPM3 NMI (SCTRL `0xfff0a000` +0x510 bit2). PSCI reset kullanılmıyor.
- **Wi-Fi/BT:** HiSilicon Hi1102, sürücü kernel'e gömülü:
  - fabrika MAC'i NV'den geliyor (NVE açılmazsa rastgele `xx:11:02`);
  - firmware vendor'da (EROFS);
  - 2,4 GHz sinyali çok zayıf, anten bağlı olmayabilir (doğrulanmadı).
- **Batarya:** HB356687ECW, 3340 mAh, 3,82 V (marka desaysony, FCC ~3291 mAh). Şarj IC'si hi6523 (i2c6 0x6B). Coul hi6555v200.
- **Termal (4.9):**
  - 18 thermal zone. Boşta SoC ~40-44 °C, açılışta ~48-49 °C. 8 çekirdek yükte 8 sn'de 63 °C.
  - 4.9 eşikleri: IPA 55 °C'de kısmaya başlıyor (hedef 80 °C), kart 55/75 °C, pil kapatma 68 °C.
  - **Pil NTC'si gerçek ve çalışıyor (G35):** 9-14 Kasım'daki ~670 örneğin hepsi 24/25 °C. Ana hatta ham HKADC 1457-1463 = 24,99-25,17 °C, yani 4.9 tablosunun 25 °C sınırı. 4.9 tamsayıya kırptığı için 24↔25 gidip geliyor. Pil kasada kartın yanında, iki yüzü açık; ısıl bağı zayıf, oda sıcaklığında kalıyor.
- **Ekran:** simplefb 1080×2312×32 (`0x18c00000`). Debian'da `kk-ekran` paneli karartıyor; **ekran siyahsa Debian açıktır**. Kurtarma ortamında sarı yazı kalır.
  - Ana hatta bootloader arka ışığı açık bırakır (LM36274, i2c3 0x11, 1252/2047; ≈ 1,1 W). P1 imajında bekçi açılıştan ~120 sn sonra arka ışığı kapatır (panel açık kalır).
- **Fiziksel durum:** Arka kapak yok, EMI shield çıplak. Ayrı bir ekran modülü flex ile takılabiliyor.
- **Bootloader:** AÇIK.
  - cmdline: `bootlock=unlocked userlock=unlocked`, `verifiedbootstate=orange`. Fastboot `Chipset-miami9.0.1.(03A0)_FASTBOOT`.
  - **FB kilidi kapalı** (`fb_lock_stat=0`). Bu yüzden `fastboot flash erecovery_*` → `Command not allowed`; `kernel` yazılabiliyor.
  - `fastboot getvar` reddediliyor. `fastboot boot` işleyicisi yok.

## 2. Cihazdaki sistem

### Katmanlar
```
[Huawei firmware: xloader, fastboot, TEE, LPM3, modem, NV]   dokunulmaz
   ↓
[kernel bölümü (p43): kendi 4.9.337 kernel'imiz v5.1, sha d27b3d73…]   gömülü initramfs ile
   ↓
[initramfs: kurtarma kabuğu + OS seçimi]  → switch_root
   ↓
[Debian 12 bookworm arm64, systemd 252, kök /data/kk/os/debian (userdata ext4 "kkdata")]

[erecovery_kernel bölümü (p40): v5.1e, sha d34af993…]  = bizim kurtarma ortamımız (eRecovery yuvasında)
```
- Test sırasında `kernel` bölümüne ana hat imajı yazılır; testten sonra her zaman `kk-v51-don` ile v5.1'e dönülür.

### Açılış mantığı (v5.1 initramfs)
- Her açılış önce initramfs'ten geçer. Öncelik sırası: `kk.rescue=1` > `/data` yok > `rescue` bayrağı > `next-os` > init yok > `os-tries ≥ 3`. Hiçbiri tutmazsa `switch_root` ile Debian.
- **Durum dosyaları** (`/data/kk/state/`): `next-os` (debian), `os-tries` (switch_root öncesi +1; Debian'da `kk-bootok` sshd dinleyince 0), `wifi-fails`, `boot-count`, `keep`, `rescue`.
- **Güvenlik anahtarı (v4.1'den beri):**
  - Bakım modu (`keep` yok): gadget kurulamazsa 20 sn sonra, `/run/kk-keep` yoksa 10 dk sonra `reboot-bl` (fastboot).
  - Kalıcı mod (`/data/kk/state/keep` var): otomatik fastboot yok.
- Gadget'ı initramfs kuruyor; kurtarmada NCM + udhcpd + telnetd 3,3 sn'de hazır.
- Logları `/data/kk/logs/` tutar. Kurtarmadaki kmsg logu 20 MB + bir eski kopya.

### Debian
- Hostname `kara-kutu`.
- sshd yalnız publickey (`PasswordAuthentication no`, `PermitRootLogin no`).
- journald kalıcı, `SystemMaxUse=200M`. `serial-getty@ttyS0` maskeli. `LANG=C.UTF-8`.
- Açılış ~3,8 sn kernel + ~2,6 sn kullanıcı alanı; yazılımla reboot'ta SSH ~20-26 sn.
- **Kendi servislerimiz:**

  | Birim | İş |
  |---|---|
  | `kk-wifi` (`/usr/local/sbin/kk-wifi`, sha `f7c8e808…`) | Sıra: wifi-fails kontrolü → ölü adam 300 sn → vendor ro → NVE (`printf`) → plat → wifi → link döngüsü (up/down/up) → `wpa_supplicant@wlan0` → canlılık ≤60 sn → bağlantı logu → **(G34) güç tasarrufunu kapat** (iki hipriv komutu). wifi-fails ≥2 ise Wi-Fi başlamaz |
  | `kk-deadman` (`009728de…`) | Ölü adam: yalnız bash yerleşikleri; süre dolarsa sysrq s → u → b; FIFO ile erken iptal |
  | `kk-charge` | Pili ~%60'ta tutar (≥60 kes, ≤50 aç; pil ≥42 °C kes). `enable_charger` düğümleri |
  | `kk-clock` + `kk-clock-save.timer` | rtc0 PMU sayacı reboot'ta sıfırlanıyor. Saat RTC + ofsetten geri yükleniyor. Kayıt kapanışta ve saatlik (chrony `Leap Normal` iken) |
  | `kk-ekran` | Paneli karartır (`blank=0` → 3 sn → `blank=4`) |
  | `kk-bootok` | sshd dinleyince `os-tries=0` |
  | `kk-wifi-olay` (G35; betik `3782796b…`, birim `798c4ae1…`) | `wpa_cli -a`: her CONNECTED'da Wi-Fi güç tasarrufunu yeniden kapatır (`wifi_pm`'e yazmaz) |

- **Ağ:** `20-kk-wlan.network` statik `.51`. `wpa_supplicant-wlan0.conf` (0600; `p2p_disabled=1` **zorunlu**, `country=TR`, yalnız PSK özeti). `wpa_supplicant.service` maskeli.
- **Saat:** chrony 4.3 (`rtcsync` kapalı; RTC → NV yazma denemelerini durdurur). timesyncd kaldırıldı.
- **Paketler:** apt güvenlik yükseltmeleri elle yapılıyor. `unattended-upgrades` yok.
- **pstore:** `/etc/tmpfiles.d/systemd-pstore.conf` yaş sınırını kaldırıyor (G32; önceden 14 gün sonra siliniyordu).
- **NV:** kernel seviyesinde salt okunur (yazma `-EROFS`). Ölçüt: nvme bölümünün sha256’sı değişmemeli.

### Wi-Fi güç yönetimi (Hi1102, G34)
- İki katman var:
  - (A) host/çip derin uykusu: `g_wlan_pm_switch`;
  - (B) 802.11 STA PS: sürücü association'dan 120 sn sonra kendisi açıyor.
- `iw … power_save off` etkisiz.
- Kapatma (çalışma anında, NV/firmware yazmaz; kk-wifi bağlantı + IP'den sonra yapıyor):
  ```
  echo "wlan0 set_sta_pm_on 0"  > /sys/hisys/hipriv
  echo "Hisilicon0 pm_switch 0" > /sys/hisys/hipriv
  ```
  Satır sonu şart.
- Doğrulama: `/sys/hisys/pmdbg/wifi_pm` (**yalnız okunur**). Beklenen `enable:0, g_wlan_pm_switch:0, dev state:0`; `sleep_succ` sabit kalır.
- (B) her yeni association'da sıfırlanır. **G35:** `kk-wifi-olay.service` (`wpa_cli -i wlan0 -a /usr/local/sbin/kk-wifi-olay`) her `CONNECTED`'da `set_sta_pm_on 0`'ı (gerekirse `pm_switch 0`'ı da) yeniden uygular ve log'a yazar. kk-wifi'nin açılıştaki adımı da duruyor.
- `pm_switch=0` iken `reassociate` (G35): ilk deneme 5 GHz BSSID'de **status 16** aldı, ~3 sn'de 2,4 GHz BSSID'ye bağlandı. AP 5180 MHz ile 2447 MHz arasında bant değiştirebiliyor.


## 3. Android'siz OS projesi

### Hedef
ana makinedeki PC özgürlüğünü bu ARM cihazda kazanmak: istenen OS'u istenen an kurup kaldırabilmek için hazır araç seti.

### Mimari
```
Huawei firmware (xloader, fastboot, TEE, LPM3, modem, NV)   dokunulmaz
Kernel: 4.9.337 v5.1 (bugün kullanılan)  |  ana hat 6.12.117 (aşama aşama)
Gömülü initramfs (Image'ın içinde)                           kurtarma kabuğu + OS seçimi
Rootfs: /data/kk/os/<dağıtım> (userdata ext4 kkdata)         Debian 12 kurulu; diğerleri tak-çıkar
```
- **Rootfs yeri kararı:** userdata ext4 `kkdata`, yapı `/data/kk/{os,state,logs}` (G13-G14).
- **4.9'un sınırı:** systemd 258+ en az 5.4, 260 en az 5.10 istiyor. Debian 12 (systemd 252) 4.9'da sorunsuz.
- **Ana hat (6.12.117) cihazda çalışıyor.** "Kirin 710 için mainline yok, tek kernel 4.9" bilgisi artık eksik: kendi DT'miz ve küçük yamalarla 6.12 açılıyor, SMP/bellek/pstore/SPMI/watchdog/eMMC/USB/Debian çalışıyor.

### 4.9 hattı (v-serisi, Görev 6-15, 20)
- v1 initcall'da kilitlendi (G7). v2'den itibaren stok DTB ile açılıyor; iki DT uyumluluk yaması var (thermal, coul).
- v3.1: NV salt okunur. v4: e2fsprogs + şarj limiti. v4.1: bakım/kalıcı mod. **v5.1: Debian `switch_root`, bugün kernel bölümünde.**
- v5.1e: eRecovery yuvasındaki kurtarma (`systemctl reboot erecovery` ile tuşsuz giriş, telnet ~18 sn).
- Debian'da panik → BFR → ilk seferde bizim kurtarma. BFR'nin misc/rrecord bayrağı kalıcıdır, temizlenmesi gerekir (kk-kurtarma bfr).
- **v5.2 listesi (beyin kararı; henüz yapılmadı):**
  - `RTC_SYSTOHC=n` + rtc NV yaması;
  - kritik bölümlere bio düzeyinde ro + `BLKROSET`;
  - kurtarma raporu; `kk-bfr-temizle`;
  - her sürüm önce `erecovery_kernel`'e, sonra `kernel`'e yazılır;
  - keypoint 250; çöküş kayıtları `/data/kk/logs/crash-*`; `kk-hv` debugfs;
  - **(G33 ek)** initramfs'teki `e2fsck -p` çıktısını (journal oynatıldı mı / clean) `/data/kk/logs/boot-NNNN` ve kmsg'ye yaz.

### Ana hat hattı (6.12.117) — aşamalar
| Aşama | Görev | Sonuç |
|---|---|---|
| 1 İlk nefes | G23-G25 | Shim → 6.12 → kendi DTB, simplefb, gömülü initramfs, SPMI ile PMIC reboot nedeni, fastboot'a dönüş. SP805 yarışı (G24) `irq-is-reset` ile çözüldü |
| 2 Temel | G26-G27 | SMP 8/8, bellek 3,79 GB, ramoops iki yönlü (4.9 ↔ ana hat), reset = LPM3 NMI. Kamera kalktı |
| 3 eMMC salt okuma | G28-G31 | Tek geçit filtresi + katı mod + CMD6 beyaz listesi. G29 güvenli başarısızlık (strobe kapısı); G30 düzeltme. G31: HS 8 bit 48 MHz, 44 MB/s, beş sha birebir, yazma 0. **Kapandı** |
| (USB) | G32 | dwc3 sargısı (PMIC'e yazmadan), NCM + telnet 2323 |
| 4 Debian salt okunur | G33 | kkdata `ro,noload` + overlay (tmpfs üst), systemd, SSH 2222, `systemctl reboot` → bootloader. B'de `CONFIG_PACKET` eksik çıktı; **B2 başarılı** |
| Tur 2 | G35 | **Pil sıcaklığı** (4.9'daki birebir LPM3 HKADC isteği, mailbox-16/0, 30 sn'de 1, tekrar yok; 6/6 yanıt) ve **SoC sıcaklıkları** (SMC `0xC5009900`, 4 sensör, 5 sn). **Sigorta** (pil > 45 °C / SoC > 70 °C, 2 ardışık → reboot bootloader; çekirdek içinde) cihazda eşik düşürülerek gösterildi. vbat 4.9'la 2-5 mV |
| Tur 1 | G34 | **HS200 192 MHz 1.8 V, 161,7 MB/s**; geri düşüş HS200 → HS → HS200 cihazda gösterildi; A sınıfı sensör (pil V/I, hw_vote); beş sha aynı, önce = sonra |
| Tur 3 | G36 | cpufreq (4.9 hw_vote birebir, yalnız 0x270/0x280) + thermal (step_wise, 55/60/63 °C). Yükte dengede; ilk sıçrama 71,2 °C (yoklama 2 sn) |
| Tur 4 | G37-G38 | Thermal yoklaması 200 ms → yük başında en çok 60,7 °C, sigorta 0. ana makine NAT: ping, DNS, chrony `Leap Normal`, HTTPS 200. **Kapandı** |
| Tur 5 şarj | G38-G43 | Faz 0 okuma/plan; Faz 1 i2c6 kapısı + hi6523 okuyucu; Faz 2 tek CHG_EN deneyi (Default mod CHG_EN = 0); Faz 3 politika + WDT katmanı (açık + 0xE8 besleme) + kapanış kancası cihazda. Üretim imajı `2cde4b56…` hazır, uzun koşu günlük sistem turunda. Faz 4 (şarj tipi) tasarımı hazır, Wi-Fi M3'e kadar bekliyor |
| Verim | G44-G48 | Teşhis: şarj farkı = sistem tüketimi ≈ 1,28 W. schedutil + cpuidle ≈ 50 mA; arka ışık ≈ 279 mA (≈ 1,1 W). **P1** (schedutil + aşamalı cpuidle + bekçiyle arka ışık kapatma) cihazda geçti. **Kapandı (G48)** |
| eMMC yazma | G45-G48 | Pencere kodu (iki katman, varsayılan kapalı); 4.9'da 1 GiB fiziksel ardışık `alan.img` (W_BAS 21 282 816); E1 ve E2'de (pencere `hazir`) yazma 0, 6 nokta zinciri birebir. İlk yazma (E4) onay bekliyor |
| Wi-Fi Hi1102 | G41-G48 | STA alt kümesi derleme + modpost temiz (199 stub); M0 salt okuma; M1 kapısı; **Faz B: kart SDIO'da görüldü** (0x0296/0x5347; 1 PMIC + 11 MMIO yazması). M2-0 firmware dosyaları alındı; M2a sürüyor |

- Her testte eMMC'ye yazma 0 (E2'de diskstats ile de). Ölçümler (`kk-olcum`) önce = sonra birebir; boot-count G48 sonunda 59.
- **İlke (G48 itibarıyla):** Ana hatta yeni bir donanım yazması yalnız ayrı onayla, beyaz listeli tek bir işlevden, her yazmadan sonra geri okumayla ve yazma kanıtıyla (objdump/nm) yapılır. Onaylı yazmalar:
  - hi6523 0x90 (yalnız CHG_EN), 0xE9 (yalnız WDT[1:0]), 0xE8 (besleme); i2c6 kapısı (CRG PEREN b27, pinmux);
  - PMIC 0x3E b0 (Wi-Fi 32 kHz; açılış başına 1, sysfs tetikle; geri alma yalnız geri okuma tutmazsa);
  - i2c3 kapısı (PEREN2, iomg ×2) + LM36274 0x04/0x05 ← 0 (arka ışık; açılış başına ≤ 2);
  - SDIO kapısı (11 girdilik MMIO beyaz listesi); `scaling_governor` / cpuidle `disable` sysfs.
  - LPM3'e yeni komut, Type-C ve diğer PMIC yazmaları yok (reboot-mode 0x1E1 dışında). Okumalardan HKADC mesajı ve SMC G35'teki gibi.

### Kapatılan konular
- Windows 11 ARM: mümkün değil (Kirin için UEFI/Windows sürücüsü yok).
- Port'un Halium-ramdisk yolu: P30 bootloader'ı normal modda `kernel` bölümündeki ramdisk'i yüklemiyor.
- Hız aşırtma: LPM3 profil tavanı var; tek yol NV lowpower, kurallarla kapalı. Bekletiliyor (G22).
- Hi1102'nin ana hatta tam portu: rafa kalktı (G36); ana hattın interneti NCM + NAT. İnce STA portu ve yükleyici (M2) ayrı hat olarak sürüyor.
- DSS LDI (A3) ve DDR oyu (A4): 4.9 ile birebir eşdeğerlik gösterilemedi, yapılmadı (G45); DDR 0x2B8 deneyi koşul sağlamadı (G47).
- Port'un script'leri (`flash.sh`, `setup-device.sh`, `device-config.sh`) asla doğrudan çalıştırılmaz (§8).

---
