# Kurulum ve kurtarma rehberi

Uyarı: bu rehber bir araştırma projesinin çalışma notudur. Cihazınızdaki **her bölümün tam yedeğini** almadan hiçbir şey flaşlamayın; kimlik ve kalibrasyon bölümleri başka kaynaktan geri getirilemez. Güvenlik kuralları: [guvenlik-tasarimi.md](guvenlik-tasarimi.md).

## 1. Ana makine hazırlığı

Gerekenler: Linux, `adb`, `fastboot`, `ssh`, `nc`, `python3`, `flock`, isteğe bağlı QEMU 8.2 + `gdb-multiarch`, `aarch64-linux-gnu-gcc` (kernel ve statik araçlar için).

1. Depoyu `/opt/kara-kutu/` altına kurun (betikler bu yolu varsayar) ve `tools/kk-bin/` içeriğini `/opt/kara-kutu/tools/kk-bin/` olarak yerleştirin. Günlükler `/opt/kara-kutu/work/kk-bin-log/` altına yazılır; dizini oluşturun.
2. Ortam değişkenleri:
   - `KK_SERI`: cihazın fastboot seri numarası (`fastboot devices` çıktısı).
   - `KK_KULLANICI`: cihazdaki Debian'da oturum açan kullanıcı (varsayılan `kk`; `sudo -n` yetkisi gerekir).
3. Bilinen iyi çekirdek imajını (`kk-rescue-kernel-v5.1.img`) kendiniz derleyin; betikler onu `/opt/kara-kutu/work/test2/` altında arar ve betik içinde sabitlenmiş sha256 ile karşılaştırır. Kendi derlemenizin sha256'sını betiklerdeki `V51_SHA`/`SHA` sabitlerine yazın ve `tools/kk-bin/SHA256SUMS` dosyasını yeniden üretin (`sha256sum` ile).
4. Cihaz tarafı yardımcıları (`tools/kk-bin/cihaz/*.sh`) kurtarma ortamına aktarılırken sha256 denetlenir; değiştirirseniz betik içindeki sabitleri güncelleyin.

### known_hosts (SSH sabitleme)

Depoda anahtar bulunmaz. Cihaz ilk kez kurulup SSH açıkken, ağa güvendiğiniz bir anda:

```
ssh-keyscan -t ed25519 172.16.42.1        > /opt/kara-kutu/tools/kk-bin/known_hosts
ssh-keyscan -t ed25519 -p 2222 172.16.42.1 > /opt/kara-kutu/tools/kk-bin/known_hosts_anahat
```

Parmak izini cihazın konsolundan doğrulayın. Betikler `StrictHostKeyChecking=yes` kullanır; bu dosyalar `SHA256SUMS`'e dahil değildir.

### USB ağı

Cihaz ana makineye USB NCM ile bağlanır. Ana makine arayüzüne `172.16.42.2/24` verin; cihaz `172.16.42.1`'dir. Cihazın internete ihtiyacı varsa ana makinede IPv4 maskeleme ve arayüzler arası yönlendirme kuralı gerekir. Güvenilir port ve kablo kullanın: kopan USB, fastboot adımlarını tehlikeye atar (`kk-usb-kontrol` 60 sn denetler).

## 2. Açılış modları

| Mod | Nasıl | Notlar |
|---|---|---|
| Normal | `kernel` bölümü | Günlük sistem. Önyükleyici normal açılışta ramdisk bölümünü yüklemez; initramfs çekirdeğe gömülüdür |
| Fastboot | `kk-reboot debian-bootloader` ya da Vol Down + Power (USB takılı) | Flaş yalnızca burada, `kk-flash-kernel` ile |
| eRecovery yuvası (kendi kurtarma ortamımız) | `systemctl reboot erecovery` ya da Vol Up + Power (USB takılı) | `telnet 172.16.42.1 23` -> `kk-kurtarma` |
| Recovery (Vol Up + Power, USB yok) | aynı `kernel` bölümü | Güvenilmez: stok ramdisk gömülü `/init`'i ezer |

