#!/bin/bash

# PSXC IMDB INFO #
##################

# version number. do not change.
VERSION="v3.2"

######################################################################################################

RECVDARGS="$1"

# Remove locale settings which might cause problems
export LC_ALL=""
export LANG=""

# Source shared library for API functions
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/psxc-imdb-lib.sh"
imdb_set_defaults
imdb_load_config || exit 0

# FIXDIRTIME mtime-snapshot carrier, resolved for this run's context
# (chrooted vs host) so the snapshot/restore works in both.
DIRDATE_CARRIER="$(imdb_dirdate_carrier)"

# Start debugging
if [ "$DEBUG" = "ON" ] || [ "$DEBUG" = "2" ]; then
 set -x
elif [ "$DEBUG" = "3" ] || [ "$DEBUG" = "4" ]; then
 # level 4 additionally traces the bash addons (see EXTERNALSCRIPTNAME below)
 set -x -v
fi

# Let's hack glftpd
if [ -z "$RECVDARGS" ] && [ ! -z "$GLFIX" ]; then
 RECVDARGS=$(ls -1Ft | grep -v "/" | grep -v "@" | head -n 1 | grep -e "[.][nN][fF][oO]$")
fi

if [ ! -z "$RECVDARGS" ]; then

# This is what is run under zs-c, chrooted.
###########################################

# PATH=$PATHCHROOTED
# IMDBLOG=$IMDBLOGCHROOTED
 FILENAME="$RECVDARGS"
   MYTMPFILE=$(strip_glroot "$TMPRESCANFILE")
   PSXCFLAG=$(head -n 1 "$MYTMPFILE" 2>/dev/null | tr -cd '0-9')
    if [ ! -z "$PSXCFLAG" ]; then
     if [ "$PSXCFLAG" -ge 4 ]; then
      let PSXCFLAG=PSXCFLAG-4
     fi
     if [ "$PSXCFLAG" -ge 2 ]; then
      DOTIMDB=""
      INFOTEMPNAME=""
      DOTDATE=""
      DOTURL=""
     fi
    fi
    # Snapshot the release dir's original date before creating any files in it
    # (FIXDIRTIME gated); restored at the end of this block and again by the
    # queue path so upload-order dirlists stay intact.
    if [ ! -z "$FIXDIRTIME" ]; then
     touch -r "$(pwd)" "$DIRDATE_CARRIER" >/dev/null 2>&1
    fi
    if [ ! -z "$DOTDATE" ]; then
     DOTDATEINFO="$(grep [Dd][Aa][Tt][Ee] "$FILENAME" | tr -c '/a-zA-Z0-9:. -/\n' ' ' | tr -s ' ')"
     if [ ! -z "$DOTDATEINFO" ]; then
      echo "$DOTDATEINFO" > "$DOTDATE"
      chmod 666 "$DOTDATE"
     fi
    fi

# Should we even begin searching for an url?
   SEARCHFORURLS=0
   if [ -z "$SCANDIRS" ]; then
    SEARCHFORURLS=1
   fi
   for SCANDIR in $SCANDIRS; do
    if [ ! -z "$(pwd | grep "$SCANDIR")" ]; then
     SEARCHFORURLS=1
     break
    fi
   done
   if [ $SEARCHFORURLS -eq 0 ]; then
    exit 0
   fi

# First, replace some old variable values
   if [ -z "$RELAXEDURLS" ]; then
    RELAXEDURLS=1
   fi
   if [ "$RELAXEDURLS" = "ON" ]; then
    RELAXEDURLS=3
   fi

# Level 0 search
   IMDBURLS="$(grep [Ii][Mm][Dd][Bb] "$FILENAME" | tr ' \|' '\n' | sed -n /[hH][tT][tT][pP][sS]*:[/][/].*[.][iI][mM][dD][bB][.].*.[0-9]/p | head -n 1 | tr -c -d '[:alnum:]\:./?')"
   if [ ! -z "$(echo "$IMDBURLS" | grep "imdb\.")" ]; then
#    IMDBURL="https://www.imdb.com/title/tt""$(echo "$IMDBURLS" | sed "s/=/-/g" | sed "s/imdb./=/" | cut -d "=" -f 2 | cut -d "/" -f 2,3 | tr -c -d '[:digit:]')"
     IMDBURL="https://www.imdb.com/title/tt""$(echo "$IMDBURLS" | sed "s/=/-/g" | sed "s/imdb\./=/" | cut -d "=" -f 2 |  grep -o "[0-9]*" | head -n 1)"
    if [ -z "$(echo "$IMDBURL" | tr -cd '0-9')" ]; then
     IMDBURL=""
    fi
   fi

# Level 1 search
   if [ -z "$IMDBURL" ] && [ "$RELAXEDURLS" -ge 1 ]; then
    IMDBURLS="$(grep [Ii][Mm][Dd][Bb] "$FILENAME" | tr ' \|' '\n' | sed -n /[hH][tT][tT][pP][sS]*:[/][/].*[iI][mM][dD][bB][.].*.[0-9]/p | head -n 1 | tr -c -d '[:alnum:]\:./?')"
    if [ ! -z "$(echo "$IMDBURLS" | grep "imdb\.")" ]; then
     IMDBURL="https://www.imdb.com/title/tt""$(echo "$IMDBURLS" | sed "s/=/-/g" | sed "s/imdb\./=/" | cut -d "=" -f 2 | cut -d "/" -f 2,3 | tr -c -d '[:digit:]')"
     if [ -z "$(echo "$IMDBURL" | tr -cd '0-9')" ]; then
      IMDBURL=""
     fi
    fi
   fi

# Level 2 search
   if [ -z "$IMDBURL" ] && [ "$RELAXEDURLS" -ge 2 ]; then
    IMDBURLS="$(grep [Ii][Mm][Dd][Bb] "$FILENAME" | tr ' \|' '\n' | sed -n /.*[iI][mM][dD][bB][.].*.[0-9]/p | head -n 1 | tr -c -d '[:alnum:]\:./?')"
    if [ ! -z "$(echo "$IMDBURLS" | grep "imdb\.")" ]; then
     IMDBURL="https://www.imdb.com/title/tt""$(echo "$IMDBURLS" | sed "s/=/-/g" | sed "s/imdb\./=/" | cut -d "=" -f 2 | cut -d "/" -f 2,3 | tr -c -d '[:digit:]')"
     if [ -z "$(echo "$IMDBURL" | tr -cd '0-9')" ]; then
      IMDBURL=""
     fi
    fi
   fi

# Level 3 search
   if [ -z "$IMDBURL" ] && [ "$RELAXEDURLS" -ge 3 ]; then
    for IMDBURLS in $(grep [Ii][Mm][Dd][Bb] "$FILENAME" | tr -c '[:digit:]' '\n' | grep -v "^$"); do
     if [ ! -z "$(echo "$IMDBURLS" | tr -cd '0-9')" ]; then
      if [ "$(echo "$IMDBURLS" | tr -cd '0-9' | wc -c)" -eq 8 ] || [ "$(echo "$IMDBURLS" | tr -cd '0-9' | wc -c)" -eq 7 ]; then
       IMDBURL="$IMDBURLS"
       break
      fi
     fi
    done
    if [ ! -z "$IMDBURL" ]; then
     IMDBURL="https://www.imdb.com/title/tt""$IMDBURL"
    fi
   fi

# Level 4 search
   if [ -z "$IMDBURL" ] && [ "$RELAXEDURLS" -ge 4 ]; then
    for IMDBURLS in $(cat "$FILENAME" | tr -c '[:digit:]' '\n' | grep -v "^$"); do
     if [ "$(echo "$IMDBURLS" | wc -c)" -eq 8 ] || [ "$(echo "$IMDBURLS" | wc -c)" -eq 7 ]; then
      IMDBURL="$IMDBURLS"
      break
     fi
    done
    if [ ! -z "$IMDBURL" ]; then
     IMDBURL="https://www.imdb.com/title/tt""$IMDBURL"
    fi
   fi

