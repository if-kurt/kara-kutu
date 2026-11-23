#!/usr/bin/env python3
"""G45: cihazda koşacak deney denetleyicilerinin kk-anahat-ssh komutlarını üretir ve YEREL olarak yalnız denetler
(kural 15b: hiçbir şey çalıştırılmaz; uzunluk <= 1000 ve iç betik `sh -n`). Çıktı: komutlar-uretilen.txt

Ortak kurallar: yalnız onaylı yazmalar -> cpufreq scaling_governor (performance <-> schedutil), cpuidle stateN/disable.
Her denetleyici çıkışta (trap EXIT) her şeyi eski hâline döndürür (governor performance, bütün durumlar kapalı);
reboot da zaten eski hâline döndürür (açılışta kapalı). Loglar <4>kk: deney: ... ile kmsg'ye (pstore'a da düşer).
"""
import shlex
import subprocess
import sys

P = "/sys/bus/i2c/devices/0-006b/sarj/durum"
C = "/sys/devices/system/cpu"
T = "/sys/class/thermal/thermal_zone4/temp"

ORTAK = (
    f"P={P};C={C};T={T};H='0 1 2 3 4 5 6 7';"
    "w(){ while ! grep -q \"durum=$1 \" $P;do sleep 1;done;};"
)

# Oturum 1: schedutil. Her pencerenin koşulu, o pencereden önceki dinlenmede ayarlanır. ABBA ABBA.
S1 = ORTAK + (
    "k(){ read u x</proc/uptime;echo \"<4>kk: deney: $* up=$u gov=$(cat $C/cpufreq/policy0/scaling_governor)/$(cat $C/cpufreq/policy4/scaling_governor) f=$(cat $C/cpufreq/policy0/scaling_cur_freq)/$(cat $C/cpufreq/policy4/scaling_cur_freq) soc=$(cat $T)\">/dev/kmsg;};"
    "g(){ echo $1>$C/cpufreq/policy0/scaling_governor;echo $1>$C/cpufreq/policy4/scaling_governor;};"
    "trap \"g performance;k geri-alindi\" EXIT;k basladi;"
    "for c in performance performance schedutil schedutil performance performance schedutil schedutil;do w DINLENME;g $c;w SARJ;sleep 2;k pencere $c;done;"
    "w DINLENME;k bitti"
)

# cpuidle ortak: s <durum> "<cpular>" <disable değeri>; x = kararlılık denetimi (yeni stall/Oops/SError satırı)
IDLE = ORTAK + (
    "k(){ read u x</proc/uptime;echo \"<4>kk: deney: $* up=$u u=$(cat $C/cpu[0-7]/cpuidle/state[12]/usage|tr '\\n' ,) soc=$(cat $T)\">/dev/kmsg;};"
    "s(){ for n in $2;do echo $3>$C/cpu$n/cpuidle/state$1/disable;done;};"
    "e(){ dmesg|grep -v -e sudo -e systemd|grep -cE 'stall|Internal e|Oops|SError|BUG:|ockup|OCKUP';};z(){ [ $(e) = $E0 ]||exit 1;};"
)
YUK = (
    "Y(){ L=;for i in 1 2;do timeout 60 yes>/dev/null& L=\"$L $!\";done;j=0;while [ $j -lt 12 ];do sleep 5;j=$((j+1));[ $(cat $T) -gt 62000 ]&&{ kill $L;k yuk-kesildi-sicak;break;};done;wait;};"
)
# Oturum 2a: core-sleep (state1) kararlılığı: CPU3 60 sn -> hepsi -> 300 sn boşta -> 60 sn yük (SoC > 62 C'de yük kesilir)
S2A = IDLE + YUK + (
    "trap \"s 1 \\\"$H\\\" 1;s 2 \\\"$H\\\" 1;k geri-kapali\" EXIT;E0=$(e);k basladi e0=$E0;"
    "s 1 3 0;k cpu3-s1;sleep 60;z;"
    "s 1 \"$H\" 0;k hepsi-s1;sleep 300;z;k bosta-ok;Y;z;trap - EXIT;k kararli-s1-acik"
)
# Oturum 2b / 3b: ölçüm. Koşul listesi = pencere başına state1/state2 disable değerleri ("d1:d2").
def olcum(kosullar):
    return IDLE + (
        "trap \"s 1 \\\"$H\\\" 1;s 2 \\\"$H\\\" 1;k geri-kapali\" EXIT;E0=$(e);k olcum-basladi;"
        f"for c in {kosullar};do w DINLENME;s 1 \"$H\" ${{c%:*}};s 2 \"$H\" ${{c#*:}};w SARJ;sleep 2;k pencere d=$c;z;done;"
        "w DINLENME;k olcum-bitti"
    )
