# Known gaps

Status of this recipe: written on paper, never built with pmbootstrap, never
booted on a device. Everything below is either a known gap or "not verified".

## 1. Boot chain (the hard part)

| Issue | Effect | State |
|---|---|---|
| The bootloader loads the payload of the `kernel` partition at 0x80000 and uses its OWN device tree (the DTB in the boot image is ignored). | A shim (`linux-huawei-marie/shim.S`) copies the Image to 0x04000000 and passes the embedded DTB. | Shim rebuilt from this source is byte identical to the one in the daily image. |
| The bootloader never loads a ramdisk (the board has no `ramdisk` partition). | The pmOS initramfs is not reachable. `deviceinfo_generate_bootimg="false"` because the generic boot.img has no shim. | OPEN. See "Initramfs" in README. |
| `fastboot boot` has no handler; `getvar` is refused. | `pmbootstrap flasher boot` will not work. | Not verified beyond the above observations. |
| Command line is not passed on; `CONFIG_CMDLINE` is empty. | `kernel-cmdline.conf` (incl. `pmos_*_uuid`) only works when written into the DTB (`tools/pack-kernel-partition.sh` does that). | Implemented, not booted with pmOS. |
| The generated pmOS initramfs exists only after the kernel build. | It cannot be embedded through `CONFIG_INITRAMFS_SOURCE`. | OPEN (option A: extend the shim to copy an initramfs to a fixed address and add `linux,initrd-start/end` to the DTB; option B: a small embedded stage 1 that mounts a pmOS rootfs and switches root). Neither is written. |

## 2. Storage

- The kernel carries a write gate: block-device writes outside a window declared in
  the DT are refused (`CONFIG_KK_EMMC_YAZMA=y`). The in-tree DTB has no window, so
  the default is NO WRITE to eMMC. A pmOS rootfs cannot live on the internal
  storage. Options: root over USB, RAM overlay, or a future DT window on a
  separate partition (needs its own review). Do not widen the gate for pmOS.
- Writing any partition of the board other than `kernel` is outside this recipe.
- Poweroff and halt do not work on this kernel (the CPU locks up after "Power
  down", the watchdog resets, the next boot goes to the recovery path). Use reboot only.

## 3. Device tree

- `deviceinfo_dtb` points at `kirin710-huawei-marie-birlesik`. The DTB of the daily
  image is that DTB plus post-processing done by the project build script: model
  string, bootargs, a "no low power" property for the MMC host, a PIL guard
  fragment, a reboot-mode fragment and the eMMC window template. The in-tree DTB
  alone is NOT equivalent. Port those fragments into the fork before relying on it.
- The `compatible` is `huawei,marie` / `hisilicon,kirin710`; the pmOS device
  package name `huawei-marie` matches it.

## 4. Kernel config (`config-huawei-marie.aarch64`)

Derived from the daily mainline image config with these changes only:
`CONFIG_INITRAMFS_SOURCE=""` (was an absolute path to a local list),
`CONFIG_LOCALVERSION="-huawei-marie"`, and the Hi1102 Wi-Fi symbols
(`KK_HI1102_YUKLE/PORT/M3A/M3B/M3C/M3C_L3_GENIS`, firmware dir, MAC) switched off
because they embed firmware from a local directory. Result: no Wi-Fi in this config.
`make olddefconfig` on the fork tree accepts it without changes to anything else.

Properties that matter to pmOS: monolithic (`MODULES` not set), `RD_GZIP` off and
`RD_ZSTD` on (hence `deviceinfo_initfs_compression="zstd:default"`), no NBD, no
`USER_NS`, `USB_CONFIGFS_NCM=y` but no RNDIS.

### pmaports kconfig check gaps (offline approximation)

Run with `tools/kconfig-gap.py` against `kconfigcheck.toml` of a local pmaports
checkout, kernel 6.12.117, aarch64. The real `pmbootstrap kconfig check` is
authoritative; the numbers below only show the size of the gap.

- default: 35. Notables: `USER_NS`, `PID_NS`, `NET_NS`, `UTS_NS`, `IPC_NS`, `SECURITY`,
  `SECURITYFS`, `SECURITY_PATH`, `DM_CRYPT`, `CRYPTO_AES/CBC/XTS`, `VFAT_FS`, `NLS_ASCII`,
  `PSI`, `SYN_COOKIES`, `UEVENT_HELPER`, `BPF_JIT`, `BPF_LSM`, `FTRACE`, `KPROBES`,
  `KPROBE_EVENTS`, `DEBUG_INFO_BTF`, `DEBUG_INFO_DWARF5`, `DRM_FBDEV_EMULATION`,
  `INPUT_EVDEV`, `NULL_TTY`, `UDMABUF`, `FW_LOADER_COMPRESS(_ZSTD)`,
  `MODULE_COMPRESS(_ZSTD)`, `MODULE_DECOMPRESS`.
- usb: 13 (storage, UAS, USB serial, USBNET, RTL8152, RNDIS host, UDL, USB audio, DRM).
- usb_gadgets: 5 (`USB_CONFIGFS_ACM/F_FS/MASS_STORAGE/RNDIS`, `USB_F_FS`).
- netboot: 2 (`BLK_DEV_NBD`, `BLK_DEV_UBLK`).
- zram: 5 (backends 842, deflate, lz4, lz4hc, lzo).
- nftables: 24 (`NETFILTER` is off; the whole nf_tables family is missing).
- filesystems: 13 (btrfs, erofs, exfat, f2fs, iso9660, udf, xfs, joliet).
- Other categories (containers 69, input 139, selinux, hardening, waydroid, ...) are
  not requested by `deviceinfo`/APKBUILD here and were not tuned.

Most of these require MODULES or new code paths in a kernel that is built and
tested as one fixed image. Closing them means a new kernel build and a new device
test round; it is not part of this recipe. `RD_GZIP`, `USER_NS` and `NETFILTER` are
the cheapest first candidates.

## 5. Conflicts with the project safety gates

- The write gate and the missing DT window (section 2).
- The charge policy, temperature fuse and chip watchdog are compiled in and
  depend on DT nodes; without the post-processed DTB (section 3) they are not
  in their tested configuration.
- No poweroff (section 2); `postmarketos-base` services that call poweroff
  (shutdown on low battery, `poweroff` from a UI) end in a reset path.
- The pmOS default firewall (`supported_firewall=nftables`) cannot work (section 4).

## 6. Not verified

- pmbootstrap was never run: `deviceinfo` was checked against the schema by name
  only; the APKBUILDs pass `sh -n` only.
- `boot-deploy` behaviour with `generate_bootimg="false"` and without a modules
  directory (`MODULES` off); whether `mkinitfs` accepts a kernel without modules.
- `fastboot boot` on this board (assumed unusable).
- That the placeholder fork URL layout (`archive/<commit>.tar.gz`) exists; the
  `_commit` and the two checksums must be filled in by the user.
- Boot of a pmOS user space on this kernel in any way.
