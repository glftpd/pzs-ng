#include <ctype.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <string.h>
#include <fcntl.h>
#include <stdlib.h>
#include <stdio.h>

#include "config.h"

#include "objects.h"
#include "macros.h"
#include "constants.h"
#include "stats.h"
#include "zsfunctions.h"

#include "../conf/zsconfig.h"

/*
 * Modified	: 01.16.2002
 * Author	: Dark0n3
 *
 * Description	: Reads crc for current file from preparsed sfv file.
 */
unsigned int readsfv_file(struct LOCATIONS *locations, struct VARS *raceI, int getfcount) {
    char		*fname;
    unsigned int	crc = 0;
    unsigned int	t_crc;
    FILE		*sfvfile;
    unsigned int	len;

    if ( (sfvfile = fopen(locations->sfv, "r")) == NULL ) {
      d_log("Failed to open sfv.\n");
      return 0;
    }
    fread( &raceI->misc.release_type, sizeof(short int), 1, sfvfile);
	d_log("Reading data from sfv (%s)\n", raceI->file.name);
    while ( fread(&len, sizeof(int), 1, sfvfile) == 1 ) {
	fname = m_alloc(len);
	fread(fname, 1, len, sfvfile);
	fread(&t_crc, sizeof(int), 1, sfvfile);
	raceI->total.files++;
	if (! strcasecmp(raceI->file.name, fname)) {
	    crc = t_crc;
	}
	if (getfcount && findfile(fname)) {
	    raceI->total.files_missing--;
	}

	d_log("Storing data on %s - CRC: %u - T_CRC: %u.\n", fname, crc, t_crc);
	m_free(fname);
    }
    fclose(sfvfile);
    raceI->total.files_missing += raceI->total.files;
    return crc;
}

/*
 * Modified	: 01.16.2002
 * Author	: Dark0n3
 *
 * Description	: Deletes all -missing files with preparsed sfv.
 */
void delete_sfv_file(struct LOCATIONS *locations) {
    char		*fname;
    FILE		*sfvfile;
    unsigned int	len;

    if ((sfvfile = fopen(locations->sfv, "r")) == NULL) {
	d_log("Couldn't fopen %s.\n", locations->sfv);
	exit(EXIT_FAILURE);
    }
    /*sfvfile = fopen(locations->sfv, "r");*/

    fseek(sfvfile, sizeof(short int), SEEK_CUR);
    while ( fread(&len, sizeof(int), 1, sfvfile) == 1 ) {
	fname = m_alloc(len + 8);
	fread(fname, 1, len, sfvfile);
	fseek(sfvfile, sizeof(int), SEEK_CUR);
	memcpy(fname + len - 1, "-missing", 9);
	unlink(fname);
	m_free(fname);
    }
    fclose(sfvfile);
}

/*
 * Modified	: 02.19.2002
 * Author	: Dark0n3
 *
 * Description	: Creates directory where all race information will be stored.
 */
void maketempdir(struct LOCATIONS *locations) {
    unsigned int	size;
    char		*fullpath, *path_p, *end_p;


    size = sizeof(storage) + locations->length_path;
    fullpath = m_alloc(size);
    memcpy(fullpath, storage, sizeof(storage));

    path_p = fullpath + sizeof(storage) - 1;
    memcpy(path_p, locations->path, locations->length_path + 1);

    for ( end_p = fullpath + size ; path_p < end_p; path_p++ ) {
	switch ( *path_p ) {
	    case	'/':
	    case	0:
		*path_p = 0;
		mkdir(fullpath, 0777);
		*path_p = '/';
		break;
	}
    }
    m_free(fullpath);
}

/*
 * Modified	: 01.16.2002
 * Author	: Dark0n3
 *
 * Description	: Reads name of old race leader and writes name of new leader into temporary file.
 *
 * Todo		: Make this unneccessary (write info to another file)
 */
void read_write_leader_file(struct LOCATIONS *locations, struct VARS *raceI, struct USERINFO *userI) {
    FILE	*file;

    if ( (file = fopen(locations->leader, "r+")) != NULL ) {
	fread(&raceI->misc.old_leader, 1, 24, file);
	rewind(file);
	fwrite(userI->name, 1, 24, file);
    } else {
	*raceI->misc.old_leader = 0;
	if ((file = fopen( locations->leader, "w+" )) == NULL) { 
		d_log("Couldn't write to %s.\n", locations->leader);
		exit(EXIT_FAILURE);
	}
	fwrite(userI->name, 1, 24, file);
    }
    fclose(file);
}

