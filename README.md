<!-- SPDX-License-Identifier: GPL-2.0-only -->
# Kara Kutu

License: GPL-2.0-only (see [LICENSE](LICENSE)). Kernel work: <https://github.com/if-kurt/linux-kirin710>

A toolkit for running a bare Huawei P30 Lite (Kirin 710, "Marie") as a headless Linux board, without Android. The goal is a repeatable way to install and remove a chosen Linux distribution on this phone SoC while keeping every step recoverable.

> **Warning.** This is a research project that writes to the storage of a real device. A wrong command can permanently brick the phone, and the identity/calibration partitions cannot be recreated. Everything here is provided as is, without warranty. Use it at your own risk and take a full backup of every partition first.

## Goal

The long-term goal is a phone-sized 24/7 low-power Linux server running **its own mainline kernel**, with the pieces the stock stack never gave to mainline:

- a mainline kernel (6.12 series) that boots and runs on the device without vendor code paths;
- **our own Wi-Fi** support for the on-board Hi1102 chip (firmware loading and bring-up written from scratch for mainline);
- **our own power management**: charging, battery and thermal handling, idle/low-power states, so the board can stay on a charger unattended;
- GPU support, later, if the mainline stack allows it;
- an installer-style toolset that can put Debian, Alpine, Droidian, postmarketOS and others on the device on demand and take them off again, with a tested way back to a known-good state at every step.

## Status

Working research project, not an installer.

