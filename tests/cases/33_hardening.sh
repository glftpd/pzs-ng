#!/bin/bash
# Regressions for the parser, path and symlink hardening fixes, each triggered for real under ASan/UBSan.
. "$TESTDIR/lib.sh"

# racer cap: more distinct uploaders than the helpers used to reserve slots for (30)
d=$(mkrel test Many.Racers-GRP)
stage=$(mktemp -d -p "$WORK")
: > "$d/release.sfv"
for n in $(seq 1 40); do echo "racer-$n" > "$stage/f$n.r$n"; printf 'f%s.r%s %s\r\n' "$n" "$n" "$(crc32hex "$stage/f$n.r$n")" >> "$d/release.sfv"; done
run_zs release.sfv "$d" 0 >/dev/null 2>&1
for n in $(seq 1 40); do cp "$stage/f$n.r$n" "$d/"; U="racer$n" upload "$d" "f$n.r$n" >/dev/null 2>&1; done
ok "ls '$d' | grep -q COMPLETE" "release with 40 distinct uploaders completed"
# racestats takes the release path relative to the site root and chdir()s into it
noasan "racestats reads a race with 40 distinct uploaders" sh -c "cd / && '$BIN/racestats' '${d#/}'"
ok "grep -q 'racer40' '$WORK/_out'" "racestats listed the 40th racer"
if [ "$MODE" != cuftpd ]; then
	noasan "rescan reads a race with 40 distinct uploaders" sh -c "cd '$d' && '$BIN/rescan'"
fi

# racestats: a path argument that fits PATH_MAX alone but not with the storage prefix
long=$(python3 -c "print('/'.join(['r'*200]*20))")
( cd "$WORK" && mkdir -p "$long" )
noasan "racestats: long path plus storage prefix does not overflow" sh -c "cd '$WORK' && '$BIN/racestats' '$long'"
rm -rf "$WORK/rrrr"*

# zip names starting with '-' reach unzip as a file, not an option
if command -v zip >/dev/null && command -v unzip >/dev/null; then
	d=$(mkrel test Dash.Zip-GRP)
	src=$(mktemp -d -p "$WORK"); echo data > "$src/a.txt"; ( cd "$src" && zip -q "$d/-t.zip" a.txt )
	upload "$d" -t.zip >"$WORK/o_dash" 2>&1; rc=$?
	ok "[ $rc -eq 0 ] && grep -qi 'ZiP integrity: oK' '$WORK/o_dash'" "a valid zip named '-t.zip' is tested as a file"
fi

# ng-undupe / ng-deldir: a symlink planted at the old predictable temp name
for h in ng-undupe:dupefile ng-deldir:dirlog; do
	bin=${h%%:*} db=${h#*:}
	[ -x "$BIN/$bin" ] || continue
	echo precious > "$WORK/victim.$db"
	: > "$WORK/ftp-data/logs/$db"
	ln -sfn "$WORK/victim.$db" "$STORAGE/$db.$(id -u)"
	noasan "$bin runs with a symlink planted at its old temp name" "$BIN/$bin" some.release
	ok "[ \"\$(cat '$WORK/victim.$db')\" = precious ]" "$bin did not write through the planted symlink"
	ok "[ -f '$WORK/ftp-data/logs/$db' ] && [ ! -L '$WORK/ftp-data/logs/$db' ]" "$bin left $db a regular file"
	rm -f "$STORAGE/$db.$(id -u)"
done

# showlog: dirlog records whose name field has no terminator
if [ -x "$TREE/sitebot/src/showlog" ]; then
	sl="$WORK/showlog"; mkdir -p "$sl/ftp-data/logs"
	printf 'rootpath %s\ndatapath /ftp-data\n' "$sl" > "$sl/glftpd.conf"
	python3 -c "open('$sl/ftp-data/logs/dirlog','wb').write(b'A'*100000)"
	noasan "showlog: unterminated dirlog names don't over-read" "$TREE/sitebot/src/showlog" -l -s -m 3 -p '*' -r "$sl/glftpd.conf"
fi

# passchk: a 13-character DES passwd entry (2-byte salt, needs its terminator)
PC="$TREE/sitebot/src/passchk"
if [ -x "$PC" ]; then
	printf 'des:%s:100:100::/site:/bin/false\n' "$(python3 -c "print('ab'+'C'*11)")" > "$WORK/passwd.des"
	noasan "passchk: DES entry with a 2-byte salt" "$PC" des secret "$WORK/passwd.des"
	ok "grep -qx NOMATCH '$WORK/_out'" "passchk: DES entry checked (NOMATCH for a wrong password)"
fi

# cleaner.sh: a symlink to another dir must not be descended into
cl="$WORK/cleaner"; rm -rf "$cl"; mkdir -p "$cl/tree" "$cl/other"
ln -s /nonexistent "$cl/other/dangling"; ln -s "$cl/other" "$cl/tree/link"
( cd "$cl/tree" && bash "$TREE/scripts/cleaner/cleaner.sh" ) >/dev/null 2>&1
ok "[ -L '$cl/other/dangling' ]" "cleaner.sh left another dir's links alone"

# unit checks
if link_harness "$TESTDIR/fixtures/h_units.c" "$WORK/h_units3" -Dmark_file_as_bad=TRUE -Wl,--wrap=update_lock; then
	cd "$(mktemp -d -p "$WORK")"
	noasan "create_dirlist(): names filling the list to limit-1 bytes" "$WORK/h_units3" dirlist
fi
# plain build: ASan's stack layout would hide avinfo()'s uninitialised read
if BIN="$WORK/$MODE/zipscript/src" link_harness "$TESTDIR/fixtures/h_units.c" "$WORK/h_units3p" -Wl,--wrap=update_lock; then
	noasan "avinfo(): short avih read reports no stack garbage" "$WORK/h_units3p" avi
fi
summary