/*
 * Modified	: 01.16.2002
 * Author	: Dark0n3
 *
 * Description	: Goes through all untested files and compares crc of file
 *		  with one that is reported in sfv.
 *
 * Todo		: Add unduper
 */
void testfiles_file(struct LOCATIONS *locations, struct VARS *raceI) {
    int		len;
    unsigned char	status;
    FILE		*file;
    char		*fname, *realfile, *target;
    unsigned int	Tcrc, crc;

    target = m_alloc(256);

    if ( ( file = fopen( locations->race, "r+" ) ) != NULL ) {
	realfile = raceI->file.name;
	while ( fread( &len, sizeof(int), 1, file ) == 1 ) {

	    fname = m_alloc(len);
	    fread(fname, 1, len, file);
	    fread(&status, 1, 1, file);
	    fread(&crc, sizeof(int), 1, file);

	    if ( status == F_NOTCHECKED ) {
		raceI->file.name = fname;
		Tcrc = readsfv_file(locations, raceI, 0);
		if ( crc != 0 && Tcrc == crc ) {
		    status = F_CHECKED;
		} else {
		    unlink(fname);
#if ( create_missing_files )
		    if ( Tcrc != 0 ) create_missing(fname, len - 1);
#endif
		    status = F_BAD;
		    if ( enable_unduper_script == TRUE ) {
			d_log("marking %s bad.\n",fname);
			sprintf(target, unduper_script " %s", fname);
			if ( execute(target) == 0 ) {
			    d_log("undupe of %s successful.\n", fname);
			} else {
			    d_log("undupe of %s failed.\n", fname);
			}
		    }
		}
	    }

	    fseek(file, -1 - sizeof(int), SEEK_CUR);
	    fwrite(&status, 1, 1, file);
	    fseek(file, 48 + 5 * sizeof(int), SEEK_CUR);
	    m_free(fname);
	}

	raceI->file.name = realfile;
	raceI->total.files = raceI->total.files_missing = 0;
	fclose(file);
    }
}

/*
 * Modified	: 01.20.2002
 * Author	: Dark0n3
 *
 * Description	: Parses file entries from sfv file and store them in a file.
 *
 * Todo		: Add dupefile remover.
 */
