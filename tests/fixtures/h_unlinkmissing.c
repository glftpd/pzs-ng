/* Regression harness for findfile()/unlink_missing() (fix: return matched name).
 * mode 1: wrong-file delete — an unrelated file must survive, the lenient marker go.
 * mode 2: NULL-deref — a dir-order-last lenient marker must not crash.
 * Prints RESULT:PASS / RESULT:FAIL; run under ASan/UBSan for the crash case. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>

extern void unlink_missing(char *);

static void touch(const char *n){ int fd=open(n,O_CREAT|O_WRONLY,0644); if(fd>=0)close(fd); }
static int exists(const char *n){ return access(n,F_OK)==0; }

int main(int argc, char **argv){
	int mode = argc>2 ? atoi(argv[2]) : 1;
	if (mkdir(argv[1],0755) && access(argv[1],F_OK)) { perror("mkdir"); return 3; }
	if (chdir(argv[1])) { perror("chdir"); return 3; }

	if (mode==1) {
		touch("other-users-release.nfo");   /* unrelated - must survive */
		touch("target_missing");            /* lenient-eq "target-missing", not byte-identical */
		unlink_missing("target");
		if (!exists("target_missing") && exists("other-users-release.nfo"))
			{ printf("RESULT:PASS marker removed, unrelated file kept\n"); return 0; }
		printf("RESULT:FAIL target_missing=%d other=%d\n",
		       exists("target_missing"), exists("other-users-release.nfo"));
		return 1;
	} else {
		/* single dir-order-last lenient variant -> old code deref'd NULL */
		touch(argv[3] ? argv[3] : "TaRgeT,MIsSINg");
		unlink_missing("target");           /* must not crash */
		printf("RESULT:PASS no crash on last-entry match\n");
		return 0;
	}
}
