/* Unit regressions for memory-safety fixes that are hard to reach through a whole
 * zipscript run.  "h_units NAME" runs one check and prints RESULT:PASS or
 * RESULT:FAIL; memory errors are caught by ASan/UBSan, the harness is built with
 * -Dmark_file_as_bad=TRUE and -Wl,--wrap=update_lock. */
#include <sys/stat.h>
#include "zsfunctions.h"
#include "convert.h"
#include "stats.h"
#include "dizreader.h"
#include "mp3info.h"
#include "race-file.h"
#include "complete.h"
#include "multimedia.h"

extern char output[2048];

/* get_stats() takes the race lock; there is no race in a unit test */
int __wrap_update_lock(struct VARS *v, unsigned int c, unsigned int d)
{
	(void)v; (void)c; (void)d;
	return 1;
}

static int check(int cond, const char *what)
{
	printf("RESULT:%s %s\n", cond ? "PASS" : "FAIL", what);
	return cond ? 0 : 1;
}

static void put(const char *name, const char *data)
{
	FILE *f = fopen(name, "w");
	fputs(data, f);
	fclose(f);
}

/* many racers with long names: announce text and racer lists must stay in bounds */
static int t_racers(void)
{
	static struct VARS v;
	static struct USERINFO u[60], *ui[60];
	static struct GROUPINFO gr, *gi[1];
	int i;

	strcpy(gr.name, "GRP"); gi[0] = &gr;
	for (i = 0; i < 60; i++) {
		ui[i] = &u[i];
		snprintf(u[i].name, sizeof(u[i].name), "racer%02dxxxxxxxxxxxxxx", i);
		u[i].bytes = 1000 - i; u[i].files = 1; u[i].speed = 1000;
	}
	v.total.users = 60; v.total.groups = 1; v.total.size = 60000; v.total.files = 60;
	strcpy(v.user.name, u[0].name);
	sortstats(&v, ui, gi);
	if (check(strlen(v.misc.racer_list) < sizeof(v.misc.racer_list) &&
	    strlen(v.misc.total_racer_list) < sizeof(v.misc.total_racer_list), "racer lists bounded"))
		return 1;
	convert(&v, ui, gi, "%R %B %R %B");
	if (check(strlen(output) == sizeof(output) - 1, "long announce truncated to output[]"))
		return 1;
	return check(!strcmp(convert(&v, ui, gi, "%% abc %u"), "% abc 60"), "normal announce unchanged");
}

/* a second .sfv just over 4 GiB: its size used to wrap to a tiny allocation */
static int t_sfv4g(void)
{
	static struct VARS v;
	int fd = open("big.sfv", O_CREAT | O_WRONLY | O_TRUNC, 0644);

	if (fd == -1 || ftruncate(fd, 4294967400LL) == -1)
		return check(0, "create sparse 4 GiB sfv");
	close(fd);
	strcpy(v.file.name, "big.sfv");
	v.file.size = 4294967400LL;
	readsfv_ffile(&v);
	unlink("big.sfv");
	return check(v.total.files == 0, "oversized sfv refused");
}

/* file_id.diz of exactly the read-buffer size, ending in a partial pattern */
static int t_diz(void)
{
	char buf[4097];
	int n;

	memset(buf, 'x', 4093); strcpy(buf + 4093, "[01");
	put("file_id.diz", buf);
	read_diz();
	put("file_id.diz", "some release [01/15]\n");
	n = read_diz();
	unlink("file_id.diz");
	return check(n == 15, "diz disk count still read");
}

/* reserved and free-format MPEG bitrate indexes have no table entry */
static int t_bitrate(void)
{
	mp3header h;

	memset(&h, 0, sizeof(h));
	h.layer = 1; h.version = 1;
	h.bitrate = 15;
	if (check(header_bitrate(&h) == 0, "reserved bitrate index rejected"))
		return 1;
	h.bitrate = 9;
	return check(header_bitrate(&h) == 128, "bitrate index 9 is 128 kbps");
}