# apply localized URL path if LOCALURL is set
   if [ ! -z "$IMDBURL" ] && [ ! -z "$LOCALURL" ]; then
    IMDBURL="$(imdb_localize_url "$IMDBURL" "$LOCALURL")"
   fi

# export what we've found
   if [ ! -z "$IMDBURL" ]; then
     imdb_queue_lookup "$IMDBURL" "$PWD" "$IMDBLOGCHROOTED"
    if [ ! -z "$DOTIMDB" ]; then
     if [ ! -e "$DOTIMDB" ] || [ -w "$DOTIMDB" ]; then
      echo -n "" > $DOTIMDB
      chmod 666 $DOTIMDB
     fi
    fi
    if [ ! -z "$DOTURL" ]; then
     DOTURLF="$(basename "$PWD" | sed "s/ /./g")"
     if [ ! "$DOTURL" = "URL" ]; then
      DOTURLF="$DOTURLF"".imdb.html"
      if [ ! -e "$DOTURLF" ] || [ -w "$DOTURLF" ]; then
       echo "<TITLE>IMDB REDIRECT</TITLE>" > $DOTURLF
       echo "<META HTTP-EQUIV=\"refresh\" CONTENT=\"0;URL=$IMDBURL\">" >> $DOTURLF
       chmod 666 $DOTURLF
      fi
     else
      DOTURLF="$DOTURLF"".imdb.url"
      if [ ! -e "$DOTURLF" ] || [ -w "$DOTURLF" ]; then
       echo "[InternetShortcut]" > $DOTURLF
       echo "URL=""$IMDBURL" >> $DOTURLF
       chmod 666 $DOTURLF
      fi
     fi
    fi
    if [ ! -z "$INFOTEMPNAME" ]; then
     if [ ! -e "$INFOTEMPNAME" ] || [ -w "$INFOTEMPNAME" ]; then
      if [ ! -z "$INFOFILEIS" ]; then
       echo -n "" > $INFOTEMPNAME
      chmod 666 $INFOTEMPNAME
      else
       mkdir -p $INFOTEMPNAME
       chmod 777 $INFOTEMPNAME
      fi
     fi
    fi
   fi
   # Restore the release dir's original date (undoing the dummy-file creation
   # bump) so the queue step snapshots the true pre-run date. Only if
   # FIXDIRTIME is enabled; default is "" - the script does not actively
   # touch directory timestamps.
   if [ ! -z "$FIXDIRTIME" ] && [ -f "$DIRDATE_CARRIER" ]; then
    touch -r "$DIRDATE_CARRIER" "$(pwd)" >/dev/null 2>&1
    rm -f "$DIRDATE_CARRIER" >/dev/null 2>&1
   fi

#else
fi
if [ ! -z "$RUNCONTINOUS" ] || [ -z "$RECVDARGS" ]; then
# run major part.

 if [ "$(basename "$0")" = "$PRENAME" ]; then

# This is what is done with pre's
#################################
  PATH=$GLPATHPRE

  a="$(tail -n 5 "$GLPRELOG" | grep "$PRETRIGGER" | tail -n 1)"
  DIRNAME=$(imdb_extract_pre_dirname "$a" "$PRETRIGGER" "$WORDS" "$SEPARATOR")
  if [ $? -ne 0 ]; then
    exit 0
  fi
  if [ -d "$GLROOT$DIRNAME" ]; then
    FILENAME=$(ls -1 "$GLROOT$DIRNAME" | grep "\.[Nn][Ff][Oo]$" | head -n 1)
    IMDBURL="$(grep [Ii][Mm][Dd][Bb] "$GLROOT$DIRNAME/$FILENAME" | tr ' ' '\n' | sed -n /[hH][tT][tT][pP][sS]*:[/][/].*[.][iI][mM][dD][bB].*.[0-9]/p | head -n 1 | tr -c -d '[:alnum:]\:./?')"
    if [ ! -z "$(echo "$IMDBURL" | grep "\.imdb\.")" ]; then
     IMDBURL="https://www.imdb.com/title/tt""$(echo "$IMDBURL" | sed "s/=/-/g" | sed "s/\.imdb\./=/" | cut -d "=" -f 2 | cut -d "/" -f 2,3 | tr -c -d '[:digit:]')"
    fi
    if [ ! -z "$IMDBURL" ] && [ ! -z "$LOCALURL" ]; then
     IMDBURL="$(imdb_localize_url "$IMDBURL" "$LOCALURL")"
    fi
    if [ ! -z "$IMDBURL" ]; then
     a="$(tail -n 5 "$GLLOG" | grep "$TRIGGER" | grep "$DIRNAME" | tail -n 1)"
    if [ -z "$a" ]; then
     SEARCHFORURLS=0
     if [ -z "$SCANDIRS" ]; then
      SEARCHFORURLS=1
     fi
     for SCANDIR in $SCANDIRS; do
      if [ ! -z "$(echo "$DIRNAME" | grep "$SCANDIR")" ]; then
       SEARCHFORURLS=1
       break
      fi
     done
     if [ ! $SEARCHFORURLS -eq 0 ]; then
       imdb_queue_lookup "$IMDBURL" "$DIRNAME" "$IMDBLOG"
     fi
    fi
   fi
  fi
  if [ -z "$RUNCONTINOUS" ]; then
   exit 0
  fi
 fi

 if [ ! -e "$IMDBLOG" ]; then

# Check to see if it's a first-run
##################################

  echo "Please read the docs before trying to run this script."
  exit 0
 fi

# The main part.
################

 if [ -z "$(cat "$IMDBLOG")" ]; then

# No new imdb-info. let's quit.
###############################
  exit 0
 fi

# Make sure this script isn't already running.
##############################################
 LOCKDIR="${IMDBPID}.lock"
 if mkdir "$LOCKDIR" 2>/dev/null; then
   trap 'rmdir "$LOCKDIR" 2>/dev/null' EXIT
 else
   IMDBPIDCONTENT="$(head -n2 "$IMDBPID" 2>/dev/null | tail -n1)"
   if [[ -n "$IMDBPIDCONTENT" ]]; then
     if [[ "$IMDBPIDCONTENT" -ne -1 ]] && [[ -z "$(ps ax | awk '{print $1}' | grep -e "^$IMDBPIDCONTENT$")" ]]; then
       rmdir "$LOCKDIR" 2>/dev/null
       mkdir "$LOCKDIR" 2>/dev/null && trap 'rmdir "$LOCKDIR" 2>/dev/null' EXIT
     else
       exit 0
     fi
   fi
 fi
 echo $$ > "$IMDBPID"

