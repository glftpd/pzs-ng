#!/bin/bash
# SFV release: good CRC accepted, wrong CRC flagged, race completes and is announced.
. "$TESTDIR/lib.sh"

d=$(mkrel test Good.Release-GRP)
stage=$(mktemp -d -p "$WORK")	# files arrive one by one, like real uploads
for n in 1 2; do echo "data-$n" > "$stage/test.r0$n"; done
printf 'test.r01 %s\r\ntest.r02 %s\r\n' "$(crc32hex "$stage/test.r01")" "$(crc32hex "$stage/test.r02")" > "$d/release.sfv"
: > "$LOGF"
run_zs release.sfv "$d" 0 >"$WORK/o0" 2>&1
ok "[ -f '$STORAGE$d/sfvdata' ]" "sfv parsed into sfvdata"
ok "ls '$d' | grep -q -- '-missing'" "-missing markers created for the sfv's files"
cp "$stage/test.r01" "$d/"; U=racer1 upload "$d" test.r01 >"$WORK/o1" 2>&1; rc=$?
ok "[ $rc -eq 0 ]" "matching-CRC upload accepted (exit 0)"
ok "grep -qi 'CRC-Check: oK' '$WORK/o1'" "CRC check reported ok"
ok "[ ! -e '$d/test.r01-missing' ]" "-missing marker removed on upload"
ok "ls '$d' | grep -q ' 50% Complete'" "status bar shows 50% after one of two files"
cp "$stage/test.r02" "$d/"; U=racer2 G=grp2 upload "$d" test.r02 >"$WORK/o2" 2>&1
ok "ls '$d' | grep -qi 'complete'" "completion status bar created"
ok "grep -q 'COMPLETE' '$LOGF' && grep -q 'Good.Release-GRP' '$LOGF'" "race complete announced in glftpd.log"
ok "grep -q 'racer1' '$LOGF' && grep -q 'racer2' '$LOGF'" "both racers appear in the announces"

d2=$(mkrel test Bad.Release-GRP)
echo "the-real-bytes" > "$d2/bad.r00"
printf 'bad.r00 DEADBEEF\r\n' > "$d2/release.sfv"
run_zs release.sfv "$d2" 0 >/dev/null 2>&1
upload "$d2" bad.r00 >"$WORK/o3" 2>&1; rc=$?
ok "[ $rc -ne 0 ]" "wrong-CRC upload rejected (non-zero exit)"
ok "ls '$d2' | grep -q '  0% Complete'" "wrong-CRC file not counted (still 0%)"

# a second, different .sfv in the same release is refused
echo "other" > "$d/other.sfv"
run_zs other.sfv "$d" 0 >"$WORK/o4" 2>&1; rc=$?
ok "[ $rc -ne 0 ]" "a second .sfv is refused"

summary
