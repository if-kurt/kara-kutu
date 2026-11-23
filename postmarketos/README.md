# postmarketOS recipe for the Huawei P30 Lite (huawei-marie), local use only

Two packages for a LOCAL pmaports fork: `device-huawei-marie` and
`linux-huawei-marie` (mainline 6.12 based fork of this project). This is not
meant for the official pmaports tree and is not submitted anywhere.

Status: untested. The recipe has not been built with pmbootstrap and has not been
booted. Read `KNOWN-GAPS.md` first.

## WARNING: no eMMC write

- Nothing in this recipe writes to the internal storage, and nothing here should.
  The kernel refuses block-device writes outside a window declared in the
  device tree, and the DTB has no such window.
- Never run `pmbootstrap flasher flash_rootfs`, `flash_kernel`, `flash_vbmeta` or
  similar against this board. The only partition that may ever be written is
  `kernel`, by hand, after a separate decision, with a known-good image ready
  to restore.
- Keep the stock bootloader, firmware, identity and modem partitions untouched.

## Layout

```
device-huawei-marie/   deviceinfo, kernel-cmdline.conf, APKBUILD
linux-huawei-marie/    APKBUILD, config-huawei-marie.aarch64, shim.S
tools/                 pack-kernel-partition.sh, clone-boot-header.py, kconfig-gap.py
KNOWN-GAPS.md          open problems and unverified items
```

## Build (host only)

1. Install pmbootstrap and create a local fork of pmaports; run `pmbootstrap init`
   and point it at that fork.
2. Copy `device-huawei-marie/` and `linux-huawei-marie/` into the fork, for
   example under `device/testing/`.
3. Edit `linux-huawei-marie/APKBUILD`: set `_commit` to a real commit of
   `https://github.com/if-kurt/linux-kirin710`, then `pmbootstrap checksum
   linux-huawei-marie device-huawei-marie`.
4. `pmbootstrap build linux-huawei-marie --arch aarch64` and
   `pmbootstrap build device-huawei-marie`.
5. Optional: `tools/kconfig-gap.py <pmaports>/kconfigcheck.toml
   linux-huawei-marie/config-huawei-marie.aarch64 6.12.117 aarch64 default usb`
   and `pmbootstrap kconfig check linux-huawei-marie`.
6. `pmbootstrap install` only fills a rootfs image on the host. It does not touch
   the device.

## Getting the kernel to the board (design, not verified)

The bootloader reads only the `kernel` partition (25165824 bytes max), loads its
payload at 0x80000 with its own device tree, and does not load a ramdisk.
`tools/pack-kernel-partition.sh IMAGE DTB STOCK_KERNEL_IMG OUT_IMG` builds that
payload: it writes `kernel-cmdline.conf` into the DTB, wraps DTB + Image in the
shim, gzips it and clones the header of YOUR OWN backup of the stock kernel
partition (that image is not included here). It only writes `OUT_IMG`.

`fastboot boot` is not usable on this board (no handler in the bootloader) and
`pmbootstrap flasher boot` is therefore not expected to work: not verified.

## Netboot

Netboot is the intended way to try this later, but it is not available yet:
the pmOS initramfs cannot reach the kernel (the bootloader ignores the ramdisk,
and the initramfs is generated after the kernel build), and the kernel has no
NBD. See "Initramfs" below and `KNOWN-GAPS.md`. Until that exists, nothing in
this recipe can boot a pmOS user space.

## Initramfs (open)

- Option A: extend the shim to copy an initramfs to a fixed address below the
  kernel and add `linux,initrd-start` / `linux,initrd-end` to `/chosen` at pack
  time; the compression must match the kernel (`zstd`, see `deviceinfo`).
- Option B: embed a small stage 1 in the kernel that finds a root on USB and
  switches root.

## Wi-Fi firmware (not shipped)

There is no firmware subpackage. The Hi1102 firmware (`cr4_asic.bin`,
`CPU_RAM_SCHED.bin`, `CPU_RAM_WBS.bin`) is not redistributable: take it from your
own device (its `vendor/firmware` directory). The config in this recipe has the
Wi-Fi driver switched off, so nothing uses it yet.

## Suggested commit message

```
Add local postmarketOS recipe for the Huawei P30 Lite (huawei-marie)

device-huawei-marie: deviceinfo, cmdline, APKBUILD.
linux-huawei-marie: APKBUILD (placeholder commit), config from the daily
image, DTB shim. tools: kernel partition packer, header clone, kconfig gap
checker. KNOWN-GAPS.md lists the open boot-chain and config problems.
Untested; no eMMC write.
```