# Seems like something was put into the log. Let's check it.
############################################################
 IMDBFLAGS=$(head -n 1 "$TMPRESCANFILE" 2>/dev/null | tr -cd '0-9')
 if [ ! -z "$IMDBFLAGS" ]; then
  if [ "$IMDBFLAGS" -ge 4 ]; then
   EXTERNALSCRIPTNAME=""
   let IMDBFLAGS=IMDBFLAGS-4
  fi
  if [ "$IMDBFLAGS" -ge 2 ]; then
   DOTIMDB=""
   INFOTEMPNAME=""
   let IMDBFLAGS=IMDBFLAGS-2
  fi
  if [ "$IMDBFLAGS" -ge 1 ]; then
   USEBOT=""
  fi
 fi

 if [ -z "$LANGUAGENUM" ] || [ "$LANGUAGENUM" -eq 0 ]; then
  LANGUAGENUM=99
 fi
 if [ -z "$COUNTRYNUM" ] || [ "$COUNTRYNUM" -eq 0 ]; then
  COUNTRYNUM=99
 fi
 if [ -z "$CERTIFICATIONNUM" ] || [ "$CERTIFICATIONNUM" -eq 0 ]; then
  CERTIFICATIONNUM=99
 fi
 if [ -z "$CASTNUM" ] || [ "$CASTNUM" -eq 0 ]; then
  CASTNUM=99
 fi
 if [ -z "$GENRENUM" ] || [ "$GENRENUM" -eq 0 ]; then
  GENRENUM=99
 fi
 if [ -z "$RUNTIMENUM" ] || [ "$RUNTIMENUM" -eq 0 ]; then
  RUNTIMENUM=99
 fi
 if [ -z "$DIRECTORNUM" ] || [ "$DIRECTORNUM" -eq 0 ]; then
  DIRECTORNUM=99
 fi

 # Defaults for new config options (not present in older conf files)
 if [ -z "$SHOWMETACRITIC" ]; then
  SHOWMETACRITIC="NO"
 fi

# Save the effective per-release defaults (after run-level IMDBFLAGS
# processing) so each queue entry starts fresh. Per-entry branches (API
# error, missing dir, find /dev/null entries) must not leak state into the
# next release processed in the same run.
  DOTIMDB_DEFAULT="$DOTIMDB"
  USEBOT_DEFAULT="$USEBOT"
  EXTERNALSCRIPTNAME_DEFAULT="$EXTERNALSCRIPTNAME"
  INFOTEMPNAME_DEFAULT="$INFOTEMPNAME"
  BOTONELINE_DEFAULT="$BOTONELINE"
  TRIGGER_DEFAULT="$TRIGGER"
  LOGFORMAT_DEFAULT="$LOGFORMAT"
  MYOWNFORMAT_DEFAULT="$MYOWNFORMAT"
  MYOWNEMPTY_DEFAULT="$MYOWNEMPTY"
  GLLOG_DEFAULT="$GLLOG"
  TAGPLOT_DEFAULT="$TAGPLOT"
  BOTHEAD_DEFAULT="$BOTHEAD"

 while [ ! -z "$(cat "$IMDBLOG")" ]; do
  IMDBLINE="$(grep -e "/" "$IMDBLOG" | head -n 1)"
  grep -F -v "$IMDBLINE" "$IMDBLOG" > "$TMPFILE"
  cat "$TMPFILE" > "$IMDBLOG"
  DOTIMDB="$DOTIMDB_DEFAULT"
  USEBOT="$USEBOT_DEFAULT"
  EXTERNALSCRIPTNAME="$EXTERNALSCRIPTNAME_DEFAULT"
  INFOTEMPNAME="$INFOTEMPNAME_DEFAULT"
  BOTONELINE="$BOTONELINE_DEFAULT"
  TRIGGER="$TRIGGER_DEFAULT"
  LOGFORMAT="$LOGFORMAT_DEFAULT"
  MYOWNFORMAT="$MYOWNFORMAT_DEFAULT"
  MYOWNEMPTY="$MYOWNEMPTY_DEFAULT"
  GLLOG="$GLLOG_DEFAULT"
  TAGPLOT="$TAGPLOT_DEFAULT"
  BOTHEAD="$BOTHEAD_DEFAULT"
  ISLIMITED=""
  BUSINESS=""
  BUSINESSSHORT=""
  PREMIERE=""
  LIMITED=""
  EXEMPTED=""
  IMDBURL="$(echo "$IMDBLINE" | cut -d "|" -f 1)"
  if [ ! -z "$IMDBURL" ] && [ ! -z "$LOCALURL" ]; then
   IMDBURL="$(imdb_localize_url "$IMDBURL" "$LOCALURL")"
  fi
  IMDBLNK="$(echo "$IMDBLINE" | cut -d "|" -f 2)"
  IMDBDST="$(echo "$IMDBLINE" | cut -d "|" -f 3)"
  DEBUGCOUNT=1
  if [ ! -z "$DEBUG" ]; then
   echo "$DEBUGCOUNT : DOTIMDB = '$DOTIMDB'"
   echo "$DEBUGCOUNT : USEBOT = '$USEBOT'"
  fi
  if [ -d "$GLROOT$IMDBLNK" ]; then
   IMDBDIR="$(basename "$IMDBLNK")"
   BASELNK="$(dirname "$IMDBLNK")"
   IMDBLKL="$IMDBLNK"
   IMDBLNK="$GLROOT$IMDBLKL/$DOTIMDB"
  elif [ "$IMDBLNK" = "/dev/null" ]; then
   IMDBLKL="$IMDBLNK"
   DOTIMDB=""
   EXTERNALSCRIPTNAME=""
   INFOTEMPNAME=""
   BOTONELINE=$FINDBOTONELINE
   TRIGGER="$FINDTRIGGER"
   LOGFORMAT="$FINDLOGFORMAT"
   MYOWNFORMAT="$FINDMYOWNFORMAT"
   MYOWNEMPTY="$FINDMYOWNEMPTY"
   if [ ! -z "$PSXCFINDLOG" ] && [ -w "$PSXCFINDLOG" ]; then
    GLLOG=$PSXCFINDLOG
   fi
  else
   DOTIMDB=""
   USEBOT=""
   EXTERNALSCRIPTNAME=""
   INFOTEMPNAME=""
  fi
  DEBUGCOUNT=2
  if [ ! -z "$DEBUG" ]; then
   echo "$DEBUGCOUNT : DOTIMDB = '$DOTIMDB'"
   echo "$DEBUGCOUNT : USEBOT = '$USEBOT'"  
  fi
  for EXEMPT in $BOTEXEMPT; do
   if [ ! -z "$(echo "$IMDBLKL" | grep "$EXEMPT")" ]; then
    USEBOT=""
    EXEMPTED="ON"
   fi
  done
  if [ ! -z "$LOGFORMAT" ]; then
   BOTONELINE="YES"
   TAGPLOT=""
   BOTHEAD=""
  fi
  DEBUGCOUNT=3
  if [ ! -z "$DEBUG" ]; then
   echo "$DEBUGCOUNT : DOTIMDB = '$DOTIMDB'"
   echo "$DEBUGCOUNT : USEBOT = '$USEBOT'"  
  fi
  if [ ! -z "$(grep "$IMDBURL" "$IMDBURLLOG")" ] || [ ! -z "$EXEMPTED" ]; then
   if [ ! "$IMDBLKL" = "/dev/null" ]; then
    USEBOT=""
   fi
  else
   if [ ! "$IMDBLKL" = "/dev/null" ]; then
    echo "$IMDBURL" >> "$IMDBURLLOG"
    tail -n "$KEEPURLS" "$IMDBURLLOG" > "$TMPFILE"
    cat "$TMPFILE" > "$IMDBURLLOG"
    echo -n "" > "$TMPFILE"
   fi
  fi
  DEBUGCOUNT=4
  if [ ! -z "$DEBUG" ]; then
   echo "$DEBUGCOUNT : DOTIMDB = '$DOTIMDB'"
   echo "$DEBUGCOUNT : USEBOT = '$USEBOT'"
  fi

# Snapshot the release dir's original date so it can be restored after
# writing the info files (FIXDIRTIME gated). Works chrooted and on host.
  RELDIR="$GLROOT$IMDBLKL"
  [ -d "$RELDIR" ] || RELDIR="$IMDBLKL"
  if [ ! -z "$FIXDIRTIME" ] && [ -d "$RELDIR" ]; then
   touch -r "$RELDIR" "$DIRDATE_CARRIER" >/dev/null 2>&1
  fi

