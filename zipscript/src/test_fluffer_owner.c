/* Minimal self-check for fluffer_owner() (docs/xattr-ownership.md).
 * Links zsfunctions.o with unresolved symbols ignored; only exercises the
 * xattr path plus get_u_name/get_g_name fallback with a stubbed user table.
 * Build+run (from zipscript/src, after configure; knob must be TRUE, e.g. -D below):
 *   gcc -DUSING_GLFTPD=1 -Dfluffer_xattr_owner=1 -DHAVE_CONFIG_H -D_WITH_NOFORMAT -DGLVERSION=20264 \
 *       -I../include/ -I../../ -I../../lib/ -c zsfunctions.c -o /tmp/zsf_test.o
 *   gcc test_fluffer_owner.c /tmp/zsf_test.o ../../lib/strl/strlcpy.o \
 *       -Wl,--unresolved-symbols=ignore-all -o /tmp/tfo && /tmp/tfo
 * Needs a filesystem with user.* xattr support (run in cwd, not tmpfs).
 */
#include <assert.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/xattr.h>
#include <unistd.h>

extern int fluffer_owner(const char *, char *, size_t, char *, size_t);

/* group table globals from zsfunctions.c (struct mirrors zsfunctions.h) */
struct GROUP {
	char           *name;
	gid_t		id;
};
extern struct GROUP **group;
extern int	num_groups;

struct ftpd_meta {
	uint32_t uid;
	uint32_t gid;
	char	 owner[32];
} __attribute__((packed));

int
main(void)
{
	char		un[64], gn[64], path[] = "./tfo_XXXXXX";
	struct ftpd_meta m = { 1001, 101, "raceuser" };
	uint32_t	v;
	int		fd = mkstemp(path);

	/* two groups in the same hundred-block: exact gid matching must pick
	 * the right one (get_g_name's id/100 bucket match would return "first") */
	struct GROUP	ga = { "first", 100 }, gb = { "second", 101 };
	struct GROUP   *gtab[] = { &ga, &gb };
	group = gtab;
	num_groups = 2;

	assert(fd != -1);

	/* unstamped -> 0 */
	assert(fluffer_owner(path, un, sizeof(un), gn, sizeof(gn)) == 0);

	/* packed meta -> owner string wins */
	assert(setxattr(path, "user.ftpd.meta", &m, sizeof(m), 0) == 0);
	assert(sizeof(m) == 40);
	assert(fluffer_owner(path, un, sizeof(un), gn, sizeof(gn)) == 1);
	assert(strcmp(un, "raceuser") == 0);
	assert(strcmp(gn, "second") == 0);

	/* truncated blob -> treated as unstamped */
	assert(setxattr(path, "user.ftpd.meta", &m, 20, 0) == 0);
	assert(fluffer_owner(path, un, sizeof(un), gn, sizeof(gn)) == 0);
	assert(removexattr(path, "user.ftpd.meta") == 0);

	/* legacy triple: incomplete -> 0, complete -> 1 */
	assert(setxattr(path, "user.ftpd.owner", "legacy", 6, 0) == 0);
	assert(fluffer_owner(path, un, sizeof(un), gn, sizeof(gn)) == 0);
	v = 1001;
	assert(setxattr(path, "user.ftpd.uid", &v, 4, 0) == 0);
	v = 200;
	assert(setxattr(path, "user.ftpd.gid", &v, 4, 0) == 0);
	assert(fluffer_owner(path, un, sizeof(un), gn, sizeof(gn)) == 1);
	assert(strcmp(un, "legacy") == 0);

	unlink(path);
	puts("fluffer_owner: all checks passed");
	return 0;
}
