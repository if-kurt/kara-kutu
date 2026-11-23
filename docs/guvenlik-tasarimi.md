# Güvenlik tasarımı

Bu belge Kara Kutu araç setinin cihazı kalıcı olarak bozmamak için koyduğu kuralları özetler. Kurallar iki yerde uygulanır: ana makinedeki sarmalayıcı betiklerde (`tools/kk-bin/`) ve cihazın erken açılış betiklerinde (`initramfs/`). Ana hat çekirdeğine ait kapılar `linux-kirin710` deposundadır.

> Summary (EN): never write bootloader/firmware/identity/modem partitions; always address the device by explicit serial; routine device actions only through hash-pinned wrapper scripts; mainline kernel writes only through allow-listed registers with read-back; thermal fuse; dead-man timers; scripted recovery. The rules below are the authoritative detail.

## 1. Cihaz seçimi

- Her `adb` ve `fastboot` çağrısı cihaz seri numarasını açıkça verir (`-s "$KK_SERI"`). Seri numarası betiklere ortam değişkeniyle gelir ve depoda bulunmaz.
- Aynı ana makineye takılı başka USB cihazlarına dokunulmaz: `usbreset`, udev değişikliği, üçüncü taraf USB kütüphaneleri kullanılmaz.

## 2. Asla yazılmayan bölümler

`flash`, `erase` ve `dd of=` ile aşağıdakilere yazılmaz:

- **Önyükleyici ve firmware:** xloader (eMMC boot bölgeleri), fastboot, vector, teeos, trustfirmware, hhee, fw_lpm3, hisee_* (encos, img, fs), sensorhub, isp_boot, isp_firmware, fw_hifi, hdcp.
- **Kimlik ve kalibrasyon:** nvme, oeminfo, modemnvm_* (factory, backup, img, update, cust), modem_secure, secure_storage, certification, persist, frp, veritykey, ddr_para, vrl, vrl_backup.
- **Modem:** modem_fw, modem_driver, modem_om, modem_patch_nv.
- **Üreticiye özel:** bootfail_info, rrecord, misc, dfx, splash2, version, patch, eng_system, eng_vendor, reserved1-7. `misc`/`rrecord` içindeki boot-hata bayrağı yalnızca onaylı tek betikle temizlenir (`tools/kk-bin/cihaz/bfr-temizle-g23.sh`, `kk-kurtarma bfr`).
- **DTB ve AVB:** dts, dto, vbmeta, recovery_vbmeta, erecovery_vbmeta.
- **vendor, odm:** yalnızca bakımcı açıkça karar verirse.

## 3. Yazılabilen bölümler (açık onayla)

`kernel`, `recovery_ramdisk`, `recovery_vendor`, `erecovery_kernel`, `erecovery_ramdisk`, `erecovery_vendor`, `system`, `product`, `preload`, `cust`, `cache`, `userdata`.

- `erecovery_*` fastboot'tan yazılamaz (önyükleyici reddeder); yalnızca çalışan Debian'dan `dd` ile ve ayrı onayla yazılır.
- Kernel imajı yazılmadan önce: boyut sıfırdan büyük ve hedef bölüm boyutuna eşit ya da küçük (`kernel` bölümü 25 165 824 bayt), tip doğru (`ANDROID!` magic), sha256 yeniden hesaplanır, geri dönüş imajının yolu ve sha256'sı önceden söylenir.

## 4. Yasak komutlar

`fastboot erase`, `fastboot oem …`, `fastboot flashing lock/unlock`, `fastboot format` ve `fastboot getvar` kullanılmaz (bu önyükleyici `getvar`ı reddeder). Cihaz açılırken zorla yeniden başlatma yapılmaz; üretici önyükleyicisinin hata sayacı eRecovery'ye atabilir. eRecovery ekranındaki "indir ve kurtar" ve silme seçenekleri kullanılmaz.

## 5. Sarmalayıcı betikler

Rutin cihaz adımları (kernel flaşı, reboot, ölçüm, pstore alma, bilinen iyi çekirdeğe dönüş, kurtarma) yalnızca `tools/kk-bin/` betikleriyle ve tek başına çalıştırılır.

