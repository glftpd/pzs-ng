/* One AFL++ harness for the zipscript parsers that eat uploader/ftpd bytes.
 * usage: harness MODE FILE   (cwd must be writable; run.sh sets it up)
 * Built by fuzz/run.sh against the real objects of a build.sh tree. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include "objects.h"
#include "zsfunctions.h"
#include "race-file.h"
#include "dizreader.h"
#include "multimedia.h"
#include "stats.h"
#include "../conf/zsconfig.h"
#include "zsconfig.defaults.h"

static void cp(const char *src, const char *dst)
{
	char b[65536]; ssize_t n; int i = open(src, O_RDONLY), o = open(dst, O_CREAT | O_TRUNC | O_WRONLY, 0644);
	if (i < 0 || o < 0) exit(2);
	while ((n = read(i, b, sizeof b)) > 0) if (write(o, b, n) != n) exit(2);
	close(i); close(o);
}

int main(int argc, char **argv)
{
	static struct VARS v;
	static struct audio a;
	static struct VIDEO vid;
	struct USERINFO *ui[1] = { 0 };
	const char *m, *f;

	if (argc != 3) { fprintf(stderr, "usage: %s sfv|diz|mp3|audio|avi|rar|passwd|group|stats FILE\n", argv[0]); return 2; }
	m = argv[1]; f = argv[2];
	strcpy(v.headpath, "nolock");	/* update_lock(): no lock held -> returns 1 */

	if (!strcmp(m, "sfv")) { v.data_type = 1; copysfv(f, "fz.sfvdata", &v); unlink("fz.sfvdata"); }
	else if (!strcmp(m, "diz")) { cp(f, "file_id.diz"); read_diz(); }
	else if (!strcmp(m, "mp3")) get_mpeg_audio_info((char *)f, &a);
	else if (!strcmp(m, "audio")) { cp(f, "fz.mp3"); get_audio_info("fz.mp3", &a); }	/* dispatches on the extension (FLAC too with HAVE_FLAC_HEADERS) */
	else if (!strcmp(m, "avi")) avinfo((char *)f, &vid);
	else if (!strcmp(m, "rar")) check_rarfile(f);
	else if (!strcmp(m, "passwd")) buffer_users((char *)f, 0);
	else if (!strcmp(m, "group")) buffer_groups((char *)f, 0);
	else if (!strcmp(m, "stats")) {	/* gl_userfiles is /tmp/ftp-data/users/ in a build.sh tree */
		mkdir(gl_userfiles, 0755); cp(f, gl_userfiles "/fz"); v.section = 0; get_stats(&v, ui);
	} else return 2;
	return 0;
}