void copysfv_file(char *source, char *target, off_t buf_bytes) {
    int		fd;
    char		*buf;
    char		*line;
    char		*newline;
    char		*eof;
    char		*fext;
    char		*crc;
    char		crclen;
    unsigned int	video	= 0;
    unsigned int	music	= 0;
    unsigned int	rars	= 0;
    unsigned int	others	= 0;
    int			len	= 0;
    short int		n	= 0;
    unsigned int	t_crc;
    int		sfv_error	= FALSE;

#if ( sfv_dupecheck == TRUE )
    char		*fname[256]; /* Semi-stupid. We limit @ 256, which is better than 100 anyways */
    unsigned int	files 	= 0;
    unsigned char	exists;
#endif
#if ( sfv_cleanup == TRUE && sfv_error == FALSE )
    int		fd_new	= open(".tmpsfv", O_CREAT|O_TRUNC|O_WRONLY, 0644);
    if (fd_new) {
        d_log("Failed to create temporary sfv file - setting cleanup of sfv to false and tries to continue.\n");
		sfv_error = TRUE;
    }

/* 15.09.2004 - Removing/Hiding the feature of adding comments to .sfv files
 *            - psxc

    if ( sfv_comment != NULL ) {
	write(fd_new, sfv_comment, sizeof(sfv_comment) - 1);
    }
 */

#endif

    fd = open(source, O_RDONLY);
    if (!fd) {
        d_log("Failed to open %s.\n", source);
		exit(EXIT_FAILURE);
    }
    buf = m_alloc(buf_bytes);
    read(fd, buf, buf_bytes);
    close(fd);
    eof = buf + buf_bytes;

    fd = open(target, O_CREAT|O_TRUNC|O_WRONLY, 0666);
    if (!fd) {
        d_log("Failed to create %s.\n", target);
		exit(EXIT_FAILURE);
    }
    write(fd, &n, sizeof(short int));

    for ( newline = buf ; newline < eof ; newline++ ) {
	for ( line = newline ; *newline != '\n' && newline < eof ; newline++ ) *newline = tolower(*newline);
	if ( *line != ';' && newline > line ) {
	    *newline = crclen = 0;
	    for ( crc = newline - 1; isxdigit(*crc) == 0 && crc > line ; crc-- ) *crc = 0;
	    for ( ; *crc != ' ' && crc > line ; crc-- ) crclen++;
	    if ( *crc == ' ' && crc > line && crclen == 8) {
		for ( fext = crc ; *fext != '.' && fext > line ; fext-- );
		if ( *fext == '.' ) fext++;
		*crc++ = 0;
		if ( ! strcomp(ignored_types, fext) && (t_crc = hexstrtodec((unsigned char*)crc)) > 0 ) {
		    len = crc - line;
#if ( sfv_dupecheck == TRUE )
		    exists = 0;
		    for ( n = 0 ; (unsigned int)n < files ; n++ ) {
			if ( ! memcmp(fname[n], line, len) ) {
			    exists = 1;
			    break;
			}
		    }

		    if ( exists == 1 ) {
			continue;
		    }

		    fname[files++] = line;
#endif
#if ( sfv_cleanup == TRUE && sfv_error == FALSE )
		    write(fd_new, line, len - 1);
		    write(fd_new, " ", 1);
		    write(fd_new, crc, 8);
		    write(fd_new, "\r\n", 2);
#endif
		    if ( ! memcmp(fext, "mp3", 4) ) {
			music++;
		    } else if ( israr(fext) ) {
			rars++;
		    } else if ( isvideo(fext) ) {
			video++;
		    } else {
			others++;
		    }
#if ( create_missing_files == TRUE )
		    if ( ! findfile(line) ) {
			create_missing(line, len - 1);
		    }
#endif
		    write(fd, &len, sizeof(int));
		    write(fd, line, len);
		    write(fd, &t_crc, sizeof(int));
		}
	    }
	}
    }

    lseek(fd, 0, 0);

    if ( music > rars ) {
	if ( video > music ) {
	    n = ( video >= others ? 4 : 2 );
	} else {
	    n = ( music >= others ? 3 : 2 );
	}
    } else {
	if ( video > rars ) {
	    n = ( video >= others ? 4 : 2 );
	} else {
	    n = ( rars >= others ? 1 : 2 );
	}
    }

    write(fd, &n, sizeof(short int));
    close(fd);

#if ( sfv_cleanup == TRUE && sfv_error == FALSE )
    unlink(source);
    rename(".tmpsfv", source);
    close(fd_new);
#endif

    m_free(buf);
}

/*
 * Modified	: 01.17.2002
 * Author	: Dark0n3
 *
 * Description	: Creates a file that contains list of files in release in alphabetical order.
 */
void create_indexfile_file(struct LOCATIONS *locations, struct VARS *raceI, char *f) {
    FILE	    *r;
    int		    l, n, m, c;
    int		    *pos;
    int		    *t_pos;
    unsigned char   s;
    char	    *t;
    char	    **fname;

    pos = m_alloc(sizeof(int) * raceI->total.files);
    t_pos = m_alloc(sizeof(int) * raceI->total.files);
    fname = m_alloc(sizeof(char*) * raceI->total.files);
    if ((r = fopen( locations->race, "r" )) == NULL) {
	d_log("Couldn't fopen %s.\n", locations->race);
	exit(EXIT_FAILURE);
	}
    /*r = fopen( locations->race, "r" );*/
    c = 0;

    /* Read filenames from race file */

    while (fread( &l, sizeof(int), 1, r ) == 1) {
	t = m_alloc(l);
	fread(t, 1, l, r);
	fread(&s, 1, 1, r);
	if (s == F_CHECKED) {
	    fname[c] = t;
	    t_pos[c] = 0;
	    c++;
	} else {
	    m_free(t);
	}
	fseek(r, 48 + 5 * sizeof(int), SEEK_CUR);
    }
    fclose(r);

    /* Sort with cache */

    for ( n = 0 ; n < c ; n++ ) {
	m = t_pos[n];
	for ( l = n + 1 ; l < c ; l++ ) {
	    if ( strcasecmp(fname[l], fname[n]) < 0 ) {
		m++;
	    } else {
		t_pos[l]++;
	    }
	}
	pos[m] = n;
    }

    /* Write to file and free memory */

    if ( ( r = fopen( f, "w" ) ) != NULL ) {
	for ( n = 0 ; n < c ; n++ ) {
	    m = pos[n];
	    fprintf(r, "%s\n", fname[m]);
	    m_free(fname[m]);
	}
	fclose(r);
    } else {
	for ( n = 0 ; n < c ; n++ ) {
	    m_free(fname[n]);
	}
    }

    m_free(fname);
    m_free(t_pos);
    m_free(pos);
}