# grab info from GraphQL API
#############################
  IMDB_ID=$(imdb_extract_id "$IMDBURL")
  OUTPUTOK=""

  if [ -z "$IMDB_ID" ]; then
    if [ ! -z "$DEBUG" ]; then
      echo "DEBUG: Could not extract IMDb ID from $IMDBURL"
    fi
  else
    TITLE_QUERY="query{title(id:\"${IMDB_ID}\"){titleText{text}originalTitleText{text}releaseYear{year}titleType{text}genres{genres{text}}ratingsSummary{aggregateRating voteCount}plot{plotText{plainText}}runtime{seconds}directors:credits(first:${DIRECTORNUM},filter:{categories:[\"director\"]}){edges{node{name{nameText{text}}}}}stars:credits(first:${CASTNUM},filter:{categories:[\"actor\",\"actress\"]}){edges{node{name{nameText{text}}}}}countriesOfOrigin{countries{id}}spokenLanguages{spokenLanguages{id}}akas(first:50){edges{node{text country{id}}}}taglines(first:1){edges{node{text}}}certificates(first:50){edges{node{rating country{id}}}}releaseDates(first:100){edges{node{day month year country{id}attributes{text}}}}productionBudget{budget{amount currency}}worldwide:lifetimeGross(boxOfficeArea:WORLDWIDE){total{amount currency}}openingWeekendGross(boxOfficeArea:DOMESTIC){gross{total{amount currency}}}metacritic{metascore{score reviewCount}}}}"
    API_RESPONSE=$(imdb_request "$TITLE_QUERY")

    if [ $? -eq 0 ] && [ -n "$API_RESPONSE" ]; then
      TITLE=$($JQ_BIN -r '.data.title.titleText.text // empty' <<< "$API_RESPONSE")
      ORIGTITLE=$($JQ_BIN -r '.data.title.originalTitleText.text // empty' <<< "$API_RESPONSE")
      TITLEYEAR=$($JQ_BIN -r '.data.title.releaseYear.year // empty' <<< "$API_RESPONSE")
      TITLETYPE=$($JQ_BIN -r '.data.title.titleType.text // empty' <<< "$API_RESPONSE")

      UNSUPPORTED_TYPE=""
      case "$TITLETYPE" in
        short|tvShort|tvSpecial|tvEpisode|videoGame)
          UNSUPPORTED_TYPE="YES"
          ;;
      esac

      if [ -n "$UNSUPPORTED_TYPE" ]; then
        if [ ! -z $DEBUG ]; then
          echo "DEBUG: Title type '$TITLETYPE' not fully supported for $IMDB_ID"
        fi
      elif [ -n "$TITLE" ] && [ -n "$TITLEYEAR" ]; then
        OUTPUTOK="OK"

        # Extract language from release name and look up localized AKA title
        LOCALETITLE=""
        if [ -z "$USEORIGTITLE" ]; then
          RELLANG=$(echo "$IMDBDIR" | tr '.\-_' '\n' | tr 'A-Z' 'a-z' | grep -xF -e chinese -e dutch -e english -e finnish -e french -e german -e greek -e hebrew -e hungarian -e italian -e japanese -e korean -e norwegian -e polish -e portuguese -e romanian -e russian -e spanish -e swedish -e turkish -e nl -e fr -e de -e it -e es -e en -e danish -e icelandic -e czech | head -n 1)
          if [ -n "$RELLANG" ] && [ -n "${LANG_TO_COUNTRY[$RELLANG]:-}" ]; then
            AKA_CC="${LANG_TO_COUNTRY[$RELLANG]}"
          else
            AKA_CC=""
          fi
          if [ ! -z "$AKA_CC" ]; then
            LOCALETITLE=$($JQ_BIN -r --arg cc "$AKA_CC" '(.data.title.akas.edges // []) | map(select(.node.country.id == $cc)) | .[0].node.text // empty' <<< "$API_RESPONSE")
            if [ -z "$LOCALETITLE" ] && [ ! -z $DEBUG ]; then
              echo "DEBUG: No AKA found for $IMDB_ID in country $AKA_CC"
            fi
          fi
        fi

        TITLENAME=$TITLE
        if [ ! -z "$LOCALETITLE" ]; then
          TITLENAME="$LOCALETITLE"
        elif [ ! -z "$USEORIGTITLE" ] && [ ! -z "$ORIGTITLE" ] && [ "$ORIGTITLE" != "null" ]; then
          TITLENAME="$ORIGTITLE"
        fi

        if [ "$ORIGTITLE" = "null" ]; then
          ORIGTITLE=""
        fi

        TITLE="$TITLENAME ($TITLEYEAR)"

        GENRECLEAN=$($JQ_BIN -r '(.data.title.genres.genres // []) | .[0:'"$GENRENUM"'] | map(.text) | join("/")' <<< "$API_RESPONSE")
        GENRE="Genre........: $GENRECLEAN"

        RATINGSCORE=$($JQ_BIN -r '.data.title.ratingsSummary.aggregateRating // empty' <<< "$API_RESPONSE")
        VOTECOUNT=$($JQ_BIN -r '.data.title.ratingsSummary.voteCount // empty' <<< "$API_RESPONSE")
        if [ -n "$VOTECOUNT" ]; then
          RATINGVOTES=$(printf "%'d" "$VOTECOUNT" 2>/dev/null || echo "$VOTECOUNT")
        else
          RATINGVOTES=""
        fi

        if [ -n "$RATINGSCORE" ] && [ -n "$RATINGVOTES" ]; then
          RATING="User Rating..: $RATINGSCORE ($RATINGVOTES)"
          RATINGCLEAN="$RATINGSCORE ($RATINGVOTES)"
          PLUS="##########"
          MINUS="----------"
          PNUM=$(echo "$RATINGSCORE" | cut -d '.' -f 1)
          MNUM=$((10 - PNUM))
          if [ $MNUM -eq 0 ]; then
            RATINGBAR="$PLUS"
          elif [ $MNUM -eq 10 ]; then
            RATINGBAR="$MINUS"
          else
            RATINGBAR="$(echo $PLUS | cut -c 1-$PNUM)$(echo $MINUS | cut -c 1-$MNUM)"
          fi
        else
          RATING="User Rating..: Awaiting votes"
          RATINGCLEAN="Awaiting votes"
          RATINGVOTES=""
          RATINGSCORE=""
          RATINGBAR=""
        fi

        COUNTRYCLEAN=$($JQ_BIN -r --argjson cmap "$COUNTRY_MAP" --arg n "$COUNTRYNUM" \
          '(.data.title.countriesOfOrigin.countries // []) | .[0:($n|tonumber)] | map(.id) | map($cmap[.] // .) | join("/")' <<< "$API_RESPONSE")
        COUNTRY="Country......: $COUNTRYCLEAN"

        LANGUAGECLEAN=$($JQ_BIN -r --argjson lmap "$LANGUAGE_MAP" --arg n "$LANGUAGENUM" \
          '(.data.title.spokenLanguages.spokenLanguages // []) | .[0:($n|tonumber)] | map(.id) | map($lmap[.] // .) | join("/")' <<< "$API_RESPONSE")
        LANGUAGE="Language.....: $LANGUAGECLEAN"

        PLOTCLEAN=$($JQ_BIN -r '.data.title.plot.plotText.plainText // empty' <<< "$API_RESPONSE" | sed "s/\"/$QUOTECHAR/g" | head -c "$PLOTWIDTH")
        PLOT="Plot: $PLOTCLEAN"

        runtime_sec=$($JQ_BIN -r '.data.title.runtime.seconds // empty' <<< "$API_RESPONSE")
        if [ -n "$runtime_sec" ] && [ "$runtime_sec" != "null" ]; then
          hours=$((runtime_sec / 3600))
          mins=$(((runtime_sec % 3600) / 60))
          if [ $hours -gt 0 ]; then
            RUNTIME="${hours}h ${mins}min"
          else
            RUNTIME="${mins}min"
          fi
        else
          RUNTIME=""
        fi
        RUNTIMECLEAN="$RUNTIME"

        DIRECTORCLEAN=$($JQ_BIN -r '(.data.title.directors.edges // []) | .[0:'"$DIRECTORNUM"'] | map(.node.name.nameText.text) | join("/")' <<< "$API_RESPONSE")
        DIRECTOR="$DIRECTORCLEAN"

        CASTCLEAN=$($JQ_BIN -r '(.data.title.stars.edges // []) | .[0:'"$CASTNUM"'] | map(.node.name.nameText.text) | join(", ")' <<< "$API_RESPONSE")
        CAST="$CASTCLEAN"
        CASTLEADNAME=$($JQ_BIN -r '(.data.title.stars.edges // [])[0].node.name.nameText.text // empty' <<< "$API_RESPONSE")
        CASTLEADCHAR=""

        TAGLINECLEAN=$($JQ_BIN -r '.data.title.taglines.edges[0].node.text // empty' <<< "$API_RESPONSE")
        TAGLINE="$TAGLINECLEAN"

        CERTCLEAN=""
        if [ ! -z "$USECERT" ]; then
          CERTCLEAN=$($JQ_BIN -r '(.data.title.certificates.edges // []) | map(select(.node.country.id == "'"$CERTCOUNTRY"'")) | .[0].node.rating // empty' <<< "$API_RESPONSE")
        fi
        CERT="$CERTCLEAN"

        PREMIERE=""
        LIMITED=""
        if [ ! -z "$USEPREMIERE" ]; then
          PREMIERE=$($JQ_BIN -r 'def pad2: tostring | if length == 1 then "0" + . else . end; def fmtdate: (.year|tostring) + (if .month then "-" + (.month|pad2) else "" end) + (if .day then "-" + (.day|pad2) else "" end); (.data.title.releaseDates.edges // []) | map(select(.node.country.id == "'"$PREMIERECOUNTRY"'" and ((.node.attributes // []) | map(.text) | any(test("premiere"; "i"))))) | .[0]?.node | if . == null then empty else (fmtdate + (if (.attributes // []) | length > 0 then " (" + ([.attributes[].text] | join(", ")) + ")" else "" end)) end' <<< "$API_RESPONSE" 2>/dev/null | head -1)
        fi
        if [ ! -z "$USELIMITED" ]; then
          LIMITED=$($JQ_BIN -r 'def pad2: tostring | if length == 1 then "0" + . else . end; def fmtdate: (.year|tostring) + (if .month then "-" + (.month|pad2) else "" end) + (if .day then "-" + (.day|pad2) else "" end); (.data.title.releaseDates.edges // []) | map(select(.node.country.id == "'"$PREMIERECOUNTRY"'" and ((.node.attributes // []) | map(.text) | any(test("limited"; "i"))))) | .[0]?.node | if . == null then empty else (fmtdate + (if (.attributes // []) | length > 0 then " (" + ([.attributes[].text] | join(", ")) + ")" else "" end)) end' <<< "$API_RESPONSE" 2>/dev/null | head -1)
        fi

        METASCORE=$($JQ_BIN -r '.data.title.metacritic.metascore.score // empty' <<< "$API_RESPONSE")
        METAREVIEWS=$($JQ_BIN -r '.data.title.metacritic.metascore.reviewCount // empty' <<< "$API_RESPONSE")
        METACLEAN="$METASCORE"

        COMMENTSHORT="User Reviews: N/A"
        COMMENTSHORTCLEAN="N/A"
        COMMENT=""
        COMMENTCLEAN=""

        ONELINE="$BOLD$TITLE$BOLD [$COUNTRYCLEAN]: $GENRECLEAN - $BOLD$RATINGCLEAN$BOLD - $IMDBURL"

        if [ ! -z "$USEBUSINESS" ]; then
          BUDGET=$($JQ_BIN -r '.data.title.productionBudget.budget.amount // empty' <<< "$API_RESPONSE")
          BUDGET_CUR=$($JQ_BIN -r '.data.title.productionBudget.budget.currency // "USD"' <<< "$API_RESPONSE")
          OPENING=$($JQ_BIN -r '.data.title.openingWeekendGross.gross.total.amount // empty' <<< "$API_RESPONSE")
          OPENING_CUR=$($JQ_BIN -r '.data.title.openingWeekendGross.gross.total.currency // "USD"' <<< "$API_RESPONSE")
          GROSS=$($JQ_BIN -r '.data.title.worldwide.total.amount // empty' <<< "$API_RESPONSE")
          GROSS_CUR=$($JQ_BIN -r '.data.title.worldwide.total.currency // "USD"' <<< "$API_RESPONSE")

          if [ -n "$OPENING" ]; then
            BUSINESSSHORT="$OPENING_CUR $(printf "%'d" "$OPENING" 2>/dev/null || echo "$OPENING")"
          fi
          if [ -n "$BUDGET" ]; then
            BUSINESS="Budget: $BUDGET_CUR $(printf "%'d" "$BUDGET" 2>/dev/null || echo "$BUDGET")"
          fi
          if [ -n "$GROSS" ]; then
            BUSINESS="$BUSINESS"$'\n'"Worldwide Gross: $GROSS_CUR $(printf "%'d" "$GROSS" 2>/dev/null || echo "$GROSS")"
          fi
        fi
      fi
    fi
  fi

  if [ -z "$OUTPUTOK" ]; then
    DOTIMDB=""
    USEBOT=""
    ERROR_MSG="Failed to fetch iMDB details. Please try again."
    if [ -n "$UNSUPPORTED_TYPE" ]; then
      ERROR_MSG="iMDB type '$TITLETYPE' not fully supported (limited data available)"
    fi
    if [ ! -z "$(echo "$IMDBLKL" | grep -e "/dev/null")" ]; then
     if [ -z "$LOGFORMAT" ]; then
        imdb_write_log "$ERROR_MSG"
       elif [ "$LOGFORMAT" = "MYOWN" ]; then
        imdb_write_log "$ERROR_MSG"
       else
        echo "$DATE $TRIGGER \"$IMDBLKL\" \"\" \"$ERROR_MSG\"" >> "$GLLOG"
       fi
    else
      rm -f "$GLROOT/$IMDBLKL/$INFOTEMPNAME" >/dev/null 2>&1
      rmdir "$GLROOT/$IMDBLKL/$INFOTEMPNAME" >/dev/null 2>&1
    fi
  else
    BUSINESS=""
    BUSINESSSHORT=""
    BUSINESSSCREENS=""
    ISLIMITED=""

    if [ ! -z "$USEBOM" ]; then
      BOMURL="https://www.boxofficemojo.com/title/${IMDB_ID}/"
      BOM_RESPONSE=$(curl "$CURLFLAGS" -s -A "$USERAGENT" --connect-timeout "$IMDBAPI_TIMEOUT" "$BOMURL" 2>/dev/null)
      if [ -n "$BOM_RESPONSE" ]; then
        BOMRELEASEGROUP=$(echo "$BOM_RESPONSE" | sed -n -E 's|.*<option value="(/releasegroup/gr[0-9]+/)">Original Release</option>.*|\1|p')
        if [ -n "$BOMRELEASEGROUP" ]; then
          BOMURLRELEASEGROUP="https://www.boxofficemojo.com${BOMRELEASEGROUP}"
          BOM_RELEASE=$(curl "$CURLFLAGS" -s -A "$USERAGENT" --connect-timeout "$IMDBAPI_TIMEOUT" "$BOMURLRELEASEGROUP" 2>/dev/null)
          BOMRELEASE=$(echo "$BOM_RELEASE" | sed -n -E 's|.*<a class="a-link-normal" href="(/release/rl[0-9]+/)[^\"]*">Domestic[^\n]*</a>.*|\1|p' | head -1)
          if [ -n "$BOMRELEASE" ]; then
            BOMURLRELEASE="https://www.boxofficemojo.com${BOMRELEASE}"
            BOM_DETAIL=$(curl "$CURLFLAGS" -s -A "$USERAGENT" --connect-timeout "$IMDBAPI_TIMEOUT" "$BOMURLRELEASE" 2>/dev/null)
            if [ ! -z "$USEWIDEST" ]; then
              BUSINESSSCREENS=$(echo "$BOM_DETAIL" | sed -n -E 's|.*<div[^>]*><span>Widest Release</span><span>([0-9,]+) theaters</span></div>.*|\1|p' | head -1 | tr -d ',')
            else
              BUSINESSSCREENS=$(echo "$BOM_DETAIL" | sed -n -E 's|.*<div[^>]*><span>Opening</span><span><span class="money">[0-9,$]+</span><br/>*([0-9,]+)$|\1|p' | head -1 | tr -d ',')
            fi
          fi
        fi
      fi

      if [ -n "$BUSINESSSCREENS" ] && [ -z "$ISLIMITED" ]; then
        if [ "$BUSINESSSCREENS" -lt 500 ] 2>/dev/null; then
          ISLIMITED=$LIMITEDYES
        else
          ISLIMITED=$LIMITEDNO
        fi
      fi
    fi
   if [ ! -z "$IMDBHEAD" ]; then
    BOTHEAD=$(echo "$BOTHEAD" | sed "s/RELEASENAME/$BOLD$IMDBDIR$BOLD/")
   fi
   if [ ! -z $DEBUG ]; then
    DEBUGCOUNT=5
    echo "$DEBUGCOUNT : DOTIMDB = '$DOTIMDB'"
    echo "$DEBUGCOUNT : USEBOT = '$USEBOT'"
   fi
   if [ ! -z "$DIRECTOR" ]; then
    DIRECTOR="Directed by..: $DIRECTOR"
   fi
   if [ ! -z $DEBUG ]; then
    DEBUGCOUNT=6
    echo "$DEBUGCOUNT : DOTIMDB = '$DOTIMDB'"
    echo "$DEBUGCOUNT : USEBOT = '$USEBOT'"  
   fi

   if [ ! -z "$USEBOT" ]; then

