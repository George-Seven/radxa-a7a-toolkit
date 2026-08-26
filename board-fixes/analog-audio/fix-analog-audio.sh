#!/bin/bash
# Radxa Cubie A7A: fix the analog (3.5 mm) audio output.
#
# The stock device tree declares the AC101B codec at I2C 0x3e; the chip actually
# answers at 0x1a. The driver binds, talks to nothing, and no analog sound card
# is ever created ("simple_dai_link_of failed" / "No soundcards found").
#
# This patches a COPY of the DTB and adds a SEPARATE boot entry. Your existing
# configuration is left untouched and stays selectable at the U-Boot menu.
set -e

[ "$(id -u)" = "0" ] || { echo "run with sudo"; exit 1; }
command -v fdtput >/dev/null || { echo "need device-tree-compiler: apt install device-tree-compiler"; exit 1; }

CODEC_NODE=/soc@3000000/twi@7085000/ac101b@3e
NEW_ADDR=0x1a

# --- find the fdtdir the current boot entry uses -----------------------------
CONF=/boot/extlinux/extlinux.conf
DEFAULT=$(awk '/^default/{print $2; exit}' "$CONF")
SRC=$(awk -v l="$DEFAULT" '$1=="label" && $2==l {f=1} f && $1=="fdtdir" {print $2; exit}' "$CONF")
[ -n "$SRC" ] || { echo "could not find fdtdir for entry '$DEFAULT'"; exit 1; }
SRC=${SRC%/}
DST="${SRC}-audio"
DTB_REL=$(cd "$SRC" && find . -name "*cubie-a7a*.dtb" | head -1)
[ -n "$DTB_REL" ] || { echo "no cubie-a7a dtb under $SRC"; exit 1; }

echo "boot entry : $DEFAULT"
echo "fdtdir     : $SRC"
echo "dtb        : $DTB_REL"

# --- sanity: is the codec really at 0x1a on this board? ----------------------
if command -v i2cdetect >/dev/null; then
  BUS=$(i2cdetect -l 2>/dev/null | awk '/7085000/{sub("i2c-","",$1); print $1; exit}')
  if [ -n "$BUS" ] && ! i2cdetect -y -r "$BUS" 2>/dev/null | grep -q " 1a "; then
    echo
    echo "WARNING: nothing answered at 0x1a on i2c-$BUS."
    echo "Your board may differ. Scan it yourself:  sudo i2cdetect -y -r $BUS"
    read -r -p "Continue anyway? [y/N] " a
    [ "$a" = "y" ] || exit 1
  fi
fi

# --- patch a copy -------------------------------------------------------------
rm -rf "$DST"
cp -a "$SRC" "$DST"
echo "current reg: $(fdtget "$DST/$DTB_REL" "$CODEC_NODE" reg 2>/dev/null || echo '?')"
fdtput -t x "$DST/$DTB_REL" "$CODEC_NODE" reg "$NEW_ADDR"
echo "patched reg: $(fdtget "$DST/$DTB_REL" "$CODEC_NODE" reg)  (26 = 0x1a)"

# --- add a boot entry ---------------------------------------------------------
chattr -i "$CONF" 2>/dev/null || true
cp -n "$CONF" "$CONF.bak_preaudio" 2>/dev/null || true

python3 - "$CONF" "$DEFAULT" "$SRC" "$DST" <<'PY'
import re, sys
conf, default, src, dst = sys.argv[1:5]
s = open(conf).read()
new_label = default + "_audio"
if new_label in s:
    print("boot entry already present, leaving it alone"); raise SystemExit
m = re.search(r'(label %s\n(?:\t.*\n)+)' % re.escape(default), s)
if not m:
    print("could not locate the default label block"); raise SystemExit(1)
blk = m.group(1)
new = blk.replace("label " + default, "label " + new_label, 1)
new = re.sub(r'(menu label .*)', r'\1 + ANALOG AUDIO', new, count=1)
new = new.replace(src.rstrip('/') + '/', dst.rstrip('/') + '/', 1)
if dst.rstrip('/') not in new:
    new = re.sub(r'fdtdir .*', 'fdtdir ' + dst.rstrip('/') + '/', new, count=1)
s = s.replace(blk, new + "\n" + blk, 1)
s = re.sub(r'^default .*$', 'default ' + new_label, s, count=1, flags=re.M)
open(conf, "w").write(s)
print("added boot entry:", new_label)
PY

chattr +i "$CONF" 2>/dev/null || true

cat <<EOF

Done. Reboot to activate.

After reboot you should see a second card:
    aplay -l   ->   card 1: sunxiac101b [sunxi-ac101b]

The codec outputs come up disabled, so enable and persist them:
    amixer -c 1 sset HPOUT on
    amixer -c 1 sset LINEOUTL on
    amixer -c 1 sset LINEOUTR on
    sudo alsactl store

To go back: pick "$DEFAULT" at the U-Boot menu, or restore $CONF.bak_preaudio
EOF