/*
 * Modified	: 01.16.2002
 * Author	: Dark0n3
 *
 * Description	: Marks file as deleted.
 */
short int clear_file_file(struct LOCATIONS *locations, char *f) {
    int			len, n;
    unsigned char	status;
    FILE		*file;
    char		*fname;

    if ((file = fopen(locations->race, "r+")) != NULL) {
	n = 0;
	while (fread(&len, sizeof(int), 1, file) == 1) {
	    fname = m_alloc(len);
	    fread(fname, 1, len, file);
	    fread(&status, 1, 1, file);

	    if (( status == F_CHECKED || status == F_NOTCHECKED || status == F_NFO ) && ! memcmp(f, fname, len)) {
		status = F_DELETED;
		n++;
		fseek(file, -1, SEEK_CUR);
		fwrite(&status, 1, 1, file);
	    }

	    fseek(file, 48 + 5 * sizeof(int), SEEK_CUR);
	    m_free(fname);
	}
	fclose(file);
	if ( n != 0 ) return 1;
    }
    return 0;
}

/*
 * Modified	: 02.19.2002
 * Author	: Dark0n3
 *
 * Description	: Reads current race statistics from fixed format file.
 */
void readrace_file(struct LOCATIONS *locations, struct VARS *raceI, struct USERINFO **userI, struct GROUPINFO **groupI) {
    off_t		fsize;
    unsigned int	uspeed;
    unsigned int	start_time;
    unsigned char	*p_buf;
    unsigned char	buf[1 + 2*24 + 3 * sizeof(int) + sizeof(off_t)];
    unsigned int	len;
    FILE		*file;
    char		*uname;
    char		*ugroup;

    if ( (file = fopen(locations->race, "r")) == NULL ) {
	return;
    }

    while ( fread(&len, sizeof(int), 1, file) == 1 ) {
	fseek(file, len, SEEK_CUR);
	fread(buf, 1, sizeof(buf), file);

	p_buf	= buf + 1 + sizeof(int);
	uname	= (char *)p_buf;			p_buf += 24;
	ugroup	= (char *)p_buf;			p_buf += 24;
	memcpy(&fsize , p_buf, sizeof(off_t));		p_buf += sizeof(off_t);
	memcpy(&uspeed, p_buf, sizeof(int));		p_buf += sizeof(int);
	memcpy(&start_time , p_buf, sizeof(int));

	switch (*buf) {
	    case F_NOTCHECKED:
	    case F_CHECKED: updatestats(raceI, userI, groupI, uname, ugroup, (off_t)fsize, (unsigned int)uspeed, (unsigned int)start_time); break;
	    case F_BAD: raceI->total.files_bad++; raceI->total.bad_size += fsize; break;
	    case F_NFO:
			raceI->total.nfo_present = 1;
			break;
	}
    }
    fclose(file);
}

/*
 * Modified	: 01.18.2002
 * Author	: Dark0n3
 *
 * Description	: Writes stuff into race file.
 */
void writerace_file(struct LOCATIONS *locations, struct VARS *raceI, unsigned int crc, unsigned char status) {
    FILE			*file;
    unsigned int		len;
    unsigned int		sz;
    unsigned char		*buf;
    unsigned char		*p_buf;

    clear_file_file(locations, raceI->file.name);

    if ( (file = fopen(locations->race, "a+")) == NULL) {
	d_log("Racefile cannot be written. Aborting.\n");
	exit(EXIT_FAILURE);
    }

    len = strlen(raceI->file.name) + 1;
    sz = len + 1 + 2*24 + 4 * sizeof(int) + sizeof(off_t);
    p_buf = buf = m_alloc(sz);

    memcpy(p_buf, &len, sizeof(int));				p_buf += sizeof(int);
    memcpy(p_buf, raceI->file.name, len);				p_buf += len;
    *p_buf++ = status;
    memcpy(p_buf, &crc, sizeof(int));				p_buf += sizeof(int);
    memcpy(p_buf, raceI->user.name, 24);				p_buf += 24;
    memcpy(p_buf, raceI->user.group, 24);				p_buf += 24;
    memcpy(p_buf, &raceI->file.size, sizeof(off_t));		p_buf += sizeof(off_t);
    memcpy(p_buf, &raceI->file.speed, sizeof(int));		p_buf += sizeof(int);
    memcpy(p_buf, &raceI->total.start_time, sizeof(int));

    fwrite(buf, 1, sz, file);
    fclose(file);
    m_free(buf);
}
