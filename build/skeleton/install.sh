#!/bin/bash
# Elastos Node for Ubuntu installer / updater - one command for everyone.
#
#   curl -fsSL https://raw.githubusercontent.com/elastos/Elastos.Node/master/build/skeleton/install.sh | bash
#
# - Fresh box      -> installs node.sh, then tells you to run `node.sh setup`.
# - Existing node  -> backs up the old node.sh, installs this tool, runs `migrate`
#                     (writes the profile + a rollback snapshot; restarts NOTHING).
# It verifies the published SHA-256 before installing, and never touches keystores
# or chain data.
set -euo pipefail

REPO="https://raw.githubusercontent.com/elastos/Elastos.Node/master/build/skeleton"
NODE_DIR="${ELASTOS_NODE_DIR:-$HOME/node}"

say()  { printf '%s\n' "$*"; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }

command -v curl    >/dev/null || die "curl is required"
command -v shasum  >/dev/null || command -v sha256sum >/dev/null || die "shasum/sha256sum is required"
sha256() { if command -v shasum >/dev/null; then shasum -a 256 "$1"; else sha256sum "$1"; fi; }

mkdir -p "$NODE_DIR"
cd "$NODE_DIR"

say "Downloading Elastos Node for Ubuntu..."
curl -fsSL -o node.sh.new "$REPO/node.sh" || die "download failed"

want=$(curl -fsSL "$REPO/node.sh.sha256" 2>/dev/null | awk '{print $1}')
if [ -n "$want" ]; then
    got=$(sha256 node.sh.new | awk '{print $1}')
    [ "$want" = "$got" ] || { rm -f node.sh.new; die "checksum mismatch - refusing to install"; }
    say "  checksum verified"
fi
bash -n node.sh.new || { rm -f node.sh.new; die "downloaded script failed syntax check"; }

# An existing install is one that already has a chain directory.
existing=
for d in ela esc eid pg; do [ -d "$NODE_DIR/$d" ] && existing=1; done

if [ -f node.sh ] && [ -n "$existing" ]; then
    bk="node.sh.bak.$(date +%s)"
    cp -p node.sh "$bk"
    say "  previous node.sh backed up -> $bk"
fi

mv node.sh.new node.sh
chmod +x node.sh
say "  installed: $NODE_DIR/node.sh"
say

if [ -n "$existing" ]; then
    say "Existing install detected - migrating onto Elastos Node for Ubuntu (nothing is restarted):"
    say
    ./node.sh migrate
else
    say "Fresh install. Next step:"
    say "  cd $NODE_DIR && ./node.sh setup"
fi
