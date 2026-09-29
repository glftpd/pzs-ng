#!/bin/bash
# Hardening fixes reachable from the ftpd helpers' arguments and the data tree.
. "$TESTDIR/lib.sh"

# datacleaner: race data of a removed dir is deleted recursively; a symlink in it must
# be removed, never followed into what it points at
out="$WORK/outside"; rm -rf "$out"; mkdir -p "$out"; echo keep > "$out/keep.txt"
gone="$STORAGE$SITE/test/Gone.Release-GRP"; rm -rf "$SITE/test/Gone.Release-GRP"
mkdir -p "$gone"; ln -sfn "$out" "$gone/link"; : > "$gone/racedata"
noasan "datacleaner sweeps race data of removed dirs" "$BIN/datacleaner"
ok "[ ! -e '$gone' ]" "race data of the removed dir deleted"
ok "[ -f '$out/keep.txt' ]" "datacleaner did not follow a symlink out of the data tree"

# postdel: DELE argument whose directory part is longer than PATH_MAX
# (cuftpd/wzd pass user, group, tagline and section first, then the file path)
longdir=$(python3 -c "print('/'.join(['x'*200]*22))")
if [ "$MODE" = cuftpd ]; then pd_args="u1 g1 tag DEFAULT /$longdir/f.r00"; else pd_args="'DELE /$longdir/f.r00' u1 g1"; fi
noasan "postdel: DELE with a >PATH_MAX directory does not overflow" sh -c "cd '$SITE' && '$BIN/postdel' $pd_args"
ok "! grep -qi 'Missing arguments\|Syntax' '$WORK/_out'" "postdel accepted the arguments (the DELE path was parsed)"

# rescan: an empty FILE-mode name
d=$(mkrel test Rescan.Empty-GRP)
if [ "$MODE" = cuftpd ]; then rs_args="u1 g1 tag DEFAULT '$d' ''"; else rs_args="''"; fi
noasan "rescan: an empty file name does not read before its buffer" sh -c "cd '$d' && '$BIN/rescan' $rs_args"
ok "grep -q 'FILE mode' '$WORK/_out'" "rescan took the empty name as a FILE-mode argument"
summary
