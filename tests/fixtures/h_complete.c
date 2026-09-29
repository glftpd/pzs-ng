/* Regression harness for complete()'s toplist buffer.  The stock user_top template
 * can't produce an entry longer than topbuf[256], so compile complete.c into this
 * harness with a template of two %K (tagline, up to 254 bytes each) and run it.
 * Must be built without complete.o.  Prints RESULT:PASS; run under ASan. */
#include "zsfunctions.h"
#include "objects.h"
#undef user_top
#define user_top "%K%K"
#include "../src/complete.c"

int main(void)
{
	static GLOBAL g;
	static struct USERINFO u, *ui[1];
	static struct GROUPINFO gr, *gi[1];

	strcpy(u.name, "racer"); u.files = 1; u.bytes = 1000; u.speed = 1000;
	strcpy(gr.name, "GRP"); gr.files = 1; gr.bytes = 1000; gr.users = 1;
	ui[0] = &u; gi[0] = &gr;
	g.ui = ui; g.gi = gi;
	g.v.total.users = g.v.total.groups = 1;
	g.v.total.files = 1; g.v.total.size = 1000;
	g.v.misc.write_log = 1;
	memset(g.v.user.tagline, 'T', sizeof(g.v.user.tagline) - 1);
	strcpy(g.l.path, "/site/test/Rel");
	g.l.incomplete = "(incomplete)-Rel";

	complete(&g, 0);
	printf("RESULT:PASS toplist built, %zu bytes\n", strlen(g.v.misc.top_messages[0]));
	return 0;
}
