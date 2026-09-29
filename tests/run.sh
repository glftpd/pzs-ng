#!/bin/bash
# run.sh [WORKDIR] [FILTER] - build pzs-ng in fluffer/glftpd/ss5 modes and run the
# functional + regression suite.  See tests/README.md.
#
#   tests/run.sh                    # temp workdir, every group, every mode
#   tests/run.sh /tmp/zs            # keep the workdir for inspection
#   tests/run.sh /tmp/zs 30         # only groups whose name contains "30"
#   NOBUILD=1 tests/run.sh /tmp/zs  # reuse the builds already in /tmp/zs
#   MODES="fluffer" tests/run.sh    # only some modes
#
# Exit status is 0 only if every build and every group passed.
set -u
TESTDIR=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$TESTDIR/.." && pwd)
WORK=${1:-$(mktemp -d)}; FILTER=${2:-}
mkdir -p "$WORK"; WORK=$(cd "$WORK" && pwd)
MODES=${MODES:-fluffer glftpd ss5 cuftpd}
RES="$WORK/results"; LOGS="$WORK/logs"
rm -rf "$RES"; mkdir -p "$RES" "$LOGS"
export WORK TESTDIR
say(){ printf '\n=== %s ===\n' "$1"; }

# isolation: user+net namespace with root mapped (also makes chroot() possible)
if unshare -Urn --map-root-user true 2>/dev/null; then ISO="unshare -Urn --map-root-user"
else ISO=""; echo "NOTE: 'unshare -Urn' unavailable - running without isolation; the chroot group will skip."; fi

# build <mode> <tree> [asan]: copy the checkout to $WORK/<tree>, re-root the compiled-in
# /site /ftp-data /bin paths under $WORK, configure and make.
build(){ mode=$1 tree=$2 san=${3:-}; d="$WORK/$tree"
	say "build $tree"
	if [ -n "${NOBUILD:-}" ] && [ -x "$d/zipscript/src/zipscript-c" ]; then
		LAST_WARN=$(grep -c 'warning:' "$d/b.log" 2>/dev/null); LAST_WARN=${LAST_WARN:-0}; echo "reused"; return 0; fi
	rm -rf "$d"; mkdir -p "$d"
	( cd "$REPO" && git ls-files -z --cached --others --exclude-standard | tar --null -T - -cf - ) | tar xf - -C "$d"
	case "$mode" in
		fluffer) mkdir -p "$d/gl/etc"; : >"$d/gl/etc/fluffer.conf"; carg="--enable-fluffer";;
		glftpd)  mkdir -p "$d/gl/bin"; : >"$d/gl/bin/glftpd";      carg="--disable-fluffer --enable-gl202-64";;
		ss5)     mkdir -p "$d/gl/etc"; : >"$d/gl/etc/fluffer.conf"; carg="--enable-fluffer --enable-ss5";;
		cuftpd)  carg="--disable-fluffer --disable-glftpd-specific";;   # wzd/cuftpd (no glftpd-specific helpers)
	esac
	if [ "$mode" = ss5 ]; then cp "$d/zipscript/conf/zsconfig.h.ss5.dist" "$d/zipscript/conf/zsconfig.h"
	else cp "$d/zipscript/conf/zsconfig.h.dist" "$d/zipscript/conf/zsconfig.h"; fi
	sed -i -E "/^#define[ \t]+[a-z_]+[ \t]+\"/ s#\"/(site|ftp-data|bin)/#\"$WORK/\1/#g; /^#define[ \t]+[a-z_]+[ \t]+\"/ s# /(site|ftp-data|bin)/# $WORK/\1/#g" \
		"$d/zipscript/include/zsconfig.defaults.h" "$d/zipscript/conf/zsconfig.h"
	sed -i "s#\"/site%s\"#\"$WORK/site%s\"#" "$d/zipscript/src/postdel.c"
	F=""; [ "$san" = asan ] && F="-g -O1 -fno-omit-frame-pointer -fsanitize=address,undefined"
	if ( cd "$d" && CFLAGS="$F" LDFLAGS="$F" ./configure --with-glpath="$d/gl" $carg >c.log 2>&1 && make -j"$(nproc)" >b.log 2>&1 ); then
		LAST_WARN=$(grep -c 'warning:' "$d/b.log"); echo "ok ($LAST_WARN compiler warnings)"
	else
		LAST_WARN=-1; echo "FAILED - see $d/c.log and $d/b.log"; return 1
	fi; }

mkdir -p "$WORK/site" "$WORK/ftp-data/pzs-ng" "$WORK/ftp-data/logs" "$WORK/ftp-data/users" "$WORK/ftp-data/misc" "$WORK/bin"
for b in zip unzip; do p=$(command -v "$b" 2>/dev/null) && ln -sf "$p" "$WORK/bin/$b"; done

# Every plain build must be warning-free.  The ASan builds aren't gated: gcc's
# sanitizer instrumentation produces a known false positive (a FORTIFY "null
# destination" warning in zipscript-c.c).
for m in $MODES; do
	pw=-1; build "$m" "$m" && pw=$LAST_WARN
	build "$m" "$m-asan" asan; ab=$?
	if [ "$pw" -lt 0 ] || [ "$ab" -ne 0 ]; then
		printf '0 1 0\nbuild failed (see %s)\n' "$WORK/$m*/b.log" > "$RES/00_build@$m"
	elif [ "$pw" -gt 0 ]; then
		printf '0 1 0\nplain %s build has %s compiler warning(s), expected 0 (see %s)\n' "$m" "$pw" "$WORK/$m/b.log" > "$RES/00_build@$m"
	else
		echo "0 0 0" > "$RES/00_build@$m"
	fi
done

# every group runs against the ASan/UBSan build of each mode: the functional checks
# then also catch memory errors in the code they exercise
for f in "$TESTDIR"/cases/*.sh; do
	g=$(basename "$f" .sh)
	[ -n "$FILTER" ] && case "$g" in *"$FILTER"*) ;; *) continue;; esac
	for m in $MODES; do
		r="$RES/$g@$m"
		if ! grep -q '^0 0 ' "$RES/00_build@$m"; then printf '0 1 0\nnot run: build failed\n' > "$r"; continue; fi
		say "$g [$m]"
		$ISO env WORK="$WORK" TESTDIR="$TESTDIR" MODE="$m" TREE="$WORK/$m-asan" RESULT="$r" \
			bash "$f" 2>&1 | tee "$LOGS/$g@$m.log"
		[ -s "$r" ] || printf '0 1 0\ngroup aborted before its summary (see %s)\n' "$LOGS/$g@$m.log" > "$r"
	done
done

python3 "$TESTDIR/report.py" "$RES" "$MODES"
