#!/bin/bash
# Regressions for the run-2 security fixes, each triggered for real under ASan/UBSan.
. "$TESTDIR/lib.sh"

# incomplete(): a long release-dir name overflowed the 256-byte indicator buffer
long=$(python3 -c "print('A'*250 + '-GRP')")
d=$(mkrel test "$long")
echo x > "$d/f.r00"; printf 'f.r00 %s\r\n' "$(crc32hex "$d/f.r00")" > "$d/release.sfv"
noasan "incomplete(): 254-char release name does not overflow" run_zs release.sfv "$d" 0

# datacleaner: RMD from a cwd near PATH_MAX overflowed st[PATH_MAX]
rm -rf "$SITE/test/deep"
noasan "datacleaner: RMD from a PATH_MAX-deep cwd does not overflow" \
	python3 "$TESTDIR/fixtures/deep_rmd.py" "$SITE/test" "$BIN/datacleaner"
ok "grep -q 'cwd length 40[89]' '$WORK/_out'" "deep cwd really reached PATH_MAX (test is effective)"
rm -rf "$SITE/test/deep"

# findfile()/unlink_missing(): a stale telldir() made it delete the wrong file or crash
if link_harness "$TESTDIR/fixtures/h_unlinkmissing.c" "$WORK/h_um"; then
	rm -rf "$WORK/um1" "$WORK/um2"
	noasan "unlink_missing: removes the marker, keeps an unrelated file" "$WORK/h_um" "$WORK/um1" 1
	noasan "unlink_missing: dir-order-last match does not crash" "$WORK/h_um" "$WORK/um2" 2 "TaRgeT,MIsSINg"
fi

# filebanned_match(): leaked one fd per call; at the fd limit the filter failed open
echo 'never-matches-xyz' > "$WORK/ftp-data/misc/banned_filelist.txt"
if link_harness "$TESTDIR/fixtures/h_fbm.c" "$WORK/h_fbm"; then
	noasan "filebanned_match: no fd leak over 2000 non-matching calls" "$WORK/h_fbm"
fi

# complete(): a toplist entry longer than topbuf[256] (needs a %K template)
if ZS_SRC="${ZS_SRC/ complete/}" link_harness "$TESTDIR/fixtures/h_complete.c" "$WORK/h_complete"; then
	mkdir -p "$WORK/cpl"
	noasan "complete(): 508-byte toplist entry does not overflow topbuf" sh -c "cd '$WORK/cpl' && '$WORK/h_complete'"
fi
summary