# Time to put stuff out so the bot can read it.
###############################################

    HEADTMP="Title........: $BOLD$TITLE$BOLD"
    if [ ! -z "$COUNTRY" ]; then
     HEADTMP="$HEADTMP / $COUNTRY"
    fi
    if [ ! -z "$LANGUAGE" ]; then
     HEADTMP="$HEADTMP / $BOLD$LANGUAGE$BOLD"
    fi
    HEAD=$(echo "$HEADTMP" | sed "s/Country......: //" | sed "s/Language.....: //" | tr -s ' ')
    if [ ! -z "$BOTHEAD" ]; then
     imdb_write_log "$BOTHEAD"
    fi
    if [ ! -z "$HEAD" ] && [ -z "$BOTONELINE" ]; then
     imdb_write_log "$HEAD"
    fi
    if [ -z "$BOTONELINE" ]; then
     imdb_write_log "IMDb Link....: $IMDBURL"
    fi
    if [ ! -z "$DIRECTOR" ] && [ -z "$BOTONELINE" ]; then
     imdb_write_log "$DIRECTOR"
    fi
    if [ ! -z "$GENRE" ] && [ -z "$BOTONELINE" ]; then
     imdb_write_log "$GENRE"
    fi
    if [ ! -z "$RATING" ] && [ -z "$BOTONELINE" ]; then
     imdb_write_log "$RATING"
    fi
    if [ ! -z "$SHOWMETACRITIC" ] && [ ! -z "$METASCORE" ] && [ -z "$BOTONELINE" ]; then
     imdb_write_log "Metacritic..: $METASCORE/100 ($METAREVIEWS reviews)"
    fi
    if [ ! -z "$SHOWSTAR" ] && [ -z "$BOTONELINE" ] && [ ! -z "$CASTLEADNAME" ]; then
     imdb_write_log "Starring.....: $CASTLEADNAME as $CASTLEADCHAR"
    fi
    if [ ! -z "$RUNTIME" ] && [ -z "$BOTONELINE" ]; then
     imdb_write_log "$RUNTIME"
    fi
    if [ ! -z "$BUSINESSSHORT" ] && [ -z "$BOTONELINE" ]; then
     imdb_write_log "Opening Stats: $BUSINESSSHORT" --usd
    fi
    if [ ! -z "$PREMIERE" ] && [ -z "$BOTONELINE" ]; then
     imdb_write_log "Premiere Date: $PREMIERE"
    fi
    if [ ! -z "$LIMITED" ] && [ -z "$BOTONELINE" ]; then
     imdb_write_log "Limited Date.: $LIMITED"
    fi
    if [ ! -z "$TAGLINE" ] && [ ! -z "$PLOT" ] && [ -z "$BOTONELINE" ]; then
     if [ "$TAGPLOT" = "TAG" ] || [ -z "$TAGPLOT" ] ; then
      imdb_write_log "$TAGLINE"
     fi
     if [ "$TAGPLOT" = "PLOT" ] || [ -z "$TAGPLOT" ]; then
      imdb_write_log "$PLOT"
     fi
    elif [ ! -z "$TAGLINE" ] && [ ! "$TAGPLOT" = "NONE" ] && [ -z "$BOTONELINE" ]; then
     imdb_write_log "$TAGLINE"
    elif [ ! -z "$PLOT" ] && [ ! "$TAGPLOT" = "NONE" ] && [ -z "$BOTONELINE" ]; then
     imdb_write_log "$PLOT"
    fi
    if [ ! -z "$SHOWCOMMENTSHORT" ] && [ ! "$COMMENTSHORT" = "User Reviews:" ] && [ -z "$BOTONELINE" ]; then
     imdb_write_log "$COMMENTSHORT"
    fi
    if  [ ! -z "$BOTONELINE" ]; then
     if [ -z "$LOGFORMAT" ]; then
      imdb_write_log "$ONELINE"
     elif [ "$LOGFORMAT" = "MYOWN" ]; then
