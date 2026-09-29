# pzs-ng test suite

Functional and regression tests for the zipscript, the ftpd helpers (rescan, postdel,
postunnuke, datacleaner) and the sitebot. The suite builds the tree itself in fluffer,
glftpd and ss5 modes, then drives the binaries the way the ftpd does: same arguments,
same environment, same `/site` and `/ftp-data` layout. It doesn't need a running ftpd.

Everything happens inside one work directory. At build time the compiled-in `/site`,
`/ftp-data` and `/bin` paths are pointed into it, so nothing on the system is touched.

## Prerequisites

| Needed | For |
|---|---|
| Linux, bash, `gcc`, `make`, git checkout | building the three modes |
| `libasan` / `libubsan` (ship with gcc) | every group runs on an ASan/UBSan build |
| `python3` | CRC32s, test file generation, the results table |
| `zip`, `unzip` | `11_zip` (skipped without them) |
| `tclsh` | `60_sitebot` (skipped without it) |
| `unshare -Urn` (util-linux, unprivileged user namespaces) | isolation, and `50_chroot` (skipped without it) |

On Debian/Ubuntu: `apt install build-essential python3 zip unzip tcl util-linux`.
Unprivileged user namespaces must be allowed. Check with `unshare -Urn true`.

Run it as a normal user, not root.

## Running

    tests/run.sh                     # temp work dir, every group, every mode
    tests/run.sh /tmp/zs             # keep the work dir for inspection
    tests/run.sh /tmp/zs 30          # only groups whose name contains "30"
    NOBUILD=1 tests/run.sh /tmp/zs   # reuse the builds already in /tmp/zs
    MODES=fluffer tests/run.sh       # only some of: fluffer glftpd ss5

A full run takes about a minute, most of it the six builds (each mode plain and with
ASan/UBSan). The exit status is 0 only if every build and every group passed, and it
ends with a table like this:

    ┌──────────────┬──────────┬──────────┬──────────┐
    │              │ fluffer  │ glftpd   │ ss5      │
    ├──────────────┼──────────┼──────────┼──────────┤
    │ 00 build     │ ✅ ok    │ ✅ ok    │ ✅ ok    │
    ├──────────────┼──────────┼──────────┼──────────┤
    │ 10 sfv       │ ✅ 12/12 │ ✅ 12/12 │ ✅ 12/12 │
    ├──────────────┼──────────┼──────────┼──────────┤
    │ 50 chroot    │ ⚪ skip  │ ⚪ skip  │ ⚪ skip  │
    ...
    └──────────────┴──────────┴──────────┴──────────┘
    ALL PASSED

✅ means every check passed. ❌ means at least one failed; the failed checks are listed
under the table. ⚪ means the group was skipped because a prerequisite is missing.

Per-group output is in `WORKDIR/logs/<group>@<mode>.log`. The builds are in
`WORKDIR/<mode>` and `WORKDIR/<mode>-asan`, and the test site is `WORKDIR/site`.

## Groups

| Group | What it checks |
|---|---|
| 00 build | fluffer, glftpd (2.02 64-bit) and ss5 build, plain and with ASan/UBSan |
| 10 sfv | SFV release: -missing markers, CRC accepted/rejected, progress bar, race completion announced with every racer, second .sfv refused |
| 11 zip | ZIP release: integrity check, file_id.diz disk count, banned members removed from the zip, a member named like a zip option (`-O...`) can't overwrite files, corrupt zip rejected |
| 12 mp3 | MP3 release: ID3v1 artist/album/title/genre/year announced with leading spaces trimmed, frame header decoded, reserved bitrate index handled |
| 20 helpers | postdel re-marks a deleted file; rescan finds it missing and completes the release again; postunnuke rebuilds the race data after SITE UNNUKE; datacleaner drops the race data after RMD |
| 30 security | the run-2 fixes, each triggered for real: incomplete() with a 254-char release name, datacleaner RMD from a PATH_MAX-deep cwd, findfile()/unlink_missing() deleting the right file, filebanned_match() fd leak, complete() with a 508-byte toplist entry |
| 31 memory | unit checks for earlier fixes: 60 racers in the announce and racer lists, a >4 GiB second sfv, a 4096-byte file_id.diz, reserved MPEG bitrate, mark_as_bad() with a 252-byte name, get_stats() on a userfile starting with an empty line, empty sfvdata, create_missing() blocked, matchpath() with a leading space, writetop() buffer growth |
| 32 hardening | datacleaner doesn't follow a symlink out of the data tree; postdel with a >PATH_MAX DELE path; rescan with an empty file name |
| 40 race | 8 concurrent zipscript-c runs on one release: no crash, race state intact |
| 50 chroot | rescan `--chroot=` refuses a directory outside the zip/sfv allow-list (needs `unshare`) |
| 60 sitebot | ngBot `themereplace()`: quotes, brackets and `$` in announce fields can't run Tcl or expand variables; backslashes, case markers and bold/underline render correctly |
| 61 passchk | passchk against a glftpd passwd (correct/wrong password, hash unchanged), a line with too many fields, a cuftpd userfile |

Every group runs against the ASan/UBSan build of each mode, so the functional checks
also catch memory errors in the code they exercise. Each regression test was checked to
fail on the code from before its fix.

## Known limits

- **No live ftpd.** The binaries get the ftpd's arguments and environment directly.
  Anything that depends on the daemon itself, such as how it passes a real upload, its
  timing, or SITE commands through a real session, needs a test on a real install.
- **cuftpd/wzd builds aren't made.** Only passchk's cuftpd mode is tested.
- **sitewho and the suid helpers aren't built in fluffer mode** and aren't tested.
- **The stock `zsconfig.h.dist` is used for each mode.** Options that are off there get
  unit coverage in `31_memory` where it matters (for example `mark_file_as_bad`), not an
  end-to-end run.

## Adding a test

Put new checks in an existing `cases/NN_name.sh`, or add a new file. A case script
sources `lib.sh`, uses its helpers and ends with `summary`:

    #!/bin/bash
    . "$TESTDIR/lib.sh"
    d=$(mkrel test My.Release-GRP)        # fresh release dir under the test site
    echo data > "$d/a.r00"
    noasan "upload runs clean" upload "$d" a.r00
    ok "[ -f '$STORAGE$d/racedata' ]" "race data written"
    summary

| Helper | Does |
|---|---|
| `ok "SHELL-TEST" "description"` | pass if the test succeeds |
| `noasan "description" CMD...` | pass if CMD doesn't trip ASan/UBSan, die from a signal or print `RESULT:FAIL`; output in `$WORK/_out` |
| `skip "reason"` | record a skipped check |
| `mkrel SECTION NAME` | create an empty release dir and clear its race data |
| `run_zs FILE DIR CRC` / `upload DIR FILE` | run zipscript-c like the ftpd after an upload |
| `link_harness SRC OUT [CFLAGS...]` | build a C harness from `fixtures/` against the zipscript objects |

Variables: `$BIN` (the mode's binaries), `$SITE`, `$STORAGE`, `$USERFILES`, `$LOGF`
(glftpd.log), `$MODE`, `$TREE`.
