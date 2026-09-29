#!/bin/bash
# MP3 release: ID3v1 fields read and trimmed, odd frame headers handled.
. "$TESTDIR/lib.sh"

# mkmp3 FILE BITRATE-NIBBLE: 20 MPEG-1 layer III frames + an ID3v1 tag whose fields
# start with spaces (get_audio_info() trims them in place)
mkmp3(){ python3 - "$1" "$2" <<'EOF'
import sys
f, br = sys.argv[1], int(sys.argv[2])
kbps = [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 128][br]
frame = bytes([0xFF, 0xFB, (br << 4) | 0x00, 0x00]) + bytes(144000 * kbps // 44100 - 4)
tag = bytearray(128); tag[0:3] = b"TAG"
for off, s in ((3, b"   Some Title"), (33, b"   Some Artist"), (63, b"   Some Album"), (93, b"2010")):
    tag[off:off + len(s)] = s
tag[127] = 17  # Rock
open(f, "wb").write(frame * 20 + bytes(tag))
EOF
}

d=$(mkrel incoming/mp3 Some_Artist-Some_Album-2010-GRP)
mkmp3 "$d/01-track.mp3" 11	# 192 kbps, allowed by the stock config
mkmp3 "$d/02-track.mp3" 15	# reserved bitrate index: no table entry
printf '01-track.mp3 %s\r\n02-track.mp3 %s\r\n' "$(crc32hex "$d/01-track.mp3")" "$(crc32hex "$d/02-track.mp3")" > "$d/release.sfv"
: > "$LOGF"
run_zs release.sfv "$d" 0 >/dev/null 2>&1
noasan "mp3 with ID3v1 tag uploads clean" upload "$d" 01-track.mp3
noasan "mp3 with reserved bitrate index uploads clean" upload "$d" 02-track.mp3
ok "! grep -q BADBITRATE '$LOGF'" "192 kbps frames decoded as an allowed bitrate"
if [ "$MODE" = ss5 ]; then
	# SiteStat 5's announces carry no ID3 fields; its completion records CBR/VBR
	ok "grep -q 'COMPLETE: .* {CBR}' '$LOGF'" "audio race completed and classified CBR"
else
	# the audio fields are announced with the race completion
	ok "grep -q '{Some Artist} {Some Album} {Some Title}' '$LOGF'" "ID3 artist/album/title announced, leading spaces trimmed"
	ok "grep -q '{Rock} {2010}' '$LOGF'" "ID3 genre and year announced"
	ok "grep -q '{44100} {Stereo} {CBR}' '$LOGF'" "frame header decoded (44.1kHz stereo CBR)"
fi
summary