#      NEWLINE="|"
      MYOWNPAIRS="%imdbdirname|IMDBDIR %imdburl|IMDBURL %imdbtitle|TITLE %imdbgenre|GENRECLEAN %imdbrating|RATINGCLEAN %imdbcountry|COUNTRYCLEAN %imdblanguage|LANGUAGECLEAN %imdbcertification|CERTCLEAN %imdbruntime|RUNTIMECLEAN %imdbdirector|DIRECTORCLEAN %imdbbusinessdata|BUSINESSSHORT %imdbpremiereinfo|PREMIERE %imdblimitedinfo|LIMITED %imdbvotes|RATINGVOTES %imdbscore|RATINGSCORE %imdbname|TITLENAME %imdbyear|TITLEYEAR %imdbnumscreens|BUSINESSSCREENS %imdbislimited|ISLIMITED %imdbcastleadname|CASTLEADNAME %imdbcastleadchar|CASTLEADCHAR %imdbtagline|TAGLINECLEAN %imdbplot|PLOTCLEAN %imdbbar|RATINGBAR %imdbcasting|CASTCLEAN %imdbcommentshort|COMMENTSHORTCLEAN %imdbmetacritic|METACLEAN %newline|NEWLINE %bold|BOLD"
      MYOWNFORMAT1="$MYOWNFORMAT"
      for OWNPAIR in $MYOWNPAIRS; do
       MYOWNSTRING="$(echo "$OWNPAIR" | cut -d '|' -f 1)"
       MYOWNVAR="$(echo "$OWNPAIR" | cut -d '|' -f 2)"
       if [ ! -z "${!MYOWNVAR}" ]; then
        MYTEMPVAR="$(echo "${!MYOWNVAR}" | tr '\&' '\`')"
        MYOWNFORMAT1="$(echo "${MYOWNFORMAT1}" | sed "s^$MYOWNSTRING^$MYTEMPVAR^g;s/\n/$NEWLINE/g" | tr '\`' '\&')"
       else
        MYOWNFORMAT1="$(echo "${MYOWNFORMAT1}" | sed "s^$MYOWNSTRING^$MYOWNEMPTY^g")"
       fi
      done
      if [ "$IMDBSPLITLINES" = "YES" ]; then
       LINE1="${MYOWNFORMAT1%%\\n*}"
       LINE2="${MYOWNFORMAT1#*\\n}"
        if [ "$LINE1" != "$LINE2" ]; then
         imdb_write_log "$LINE1" --usd
         CURTRIG="$TRIGGER"
         [ -n "$IMDBSPLITTRIG" ] && CURTRIG="$IMDBSPLITTRIG"
         imdb_write_log "$LINE2" --usd "$CURTRIG"
       else
        imdb_write_log "${MYOWNFORMAT1}" --usd
       fi
      else
       imdb_write_log "${MYOWNFORMAT1}" --usd
      fi
     else
      imdb_write_log "$IMDBDIR\" \"$IMDBURL\" \"$TITLE\" \"$GENRECLEAN\" \"$RATINGCLEAN\" \"$COUNTRYCLEAN\" \"$LANGUAGECLEAN\" \"$CERTCLEAN\" \"$RUNTIMECLEAN\" \"$DIRECTORCLEAN\" \"$BUSINESSSHORT\" \"$PREMIERE\" \"$LIMITED\" \"$RATINGVOTES\" \"$RATINGSCORE\" \"$TITLENAME\" \"$TITLEYEAR\" \"$BUSINESSSCREENS\" \"$ISLIMITED\" \"$CASTLEADNAME\" \"$CASTLEADCHAR\" \"$TAGLINECLEAN\" \"$PLOTCLEAN\" \"$RATINGBAR\" \"$CASTCLEAN\" \"$COMMENTSHORTCLEAN\" \"$METACLEAN" --usd
     fi
    fi
   fi
   if [ ! -z "$DOTIMDB" ]; then

