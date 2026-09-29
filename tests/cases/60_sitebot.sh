#!/bin/bash
# ngBot themereplace(): announce fields can't inject Tcl, and normal announces render.
. "$TESTDIR/lib.sh"
command -v tclsh >/dev/null || { skip "tclsh not installed"; summary; exit 0; }

cat > "$WORK/tr.tcl" <<'EOF'
# load themereplace from ngBot.tcl as shipped, then feed it hostile and normal text
set ::SECRET "bot-secret"
namespace eval ::ngBot { variable theme; array set theme {} }
set fh [open [lindex $argv 0]]; set data [read $fh]; close $fh
set i [string first "proc themereplace " $data]
set j [string first "\n\t}\n" $data $i]
namespace eval ::ngBot [string range $data $i [expr {$j + 2}]]
proc ::pwn {} { set ::pwned 1; return "" }
proc try {name text {want ""}} {
	set ::pwned 0
	if {[catch {set out [::ngBot::themereplace $text NONE]} err]} { set out "ERROR: $err" }
	set out [string map {\002 <b> \037 <u>} $out]
	if {$::pwned} { puts "FAIL $name: command executed"
	} elseif {[string match "ERROR:*" $out]} { puts "FAIL $name: $out"
	} elseif {$want ne "" && $out ne $want} { puts "FAIL $name: got {$out} want {$want}"
	} else { puts "PASS $name" }
}
try "quote in a %T{} field can't close the argument"  {%T{a"; ::pwn; "b}}
try "brackets in a field aren't run"                   {artist [::pwn] title}  {artist [::pwn] title}
try "brackets with ; inside %U{} aren't run"           {%U{[::pwn;]}}          {[::PWN;]}
try "variables in a field aren't expanded"             {leak $::SECRET here}   {leak $::SECRET here}
try "backslash in a field is kept"                     {AC\DC %T{ac\dc}}       {AC\DC Ac\dc}
try "case markers render"                              {%T{hello world} %U{up} %L{DOWN}} {Hello world UP down}
try "bold/underline render around a bracketed word"    {%b{new} [stats] %u{dir}} {<b>new<b> [stats] <u>dir<u>}
EOF
tclsh "$WORK/tr.tcl" "$TREE/sitebot/ngBot.tcl" >"$WORK/tr.o" 2>&1
grep -q '^PASS\|^FAIL' "$WORK/tr.o" || _no "themereplace test script ran" "$(head -c200 "$WORK/tr.o")"
while read -r line; do case "$line" in PASS*) _ok "${line#PASS }";; FAIL*) _no "${line#FAIL }";; esac; done < "$WORK/tr.o"
summary
