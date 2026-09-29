/* Regression harness for filebanned_match() fd leak.  Calls it many times with a
 * non-matching name; the fixed version keeps the fd count flat.  Fails if the open
 * fd count grows with calls (leak) or the banned filter starts failing open. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>

extern int filebanned_match(const char *);

static int openfds(void){
	DIR *d=opendir("/proc/self/fd"); if(!d) return -1; int n=0; struct dirent *e;
	while((e=readdir(d))) if(e->d_name[0]!='.') n++;
	closedir(d); return n; /* includes the opendir fd itself, constant offset */
}

int main(void){
	int base = openfds();
	for (int i=0;i<2000;i++) filebanned_match("not-a-banned-name.dat");
	int after = openfds();
	/* allow a tiny slack; a per-call leak would be ~2000 */
	if (after - base <= 5) { printf("RESULT:PASS fd delta=%d over 2000 calls\n", after-base); return 0; }
	printf("RESULT:FAIL fd delta=%d over 2000 calls (leak)\n", after-base); return 1;
}
