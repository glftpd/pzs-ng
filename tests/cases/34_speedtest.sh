#!/bin/bash
# Speedtest logging: dl_speedtest (RETR post cscript) and zipscript-c in speedtest_dirs.
# The ftpd hands over paths as the client typed them, so a speedtest must be detected
# from the file's own directory - not from where the user happened to CWD to.
. "$TESTDIR/lib.sh"

DL="$TREE/sitebot/src/dl_speedtest"
ST="$SITE/speedtest"
mkdir -p "$ST/sub" "$SITE/other" "$(dirname "$LOGF")"
mib(){ head -c 1048576 /dev/zero > "$1"; }
mib "$ST/dl.file"; mib "$ST/sub/dl.file"; mib "$SITE/other/dl.file"
lines(){ grep -c "$1" "$LOGF" 2>/dev/null || true; }

# dl CWD ARG: run dl_speedtest the way glftpd runs a RETR post cscript
dl(){ ( cd "$1" && env -i PATH=/usr/bin:/bin USER=u1 GROUP=g1 SPEED=2048 \
	ASAN_OPTIONS="$ASAN_OPTIONS" UBSAN_OPTIONS="$UBSAN_OPTIONS" "$DL" "RETR $2" ) >"$WORK/_out" 2>&1; }
# dltest DESC CWD ARG LOGGED-DIR|-: one DLTEST line for LOGGED-DIR with a 1.0 MiB size, or none (-)
dltest(){ local n; n=$(lines DLTEST); dl "$2" "$3"
	if [ "$4" = - ]; then ok "[ $(lines DLTEST) -eq $n ]" "$1"
	else ok "[ $(lines DLTEST) -eq $((n+1)) ] && tail -1 '$LOGF' | grep -qF 'DLTEST: \"$4\"' && tail -1 '$LOGF' | grep -qF '{1.0}'" "$1"; fi; }

dltest "dl: CWD speedtest, RETR file"                       "$ST"        dl.file                   "$ST"
dltest "dl: CWD speedtest, RETR /speedtest/file (ftp-absolute)" "$ST"    /speedtest/dl.file        "$ST"
dltest "dl: CWD /, RETR /speedtest/file"                    "$SITE"      /speedtest/dl.file        "$ST"
dltest "dl: CWD /, RETR speedtest/file (relative)"          "$SITE"      speedtest/dl.file         "$ST"
dltest "dl: CWD other dir, RETR /speedtest/sub/file"        "$SITE/other" /speedtest/sub/dl.file   "$ST/sub"
dltest "dl: CWD speedtest, RETR sub/file logs the file's dir" "$ST"      sub/dl.file               "$ST/sub"
dltest "dl: RETR with the full chroot path (README test)"   "$SITE"      "$ST/dl.file"             "$ST"
# no line for downloads outside speedtest_dirs, wherever the user is
dltest "dl: CWD speedtest, RETR /other/file is not a test"  "$ST"        /other/dl.file            -
dltest "dl: CWD speedtest, RETR ../other/file is not a test" "$ST"       ../other/dl.file          -
dltest "dl: CWD other, RETR file is not a test"             "$SITE/other" dl.file                  -
dltest "dl: missing file logs nothing"                      "$ST"        /speedtest/nope.file      -
dltest "dl: RETR of a directory name ending in / logs nothing" "$ST"     /speedtest/sub/           -
noasan "dl: overlong RETR argument" sh -c "cd '$ST' && env USER=u GROUP=g SPEED=1 '$DL' \"RETR /\$(printf 'x%.0s' \$(seq 1 5000))/f\""

# zs FILE DIR [BIN]: zipscript-c with glftpd's argv ($1 file as given, $2 dir, $3 crc)
zs(){ ( cd "$2" && env -i PATH=/usr/bin:/bin USER=u1 GROUP=g1 TAGLINE=t SPEED=2048 SECTION=DEFAULT \
	ASAN_OPTIONS="$ASAN_OPTIONS" UBSAN_OPTIONS="$UBSAN_OPTIONS" "${3:-$BIN/zipscript-c}" "$1" "$2" 00000000 0 ) >"$WORK/_out" 2>&1; }
# ultest DESC CWD FILE DIR UPLOADED-AS [BIN]: one ULTEST line with the 1.0 MiB size
ultest(){ local n; n=$(lines ULTEST); mib "$5"; zs "$3" "$4" "${6:-}"
	ok "[ $(lines ULTEST) -eq $((n+1)) ] && tail -1 '$LOGF' | grep -qE '[{/]1\\.0[}/]'" "$1"; }

if [ "$MODE" = cuftpd ]; then
	n=$(lines ULTEST); mib "$ST/up.file"; U=u1 G=g1 run_zs up.file "$ST" 00000000
	ok "[ $(lines ULTEST) -eq $((n+1)) ]" "ul: upload in speedtest dir logs ULTEST"
	summary; exit 0
fi

# combine_path FALSE (default): glftpd passes the upload's real directory as $2
ultest "ul: STOR into speedtest dir (default)"                 "$ST" up1.file "$ST" "$ST/up1.file"
ultest "ul: STOR into speedtest subdir (default)"              "$ST/sub" up2.file "$ST/sub" "$ST/sub/up2.file"
n=$(lines ULTEST); mib "$SITE/other/up3.file"; zs up3.file "$SITE/other"
ok "[ $(lines ULTEST) -eq $n ]" "ul: upload outside speedtest_dirs is not a test (default)"

# combine_path TRUE: $1 may carry the client's path, $2 is the cwd
if link_harness "$BIN/zipscript-c.c" "$WORK/zs_combine" -Dcombine_path=TRUE "$BIN/print_config.c"; then
	ZC="$WORK/zs_combine"
	ultest "ul combine: STOR /speedtest/file from /"            "$SITE" /speedtest/c1.file "$SITE" "$ST/c1.file" "$ZC"
	ultest "ul combine: STOR /speedtest/sub/file from other dir" "$SITE/other" /speedtest/sub/c2.file "$SITE/other" "$ST/sub/c2.file" "$ZC"
	ultest "ul combine: STOR speedtest/file from / (relative)"  "$SITE" speedtest/c3.file "$SITE" "$ST/c3.file" "$ZC"
	ultest "ul combine: STOR sub/file from speedtest with \$2 ending in /" "$ST" sub/c4.file "$ST/" "$ST/sub/c4.file" "$ZC"
	ultest "ul combine: plain name still uses \$2"              "$ST" c5.file "$ST" "$ST/c5.file" "$ZC"
	n=$(lines ULTEST); mib "$SITE/other/c6.file"; zs /other/c6.file "$ST" "$ZC"
	ok "[ $(lines ULTEST) -eq $n ]" "ul combine: STOR /other/file from speedtest is not a test"
fi
summary
