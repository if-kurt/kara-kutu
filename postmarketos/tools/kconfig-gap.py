#!/usr/bin/env python3
# Approximate offline re-implementation of the pmaports kconfig check rules.
# It only reads files. The authoritative tool is "pmbootstrap kconfig check".
# usage: kconfig-gap.py KCONFIGCHECK_TOML CONFIG KERNEL_VERSION ARCH [category ...]
#   KCONFIGCHECK_TOML: kconfigcheck.toml from your local pmaports checkout
#   example: kconfig-gap.py ~/pmaports/kconfigcheck.toml config-huawei-marie.aarch64 6.12.117 aarch64 default usb
import re, sys, tomllib

toml_path, cfg_path, kver, arch = sys.argv[1:5]
want = sys.argv[5:]
data = tomllib.load(open(toml_path, "rb"))

def vt(s):
    s = s.replace("_rc", ".0.rc")
    m = re.match(r"(\d+)\.(\d+)(?:\.(\d+))?", s)
    return (int(m[1]), int(m[2]), int(m[3] or 0), 0 if "rc" in s else 1)

kv = vt(kver)

def ver_ok(spec):
    for part in spec.split():
        m = re.match(r"(>=|<=|<|>|=)(.*)", part)
        op, v = m[1], vt(m[2])
        vv = kv
        if "rc" in m[2]:
            v = v[:3]; vv = kv[:3]
        ok = {">=": vv >= v, "<=": vv <= v, "<": vv < v, ">": vv > v, "=": vv == v}[op]
        if not ok:
            return False
    return True

cfg = {}
for ln in open(cfg_path):
    ln = ln.rstrip("\n")
    m = re.match(r"CONFIG_(\w+)=(.*)", ln)
    if m:
        cfg[m[1]] = m[2].strip('"')
        continue
    m = re.match(r"# CONFIG_(\w+) is not set", ln)
    if m:
        cfg[m[1]] = "n"

out = {}
for key, secs in data.items():
    if not key.startswith("category:"):
        continue
    cat = key[9:]
    if want and cat not in want:
        continue
    for vspec, archs in secs.items():
        if not ver_ok(vspec):
            continue
        for aspec, opts in archs.items():
            if aspec != "all" and arch not in aspec.split():
                continue
            for opt, val in opts.items():
                got = cfg.get(opt, "n")  # unset == n
                if isinstance(val, list):
                    ok = all(x in got.split(",") for x in val)
                elif val in ("y", "m"):
                    ok = got == "y" or (got == "m" and val == "m") or (got == "m" and val == "y")
                    if val == "y" and got == "m":
                        ok = True
                elif val == "n":
                    ok = got == "n"
                else:
                    ok = got == val
                if not ok:
                    out.setdefault(cat, []).append((opt, str(val), got if opt in cfg else "unset"))
tot = 0
for cat in sorted(out):
    print(f"## {cat}: {len(out[cat])}")
    for o, w, g in sorted(set(out[cat])):
        print(f"  {o}: want {w!r} have {g!r}")
    tot += len(set(out[cat]))
print(f"TOTAL {tot}")
