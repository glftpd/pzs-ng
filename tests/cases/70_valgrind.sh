#!/bin/bash
# Slow lane (SLOW=1): run representative uploads through the *plain* build under
# valgrind memcheck, which catches invalid reads/writes, uninitialised values and
# leaks that ASan can miss.  Uses the non-instrumented tree (valgrind + ASan don't mix).
. "$TESTDIR/lib.sh"
[ -n "${SLOW:-}" ] || { skip "SLOW not set (run: SLOW=1 tests/run.sh ...)"; summary; exit 0; }
command -v valgrind >/dev/null || { skip "valgrind not installed"; summary; exit 0; }

PLAIN="$WORK/$MODE/zipscript/src"
[ -x "$PLAIN/zipscript-c" ] || { skip "plain $MODE build not present"; summary; exit 0; }
VG="valgrind -q --error-exitcode=97 --leak-check=summary --errors-for-leak-kinds=definite --track-origins=yes"

# vg_zs DESC FILE DIR CRC: run zipscript-c (mode-aware contract) under valgrind, assert clean
vg_zs(){ local desc=$1 file=$2 dir=$3 crc=$4
	if [ "$MODE" = cuftpd ]; then
		( cd "$dir" && env -i PATH=/usr/bin:/bin $VG "$PLAIN/zipscript-c" "$dir/$file" "$crc" u1 g1 "$TAGLINE" 1000 DEFAULT ) >"$WORK/_vg" 2>&1
	else
		( cd "$dir" && env -i PATH=/usr/bin:/bin USER=u1 GROUP=g1 TAGLINE="$TAGLINE" SPEED=1000 SECTION=DEFAULT \
			$VG "$PLAIN/zipscript-c" "$file" "$dir" "$crc" 0 ) >"$WORK/_vg" 2>&1
	fi
	local rc=$?
	if [ "$rc" = 97 ] || grep -qE "Invalid (read|write)|uninitialised|definitely lost: [1-9]" "$WORK/_vg"; then
		_no "$desc" "$(grep -m1 -E 'Invalid|uninitialised|definitely lost' "$WORK/_vg")"
	else _ok "$desc"; fi; }

# SFV release
d=$(mkrel test VG.Sfv-GRP); echo "some bytes here" > "$d/a.r00"
printf 'a.r00 %s\r\n' "$(crc32hex "$d/a.r00")" > "$d/release.sfv"
vg_zs "valgrind: sfv registration is clean" release.sfv "$d" 0
vg_zs "valgrind: matching upload is clean" a.r00 "$d" "$(crc32hex "$d/a.r00")"

# MP3 with an ID3v1 tag (exercises the mp3/id3 parser under valgrind)
d=$(mkrel incoming/mp3 VG.Mp3-GRP)
python3 - "$d/t.mp3" <<'EOF'
import sys
frame=bytes([0xFF,0xFB,(11<<4),0x00])+bytes(144000*192//44100-4)
tag=bytearray(128);tag[0:3]=b"TAG";tag[3:8]=b"Title";tag[33:39]=b"Artist";tag[93:97]=b"2010";tag[127]=17
open(sys.argv[1],"wb").write(frame*20+bytes(tag))
EOF
printf 't.mp3 %s\r\n' "$(crc32hex "$d/t.mp3")" > "$d/release.sfv"
vg_zs "valgrind: mp3/id3 parse is clean" t.mp3 "$d" "$(crc32hex "$d/t.mp3")"
summary