S2B = olcum("0:1 0:1 1:1 1:1 0:1")
# Oturum 3a: cluster-sleep kararlılığı (state1 zaten açık başlatılır): A53 kümesi 60 sn -> A73 -> 300 sn boşta -> 60 sn yük
S3A = IDLE + YUK + (
    "trap \"s 1 \\\"$H\\\" 1;s 2 \\\"$H\\\" 1;k geri-kapali\" EXIT;E0=$(e);k s3a e0=$E0;"
    "s 1 \"$H\" 0;"
    "s 2 '0 1 2 3' 0;k a53;sleep 60;z;"
    "s 2 '4 5 6 7' 0;k s2;sleep 300;z;k bosta-ok;Y;z;trap - EXIT;k kararli-s2-acik"
)
S3B = olcum("0:0 0:0 0:1 0:1 1:1 1:1")
# Oturum 4: birleşik. Önce bütün durumlar + schedutil 120 sn (kararlılık denetimi), sonra pencere başına A (hepsi açık +
# schedutil) / B (hepsi kapalı + performance): A A B B A A B B. Durumlar S2/S3'te tek tek kararlılık göstermiş olmalı.
S4 = IDLE + (
    "g(){ echo $1>$C/cpufreq/policy0/scaling_governor;echo $1>$C/cpufreq/policy4/scaling_governor;};"
    "a(){ s 1 \"$H\" $1;s 2 \"$H\" $1;};"
    "trap \"a 1;g performance;k geri\" EXIT;E0=$(e);a 0;g schedutil;k s4;sleep 120;z;"
    "for c in A A B B A A B B;do w DINLENME;[ $c = A ]&&{ a 0;g schedutil;}||{ a 1;g performance;};w SARJ;sleep 2;k pencere $c $(cat $C/cpufreq/policy4/scaling_governor);z;done;"
    "w DINLENME;k s4-bitti"
)


def sar(birim, betik):
    # kk-anahat-ssh '<komut>': dış tek tırnak; betikte tek tırnak var -> '\'' ile kaçır
    ic = betik.replace("'", "'\\''")
    return f"sudo -n systemd-run --unit={birim} --collect /bin/sh -c '{ic}'", betik


def main():
    out = []
    ok = True
    for ad, birim, b in (("S1", "kk-verim-deney", S1), ("S2A", "kk-verim-kararlilik", S2A), ("S2B", "kk-verim-deney", S2B),
                         ("S3A", "kk-verim-kararlilik", S3A), ("S3B", "kk-verim-deney", S3B), ("S4", "kk-verim-deney", S4)):
        uzak, betik = sar(birim, b)
        # kk-anahat-ssh argümanı = uzak komut; dış kabukta tek tırnaklı verilir
        arg = uzak
        r = subprocess.run(["sh", "-n", "-c", betik], capture_output=True, text=True)
        # uzak kabuk ayrıştırması: uzak komutun kendisi de sh ile ayrıştırılabilmeli
        r2 = subprocess.run(["sh", "-n", "-c", uzak], capture_output=True, text=True)
        durum = "OK" if (r.returncode == 0 and r2.returncode == 0 and len(arg) <= 1000) else "HATA"
        ok &= durum == "OK"
        out.append(f"# {ad} uzunluk={len(arg)} sh-n(ic)={r.returncode} sh-n(uzak)={r2.returncode} {durum} {r.stderr.strip()} {r2.stderr.strip()}")
        out.append(f"{ad}={arg}")
        out.append(f"{ad}_CAGRI=/opt/kara-kutu/tools/kk-bin/kk-anahat-ssh {shlex.quote(arg)}")
        # geri dönüşüm denetimi: yerel kabuk tırnaklı argümanı tam olarak aynı dizgeye çözmeli
        geri = subprocess.run(["sh", "-c", "printf %s " + shlex.quote(arg)], capture_output=True, text=True).stdout
        assert geri == arg, ad
    open(sys.argv[1], "w").write("\n".join(out) + "\n")
    print("\n".join(l for l in out if l.startswith("#")))
    sys.exit(0 if ok else 1)


main()
