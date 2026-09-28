# pzs-ng for fluffer

This is pzs-ng (from [glftpd/pzs-ng](https://github.com/glftpd/pzs-ng)) with
a small patch stack that lets it run under **fluffer**. fluffer is a
single-uid ftpd: every file on disk belongs to the daemon user, and the
real uploader is kept in the `user.ftpd.meta` extended attribute.

Branches:

| Branch | Contents |
|--------|----------|
| `master` | An unmodified mirror of glftpd/pzs-ng |
| `fluffer` | master plus the fluffer patches (the default branch) |

Each tested state is tagged `fluffer-YYYY.MM`. The same changes are
attached to each release as `git format-patch` files, so you can apply
them to your own pzs-ng tree.

## Build

    ./configure --with-glpath=/path/to/fluffer/chroot
    make && make install
    scripts/libcopy/libcopy.sh /path/to/fluffer/chroot

configure recognises the chroot as fluffer's by
`etc/fluffer.conf` or `conf/fluffer.conf` under the glpath, and switches to
fluffer mode on its own. The fluffer binary itself lives outside the chroot
and is not needed.

| glpath contains | configure builds for |
|---|---|
| `bin/glftpd` only | glftpd, detected exactly as upstream does |
| `etc/fluffer.conf` or `conf/fluffer.conf`, no `bin/glftpd` | fluffer |
| both (fluffer installed alongside glftpd) | glftpd, with a NOTICE; add `--enable-fluffer` for fluffer |
| neither | stops with "Invalid glpath" |

`--enable-fluffer` / `--disable-fluffer` always override the detection.

libcopy.sh accepts the same chroots. On fluffer it skips the check for the
suid helpers, and it keeps the existing `etc/ld.so.conf` lines (fluffer's
own library dirs) instead of rebuilding the file.

Everything else (`zsconfig.h`, hooks, sitebot) is set up the same way as
on glftpd. See `INSTALL` and `README.ZSCONFIG`.

## What `--enable-fluffer` changes

- **File ownership from xattrs.** rescan and postunnuke read the uploader
  from `user.ftpd.meta` instead of `st_uid`. The owner and group are stored
  by name in the xattr, and those names are used as-is. The older 40-byte
  stamp (group resolved from gid through the chroot's `/etc/group`) and the
  legacy `user.ftpd.{uid,gid,owner}` triple still work. Files without a
  stamp fall back to `st_uid`/`st_gid`. The format is described in
  `docs/xattr-ownership.md`.
- **No suid helpers.** ng-undupe, ng-deldir and ng-chown are not built or
  installed, and neither are sitewho and showlog, because they read
  glftpd's shared memory and binary logs. The `chmod 4777`/`chown 0:0`
  install steps are skipped. fluffer keeps its dupe and dirlog data in
  SQLite, so `enable_unduper_script` and `enable_delbanned_script`
  default to FALSE.
- **Version detection.** The build is treated as glftpd 2.02 (64-bit)
  compatible.

zipscript-c needs no xattr code. It takes the uploader from `$USER`/`$GROUP`,
because fluffer writes a file's stamp only after `post_check` returns.

## glftpd builds are unaffected

Without `--enable-fluffer` the fluffer code is compiled out or disabled:

- the xattr lookup is off;
- the suid helpers, sitewho and showlog are built and installed as usual;
- defaults are unchanged.

configure only switches to fluffer mode when the glpath has a fluffer
config and no `bin/glftpd`. Stock upstream fails on such a path anyway, so
no working glftpd setup changes. On a glftpd root, libcopy.sh behaves
exactly as before.

The only change that affects glftpd builds: the hide-user/group code
(`hide_uname`, `hide_gname` and the affil variants) now copies up to the
full 23-character field instead of cutting names at 17 characters.

## A fluffer build on glftpd

A fluffer build also runs on glftpd, so one set of binaries covers both
servers. glftpd files have no `user.ftpd.meta` stamp, so rescan and
postunnuke fall back to the file's uid/gid, and races, rescan and
attribution work as usual. What a fluffer build lacks on glftpd is what it
drops on purpose:

- dupe and dirlog upkeep: no ng-undupe/ng-deldir, and the unduper and
  delbanned scripts are off by default;
- ngBot's `WHO`/`SHOWLOG`: no sitewho or showlog;
- the storage-dir and `glftpd.log` permission steps at install time.

A glftpd site that wants those should use a normal build.

## Tested

On `fluffer-2026.09.1`:

- configure detection for each row of the table above, plus `--enable-fluffer`
  and `--disable-fluffer` overrides.
- `--enable-fluffer` build: no suid binaries.
- `--enable-gl202-64` build: ng-chown, ng-deldir, ng-undupe and sitewho.
- `--disable-glftpd-specific` build.
- The `test_fluffer_owner.c` self-check (build line in its header).
- libcopy.sh on a glftpd root gives the same output and files as upstream's
  script. On a fluffer chroot (`etc/` or `conf/`) it keeps `ld.so.conf`
  and skips the suid-helper check.

`configure` is committed as generated output. The fluffer changes were
made to both `configure.ac` and `configure`, following autoconf 2.72's
output style.

## fluffer-side documentation

The hook mapping, exit-code semantics, environment variables, and
what moved from glftpd's binary logs to SQLite are covered in fluffer's
own docs: `pzs-ng-integration.md`, `hooks_and_environment.txt`,
`xattr-ownership.md` and `glftpd-unsupported.md`.
