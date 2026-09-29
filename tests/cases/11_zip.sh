#!/bin/bash
# ZIP release: integrity check, file_id.diz disk count, banned member removal.
. "$TESTDIR/lib.sh"
command -v zip >/dev/null && command -v unzip >/dev/null || { skip "zip/unzip not installed"; summary; exit 0; }

printf '*.crc\n' > "$WORK/ftp-data/misc/banned_filelist.txt"
d=$(mkrel test Zip.Release-GRP)
src=$(mktemp -d -p "$WORK")
( cd "$src" && printf 'Zip Release\n[01/03]\n' > file_id.diz && echo data > good.txt \
  && echo banned > sfv.crc && echo evil > ./-Ofoo.crc \
  && zip -q "$d/zr.zip" file_id.diz good.txt sfv.crc ./-Ofoo.crc )
echo victim > "$d/foo.crc"	# what "zip -O foo.crc" would overwrite
upload "$d" zr.zip >"$WORK/o1" 2>&1; rc=$?
ok "[ $rc -eq 0 ]" "valid zip accepted"
ok "grep -qi 'ZiP integrity: oK' '$WORK/o1'" "zip integrity reported ok"
ok "[ -f '$d/file_id.diz' ]" "file_id.diz extracted"
ok "grep -q '1/3' '$WORK/o1'" "disk count read from file_id.diz (1/3)"
ok "! unzip -l '$d/zr.zip' | grep -q 'sfv.crc'" "banned member removed from the zip"
ok "! unzip -l '$d/zr.zip' | grep -q -- '-Ofoo.crc'" "banned member named like an option removed"
ok "unzip -l '$d/zr.zip' | grep -q 'good.txt'" "allowed member kept"
ok "[ \"\$(cat '$d/foo.crc')\" = victim ]" "member name not parsed as a zip option (foo.crc untouched)"

echo "not a zip" > "$d/zr2.zip"
upload "$d" zr2.zip >"$WORK/o2" 2>&1; rc=$?
ok "[ $rc -ne 0 ]" "corrupt zip rejected"
summary
