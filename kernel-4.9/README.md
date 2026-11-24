# 4.9 vendor kernel: known-good fallback (v5.2) and recovery slot (v5.2e)

The daily system runs mainline Linux (see the `linux-kirin710` repository). The
Huawei 4.9 kernel is kept as the safety net:

| Image | Partition | Role |
|---|---|---|
| v5.2 | `kernel` (normal boot slot, only while falling back) | known-good 4.9 + Debian; what `tools/kk-bin/kk-v51-don` writes back |
| v5.2e | `erecovery_kernel` (eRecovery slot) | recovery environment (telnet on the USB link); boots after a bootloader fail-boot redirect or `reboot erecovery` |

Neither image is distributed (they embed vendor-derived parts). This directory
holds what is needed to rebuild them.

## Base

- Tree: <https://github.com/jglasovic/android_kernel_huawei_kirin710>, branch
  `headless-kirin710`, commit `3ca6a91197e82ae9e6aa0547db1422fc13825249`.
- Patches, applied in order with `git am` (0001-0003) and `git apply` (0010, 0011):

| Patch | Applies to | What it does |
|---|---|---|
| `0001-thermal-hisi-…` | both | thermal: fall back to the legacy kirin710 sensor tables on EMUI 9 device trees |
| `0002-power-hisi-coul-…` | both | coul: match the EMUI 9 hi6555v200 compatible |
| `0003-mtd-hisi_nve-…` | both | NV partition read-only: every NV write is refused |
| `0010-block-mmc-emmc-write-gate.patch` | both | eMMC write gate (below) |
| `0011-init-ignore-bootloader-initrd-recovery-slot.patch` | v5.2e only | ignore the bootloader's ramdisk; use the embedded rescue initramfs |

## eMMC write gate (`CONFIG_KK_EMMC_KAPI`)

- At first use the gate reads the GPT and compares partition names, numbers,
  start sectors and sizes, the disk capacity and the partition count with the
  expected layout. Any mismatch keeps the gate closed: every write is refused.
- Writes are allowed only inside the ranges of the selected profile
  (`CONFIG_KK_EMMC_KAPI_PROFIL`):
  - **1** (v5.2): `userdata`, `erecovery_kernel`
  - **2** (v5.2e): `userdata`, `kernel`, and the first 8 sectors of `misc` and `rrecord`
    (the fail-boot flag reset)
  - **3**: `userdata` only. The rescue init narrows 2 → 3 (one way) before it
    switches to Debian.
- Layers:
  - the block layer (absolute sector after remap);
  - the MMC core: data-write opcodes CMD24/25/35/36/38;
  - a CMD6 (SWITCH) allowlist of the EXT_CSD fields the 4.9 init path really sets;
  - `MMC_IOC_CMD`/`MMC_IOC_MULTI_CMD` blocked;
  - command queue and packed commands off.
- Boot partitions and RPMB are never writable.
- A refused bio ends with `-EPERM`. Userspace sees `EIO` with direct I/O, because
  4.9 direct-io maps every bio error to `EIO`.
- Counters and state are in `/sys/kernel/kk_emmc_kapi/` (`durum`, `profil`,
  `red_bio`, `red_mmc`, `red_cmd6`, `red_ioctl`, `son_red`).
- Expected at boot: one CMD6 refusal (EXT_CSD 56, the vendor eMMC monitor
  enabling dynamic-capacity events; the vendor code only logs the failure).

## Configuration

`config/v5.2.config` and `config/v5.2e.config` are the full configurations.
Relative to the earlier v5.1/v5.1e images the only changes are:
`CONFIG_KK_EMMC_KAPI=y`, `CONFIG_KK_EMMC_KAPI_PROFIL=1|2`,
`CONFIG_PANIC_TIMEOUT=10` (reboot 10 s after a panic), and for v5.2e the embedded
rescue initramfs (`CONFIG_INITRAMFS_SOURCE`) with `rescue/init`.

## Rescue init (`rescue/init`, v5.2e)

- USB NCM link with telnet on port 23, the fail-boot flag reset, and the
  battery charge limit.
- **Session timer:** if no telnet session is seen within 45 minutes of boot, the
  init narrows the write gate to profile 3 and switches to the 4.9 Debian on
  `userdata`. That Debian is reachable over Wi-Fi, so the board stays
  reachable on a plain power adapter.
- The host-side automation (`tools/kk-bin/kk-kurtarma-oto`) acts after
  20 minutes, so on USB the host acts first.
- Limits: at most 3 consecutive automatic switches, and at most 4 per 24 h
  (the 24 h limit applies only when the clock is valid).

## Build

```
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- O=out olddefconfig        # with config/v5.2.config as out/.config
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- O=out "BALONG_INC=-I$PWD/kernel" \
     KCFLAGS="-Wno-error=maybe-uninitialized -Wno-error=address -Wno-error=sizeof-pointer-memaccess -Wno-error=misleading-indentation" \
     Image.gz
```

- Reproducible builds:
  - set `KBUILD_BUILD_TIMESTAMP`, `KBUILD_BUILD_USER` and `KBUILD_BUILD_HOST` to fixed values;
  - use a fresh `O=` directory;
  - keep the same absolute source and output paths.
- Packing: `tools/py/mktest.py kernel <stock kernel image> out/arch/arm64/boot/Image.gz <output>`
  reuses the header of the board's own stock `kernel` image (not distributed).
  The output must be an Android boot image (`ANDROID!`) no larger than the
  partition (25 165 824 bytes).
- The rescue initramfs list (`CONFIG_INITRAMFS_SOURCE`) also needs a static
  busybox and static e2fsprogs. These are built from upstream sources; they are
  not included here.

## Verified on the board

- v5.2 in the normal slot:
  - gate `ACIK 1` (open, profile 1);
  - a test write to `cache` was refused (`red_bio` +1, partition hash unchanged);
  - the Debian services ran normally.
- v5.2e in the recovery slot:
  - gate open with profile 2 (`GPT 68 partitions`);
  - the 45-minute timer switched to Debian (gate profile 3), which was reachable over Wi-Fi;
  - after a mainline panic, the fail-boot redirect landed in v5.2e, and the host
    automation cleared the flag and returned to mainline.
