# lib.sh - sourced by every case.  run.sh sets WORK, TESTDIR, MODE, TREE (the ASan
# build of MODE) and RESULT.  The binaries have $WORK/site, $WORK/ftp-data and
# $WORK/bin compiled in where a real install has /site, /ftp-data and /bin.
: "${WORK:?run via run.sh}"; : "${TREE:?}"; : "${TESTDIR:?}"; : "${MODE:?}"; : "${RESULT:?}"
BIN="$TREE/zipscript/src"
SITE="$WORK/site"
STORAGE="$WORK/ftp-data/pzs-ng"
USERFILES="$WORK/ftp-data/users"
LOGF="$WORK/ftp-data/logs/glftpd.log"
: "${TAGLINE:=a tagline}"
export ASAN_OPTIONS=abort_on_error=1:detect_leaks=0 UBSAN_OPTIONS=halt_on_error=1:abort_on_error=1:print_stacktrace=1

pass=0; fail=0; skipped=0; failed_checks=""
_ok(){ pass=$((pass+1)); echo "  ok   - $1"; }
_no(){ fail=$((fail+1)); failed_checks="$failed_checks$1
"; echo "  FAIL - $1"; [ -n "${2:-}" ] && echo "         $2"; return 0; }
skip(){ skipped=$((skipped+1)); echo "  skip - $1"; }
ok(){ if eval "$1"; then _ok "$2"; else _no "$2" "[$1]"; fi; }
# noasan DESC CMD...: the command must not trip ASan/UBSan, die from a signal, or (for
# the C harnesses) print RESULT:FAIL.  Its output is left in $WORK/_out.
noasan(){ local d=$1; shift; "$@" >"$WORK/_out" 2>&1; local got=$?
	if grep -qiE "AddressSanitizer|runtime error:|UndefinedBehavior" "$WORK/_out"; then
		_no "$d" "sanitizer: $(grep -m1 -iE 'AddressSanitizer|runtime error' "$WORK/_out")"
	elif [ "$got" -ge 128 ]; then _no "$d" "signal (exit $got): $(head -c160 "$WORK/_out")"
	elif grep -q 'RESULT:FAIL' "$WORK/_out"; then _no "$d" "$(grep -m1 'RESULT:FAIL' "$WORK/_out")"
	else _ok "$d"; fi; }
crc32hex(){ python3 -c "import zlib,sys;print('%08X'%(zlib.crc32(open(sys.argv[1],'rb').read())&0xffffffff))" "$1"; }
# mkrel SECTION NAME: a fresh, empty release dir under $SITE
mkrel(){ local d="$SITE/$1/$2"; rm -rf "$d" "$STORAGE$d"; mkdir -p "$d" "$STORAGE" "$USERFILES" \
	"$(dirname "$LOGF")" "$WORK/ftp-data/misc"; echo "$d"; }
# run_zs FILE DIR CRC: invoke zipscript-c the way the ftpd does after an upload
run_zs(){ ( cd "$2" && env -i PATH=/usr/bin:/bin USER="${U:-tester}" GROUP="${G:-testgrp}" \
	TAGLINE="$TAGLINE" SPEED=1000 SECTION="${SEC:-DEFAULT}" ASAN_OPTIONS="$ASAN_OPTIONS" \
	UBSAN_OPTIONS="$UBSAN_OPTIONS" "$BIN/zipscript-c" "$1" "$2" "$3" 0 ); }
# upload DIR FILE: run_zs with the file's real CRC
upload(){ run_zs "$2" "$1" "$(crc32hex "$1/$2")"; }
# link_harness SRC OUT [EXTRA-CFLAGS...]: build a C harness against the zipscript
# objects of $TREE.  With extra flags (e.g. -Dmark_file_as_bad=TRUE) the sources are
# recompiled with them instead of using the tree's objects.
ZS_SRC="zsfunctions convert race-file helpfunctions stats mp3info abs2rel crc dizreader multimedia audiosort complete"
link_harness(){ local src=$1 out=$2; shift 2
	( cd "$BIN" && F=$(sed -n 's/^CFLAGS=//p' Makefile)
	  if [ $# -eq 0 ]; then u=$(for s in $ZS_SRC; do printf '%s.o ' "$s"; done)
	  else u=$(for s in $ZS_SRC; do printf '%s.c ' "$s"; done); fi
	  ${CC:-gcc} $F "$@" -Wno-error -o "$out" "$src" $u ../../lib/strl/strlcpy.o -lz-ng ) >"$out.log" 2>&1 \
	|| { _no "build harness $(basename "$src")" "$(grep -m1 -E 'error|undefined' "$out.log")"; return 1; }; }
summary(){ echo "== $(basename "$0" .sh) [$MODE]: $pass passed, $fail failed, $skipped skipped =="
	{ echo "$pass $fail $skipped"; printf '%s' "$failed_checks"; } > "$RESULT"; }
