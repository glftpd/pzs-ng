#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>

#include "dizreader.h"

/*
 * ? = any char
 * & = character is not ... (ie &/ = character is not /)
 * &! = character is not 0-9, o or x
 * # = total disk count
 * ! = chars 0-9, o & x
 *
 * !!! USE LOWERCASE !!!
 */
const char * const search[] = {
		"[?!/##]",
		"(?!/##)",
		"[?!!/###]",
		"(?!!/###)",
		"[?/#]",
		"[?/##]",
		"(?/#)",
		"[disk:!!/##]",
		"[disk:?!/##]",
		"o?/o#",
		"disks[!!/##",
		" !/# ",
		" !!/##&/&!",
		"&/!!/## ",
		"[!!/#]",
		": ?!/##&/",
		"xx/##",
		"<!!/##>",
		"x/##",
		"! of #",
		"? of #",
		"x of #",
		"ox of o#",
		"!! of ##",
		"?! of ##",
		"xx of ##"};

const size_t search_size = sizeof(search) / sizeof(char*);

void 
removespaces(char *instr, int l)
{
	int spaces = 0;
    int j = 0;

	for (int cnt = 0; cnt < l; cnt++)
		switch (instr[cnt]) {
		case '\0':
		case ' ':
		case '\n':
			if (!spaces)
				instr[j++] = ' ';
			spaces++;
			break;
		default:
			instr[j++] = tolower(instr[cnt]);
			spaces = 0;
			break;
		}
	instr[j] = 0;
}

int 
read_diz(void)
{
	int		    pos, fd, diskc, skip_count, tgt;
	int         cnt, cnt2, cnt3, matches;
	char        data[4096];
	char        disks[4];

	fd = open("file_id.diz", O_NONBLOCK);
	while ((tgt = read(fd, data, 4096)) > 0) {
		removespaces(data, tgt);

		for (cnt = 0; cnt < tgt; cnt++)
			for (cnt2 = 0; cnt2 < (int) search_size; cnt2++) {
				pos = matches = skip_count = 0;
				disks[0] = disks[1] = disks[2] = disks[3] = '\0';
				for (cnt3 = 0; cnt3 <= (int)(strlen(search[cnt2])) - skip_count; cnt3++)
					switch (search[cnt2][cnt3 + skip_count]) {
					case '#':
						if (isdigit(data[cnt + cnt3]) || data[cnt + cnt3] == ' ' || data[cnt + cnt3] == 'o') {
							if (data[cnt + cnt3] == 'o')
								data[cnt + cnt3] = '0';
							matches++;
							pos += sprintf(disks + pos, "%c", data[cnt + cnt3]);
						} break;
					case '?':
						matches++;
						break;
					case '!':
						if (isdigit(data[cnt + cnt3]) || data[cnt + cnt3] == 'o' || data[cnt + cnt3] == 'x')
							matches++;
						break;
					case '&':
						skip_count++;
						if (!(search[cnt2][cnt3 + skip_count] == '!' && (isdigit(data[cnt + cnt3]) || data[cnt + cnt3] == 'o' || data[cnt + cnt3] == 'x')) && data[cnt + cnt3] != search[cnt2][cnt3 + skip_count])
							matches++;
						break;
					default:
						if (search[cnt2][cnt3 + skip_count] == data[cnt + cnt3])
							matches++;
						break;
					}
				if (matches == (int)strlen(search[cnt2]) - skip_count && (diskc = strtol(disks, NULL, 10))) {
                    close(fd);
					return diskc;
                }
			}
	}
	close(fd);
	return 0;
}
