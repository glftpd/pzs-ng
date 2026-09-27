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

    ./configure --enable-fluffer --with-glpath=/path/to/fluffer/chroot
    make && make install

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

If configure finds a fluffer binary but no glftpd binary, it stops and
asks for `--enable-fluffer` instead of switching modes on its own.

The only change that affects glftpd builds: the hide-user/group code
(`hide_uname`, `hide_gname` and the affil variants) now copies up to the
full 23-character field instead of cutting names at 17 characters.

## Tested

On `fluffer-2026.09`:

- `--enable-fluffer` build: no suid binaries.
- `--enable-gl202-64` build: ng-chown, ng-deldir, ng-undupe and sitewho.
- `--disable-glftpd-specific` build.
- The `test_fluffer_owner.c` self-check (build line in its header).

`configure` is committed as generated output. The fluffer changes were
made to both `configure.ac` and `configure`, following autoconf 2.72's
output style.

## fluffer-side documentation

The hook mapping, exit-code semantics, environment variables, and
what moved from glftpd's binary logs to SQLite are covered in fluffer's
own docs: `pzs-ng-integration.md`, `hooks_and_environment.txt`,
`xattr-ownership.md` and `glftpd-unsupported.md`.
