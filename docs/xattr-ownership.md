# Virtual file ownership — xattr format for external tools

fluffer is a single-uid daemon: every file in the chroot is physically
owned by the daemon user, and per-uploader ownership is **virtual**,
carried in an extended attribute.  Any external tool that attributes
files to users the glftpd way — `stat()` + `getpwuid(st_uid)` — sees
the daemon user on every fluffer-uploaded file.  Zipscripts (pzs-ng /
zipscript-c), race stats generators, and cleanup tools need the xattr
instead.  This document is the complete, self-contained format spec;
copy it into the third-party tool's tree.

## Attribute: `user.ftpd.meta`

One binary blob per file/directory, packed, host-endian (x86_64 →
little-endian), **40 bytes**:

```c
struct ftpd_meta {                /* __attribute__((packed)) */
    uint32_t uid;                 /* virtual uid  (chroot /etc/passwd) */
    uint32_t gid;                 /* virtual gid  (chroot /etc/group)  */
    char     owner[32];           /* username, NUL-terminated, max 31  */
};
```

- `owner` is authoritative for display/attribution — no passwd lookup
  needed.  `uid`/`gid` are for permission checks and survive user
  renames only as numbers; resolve them against the **chroot's**
  `/etc/passwd` / `/etc/group` (fluffer's virtual users live there,
  NOT in the host's NSS — never use `getpwuid(3)` from outside the
  chroot).
- The group *name* is not embedded; map `gid` via chroot
  `/etc/group`.
- Read with one syscall:

```c
#include <sys/xattr.h>

struct ftpd_meta m;
if (getxattr(path, "user.ftpd.meta", &m, sizeof(m)) == (ssize_t)sizeof(m)) {
    m.owner[31] = '\0';
    /* m.owner = uploader, m.uid/m.gid = virtual ids */
}
```

A read that returns any size other than 40 means "no valid stamp" —
treat as unstamped (below).

## Legacy attributes (read-only fallback)

Files written by early fluffer builds may instead carry three separate
attributes; check them only when `user.ftpd.meta` is absent:

| name              | payload                          |
|-------------------|----------------------------------|
| `user.ftpd.uid`   | `uint32_t` (4 bytes, host-endian) |
| `user.ftpd.gid`   | `uint32_t` (4 bytes, host-endian) |
| `user.ftpd.owner` | username string (not NUL-padded) |

All three must be present to count as a valid stamp.

## When the stamp exists — and when it does not

- **Directories**: stamped by MKD at creation time.  Always present
  before any hook can see the directory.
- **Files**: stamped by STOR **after the upload completes** — and
  specifically **after `post_check` has run**.  A zipscript invoked as
  fluffer's `post_check` must NOT read the xattr of the file it is
  currently validating (it isn't there yet); use the hook environment
  instead (`$USER`, `$GROUP`, `$SPEED`, … — glftpd-compatible names,
  see docs/hooks_and_environment.txt).  Every *other* completed file
  in the directory already carries its stamp, so race-status passes
  over sibling files work normally.
- **Unstamped files** (pre-migration glftpd archives, filesystems
  without `user.*` xattr support): fall back to real `st_uid`/`st_gid`
  resolved against the chroot's passwd/group — glftpd kept real
  ownership in sync with those files, so this yields correct names for
  migrated archives.  fluffer's own LIST/STAT/MLSx use exactly this
  chain (xattr owner → xattr uid/gid → real uid/gid → numeric); a
  tool that mirrors it renders identical output.  The bulk stamping
  tool `tools/fluffer-import-owners.c` exists but is optional.
- fluffer's delete-own/rename-own checks treat a missing stamp as
  "unowned" (fail closed), not "everybody's".

## Related attribute: `user.ftpd.nuke`

Directories nuked via SITE NUKE carry a second packed blob (40 bytes,
host-endian) — the authoritative "this tree is nuked" marker (the
SQLite nukes table is reporting-only):

```c
struct ftpd_nuke {                /* __attribute__((packed)) */
    uint32_t multiplier;          /* NUKE multiplier, for symmetric refund */
    uint32_t nuked_at;            /* time_t of the NUKE (informational)    */
    char     nuker[32];           /* NUL-terminated (informational)        */
};
```

Removed by SITE UNNUKE.  Tools that skip/flag nuked releases can test
for the attribute's presence alone.

## Integration checklist for a zipscript (pzs-ng-style knob)

1. Add a build/config knob (e.g. `fluffer_xattr_owner 1`).
2. Everywhere the tool does `getpwuid(st.st_uid)` to name a file's
   uploader, first try `getxattr(path, "user.ftpd.meta", ...)` (then
   the legacy triple), and only then fall back to the stat-based
   lookup — that fallback keeps the same binary correct on glftpd.
3. Resolve group names from the chroot's `/etc/group` by the blob's
   `gid`.
4. In the `post_check` invocation path, take the uploader from the
   environment (`$USER`/`$GROUP`), never from the just-uploaded file.
5. Nothing else changes: fluffer runs hooks chdir'd to the file's
   directory with glftpd-compatible argv/env, and the ONLINE shared
   memory segment + glftpd.log formats are compatible (see
   docs/signals.md for transfer-kick integration).

Source of truth: `src/core/xattr.c` (struct layouts and attribute
names are stable ABI for on-disk data; any future change will be
additive with the old names still readable).