- Betik girdisini kendisi denetler, ortak bir kilit alır (aynı anda iki cihaz komutu çalışmaz; kilit doluysa çıkış kodu 77) ve günlüğe yazar.
- Betikler ve cihaza gönderilen yardımcılar (`tools/kk-bin/cihaz/`) sha256 ile sabitlenir (`SHA256SUMS`); beklenen özet tutmazsa çalışmayı reddeder.
- Cihaza dokunan komutlar tek tek gönderilir; önceki komutun çıktısı okunmadan yenisi gönderilmez. Yeniden başlatma ya da flaş sonrası beklenen durum (fastboot'ta görünme ya da SSH yanıtı) doğrulanmadan sonraki adıma geçilmez.
- SSH yalnızca anahtarla ve sabitlenmiş `known_hosts` ile yapılır (`StrictHostKeyChecking=yes`).

## 6. Uzaktan çalışma kuralları

- Yeniden başlatmalar yalnızca yazılımla yapılır; tuş kombinasyonu gerektiren adım planlanmaz.
- Fastboot'a almadan önce USB kararlılığı denetlenir (`kk-usb-kontrol`: 60 sn kopma yok).
- Açılıştan sonra cihaz 4 dakika içinde beklenen uçta (SSH ya da telnet) görünmezse önce `fastboot devices` denetlenir. Fastboot'taysa geri dönüş imajını yazmak önerilir. Ne SSH/telnet'te ne fastboot'ta görünüyorsa dur: başka komut denenmez, fiziksel müdahale istenir.
- İnternetten indirilen her dosya boyut, tür ve mümkünse sha256 ile doğrulanır; sürümler sabitlenir; indirilen betikler çalıştırılmaz, yalnızca veri olarak incelenir.

## 7. Ölü adam sayaçları

- **Riskli uzak adım:** `kk-deadman` sayacı altında yapılır (süre en az 300 sn). Sayaç korunan adımla aynı betikte `trap … EXIT` ile iptal edilir ve iptal doğrulanır (birim pasif, "iptal (sağlıklı)" satırı var, işaret dosyaları silinmiş).
- **Fastboot ölü adamı** (`kk-fb-oluadam`, 5 dakikada bir): cihaz 20 dakika kesintisiz fastboot'ta ve o sürede hiçbir kk-bin çağrısı yoksa bilinen iyi çekirdeğe döner (`kk-v51-don`); kalış başına 1, 24 saatte en çok 2 deneme. Bilerek uzun fastboot beklemesinden önce kapatma dosyası konur.
- **4.9 Wi-Fi bekçisi** (`wifi/kk-wifi-bekci`): 20 dakika kesintisiz bağlantısızlıkta flaşsız yeniden başlatma (6 saatte 1, 24 saatte 3; son 30 dakikada SSH oturumu varsa bekler).
- **Ana hat oturumları:** oturum sınırı zamanlayıcısı (varsayılan 720 sn; test 1200 sn), şarj IC'sinin donanım bekçisi ve SP805 bekçisi (60 sn) birlikte güvenlik ağıdır.

## 8. Ana hat çekirdeğinde yazma kapıları

Ana hat çekirdeği PMIC, şarj IC'si, Type-C ve düşük güç yönetim işlemcisine (LPM3) yazmaz; istisnalar yalnızca şu onaylı izin listeleridir:

| Aygıt | Yazılabilen | Koşul |
|---|---|---|
| Şarj IC'si, yazmaç 0x90 | yalnızca CHG_EN biti | geri okuma |
| Şarj IC'si, yazmaç 0xE9 | yalnızca WDT[1:0] | geri okuma |
| Şarj IC'si, yazmaç 0xE8 | besleme | geri okuma |
| PMIC 0x3E bit 0 | Wi-Fi 32 kHz saati | açılış başına 1; geri okuma tutmazsa 1 geri alma |
| LM36274 0x04/0x05 ← 0 | arka ışık kapatma | açılış başına en çok 2 |

Yeni bir yazma ayrı onay, tek işlev, geri okuma ve yazma kanıtı ister. Şarj IC'sinin donanım bekçisi (`0xE9`) besleme kesilince en geç 40 sn'de CHG_EN=0 yapar.

## 9. Sıcaklık sigortası (ana hat)

Pil 45 C üstü ya da SoC 70 C üstü, iki ardışık okumada: CHG_EN=0 (300 ms içinde, yeniden başlatma geciktirilmez), sonra önyükleyiciye yeniden başlatma. sysfs eşikleri yalnızca düşürülebilir; o anki sıcaklığın altına çekmek oturumu birkaç saniyede bitirir.

## 10. eMMC yazma penceresi (ana hat)

Ana hat eMMC'ye yalnızca zaman sınırlı bir yazma penceresinde yazar; pencere dışı yazma ya da yetkisiz bölüme yazma çekirdek katmanında reddedilir. Döngü (loop) aygıtlarında doğrudan G/Ç (`direct-io`) zorunludur: tamponlu yazma pencere dışında loop katında başarılı görünür, hata ancak `sync`'te çıkar ve veri karta inmez. `losetup` yazma penceresi kapalıyken rw isteğini sessizce salt okunura düşürür; sysfs `ro` değeri ayrıca denetlenir.

## 11. Ana hatta kapanış

Ana hatta `poweroff`/`halt` yoktur: "Power down" sonrası CPU kilitlenir, SP805 sıfırlaması boot-hata bayrağını kurar ve sonraki açılış eRecovery yuvasına gider. Kapatma yerine yeniden başlatma kullanılır. Sebepsiz sıfırlama (sysrq-b, SP805) da önyükleyicece anormal sayılır; sonraki yeniden başlatma kurtarma yuvasına düşer ve bayrak `kk-kurtarma bfr` ile temizlenir.

## 12. Belgeler ve kayıt

Her görev sonunda ham bulgular tek bir çalışma kaydına yazılır; kalıcı belgeler yalnızca bir aşama kapandığında güncellenir. Cihaza gidecek betiklerin hiçbiri belge üretmez; belgeler elle yazılır.