# Echo stuff to the .imdb file
##############################

    printf "%b\n" "$IMDBHEAD" > "$IMDBLNK"
    OWNER=$(ls -1nl "$GLROOT$IMDBLKL" | tail -n 1 | { read junk junk owner group junk; echo "$owner:$group"; };)
    echo "Title........: $TITLE" | fold -s -w "$IMDBWIDTH" | head -n 1 >> "$IMDBLNK"
    echo "-" >> "$IMDBLNK"
    echo "IMDb Link....: $IMDBURL" | head -n 1 >> "$IMDBLNK"
    if [ ! -z "$DIRECTOR" ]; then
     echo "$DIRECTOR" | fold -s -w "$IMDBWIDTH" | head -n 1 >> "$IMDBLNK"
    fi
    if [ ! -z "$GENRE" ]; then
     echo "$GENRE" | fold -s -w "$IMDBWIDTH" | head -n 1 >> "$IMDBLNK"
    fi
    if [ ! -z "$RATING" ]; then
     echo "$RATING" | fold -s -w "$IMDBWIDTH" | head -n 1 >> "$IMDBLNK"
    fi
    if [ ! -z "$SHOWMETACRITIC" ] && [ ! -z "$METASCORE" ]; then
     echo "Metacritic..: $METASCORE/100 ($METAREVIEWS reviews)" | fold -s -w "$IMDBWIDTH" | head -n 1 >> "$IMDBLNK"
    fi
    if [ ! -z "$TAGLINE" ]; then
     echo "$TAGLINE" | fold -s -w "$IMDBWIDTH" >> "$IMDBLNK"
    fi
    echo "-" >> "$IMDBLNK"
    if [ ! -z "$COUNTRY" ]; then
     echo "$COUNTRY" | fold -s -w "$IMDBWIDTH" | head -n 1 >> "$IMDBLNK"
    fi
    if [ ! -z "$LANGUAGE" ]; then
     echo "$LANGUAGE" | fold -s -w "$IMDBWIDTH" | head -n 1 >> "$IMDBLNK"
    fi
    if [ ! -z "$CERT" ]; then
     echo "Certification:[[SPACE]]$CERT" | fold -s -w "$IMDBWIDTH" | head -n 1 | sed 's/\[\[SPACE\]\]/ /' >> "$IMDBLNK"
    fi
    if [ ! -z "$PREMIERE" ]; then
     echo "Premiere Date: $PREMIERE" | fold -s -w "$IMDBWIDTH" | head -n 1 >> "$IMDBLNK"
    fi
    if [ ! -z "$LIMITED" ]; then
     echo "Limited Date.: $LIMITED" | fold -s -w "$IMDBWIDTH" | head -n 1 >> "$IMDBLNK"
    fi
    if [ ! -z "$RUNTIME" ]; then
     echo "Runtime......: $RUNTIME" | fold -s -w "$IMDBWIDTH" | head -n 1 >> "$IMDBLNK"
    fi
    if [ ! -z "$CAST" ]; then
     echo "-" >> "$IMDBLNK"
     echo "Credited Cast:" >> "$IMDBLNK"
     echo "$CAST" | fold -s -w "$IMDBWIDTH" >> "$IMDBLNK"
    fi
    if [ ! -z "$BUSINESS" ]; then
     echo "-" >> "$IMDBLNK"
     echo "Business Data on Opening Weekend:" >> "$IMDBLNK"
     echo "$BUSINESS" | fold -s -w "$IMDBWIDTH" >> "$IMDBLNK"
    fi
    if [ ! -z "$PLOT" ]; then
     echo "-" >> "$IMDBLNK"
     #echo "$PLOT" | fold -s -w "$IMDBWIDTH" >> "$IMDBLNK"
     echo "$PLOT" | sed s/"$NEWLINE"//g | fold -s -w "$IMDBWIDTH" >> "$IMDBLNK"
    fi
    if [ ! -z "$SHOWCOMMENT" ] && [ ! -z "$COMMENT" ]; then
     echo "---" >> "$IMDBLNK"
     echo "User Review:" >> "$IMDBLNK"
     echo "$COMMENT" | sed "s/^\ *//g" | sed "s/\ *$//g" | tr -s ' ' | fold -s -w "$IMDBWIDTH" >> "$IMDBLNK"
    fi
    printf "%b\n" "$IMDBTAIL" >> "$IMDBLNK"
   fi

   if [ ! -z "$INFOTEMPNAME" ] && [ -e "$GLROOT$IMDBLKL/$INFOTEMPNAME" ]; then

