#!/bin/bash
# Slow lane (SLOW=1): coverage-guided fuzzing of the uploader-controlled parsers with
# AFL++ under ASan.  Parsers are ftpd-mode-independent, so this runs once (under
# fluffer) and skips on the other modes.  Needs afl-fuzz + afl-clang-fast; skips if
# absent.  FUZZ_SECS (default 25) is the time per parser.
. "$TESTDIR/lib.sh"
[ -n "${SLOW:-}" ] || { skip "SLOW not set"; summary; exit 0; }
[ "$MODE" = fluffer ] || { skip "parsers are mode-independent; fuzzed under fluffer"; summary; exit 0; }
command -v afl-fuzz >/dev/null && command -v afl-clang-fast >/dev/null || { skip "AFL++ (afl-fuzz/afl-clang-fast) not installed"; summary; exit 0; }
SECS=${FUZZ_SECS:-25}

fz="$WORK/fuzz"; rm -rf "$fz"; mkdir -p "$fz/inc"; : > "$fz/inc/syslimits.h"   # clang lacks the header objects.h wants
src="$WORK/fluffer/zipscript/src"
CFL=$(sed -n 's/^CFLAGS=//p' "$src/Makefile")
# build an instrumented harness: harness + ZS sources compiled with afl-clang-fast + ASan
if ! ( cd "$src" && AFL_QUIET=1 afl-clang-fast -g -O1 -fsanitize=address,undefined -I"$fz/inc" $CFL \
	-Wno-error -o "$fz/h" "$TESTDIR/fixtures/h_fuzz.c" \
	zsfunctions.c convert.c race-file.c helpfunctions.c stats.c mp3info.c abs2rel.c crc.c \
	dizreader.c multimedia.c audiosort.c complete.c ../../lib/strl/strlcpy.o -lz-ng ) >"$fz/build.log" 2>&1; then
	_no "fuzz harness built" "$(grep -m1 -E 'error|undefined' "$fz/build.log")"; summary; exit 0
fi

seed(){ mkdir -p "$fz/in_$1"; printf "$2" > "$fz/in_$1/s0"; }
seed sfv    '; comment\r\nfile.r00 0123ABCD\nfile.rar DEADBEEF\n'
seed diz    'Some.Release [01/15]\r\n(xx/15)\n'
seed mp3    'ID3\003\000\000\000\000\000\000\377\373\220\144\000\000'
seed stats  'USER x\nDAYUP 1 2 3\nWKUP 1 2 3\n\n'
seed passwd 'glftpd:x:0:0:0:/site:/bin/false\nu:x:1:2::/s:/b\n'

for p in sfv diz mp3 stats passwd; do
	AFL_SKIP_CPUFREQ=1 AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1 AFL_NO_UI=1 AFL_NO_AFFINITY=1 AFL_BENCH_UNTIL_CRASH=1 \
	ASAN_OPTIONS=abort_on_error=1:detect_leaks=0 UBSAN_OPTIONS=halt_on_error=1:abort_on_error=1 \
		timeout $((SECS+20)) afl-fuzz -V "$SECS" -i "$fz/in_$p" -o "$fz/out_$p" -- "$fz/h" "$p" @@ >"$fz/afl_$p.log" 2>&1 || true
	nc=$(ls "$fz/out_$p/default/crashes" 2>/dev/null | grep -c '^id:' || true)
	nh=$(ls "$fz/out_$p/default/hangs"   2>/dev/null | grep -c '^id:' || true)
	ex=$(sed -n 's/^execs_done *: *//p' "$fz/out_$p/default/fuzzer_stats" 2>/dev/null)
	# "no crashes" only counts if AFL really ran the target
	ok "[ '${ex:-0}' -gt 0 ] && [ '${nc:-0}' = 0 ] && [ '${nh:-0}' = 0 ]" \
		"fuzz $p: ${SECS}s, ${ex:-0} execs, ${nc:-0} crashes, ${nh:-0} hangs"
done
rm -f "$USERFILES/fz"	# the stats harness writes its input there
summary
