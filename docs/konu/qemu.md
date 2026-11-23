# Konu: QEMU tuzakları


- QEMU `-dtb` ile verilen `/psci` düğümünü silip yeniden yazar; QEMU'da sınanacak özel PSCI bayrakları başka düğüme konur (`/cpus/idle-states`).
- QEMU sahte Hi1102 ROM'u SDIO çağrılarını mmc/dw_mmc/IDMAC katmanına inmeden yakalar: saat, bus kipi (LOW_PWR) ve büyük CMD53 içeriği QEMU'da sınanmaz (G50).