# make a file/dir with imdb info in the name 

    INFOGENRES=$(echo "$GENRECLEAN" | tr '/ ' '\n' |  sed -e /^$/d | wc -l)
    if [ ! "$INFOGENRES" -gt "$INFOGENREMAX" ]; then
     let INFOGENREMAXED=INFOGENRES
    else
     let INFOGENREMAXED=INFOGENREMAX
    fi
    if [ ! "$INFOGENRES" -lt 1 ]; then
     GENREFILE="$(echo "$GENRECLEAN" | tr '/ ' '\n' |  sed -e /^$/d | head -n "$INFOGENREMAX" | tr '\n' ' ' | sed "s/ /$INFOGENRESEP/g" | cut -d "$INFOGENRESEP" -f 1-"$INFOGENREMAXED")"
    else
     GENREFILE="Unclassified"
    fi
    VOTESFILE="$(echo "$RATINGVOTES" | tr ',' '.')"
    [[ -z "$VOTESFILE" ]] && VOTESFILE="NA"
    SCOREFILE="$RATINGSCORE"
    [[ -z "$SCOREFILE" ]] && SCOREFILE="NA"
    LIMITEDFILE="$ISLIMITED"
    [[ -z "$LIMITEDFILE" ]] && LIMITEDFILE="unknown"
    NUMSCREENS="$(echo "$BUSINESSSCREENS" | tr ',' '.')"
    [[ -z "$NUMSCREENS" ]] && NUMSCREENS="unknown"
    RUNTIMEFILE="$RUNTIMECLEAN"
    [[ -z "$RUNTIMEFILE" ]] && RUNTIMEFILE="unknown"
    INFOFILENAMEOLD="$(echo "$INFOFILENAME" | tr -c "$INFOVALID" "$INFOCHARTO" | sed "s%VOTES%*%g" | sed "s%SCORE%*%g" | sed "s%GENRE%*%g" | sed "s%RUNTIME%*%g" | sed "s%YEAR%*%g" | sed "s%ISLIMITED%*%g" | sed "s%SCREENS%*%g")"
    INFOFILENAMEOLDA="$(echo "$INFOFILENAMEOLD" | sed "s%*%.*%g")"
    INFOFILENAMEOLDB="$(echo "$INFOFILENAMEOLDA" | tr '\]\[' '.')"
    INFOFILENAMEPRINT="$(echo "$INFOFILENAME" | sed "s%VOTES%$VOTESFILE%g" | sed "s%SCORE%$SCOREFILE%g" | sed "s%GENRE%$GENREFILE%g" | sed "s%RUNTIME%$RUNTIMEFILE%g" | sed "s%YEAR%$TITLEYEAR%g" | sed "s%ISLIMITED%$LIMITEDFILE%g" | sed "s%SCREENS%$NUMSCREENS%g")"
    INFOFILENAMEPRINT="$(echo "$INFOFILENAMEPRINT" | tr -c "$INFOVALID" "$INFOCHARTO")"
    if [ ! -z "$(ls -1 "$GLROOT$IMDBLKL" | grep -e "$INFOFILENAMEOLDB")" ]; then
     for OLDINFOFILE in $(ls -1  "$GLROOT$IMDBLKL" | grep -e "$INFOFILENAMEOLDB" | tr ' ' '^'); do
      OLDINFOFILE="$(echo "$OLDINFOFILE" | tr '^' ' ')"
      rm -f "$GLROOT$IMDBLKL/$OLDINFOFILE" >/dev/null 2>&1
      rmdir "$GLROOT$IMDBLKL/$OLDINFOFILE" >/dev/null 2>&1
     done
    fi
    mv "$GLROOT$IMDBLKL/$INFOTEMPNAME" "$GLROOT$IMDBLKL/$INFOFILENAMEPRINT"
   fi

# create a thumbnail?

   if [ "$DOWNLOADTHUMB" = "YES" ]; then
    FILENAME=$(ls -1Ftr "$GLROOT$IMDBLKL" | grep -v "/" | grep -v "@" | grep -e "[.][nN][fF][oO]" | head -n 1)
    TMBNAME=$(echo "$FILENAME" | sed "s/\.nfo/.jpg/")
    if [ ! -z "$USEWGET" ]; then
     wget "$WGETFLAGS" -U "$USERAGENT" -O "$TMPFILE" --timeout=30 "$GLROOT$IMDBLKL/$TMBNAME" >/dev/null 2>&1
    elif [ ! -z "$USECURL" ]; then
     curl "$CURLFLAGS" -A "$USERAGENT" -o "$TMPFILE" --connect-timeout 30 "$GLROOT$IMDBLKL/$TMBNAME" >/dev/null 2>&1
    fi
   fi

# Should we run any external scripts?

   if [ ! -z "$EXTERNALSCRIPTNAME" ]; then
    for EXTERNALNAME in $EXTERNALSCRIPTNAME; do
     if [ "$DEBUG" = "4" ] && [ ! -z "$(head -n 1 "$EXTERNALNAME" | grep -e "/bin/bash")" ]; then
      bash -x -v "$EXTERNALNAME" "\"$DATE\" \"$IMDBLNK\" \"$IMDBLKL\" \"$IMDBDIR\" \"$IMDBURL\" \"$TITLE\" \"$GENRECLEAN\" \"$RATINGCLEAN\" \"$COUNTRYCLEAN\" \"$LANGUAGECLEAN\" \"$CERTCLEAN\" \"$RUNTIMECLEAN\" \"$DIRECTORCLEAN\" \"$BUSINESSSHORT\" \"$PREMIERE\" \"$LIMITED\" \"$RATINGVOTES\" \"$RATINGSCORE\" \"$TITLENAME\" \"$TITLEYEAR\" \"$BUSINESSSCREENS\" \"$ISLIMITED\" \"$CASTLEADNAME\" \"$CASTLEADCHAR\" \"$TAGLINECLEAN\" \"$PLOTCLEAN\" \"$RATINGBAR\" \"$CASTCLEAN\" \"$COMMENTSHORTCLEAN\" \"$COMMENTCLEAN\" \"$METACLEAN\""
     else
      "$EXTERNALNAME" "\"$DATE\" \"$IMDBLNK\" \"$IMDBLKL\" \"$IMDBDIR\" \"$IMDBURL\" \"$TITLE\" \"$GENRECLEAN\" \"$RATINGCLEAN\" \"$COUNTRYCLEAN\" \"$LANGUAGECLEAN\" \"$CERTCLEAN\" \"$RUNTIMECLEAN\" \"$DIRECTORCLEAN\" \"$BUSINESSSHORT\" \"$PREMIERE\" \"$LIMITED\" \"$RATINGVOTES\" \"$RATINGSCORE\" \"$TITLENAME\" \"$TITLEYEAR\" \"$BUSINESSSCREENS\" \"$ISLIMITED\" \"$CASTLEADNAME\" \"$CASTLEADCHAR\" \"$TAGLINECLEAN\" \"$PLOTCLEAN\" \"$RATINGBAR\" \"$CASTCLEAN\" \"$COMMENTSHORTCLEAN\" \"$COMMENTCLEAN\" \"$METACLEAN\""
     fi
     done
    fi
   fi

# restore the releasedir's original date.
#########################################
   RELDIR="$GLROOT$IMDBLKL"
   [ -d "$RELDIR" ] || RELDIR="$IMDBLKL"
   if [ ! -z "$FIXDIRTIME" ] && [ -f "$DIRDATE_CARRIER" ] && [ -d "$RELDIR" ]; then
    touch -r "$DIRDATE_CARRIER" "$RELDIR" >/dev/null 2>&1
    rm -f "$DIRDATE_CARRIER" >/dev/null 2>&1
   fi

# clean up and make ready for next run.
#######################################

  grep -F -v "$IMDBLINE" "$IMDBLOG" > "$TMPFILE"
  cat "$TMPFILE" > "$IMDBLOG"
  > "$TMPFILE"
 done
 > "$TMPRESCANFILE"
 > "$IMDBPID"
fi
exit 0
