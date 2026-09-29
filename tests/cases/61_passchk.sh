#!/bin/bash
# sitebot passchk: password checks against glftpd passwd and cuftpd userfiles.
. "$TESTDIR/lib.sh"
PC="$TREE/sitebot/src/passchk"
[ -x "$PC" ] || { _no "passchk was built"; summary; exit 0; }
cd "$(mktemp -d -p "$WORK")"

# a glftpd PBKDF2 entry for the password "secret"; passchk hashes must never change
hash='$0a1b2c3d$7f2076efb96fc7f2c642b53e755bdc13e35e3082'
printf 'bob:%s:100:100::/site:/bin/false\n' "$hash" > passwd
noasan "glftpd passwd: correct password" "$PC" bob secret passwd
ok "grep -qx MATCH '$WORK/_out'" "glftpd passwd: correct password matches (hash unchanged)"
noasan "glftpd passwd: wrong password" "$PC" bob wrong passwd
ok "grep -qx NOMATCH '$WORK/_out'" "glftpd passwd: wrong password rejected"

printf 'x:a:b:c:d:e:f:g:h:i:j:k:l\nbob:%s:100:100::/site:/bin/false\n' "$hash" > passwd.colons
noasan "passwd line with 12 colons does not overflow the field table" "$PC" bob secret passwd.colons

mkdir -p users
printf 'username=bob\npassword=%s\n' "$hash" > users/bob
noasan "cuftpd userfile: lookup" "$PC" -c bob secret users
ok "grep -qx MATCH '$WORK/_out'" "cuftpd userfile: correct password matches"
summary