- Daily system: a custom 4.9 kernel (fork of the vendor tree plus an embedded initramfs) running Debian 12.
- Mainline 6.12.117 is brought up in stages in a separate repository, [`linux-kirin710`](https://github.com/if-kurt/linux-kirin710) (may be private): charging phases 1-3 with a thermal fuse, an efficiency stage, time-boxed eMMC write gating, and Wi-Fi bring-up (the Hi1102 card is detected; the firmware handshake is the next step).
- Every mainline test session ends with a return to the known-good 4.9 kernel.

## Repository layout

| Path | Contents |
|---|---|
| `docs/cihaz-ozeti.md` | Device and system overview (Turkish) |
| `docs/teknik-rapor.md` | Kernel and boot technical report with a corrections log (Turkish) |
| `docs/guvenlik-tasarimi.md` | Safety design: protected partitions, write gates, allow-lists, thermal fuse, dead-man timers (Turkish, English summary at the top) |
| `docs/kurulum-kurtarma.md` | Boot modes, install and recovery procedures (Turkish) |
| `docs/konu/` | Topic notes: tooling pitfalls, kernel log handling, QEMU (Turkish) |
| `tools/kk-bin/` | Host-side wrapper scripts. Each validates its input, takes a lock and logs. Includes the dead-man timers and the scripted recovery (`kk-kurtarma`, `kk-kurtarma-oto`) |
| `tools/py/` | Image tools: AVB info, test boot image builder, Huawei UPDATE.APP unpacker, EROFS reader, block diff |
| `tools/qemu/` | QEMU VM slot helper used for regression runs |
| `initramfs/` | Early-boot scripts embedded in the kernel image: `init`, write gate (`kk-alan`), health watchdog (`kk-saglik`), idle watchdog, zram setup, Wi-Fi firmware loader and watchdog, rescue shell helper |
| `wifi/` | Wi-Fi watchdog and event helpers for the 4.9 Debian side |
| `postmarketos/` | Local postmarketOS recipe (`device-huawei-marie`, `linux-huawei-marie`) for use with your own pmaports checkout; not bootable yet, see `postmarketos/KNOWN-GAPS.md` |

Documentation is in Turkish; the safety summary below and the header of `docs/guvenlik-tasarimi.md` are in English.

## Safety design in one page

The device has no recovery that can be trusted after writing the wrong partition, so the toolkit is built around not being able to do that:

- **Protected partitions.** Bootloader, firmware, identity/calibration, modem and vendor-specific partitions are never written. Only a short allow-list (`kernel`, recovery slots, `system`, `product`, `preload`, `cust`, `cache`, `userdata`) can be flashed, and only with explicit approval.
- **Fixed device selection.** Every fastboot/adb call names the device serial explicitly (`KK_SERI`); other USB devices are never touched.
- **Wrapper scripts.** Routine device actions (kernel flash, reboot, measurement, pstore collection, return to the known-good kernel, rescue) go through `tools/kk-bin/` scripts that check image type, size and sha256 before acting. The manifest `tools/kk-bin/SHA256SUMS` pins them.
- **No blind erase/unlock.** `fastboot erase`, `oem`, `flashing lock/unlock`, `format` and `getvar` are not used.
- **Mainline write gates.** The mainline kernel can write only to the charger IC (CHG_EN, watchdog bits), one PMIC clock bit and the backlight driver, each through an explicit allow-list with read-back. eMMC writes happen only inside a time-boxed window with direct I/O enforced.
- **Thermal fuse.** Battery above 45 C or SoC above 70 C (two consecutive samples) clears CHG_EN and reboots to the bootloader.
- **Dead-man timers.** Risky remote steps run under a timer that is cancelled inside the same script and verified. A fastboot dead-man returns the device to the known-good kernel after 20 minutes in fastboot; a Wi-Fi watchdog reboots the 4.9 system after 20 minutes without connectivity. Mainline sessions have a session limit plus two hardware watchdogs (charger IC and SP805).
- **Recovery automation.** The recovery slot carries a rescue environment (telnet) with scripted steps: transfer image, write kernel, clear the boot-failure flag, reboot into either kernel (`kk-kurtarma`, and the unattended variant `kk-kurtarma-oto`).

Details: [docs/guvenlik-tasarimi.md](docs/guvenlik-tasarimi.md). Install and recovery guide: [docs/kurulum-kurtarma.md](docs/kurulum-kurtarma.md).

## Quick start (host side)

Requirements: Linux host with `adb`/`fastboot`, `ssh`, `nc`, `python3`; optional QEMU 8.2 for regression runs.

```
export KK_SERI=<fastboot serial of your device>
export KK_KULLANICI=<login user on the device>     # default: kk
cd tools/kk-bin
./kk-usb-kontrol            # USB stability check before touching fastboot
```

The scripts expect to live in `/opt/kara-kutu/tools/kk-bin` (see the install guide) and read the known-good kernel image from a path you provide. They refuse to run when the manifest hash or image checks fail. Read the recovery guide before flashing anything. Host key pinning uses a per-installation `known_hosts` that is not shipped; generate it as described in the install guide.

## Not included

Stock images and backups, vendor firmware (bootloader, Wi-Fi/Bluetooth firmware), raw logs and dumps, per-device identity data. Make your own backup of every partition before using this on a device.

## License

GPL-2.0-only for the scripts, tools and documentation in this repository (full text in `LICENSE`, taken from the Linux kernel's `LICENSES/preferred/GPL-2.0`). The kernel work lives in the separate `linux-kirin710` repository and is also GPL-2.0-only.

## Türkçe özet

Kara Kutu, Huawei P30 Lite'ı (Kirin 710) Android olmadan, başsız (headless) bir Linux kartı olarak çalıştırmak için bir araç setidir. Asıl hedef: kendi ana hat (mainline) Linux çekirdeği, kendi Wi-Fi ve güç yönetimi desteği, 7/24 çalışan düşük güçlü bir sunucu ve ileride GPU; ayrıca Debian, Alpine, Droidian, postmarketOS gibi dağıtımları istenen anda kurup kaldırabilen, her adımı geri alınabilir bir araç seti.

Cihazda şu an kendi 4.9 çekirdeğimiz (gömülü initramfs) ve Debian 12 günlük sistem olarak çalışır; ana hat 6.12.117 çekirdeği aşama aşama taşınmaktadır (ayrı depo: [`linux-kirin710`](https://github.com/if-kurt/linux-kirin710)).

Tasarımın özü güvenliktir: asla yazılmayan bölüm listesi (önyükleyici, firmware, kimlik/kalibrasyon, modem), cihaz seri numarasının her komutta açıkça verilmesi, özetle sabitlenmiş `kk-bin` sarmalayıcı betikleri, ana hat çekirdeğinde yalnızca izin listeli yazmalar, sıcaklık sigortası, ölü adam sayaçları ve betikli kurtarma. Ayrıntı: `docs/guvenlik-tasarimi.md`; kurulum ve kurtarma: `docs/kurulum-kurtarma.md`.

Uyarı: cihaz kalıcı olarak bozulabilir; sorumluluk size aittir. Kendi yedeğinizi almadan hiçbir şey çalıştırmayın; kimlik ve kalibrasyon bölümleri yeniden üretilemez. postmarketOS tarifi ayrı bir commit ile eklenecektir (`postmarketos/`, planlanıyor).
