/*
A utility to display racestats based on the racedata file.
No rechecking of SFV-data or DIZ-data is done: it is assumed racedata is valid.
*/

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdbool.h>
#include <time.h>
#include <fcntl.h>
#include <sys/time.h>
#include <sys/types.h>
#include <sys/stat.h>

#include "zsfunctions.h"
#include "race-file.h"
#include "objects.h"
#include "macros.h"
#include "convert.h"
#include "dizreader.h"
#include "stats.h"

#include "../conf/zsconfig.h"
#include "../include/zsconfig.defaults.h"

#define COOKIE		"{%r} {%F} {%f} {%u} {%g} %C0 %c0"

static void init_g(GLOBAL*);

static void
init_g(GLOBAL *g) {
	g->l.race = malloc(PATH_MAX);
	g->l.sfv = malloc(PATH_MAX);

	g->ui = malloc(sizeof(struct USERINFO *) * 30);
	memset(g->ui, 0, sizeof(struct USERINFO *) * 30);
	g->gi = malloc(sizeof(struct GROUPINFO *) * 30);
	memset(g->gi, 0, sizeof(struct GROUPINFO *) * 30);

	g->v.misc.slowest_user[0] = ULONG_MAX;
	g->v.misc.fastest_user[0] =
		g->v.total.speed =
		g->v.total.files_missing =
		g->v.total.files =
		g->v.total.size =
		g->v.total.users =
		g->v.total.groups = 0;

	g->v.file.name[0] = '.';
	g->v.file.name[1] = 0;
}

bool
set_path(GLOBAL *g, bool chrooted, char **argv) {
	int n=0;

	if (chrooted) {
		strcpy(g->l.path, argv[1]);
	} else {
		if (chroot(argv[1]) != 0) {
    	    perror("chroot failed");
        	exit(EXIT_FAILURE);
    	}
		strcpy(g->l.path, argv[2]);
	}

	n = strlen(g->l.path);
	
	if (g->l.path[n] == '/') {
		g->l.path[n] = 0;
	}

	return chdir(g->l.path) == 0;
}

void
clean_up(GLOBAL *g, char *stat_cookies) {
	free(g->l.race);
	free(g->l.sfv);
	free(g->gi);
	free(g->ui);
	free(stat_cookies);
}

int 
main(int argc, char **argv)
{
	GLOBAL g;
	char *stat_cookies;

	if (argc < 2 || argc > 4 ) {
		printf("Usage: %s <chrooted-path>\n", argv[0]);
		printf("   or: %s <glftpd-path> <site-path> <stats-format-line>\n", argv[0]);
		exit(EXIT_FAILURE);
	}


	if (argc == 3) {
		stat_cookies = strdup(COOKIE);
	} else {
		stat_cookies = strdup(argv[3]);
	}

	init_g(&g);
	if (set_path(&g, (argc == 2), argv) == false) {
		clean_up(&g, stat_cookies);
		exit(EXIT_FAILURE);
	}

	getrelname(&g);
	sprintf(g.l.race, storage "/%s/racedata", g.l.path);
	if (!fileexists(g.l.race)) {
		clean_up(&g, stat_cookies);
		exit(EXIT_FAILURE);
	}

	readrace(g.l.race, &g.v, g.ui, g.gi);
	sortstats(&g.v, g.ui, g.gi);
	if (g.v.total.users) {
		printf("%s\n", convert(&g.v, g.ui, g.gi, stat_cookies));
	}

	clean_up(&g, stat_cookies);
	exit(EXIT_SUCCESS);
}