/* mark_as_bad() on a name with no room left for ".bad" */
static int t_markbad(void)
{
	char name[256];
	int kept, marked;

	memset(name, 'n', 252); name[252] = '\0';
	put(name, "x");
	mark_as_bad(name);
	kept = access(name, F_OK) == 0;
	unlink(name);
	put("short.r00", "x");
	mark_as_bad("short.r00");
	marked = access("short.r00.bad", F_OK) == 0;
	unlink("short.r00.bad");
	return check(kept && marked, "long name left alone, short name marked .bad");
}

/* get_stats() on a userfile whose first line is empty */
static int t_getstats(const char *userfiles)
{
	static struct VARS v;
	char path[PATH_MAX];

	snprintf(path, sizeof(path), "%s/zz-emptyline", userfiles);
	put(path, "\nDAYUP 1 2\nWKUP 1 2 777\n");
	get_stats(&v, NULL);
	unlink(path);
	return check(1, "userfile with an empty first line read");
}

/* get_first_filename_from_sfvdata() on an empty sfvdata file */
static int t_sfvdata(void)
{
	char *f;

	put("sfvdata", "");
	f = get_first_filename_from_sfvdata("sfvdata");
	unlink("sfvdata");
	return check(f == NULL, "empty sfvdata gives no file name");
}

/* create_missing() when "<name>-missing" can't be created (a directory is in the way) */
static int t_missing(void)
{
	mkdir("blocked-missing", 0755);
	create_missing("blocked");
	rmdir("blocked-missing");
	return check(1, "unwritable -missing marker skipped");
}

/* matchpath() on a path list that starts with a space */
static int t_matchpath(void)
{
	char *list = strdup(" /site/test/");
	short r = matchpath(list, "/site/test/Rel");

	free(list);
	return check(r == 1, "path list with a leading space still matches");
}

/* writetop(): the group toplist outgrows its first FILE_MAX buffer */
static int t_writetop(void)
{
	static GLOBAL g;
	static struct USERINFO u[12], *ui[12];
	static struct GROUPINFO gr[12], *gi[12];
	int i;

	for (i = 0; i < 12; i++) {
		ui[i] = &u[i]; gi[i] = &gr[i];
		snprintf(u[i].name, sizeof(u[i].name), "user%02dxxxxxxxxxxxxxxxx", i);
		snprintf(gr[i].name, sizeof(gr[i].name), "group%02dxxxxxxxxxxxxxxx", i);
		u[i].bytes = gr[i].bytes = 1000000000000000LL - i;
		u[i].files = gr[i].files = gr[i].users = 1;
		u[i].speed = gr[i].speed = 1000;
		u[i].pos = gr[i].pos = i;
	}
	g.ui = ui; g.gi = gi;
	g.v.total.users = g.v.total.groups = 12;
	g.v.total.size = 12000000000000000LL;
	g.v.misc.write_log = 1;
	writetop(&g, 1);
	return check(1, "toplists written after buffer growth");
}

/* create_dirlist(): two group-dir names that fill the list to exactly limit-1 bytes */
static int t_dirlist(void)
{
	char *list = malloc(64);
	char name[40];

	mkdir("gd", 0755);
	memset(name, 'a', 31); name[31] = '\0';
	snprintf(list, 64, "gd/%s", name); mkdir(list, 0755);
	memset(name, 'b', 32); name[32] = '\0';
	snprintf(list, 64, "gd/%s", name); mkdir(list, 0755);
	memset(list, 0, 64);
	create_dirlist("gd/", list, 64);
	return check(strlen(list) < 64, "affil list terminated inside its buffer");
}

/* avinfo(): a short read of the avih header.  The old code seeked back and parsed on
 * from earlier in the file; this layout makes that land on a "LIST movi" chunk, which
 * ends the parse and reports whatever avih held - stack garbage.  Run it on a plain
 * (non-ASan) build: ASan's stack layout hides the leak. */
static void dirty_stack(void)
{
	volatile char junk[16384];

	memset((char *)junk, 0x41, sizeof(junk));
}

