#!/bin/bash
# G57 G-2 önerisi: build.sh'e eklenecek DTB denetimi (reboot-mode beyaz listesi; çalışma anında yazma engellenemediği
# için asıl engel budur). Kullanım: rm-denetim.sh <dtb> <beklenen: eski|g2>
#   eski: reboot-mode modları TAM OLARAK {bootloader=0x01}          (bugünkü bütün imajlar)
#   g2  : reboot-mode modları TAM OLARAK {bootloader=0x01, erecovery=0x08, normal=0x10}
# Ayrıca: offset 0x1e1, mask 0xff, tek reboot-mode düğümü; sigorta hedefi yalnız bootloader|erecovery ve erecovery
# ise mode-erecovery şart. Çıkış 0 = TUTTU, 1 = TUTMADI (build durur).
set -u
DTB=$1; BEK=$2
case $BEK in eski) IST="bootloader=0x01";; g2) IST="bootloader=0x01 erecovery=0x08 normal=0x10";; *) echo "kullanim: rm-denetim.sh <dtb> eski|g2"; exit 64;; esac
T=$(dtc -q -I dtb -O dts "$DTB") || { echo "RM-DENETIM: dtc okuyamadi"; exit 1; }
n=$(echo "$T" | grep -c 'compatible = "syscon-reboot-mode"')
[ "$n" = 1 ] || { echo "RM-DENETIM TUTMADI: syscon-reboot-mode dugumu sayisi $n"; exit 1; }
RM=$(echo "$T" | awk '/compatible = "syscon-reboot-mode"/{f=1} f{print} f&&/};/{exit}')
echo "$RM" | grep -q 'offset = <0x1e1>;' || { echo "RM-DENETIM TUTMADI: offset 0x1e1 degil"; exit 1; }
echo "$RM" | grep -q 'mask = <0xff>;' || { echo "RM-DENETIM TUTMADI: mask 0xff degil"; exit 1; }
VAR=$(echo "$RM" | sed -n 's/^[[:space:]]*mode-\([a-z0-9_-]*\) = <\(0x[0-9a-f]*\)>;.*/\1=\2/p' | while IFS== read -r a v; do printf '%s=0x%02x\n' "$a" $((v)); done | sort | tr '\n' ' ' | sed 's/ $//')
BEKS=$(echo "$IST" | tr ' ' '\n' | sort | tr '\n' ' ' | sed 's/ $//')
[ "$VAR" = "$BEKS" ] || { echo "RM-DENETIM TUTMADI: modlar '$VAR' beklenen '$BEKS'"; exit 1; }
H=$(echo "$T" | sed -n 's/.*karakutu,sigorta-hedef = "\([^"]*\)";.*/\1/p')
case ${H:-bootloader} in bootloader) ;; erecovery) echo "$VAR" | grep -q 'erecovery=0x08' || { echo "RM-DENETIM TUTMADI: sigorta-hedef erecovery ama mode-erecovery yok"; exit 1; };; *) echo "RM-DENETIM TUTMADI: sigorta-hedef '$H' izinli degil"; exit 1;; esac
P=$(echo "$T" | sed -n 's/.*karakutu,pil-kurtarma-hedef = "\([^"]*\)";.*/\1/p')
case ${P:-bootloader} in bootloader) ;; erecovery) echo "$VAR" | grep -q 'erecovery=0x08' || { echo "RM-DENETIM TUTMADI: pil-kurtarma-hedef erecovery ama mode-erecovery yok"; exit 1; };; *) echo "RM-DENETIM TUTMADI: pil-kurtarma-hedef '$P' izinli degil"; exit 1;; esac
echo "RM-DENETIM TUTTU: modlar '$VAR' sigorta-hedef ${H:-bootloader} pil-kurtarma-hedef ${P:-bootloader}"
