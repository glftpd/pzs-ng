#!/bin/bash
# Unit regressions for the memory-safety fixes that a whole upload can't easily reach
# (oversized files, non-default options, error paths), run under ASan/UBSan.
. "$TESTDIR/lib.sh"

link_harness "$TESTDIR/fixtures/h_units.c" "$WORK/h_units" -Dmark_file_as_bad=TRUE -Wl,--wrap=update_lock \
	|| { summary; exit 0; }
cd "$(mktemp -d -p "$WORK")"
unit(){ noasan "$2" "$WORK/h_units" "$1" ${3:-}; }

unit racers    "convert()/sortstats(): 60 racers stay inside output[] and the racer lists"
unit sfv4g     "readsfv_ffile(): a >4 GiB second sfv is refused, not overflowed"
unit diz       "read_diz(): a 4096-byte file_id.diz stays inside its buffer"
unit bitrate   "header_bitrate(): reserved bitrate index has no table entry"
unit markbad   "mark_as_bad(): a 252-byte name can't overflow newname (mark_file_as_bad on)"
unit getstats  "get_stats(): a userfile starting with an empty line" "$USERFILES"
unit sfvdata   "get_first_filename_from_sfvdata(): an empty sfvdata file"
unit missing   "create_missing(): no crash when the marker can't be created"
unit matchpath "matchpath(): a path list starting with a space"
unit writetop  "writetop(): the group toplist outgrows its first buffer"
summary