static int t_avi(void)
{
	static struct VIDEO vi;
	static const unsigned char avi[80] =
		"RIFF\x48\x00\x00\x00" "AVI "
		"JUNK\x28\x00\x00\x00" "\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"
		"\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"
		"avih\x2c\x00\x00\x00" "LIST\x04\x00\x00\x00" "movi";
	FILE *f = fopen("short.avi", "wb");

	fwrite(avi, 1, sizeof(avi), f);
	fclose(f);
	dirty_stack();
	avinfo("short.avi", &vi);
	unlink("short.avi");
	printf("width=%d height=%d\n", vi.width, vi.height);
	return check(vi.width == 0 && vi.height == 0, "short avih read reports no dimensions");
}

/* lenient_compare(): '.' vs '_' in either name are equivalent (b[0] was tested as a[0]) */
static int t_lenient(void)
{
	char a[] = "rel.r00", b[] = "rel_r00";

	return check(lenient_compare(a, b) && lenient_compare(b, a), "lenient sfv match treats . and _ alike");
}

/* unpad(): an empty ID3 field used to read string[-1] */
static int t_unpad(void)
{
	char e[] = "", t[] = "abc  \t";

	unpad(e);
	unpad(t);
	return check(!*e && !strcmp(t, "abc"), "unpad on empty and padded strings");
}

/* convert(): a reverse range wider than the group list, and a trailing '%' */
static int t_convrange(void)
{
	static struct VARS v;
	static struct USERINFO u[2], *ui[2];
	static struct GROUPINFO g[2], *gi[2];
	int i;

	for (i = 0; i < 2; i++) {
		ui[i] = &u[i]; gi[i] = &g[i]; g[i].pos = i;
		snprintf(u[i].name, sizeof(u[i].name), "u%d", i);
		snprintf(g[i].name, sizeof(g[i].name), "G%d", i);
	}
	v.total.users = 2; v.total.groups = 2;
	convert(&v, ui, gi, "%c-5|%C-5|");
	if (check(strlen(output) < sizeof(output), "reverse range wider than the list stays in bounds"))
		return 1;
	return check(!strcmp(convert(&v, ui, gi, "end%"), "end"), "trailing % stops at the terminator");
}

/* filebanned_match(): CRLF lists and a last line without a newline */
static int t_banned(void)
{
	char old[4096] = "";
	size_t n = 0;
	FILE *f = fopen(banned_filelist, "r");
	int r;

	if (f) { n = fread(old, 1, sizeof(old), f); fclose(f); }
	put(banned_filelist, "*.crlf\r\n*.last");
	r = filebanned_match("a.crlf") && filebanned_match("a.last") && !filebanned_match("a.las");
	f = fopen(banned_filelist, "w");
	fwrite(old, 1, n, f);
	fclose(f);
	return check(r, "banned list with CRLF and no trailing newline");
}

/* extractDirname(): a root-level path used to leave dirname unset */
static int t_dirname(void)
{
	char d[64] = "unset";

	extractDirname(d, "/foo");
	return check(!strcmp(d, "foo"), "extractDirname(\"/foo\") gives foo");
}

int main(int argc, char **argv)
{
	const char *t = argc > 1 ? argv[1] : "";

	if (!strcmp(t, "racers")) return t_racers();
	if (!strcmp(t, "sfv4g")) return t_sfv4g();
	if (!strcmp(t, "diz")) return t_diz();
	if (!strcmp(t, "bitrate")) return t_bitrate();
	if (!strcmp(t, "markbad")) return t_markbad();
	if (!strcmp(t, "getstats")) return t_getstats(argc > 2 ? argv[2] : ".");
	if (!strcmp(t, "sfvdata")) return t_sfvdata();
	if (!strcmp(t, "missing")) return t_missing();
	if (!strcmp(t, "matchpath")) return t_matchpath();
	if (!strcmp(t, "writetop")) return t_writetop();
	if (!strcmp(t, "dirlist")) return t_dirlist();
	if (!strcmp(t, "avi")) return t_avi();
	if (!strcmp(t, "lenient")) return t_lenient();
	if (!strcmp(t, "unpad")) return t_unpad();
	if (!strcmp(t, "convrange")) return t_convrange();
	if (!strcmp(t, "banned")) return t_banned();
	if (!strcmp(t, "dirname")) return t_dirname();
	fprintf(stderr, "unknown test %s\n", t);
	return 2;
}
