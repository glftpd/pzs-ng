#!/bin/bash
# The ftpd helpers on a real release: postdel (DELE), rescan, postunnuke (SITE UNNUKE),
# datacleaner (RMD).
. "$TESTDIR/lib.sh"
skip_if_mode cuftpd "the ftpd helpers take a different, cuftpd-specific argv contract; validate on a live cuftpd/wzd"
RS=$BIN/rescan; PD=$BIN/postdel; DC=$BIN/datacleaner; PU=$BIN/postunnuke

d=$(mkrel test Helper.Release-GRP)
stage=$(mktemp -d -p "$WORK")
for n in 1 2; do echo "helper-$n" > "$stage/f$n.r0$n"; done
printf 'f1.r01 %s\r\nf2.r02 %s\r\n' "$(crc32hex "$stage/f1.r01")" "$(crc32hex "$stage/f2.r02")" > "$d/release.sfv"
run_zs release.sfv "$d" 0 >/dev/null 2>&1
for n in 1 2; do cp "$stage/f$n.r0$n" "$d/"; upload "$d" "f$n.r0$n" >/dev/null 2>&1; done
ok "ls '$d' | grep -q 'COMPLETE'" "release complete before the helpers run"

# DELE: the ftpd removes the file, then runs postdel
rm "$d/f2.r02"
noasan "postdel handles a DELE" sh -c "cd '$d' && '$PD' 'DELE f2.r02' u1 g1"
ok "[ -e '$d/f2.r02-missing' ]" "postdel recreated the -missing marker"
ok "ls '$d' | grep -q ' 50% Complete'" "postdel dropped the release back to 50%"

noasan "rescan runs on the release" sh -c "cd '$d' && '$RS'"
ok "grep -q 'Missing: 1' '$WORK/_out'" "rescan reports the deleted file missing"
cp "$stage/f2.r02" "$d/"
noasan "rescan --normal runs after the file is back" sh -c "cd '$d' && '$RS' --normal"
ok "grep -q 'Passed : 2' '$WORK/_out'" "rescan passes both files"
ok "ls '$d' | grep -q 'COMPLETE'" "rescan marked the release complete again"

# SITE UNNUKE: a nuke renamed the dir away from its race data; after the unnuke the
# ftpd runs postunnuke from the section dir with "site unnuke <rel>" to rebuild it
rm -rf "$STORAGE$d"
noasan "postunnuke runs for SITE UNNUKE" sh -c "cd '$SITE/test' && '$PU' 'site unnuke Helper.Release-GRP' u1 g1"
ok "! grep -qi 'Could not' '$WORK/_out'" "postunnuke gets past chdir()/getcwd()"
ok "[ -s '$STORAGE$d/racedata' ] && [ -s '$STORAGE$d/sfvdata' ]" "postunnuke rebuilt the race data"
ok "ls '$d' | grep -q 'COMPLETE'" "postunnuke restored the complete status"

# RMD: the ftpd removes the dir, then datacleaner drops its race data
rm -rf "$d"
ok "[ -d '$STORAGE$d' ]" "race data exists before RMD"
noasan "datacleaner handles an RMD" sh -c "cd '$SITE/test' && '$DC' 'RMD Helper.Release-GRP'"
ok "[ ! -d '$STORAGE$d' ]" "datacleaner removed the race data of the removed dir"
summary
