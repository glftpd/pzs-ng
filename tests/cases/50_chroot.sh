#!/bin/bash
# rescan --chroot=: only directories on the zip/sfv allow-list may become the root.
# Needs root in a user namespace (run.sh uses 'unshare -Urn' when available).
. "$TESTDIR/lib.sh"
if [ "$(id -u)" != 0 ]; then skip "not root in a user namespace ('unshare -Urn' unavailable)"; summary; exit 0; fi
if ! python3 -c 'import os; os.chroot("/")' 2>/dev/null; then skip "chroot() not permitted here"; summary; exit 0; fi

mkdir -p "$WORK/secret_area"
out=$(cd "$WORK" && "$BIN/rescan" "--chroot=$WORK/secret_area" 2>&1)
ok "echo \"\$out\" | grep -qiE 'not allowed'" "rescan --chroot to a dir outside the allow-list is refused"
ok "! echo \"\$out\" | grep -qi 'Chroot.ing to'" "rescan did not chroot into it"
summary