`boot` adlı bölüm yoktur; hedef `kernel` bölümüdür. `fastboot flash boot` yanlıştır.

## 3. Çekirdek flaşı

Tek adımlık, kontrollü yol:

1. `kk-usb-kontrol`: USB kararlılığı.
2. Cihaz açıkken `kk-reboot debian-bootloader` (ana hat Debian'ından `kk-anahat-ssh 'sudo -n systemctl reboot'`).
3. `fastboot devices` cihazı gösterene kadar bekleyin.
4. `kk-flash-kernel <imaj>`: imajı yalnızca `kernel` bölümüne, yalnızca `-s "$KK_SERI"` ile yazar. Boyut, `ANDROID!` magic'i ve sha256 denetlenir. Yeniden başlatma yapmaz.
5. `kk-reboot fastboot-normal`.
6. 4 dakika içinde cihaz SSH (22 / 2222) ya da telnet (23 / 2323) ucunda görünmezse `fastboot devices`'a bakın; fastboot'taysa `kk-v51-don` ile bilinen iyi çekirdeği yazın.

Ana hat çekirdeği testlerinden sonra her seferinde bilinen iyi 4.9 çekirdeğine dönülür.

## 4. Kurtarma

Kernel açılmıyorsa ve cihaz fastboot'a da düşmüyorsa, eRecovery yuvasındaki kendi kurtarma ortamı (telnet 23) kullanılır. Sıra: **aktar, kernel, bfr, reboot**.

- `kk-kurtarma durum`: salt okuma; boot-hata nedeni, `misc`/`rrecord` ilk baytları, bazı bölümlerin sha'ları.
- `kk-kurtarma aktar`: bilinen iyi imaj ile iki cihaz betiğini `nc` ile kurtarma ortamının `/tmp` bölgesine aktarır; üçünün sha256'sı denetlenir.
- `kk-kurtarma kernel`: sha256'lar yeniden denetlenir, sonra imaj `kernel` bölümüne yazılır.
- `kk-kurtarma bfr`: boot-hata bayrağını temizler. Önce kernel, sonra bayrak.
- `kk-kurtarma reboot [22|2222]`: `/data` ayrılır, sonra 22 (4.9 Debian) ya da 2222 (ana hat Debian) uçunda SSH beklenir.

Telnet 23 de yanıt vermiyorsa: ekranı ve tuşları olan birinin cihazın başına gitmesi gerekir. Kurtarma yuvası ya da bölümler elle yazılmaz; başka komut denenmez.

### Sık karşılaşılan durumlar

- Ana hat çekirdeği donarsa SP805 sıfırlaması boot-hata sayılır ve açılış eRecovery yuvasına gider (fastboot'a değil). `kk-kurtarma bfr` bayrağı temizler.
- Sebepsiz sıfırlamadan sonraki açılış normal geçebilir, bir sonraki yeniden başlatma kurtarmaya düşebilir.
- Ana hatta kapatma komutu yoktur; kapatma yerine yeniden başlatma kullanılır.
- Cihaz şarj adaptöründeyken ana hat ağsızdır. Kabloyu yalnızca 4.9 açıkken değiştirin.

## 5. Ana hat çekirdeği

Ayrı depoda (`linux-kirin710`). Önce QEMU ve birim sınamaları (`tools/qemu/`), sonra cihazda sınırlı oturum. Her ana hat oturumunun başında şu üç güvenlik ağı okunarak doğrulanır: oturum sınırı zamanlayıcısı, şarj IC'sinin donanım bekçisi, SP805. Ayrıntı: [teknik-rapor.md](teknik-rapor.md).

## 6. Wi-Fi notları

- `wpa_supplicant` yapılandırmasında `p2p_disabled=1` zorunludur (P2P kararsızlık yaratır).
- Çip yönetim düğümlerine rastgele yazmayın; özellikle `wifi_pm` güç yönetimi düğümüne yazmak çipin zamanlayıcılarını durdurur.
- Firmware dosyaları depoda yoktur; kendi cihazınızdan alın (`kk-49-wifi-fw-al`).
