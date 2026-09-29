#!/bin/bash
# Concurrency: 8 zipscript-c runs on one release must not crash or corrupt the lock.
. "$TESTDIR/lib.sh"
d=$(mkrel test Race.Release-GRP)
for n in $(seq 1 8); do echo "bytes-$n" > "$d/f$n.r00"; done
: > "$d/release.sfv"
for n in $(seq 1 8); do printf 'f%s.r00 %s\r\n' "$n" "$(crc32hex "$d/f$n.r00")" >> "$d/release.sfv"; done
run_zs release.sfv "$d" 0 0 >/dev/null 2>&1
pids=""
for n in $(seq 1 8); do
  ( cd "$d" && env -i PATH=/usr/bin:/bin USER="u$n" GROUP=g1 TAGLINE=t SPEED=1 SECTION=DEFAULT \
      ASAN_OPTIONS=abort_on_error=1:detect_leaks=0 \
      "$BIN/zipscript-c" "f$n.r00" "$d" "$(crc32hex "$d/f$n.r00")" 0 >"$WORK/race.$n" 2>&1 ) &
  pids="$pids $!"
done
crashed=0; for p in $pids; do wait "$p" || { c=$?; [ "$c" -ge 128 ] && crashed=1; }; done
ok "[ $crashed -eq 0 ]" "no concurrent zipscript-c run crashed (signal)"
ok "! grep -qiE 'AddressSanitizer|runtime error' $WORK/race.* 2>/dev/null" "no sanitizer trip under concurrency"
ok "[ -f '$STORAGE$d/headdata' ]" "race state intact after concurrent runs"
summary
