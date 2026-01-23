#!/bin/bash

# PSXC IMDB INFO #
##################

# Just edit the 2 lines below, then continue on the "real" config file.

# your glftpd root path.
GLROOT=/glftpd

# path to the config file when chrooted by glftpd.
CONFFILE=/etc/psxc-imdb.conf

## End of config ##
###################

# version number. do not change.
VERSION="v3.0-api"

######################################################################################################

RECVDARGS="$1"
# check if configfile exists
############################

if [ -r $GLROOT$CONFFILE ]; then
 . $GLROOT$CONFFILE
 if [ $? -ne 0 ]; then
  echo "Unable to open config file ($GLROOT$CONFFILE). Forced to exit."
  exit 0
 fi
elif [ -r $CONFFILE ]; then
 . $CONFFILE
 if [ $? -ne 0 ]; then
  echo "Unable to open config file ($CONFFILE). Forced to exit."
  exit 0
 fi
else
 echo "Config file not found. Forced to exit."
 exit 0
fi

# Start debugging
if [ "$DEBUG" = "ON" ] || [ "$DEBUG" = "2" ]; then
 set -x
elif [ "$DEBUG" = "3" ]; then
 set -x -v
elif [ "$DEBUG" = "4" ]; then
 set -x -v
fi

# Let's hack glftpd
if [ -z "$RECVDARGS" ] && [ ! -z "$GLFIX" ]; then
 RECVDARGS=$(ls -1Ft | grep -a -v "/" | grep -a -v "@" | head -n 1 | grep -a -e "[.][nN][fF][oO]$")
fi

# Remove locale settings which might cause problems
export LC_ALL=""
export LANG=""

if [ -z "$USERAGENT" ]; then
  USERAGENT="psxc-imdb/3.0"
fi

if [ -z "$IMDBAPI_BASE" ]; then
  IMDBAPI_BASE="https://api.imdbapi.dev"
fi
if [ -z "$IMDBAPI_TIMEOUT" ]; then
  IMDBAPI_TIMEOUT=30
fi
if [ -z "$API_RETRY_COUNT" ]; then
  API_RETRY_COUNT=3
fi
if [ -z "$API_RETRY_DELAY" ]; then
  API_RETRY_DELAY=2
fi
if [ -z "$JQ_BIN" ]; then
  JQ_BIN="/bin/jq"
fi
if [ -z "$CERTCOUNTRY" ]; then
  CERTCOUNTRY="US"
fi
if [ -z "$PREMIERECOUNTRY" ]; then
  PREMIERECOUNTRY="US"
fi

api_request() {
  local endpoint="$1"
  local retries=0
  local response=""

  while [ $retries -lt $API_RETRY_COUNT ]; do
    response=$(curl $CURLFLAGS -s -A "$USERAGENT" \
      --connect-timeout $IMDBAPI_TIMEOUT \
      "${IMDBAPI_BASE}${endpoint}" 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$response" ]; then
      if echo "$response" | $JQ_BIN -e . >/dev/null 2>&1; then
        echo "$response"
        return 0
      fi
    fi
    retries=$((retries + 1))
    sleep $API_RETRY_DELAY
  done
  return 1
}

extract_imdb_id() {
  local url="$1"
  echo "$url" | grep -oP 'tt[0-9]+' | head -1
}

if [ ! -z "$RECVDARGS" ]; then

# This is what is run under zs-c, chrooted.
###########################################

# PATH=$PATHCHROOTED
# IMDBLOG=$IMDBLOGCHROOTED
 FILENAME="$RECVDARGS"
   if [ ! -z "$GLROOT" ]; then
    MYTMPFILE=$(echo "$TMPRESCANFILE" | sed "s%$GLROOT%%")
   else
    MYTMPFILE=$TMPRESCANFILE
   fi
   PSXCFLAG=$(head -n 1 $MYTMPFILE | tr -cd '0-9')
   if [ ! -z "$PSXCFLAG" ]; then
    if [ $PSXCFLAG -ge 4 ]; then
     let PSXCFLAG=PSXCFLAG-4
    fi
    if [ $PSXCFLAG -ge 2 ]; then
     DOTIMDB=""
     INFOTEMPNAME=""
     DOTDATE=""
     DOTURL=""
    fi
   fi
   if [ ! -z "$DOTDATE" ]; then
    DOTDATEINFO="$(grep -a [Dd][Aa][Tt][Ee] $FILENAME | tr -c '/a-zA-Z0-9:. -/\n' ' ' | tr -s ' ')"
    if [ ! -z "$DOTDATEINFO" ]; then
     echo "$DOTDATEINFO" > $DOTDATE
     chmod 666 $DOTDATE
    fi
   fi

# Should we even begin searching for an url?
   SEARCHFORURLS=0
   if [ -z "$SCANDIRS" ]; then
    SEARCHFORURLS=1
   fi
   for SCANDIR in $SCANDIRS; do
    if [ ! -z "$(pwd | grep -a "$SCANDIR")" ]; then
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
   IMDBURLS="$(grep -a [Ii][Mm][Dd][Bb] $FILENAME | tr ' \|' '\n' | sed -n /[hH][tT][tT][pP][sS]*:[/][/].*[.][iI][mM][dD][bB][.].*.[0-9]/p | head -n 1 | tr -c -d '[:alnum:]\:./?')"
   if [ ! -z "$(echo $IMDBURLS | grep -a "imdb\.")" ]; then
#    IMDBURL="https://www.imdb.com/title/tt""$(echo $IMDBURLS | sed "s/=/-/g" | sed "s/imdb./=/" | cut -d "=" -f 2 | cut -d "/" -f 2,3 | tr -c -d '[:digit:]')"
    IMDBURL="https://www.imdb.com/title/tt""$(echo $IMDBURLS | sed "s/=/-/g" | sed "s/imdb./=/" | cut -d "=" -f 2 |  grep -a -o "[0-9]*" | head -n 1)"
    if [ -z $(echo $IMDBURL | tr -cd '0-9') ]; then
     IMDBURL=""
    fi
   fi

# Level 1 search
   if [ -z "$IMDBURL" ] && [ $RELAXEDURLS -ge 1 ]; then
    IMDBURLS="$(grep -a [Ii][Mm][Dd][Bb] $FILENAME | tr ' \|' '\n' | sed -n /[hH][tT][tT][pP][sS]*:[/][/].*[iI][mM][dD][bB][.].*.[0-9]/p | head -n 1 | tr -c -d '[:alnum:]\:./?')"
    if [ ! -z "$(echo $IMDBURLS | grep -a "imdb\.")" ]; then
     IMDBURL="https://www.imdb.com/title/tt""$(echo $IMDBURLS | sed "s/=/-/g" | sed "s/imdb./=/" | cut -d "=" -f 2 | cut -d "/" -f 2,3 | tr -c -d '[:digit:]')"
     if [ -z $(echo $IMDBURL | tr -cd '0-9') ]; then
      IMDBURL=""
     fi
    fi
   fi

# Level 2 search
   if [ -z "$IMDBURL" ] && [ $RELAXEDURLS -ge 2 ]; then
    IMDBURLS="$(grep -a [Ii][Mm][Dd][Bb] $FILENAME | tr ' \|' '\n' | sed -n /.*[iI][mM][dD][bB][.].*.[0-9]/p | head -n 1 | tr -c -d '[:alnum:]\:./?')"
    if [ ! -z "$(echo $IMDBURLS | grep -a "imdb\.")" ]; then
     IMDBURL="https://www.imdb.com/title/tt""$(echo $IMDBURLS | sed "s/=/-/g" | sed "s/imdb./=/" | cut -d "=" -f 2 | cut -d "/" -f 2,3 | tr -c -d '[:digit:]')"
     if [ -z $(echo $IMDBURL | tr -cd '0-9') ]; then
      IMDBURL=""
     fi
    fi
   fi

# Level 3 search
   if [ -z "$IMDBURL" ] && [ $RELAXEDURLS -ge 3 ]; then
    for IMDBURLS in $(grep -a [Ii][Mm][Dd][Bb] $FILENAME | tr -c '[:digit:]' '\n' | grep -a -v "^$"); do
     if [ ! -z $(echo $IMDBURLS | tr -cd '0-9') ]; then
      if [ $(echo $IMDBURLS | tr -cd '0-9' | wc -c) -eq 8 ] || [ $(echo $IMDBURLS | tr -cd '0-9' | wc -c) -eq 7 ]; then
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
   if [ -z "$IMDBURL" ] && [ $RELAXEDURLS -ge 4 ]; then
    for IMDBURLS in $(cat $FILENAME | tr -c '[:digit:]' '\n' | grep -a -v "^$"); do
     if [ $(echo $IMDBURLS | wc -c) -eq 8 ] || [ $(echo $IMDBURLS | wc -c) -eq 7 ]; then
      IMDBURL="$IMDBURLS"
      break
     fi
    done
    if [ ! -z "$IMDBURL" ]; then
     IMDBURL="https://www.imdb.com/title/tt""$IMDBURL"
    fi
   fi

# export what we've found
   if [ ! -z "$IMDBURL" ]; then
    echo "$IMDBURL""|""$PWD" >> $IMDBLOGCHROOTED
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
   touch -acmr "$FILENAME" $(pwd) >/dev/null 2>&1

#else
fi
if [ ! -z "$RUNCONTINOUS" ] || [ -z "$RECVDARGS" ]; then
# run major part.

 if [ "$(basename "$0")" = "$PRENAME" ]; then

# This is what is done with pre's
#################################
  PATH=$GLPATHPRE

  a="$(tail -n 5 $GLPRELOG | grep -a "$PRETRIGGER" | tail -n 1)"
  DIRNAME=""
  for WORD in $WORDS; do
   count=0
   combine=0
   if [ -z "$a" ]; then
    exit 0
   fi
   if [ ! -z "$PRETRIGGER" ]; then
    let WORD=WORD+1
   fi
   for b in $a; do
    if [ -z $(echo $b | grep -a "$PRETRIGGER") ] && [ $count -gt 0 ] || [ -z "$PRETRIGGER" ]; then
     if [ $combine -eq 1 ]; then
      c=$c$b
     else
      c=$b
     fi
     if [ ! -z $(echo "$c" | grep -a "^\"") ]; then
      combine=1
     else
      c=$b
      let count=count+1
     fi
     if [ ! -z $(echo "$c" | grep -a "\"$") ]; then
      combine=0
      let count=count+1
     fi
     if [ $count -eq $WORD ]; then
      break
     fi
    else
     if [ "$b" = "$PRETRIGGER" ]; then
      count=1
     fi
    fi
   done
   DIRNAME="$DIRNAME""$c"
  done
  DIRNAME=$(echo $DIRNAME | sed "s|\"\"|$SEPARATOR|g" | sed "s|\"||g")
  if [ -d $GLROOT$DIRNAME ]; then
   FILENAME=$(ls -1 $GLROOT$DIRNAME | grep -a "\.[Nn][Ff][Oo]$" | head -n 1)
   IMDBURL="$(grep -a [Ii][Mm][Dd][Bb] $GLROOT$DIRNAME/$FILENAME | tr ' ' '\n' | sed -n /[hH][tT][tT][pP][sS]*:[/][/].*[.][iI][mM][dD][bB].*.[0-9]/p | head -n 1 | tr -c -d '[:alnum:]\:./?')"
   if [ ! -z "$(echo $IMDBURL | grep -a "\.imdb\.")" ]; then
    IMDBURL="https://www.imdb.com/title/tt""$(echo $IMDBURL | sed "s/=/-/g" | sed "s/.imdb./=/" | cut -d "=" -f 2 | cut -d "/" -f 2,3 | tr -c -d '[:digit:]')"
   fi
   if [ ! -z "$IMDBURL" ]; then
    a="$(tail -n 5 $GLLOG | grep -a "$TRIGGER" | grep -a "$DIRNAME" | tail -n 1)"
    if [ -z "$a" ]; then
     SEARCHFORURLS=0
     if [ -z "$SCANDIRS" ]; then
      SEARCHFORURLS=1
     fi
     for SCANDIR in $SCANDIRS; do
      if [ ! -z "$(echo "$DIRNAME" | grep -a "$SCANDIR")" ]; then
       SEARCHFORURLS=1
       break
      fi
     done
     if [ ! $SEARCHFORURLS -eq 0 ]; then
      echo "$IMDBURL""|""$DIRNAME" >> $IMDBLOG
     fi
    fi
   fi
  fi
  if [ -z "$RUNCONTINOUS" ]; then
   exit 0
  fi
 fi

 if [ ! -e $IMDBLOG ]; then

# Check to see if it's a first-run
##################################

  echo "Please read the docs before trying to run this script."
  exit 0
 fi

# The main part.
################

 if [ -z "$(cat $IMDBLOG)" ]; then

# No new imdb-info. let's quit.
###############################
  exit 0
 fi

# Make sure this script isn't already running.
##############################################
 sleep 0.$RANDOM
 IMDBPIDCONTENT="$(head -n2 $IMDBPID | tail -n1)"
 [[ ! -z "$IMDBPIDCONTENT" ]] &&
   [[ -1 -eq "$IMDBPIDCONTENT" || ! -z $(ps ax | awk '{print $1}' | grep -a -e "^$IMDBPIDCONTENT$") ]] &&
     exit 0
 echo $$ > $IMDBPID

# Seems like something was put into the log. Let's check it.
############################################################
 IMDBFLAGS=$(head -n 1 $TMPRESCANFILE | tr -cd '0-9')
 if [ ! -z "$IMDBFLAGS" ]; then
  if [ $IMDBFLAGS -ge 4 ]; then
   EXTERNALSCRIPTNAME=""
   let IMDBFLAGS=IMDBFLAGS-4
  fi
  if [ $IMDBFLAGS -ge 2 ]; then
   DOTIMDB=""
   INFOTEMPNAME=""
   let IMDBFLAGS=IMDBFLAGS-2
  fi
  if [ $IMDBFLAGS -ge 1 ]; then
   USEBOT=""
  fi
 fi

 if [ -z "$LANGUAGENUM" ] || [ $LANGUAGENUM -eq 0 ]; then
  LANGUAGENUM=99
 fi
 if [ -z "$COUNTRYNUM" ] || [ $COUNTRYNUM -eq 0 ]; then
  COUNTRYNUM=99
 fi
 if [ -z "$CERTIFICATIONNUM" ] || [ $CERTIFICATIONNUM -eq 0 ]; then
  CERTIFICATIONNUM=99
 fi
 if [ -z "$CASTNUM" ] || [ $CASTNUM -eq 0 ]; then
  CASTNUM=99
 fi
 if [ -z "$GENRENUM" ] || [ $GENRENUM -eq 0 ]; then
  GENRENUM=99
 fi
 if [ -z "$RUNTIMENUM" ] || [ $RUNTIMENUM -eq 0 ]; then
  RUNTIMENUM=99
 fi
 if [ -z "$DIRECTORNUM" ] || [ $DIRECTORNUM -eq 0 ]; then
  DIRECTORNUM=99
 fi

 while [ ! -z "$(cat $IMDBLOG)" ]; do
  IMDBLINE="$(grep -a -e "/" "$IMDBLOG" | head -n 1)"
  grep -a -F -v "$IMDBLINE" "$IMDBLOG" > $TMPFILE
  cat $TMPFILE > $IMDBLOG
  ISLIMITED=""
  BUSINESS=""
  BUSINESSSHORT=""
  PREMIERE=""
  LIMITED=""
  EXEMPTED=""
  IMDBURL="$(echo $IMDBLINE | cut -d "|" -f 1)"
  IMDBLNK="$(echo $IMDBLINE | cut -d "|" -f 2)"
  IMDBDST="$(echo $IMDBLINE | cut -d "|" -f 3)"
  DEBUGCOUNT=1
  if [ ! -z $DEBUG ]; then
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
   if [ ! -z "$PSXCFINDLOG" ] && [ -w $PSXCFINDLOG ]; then
    GLLOG=$PSXCFINDLOG
   fi
  else
   DOTIMDB=""
   USEBOT=""
   EXTERNALSCRIPTNAME=""
   INFOTEMPNAME=""
  fi
  DEBUGCOUNT=2
  if [ ! -z $DEBUG ]; then
   echo "$DEBUGCOUNT : DOTIMDB = '$DOTIMDB'"
   echo "$DEBUGCOUNT : USEBOT = '$USEBOT'"  
  fi
  for EXEMPT in $BOTEXEMPT; do
   if [ ! -z $(echo "$IMDBLKL" | grep -a "$EXEMPT") ]; then
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
  if [ ! -z $DEBUG ]; then
   echo "$DEBUGCOUNT : DOTIMDB = '$DOTIMDB'"
   echo "$DEBUGCOUNT : USEBOT = '$USEBOT'"  
  fi
  if [ ! -z $(grep -a "$IMDBURL" "$IMDBURLLOG") ] || [ ! -z $EXEMPTED ]; then
   if [ ! "$IMDBLKL" = "/dev/null" ]; then
    USEBOT=""
   fi
  else
   if [ ! "$IMDBLKL" = "/dev/null" ]; then
    echo "$IMDBURL" >> $IMDBURLLOG
    tail -n $KEEPURLS $IMDBURLLOG > $TMPFILE
    cat $TMPFILE > $IMDBURLLOG
    echo -n "" > $TMPFILE
   fi
  fi
  DEBUGCOUNT=4
  if [ ! -z $DEBUG ]; then
   echo "$DEBUGCOUNT : DOTIMDB = '$DOTIMDB'"
   echo "$DEBUGCOUNT : USEBOT = '$USEBOT'"
  fi

# grab info from API
####################
  IMDB_ID=$(extract_imdb_id "$IMDBURL")
  OUTPUTOK=""

  if [ -z "$IMDB_ID" ]; then
    if [ ! -z $DEBUG ]; then
      echo "DEBUG: Could not extract IMDb ID from $IMDBURL"
    fi
  else
    API_RESPONSE=$(api_request "/titles/${IMDB_ID}")

    if [ $? -eq 0 ] && [ -n "$API_RESPONSE" ]; then
      TITLE=$($JQ_BIN -r '.primaryTitle // empty' <<< "$API_RESPONSE")
      ORIGTITLE=$($JQ_BIN -r '.originalTitle // .primaryTitle // empty' <<< "$API_RESPONSE")
      TITLEYEAR=$($JQ_BIN -r '.startYear // empty' <<< "$API_RESPONSE")
      TITLETYPE=$($JQ_BIN -r '.titleType // .type // empty' <<< "$API_RESPONSE")

      UNSUPPORTED_TYPE=""
      case "$TITLETYPE" in
        short|tvShort|tvSpecial|tvEpisode|videoGame)
          UNSUPPORTED_TYPE="YES"
          ;;
      esac

      if [ -n "$UNSUPPORTED_TYPE" ]; then
        if [ ! -z $DEBUG ]; then
          echo "DEBUG: Title type '$TITLETYPE' not fully supported by API for $IMDB_ID"
        fi
      elif [ -n "$TITLE" ] && [ -n "$TITLEYEAR" ]; then
        OUTPUTOK="OK"

        TITLENAME=$TITLE
        if [ ! -z "$USEORIGTITLE" ] && [ ! -z "$ORIGTITLE" ] && [ "$ORIGTITLE" != "null" ]; then
          TITLENAME="$ORIGTITLE"
        fi

        if [ -z "$ORIGTITLE" ] || [ "$ORIGTITLE" = "null" ] || [ "$ORIGTITLE" = "$TITLE" ]; then
          AKA_RESPONSE=$(api_request "/titles/${IMDB_ID}/akas")
          if [ $? -eq 0 ] && [ -n "$AKA_RESPONSE" ]; then
            AKA_TITLE=$($JQ_BIN -r '(.akas // []) | map(select(.text != "'"$TITLE"'")) | .[0].text // empty' <<< "$AKA_RESPONSE" 2>/dev/null)
            if [ -n "$AKA_TITLE" ] && [ "$AKA_TITLE" != "null" ] && [ "$AKA_TITLE" != "$TITLE" ]; then
              ORIGTITLE="$AKA_TITLE"
              if [ ! -z "$USEORIGTITLE" ]; then
                TITLENAME="$ORIGTITLE"
              fi
            fi
          fi
        fi

        TITLE="$TITLENAME ($TITLEYEAR)"

        GENRECLEAN=$($JQ_BIN -r '(.genres // []) | .[0:'"$GENRENUM"'] | join("/")' <<< "$API_RESPONSE")
        GENRE="Genre........: $GENRECLEAN"

        RATINGSCORE=$($JQ_BIN -r '.rating.aggregateRating // empty' <<< "$API_RESPONSE")
        VOTECOUNT=$($JQ_BIN -r '.rating.voteCount // empty' <<< "$API_RESPONSE")
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

        COUNTRYCLEAN=$($JQ_BIN -r '(.originCountries // []) | map(.name // .code // empty) | .[0:'"$COUNTRYNUM"'] | join("/")' <<< "$API_RESPONSE")
        if [ -z "$COUNTRYCLEAN" ] || [ "$COUNTRYCLEAN" = "null" ]; then
          COUNTRYCLEAN=$($JQ_BIN -r '(.countries // []) | map(.name // .code // empty) | .[0:'"$COUNTRYNUM"'] | join("/")' <<< "$API_RESPONSE")
        fi
        COUNTRY="Country......: $COUNTRYCLEAN"

        LANGUAGECLEAN=$($JQ_BIN -r '(.spokenLanguages // []) | map(.name // .code // empty) | .[0:'"$LANGUAGENUM"'] | join("/")' <<< "$API_RESPONSE")
        LANGUAGE="Language.....: $LANGUAGECLEAN"

        PLOTCLEAN=$($JQ_BIN -r '.plot // empty' <<< "$API_RESPONSE" | sed "s/\"/$QUOTECHAR/g" | head -c "$PLOTWIDTH")
        PLOT="Plot: $PLOTCLEAN"

        runtime_sec=$($JQ_BIN -r '.runtimeSeconds // empty' <<< "$API_RESPONSE")
        if [ -n "$runtime_sec" ] && [ "$runtime_sec" != "null" ]; then
          hours=$((runtime_sec / 3600))
          mins=$(((runtime_sec % 3600) / 60))
          if [ $hours -gt 0 ]; then
            RUNTIME="${hours}h ${mins}min"
          else
            RUNTIME="${mins}min"
          fi
        else
          runtime_min=$($JQ_BIN -r '.runtime // empty' <<< "$API_RESPONSE")
          if [ -n "$runtime_min" ] && [ "$runtime_min" != "null" ]; then
            hours=$((runtime_min / 60))
            mins=$((runtime_min % 60))
            if [ $hours -gt 0 ]; then
              RUNTIME="${hours}h ${mins}min"
            else
              RUNTIME="${mins}min"
            fi
          else
            RUNTIME=""
          fi
        fi
        RUNTIMECLEAN="$RUNTIME"

        DIRECTORCLEAN=$($JQ_BIN -r '(.directors // []) | .[0:'"$DIRECTORNUM"'] | map(.displayName // .name // empty) | join("/")' <<< "$API_RESPONSE")
        DIRECTOR="Directed by..: $DIRECTORCLEAN"

        CASTCLEAN=$($JQ_BIN -r '(.stars // []) | .[0:'"$CASTNUM"'] | map(.displayName // .name // empty) | join(", ")' <<< "$API_RESPONSE")
        CASTLEADNAME=$($JQ_BIN -r '(.stars // [])[0].displayName // (.stars // [])[0].name // empty' <<< "$API_RESPONSE")
        CASTLEADCHAR=""

        TAGLINECLEAN=""

        CERTCLEAN=""
        if [ ! -z "$USECERT" ]; then
          CERT_RESPONSE=$(api_request "/titles/${IMDB_ID}/certificates")
          if [ $? -eq 0 ] && [ -n "$CERT_RESPONSE" ]; then
            CERTCLEAN=$($JQ_BIN -r '(.certificates // []) | map(select(.country.code == "'"$CERTCOUNTRY"'")) | map(.rating + (if (.attributes // []) | length > 0 then " (" + (.attributes | join(", ")) + ")" else "" end)) | .[0] // empty' <<< "$CERT_RESPONSE")
          fi
        fi
        CERT="$CERTCLEAN"

        COMMENTSHORT="User Reviews: N/A (API)"
        COMMENTSHORTCLEAN="N/A (API)"
        COMMENT=""
        COMMENTCLEAN=""

        ONELINE="$BOLD$TITLE$BOLD [$COUNTRYCLEAN]: $GENRECLEAN - $BOLD$RATINGCLEAN$BOLD - $IMDBURL"
      fi
    fi
  fi

  if [ -z "$OUTPUTOK" ]; then
    DOTIMDB=""
    USEBOT=""
    ERROR_MSG="Failed to fetch iMDB details. Please try again."
    if [ -n "$UNSUPPORTED_TYPE" ]; then
      ERROR_MSG="iMDB type '$TITLETYPE' not fully supported by API (limited data available)"
    fi
    if [ ! -z "$(echo $IMDBLKL | grep -a -e "/dev/null")" ]; then
      if [ -z "$LOGFORMAT" ]; then
        echo "$DATE $TRIGGER \"$IMDBLKL\" \"$ERROR_MSG\" \"$IMDBDST\"" >> $GLLOG
      elif [ "$LOGFORMAT" = "MYOWN" ]; then
        echo "$DATE $TRIGGER \"$IMDBLKL\" \"$ERROR_MSG\" \"$IMDBDST\"" >> $GLLOG
      else
        echo "$DATE $TRIGGER \"$IMDBLKL\" \"\" \"$ERROR_MSG\"" >> $GLLOG
      fi
    else
      rm -f "$GLROOT/$IMDBLKL/$INFOTEMPNAME" >/dev/null 2>&1
      rmdir "$GLROOT/$IMDBLKL/$INFOTEMPNAME" >/dev/null 2>&1
    fi
  else
    BUSINESS=""
    BUSINESSSHORT=""
    BUSINESSSCREENS=""
    PREMIERE=""
    LIMITED=""
    ISLIMITED=""

    if [ ! -z "$USEBUSINESS" ]; then
      BOX_RESPONSE=$(api_request "/titles/${IMDB_ID}/boxOffice")
      if [ $? -eq 0 ] && [ -n "$BOX_RESPONSE" ]; then
        BUDGET=$($JQ_BIN -r '.budget.amount // empty' <<< "$BOX_RESPONSE")
        BUDGET_CUR=$($JQ_BIN -r '.budget.currency // "USD"' <<< "$BOX_RESPONSE")
        OPENING=$($JQ_BIN -r '.openingWeekendGross.amount // empty' <<< "$BOX_RESPONSE")
        OPENING_CUR=$($JQ_BIN -r '.openingWeekendGross.currency // "USD"' <<< "$BOX_RESPONSE")
        GROSS=$($JQ_BIN -r '.worldwideGross.amount // empty' <<< "$BOX_RESPONSE")

        if [ -n "$OPENING" ]; then
          BUSINESSSHORT="$OPENING_CUR $(printf "%'d" "$OPENING" 2>/dev/null || echo "$OPENING")"
        fi
        if [ -n "$BUDGET" ]; then
          BUSINESS="Budget: $BUDGET_CUR $(printf "%'d" "$BUDGET" 2>/dev/null || echo "$BUDGET")"
        fi
      fi
    fi

    if [ ! -z "$USEPREMIERE" ] || [ ! -z "$USELIMITED" ]; then
      RELEASE_RESPONSE=$(api_request "/titles/${IMDB_ID}/releaseDates")
      if [ $? -eq 0 ] && [ -n "$RELEASE_RESPONSE" ]; then
        if [ ! -z "$USEPREMIERE" ]; then
          PREMIERE=$($JQ_BIN -r 'def pad2: tostring | if length == 1 then "0" + . else . end; def fmtdate: (.releaseDate.year|tostring) + "-" + (.releaseDate.month|pad2) + "-" + (.releaseDate.day|pad2); (.releaseDates // []) | map(select(.country.code == "'"$PREMIERECOUNTRY"'")) | .[0]? | if . == null then empty else (fmtdate + (if (.attributes // []) | length > 0 then " (" + (.attributes | join(", ")) + ")" else "" end)) end' <<< "$RELEASE_RESPONSE" 2>/dev/null | head -1)
        fi
        if [ ! -z "$USELIMITED" ]; then
          LIMITED=$($JQ_BIN -r 'def pad2: tostring | if length == 1 then "0" + . else . end; def fmtdate: (.releaseDate.year|tostring) + "-" + (.releaseDate.month|pad2) + "-" + (.releaseDate.day|pad2); (.releaseDates // []) | map(select(.country.code == "'"$PREMIERECOUNTRY"'" and ((.attributes // []) | join(" ") | test("limited"; "i")))) | .[0]? | if . == null then empty else (fmtdate + (if (.attributes // []) | length > 0 then " (" + (.attributes | join(", ")) + ")" else "" end)) end' <<< "$RELEASE_RESPONSE" 2>/dev/null | head -1)
        fi
      fi
    fi

    if [ ! -z "$USEBOM" ]; then
      BOMURL="https://www.boxofficemojo.com/title/${IMDB_ID}/"
      BOM_RESPONSE=$(curl $CURLFLAGS -s -A "$USERAGENT" --connect-timeout $IMDBAPI_TIMEOUT "$BOMURL" 2>/dev/null)
      if [ -n "$BOM_RESPONSE" ]; then
        BOMRELEASEGROUP=$(echo "$BOM_RESPONSE" | sed -n -E 's|.*<option value="(/releasegroup/gr[0-9]+/)">Original Release</option>.*|\1|p')
        if [ -n "$BOMRELEASEGROUP" ]; then
          BOMURLRELEASEGROUP="https://www.boxofficemojo.com${BOMRELEASEGROUP}"
          BOM_RELEASE=$(curl $CURLFLAGS -s -A "$USERAGENT" --connect-timeout $IMDBAPI_TIMEOUT "$BOMURLRELEASEGROUP" 2>/dev/null)
          BOMRELEASE=$(echo "$BOM_RELEASE" | sed -n -E 's|.*<a class="a-link-normal" href="(/release/rl[0-9]+/)[^\"]*">Domestic[^\n]*</a>.*|\1|p' | head -1)
          if [ -n "$BOMRELEASE" ]; then
            BOMURLRELEASE="https://www.boxofficemojo.com${BOMRELEASE}"
            BOM_DETAIL=$(curl $CURLFLAGS -s -A "$USERAGENT" --connect-timeout $IMDBAPI_TIMEOUT "$BOMURLRELEASE" 2>/dev/null)
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
    BOTHEAD=$(echo $BOTHEADORIG | sed "s/RELEASENAME/$BOLD$IMDBDIR$BOLD/")
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

    if [ ! -z "$LOCALURL" ]; then
     IMDBURL="$(echo $IMDBURL | sed "s|/www.|/$LOCALURL.|g" | tr 'A-Z' 'a-z')"
    fi
    HEADTMP="Title........: $BOLD$TITLE$BOLD"
    if [ ! -z "$COUNTRY" ]; then
     HEADTMP="$HEADTMP / $COUNTRY"
    fi
    if [ ! -z "$LANGUAGE" ]; then
     HEADTMP="$HEADTMP / $BOLD$LANGUAGE$BOLD"
    fi
    HEAD=$(echo "$HEADTMP" | sed "s/Country......: //" | sed "s/Language.....: //" | tr -s ' ')
    if [ ! -z "$BOTHEAD" ]; then
     echo "$DATE $TRIGGER \"$IMDBLKL\" \"$BOTHEAD\" \"$IMDBDST\"" >> $GLLOG
    fi
    if [ ! -z "$HEAD" ] && [ -z "$BOTONELINE" ]; then
     echo "$DATE $TRIGGER \"$IMDBLKL\" \"$HEAD\" \"$IMDBDST\"" >> $GLLOG
    fi
    if [ -z "$BOTONELINE" ]; then
     echo "$DATE $TRIGGER \"$IMDBLKL\" \"IMDb Link....: $IMDBURL\" \"$IMDBDST\"" >> $GLLOG
    fi
    if [ ! -z "$DIRECTOR" ] && [ -z "$BOTONELINE" ]; then
     echo "$DATE $TRIGGER \"$IMDBLKL\" \"$DIRECTOR\" \"$IMDBDST\"" >> $GLLOG
    fi
    if [ ! -z "$GENRE" ] && [ -z "$BOTONELINE" ]; then
     echo "$DATE $TRIGGER \"$IMDBLKL\" \"$GENRE\" \"$IMDBDST\"" >> $GLLOG
    fi
    if [ ! -z "$RATING" ] && [ -z "$BOTONELINE" ]; then
     echo "$DATE $TRIGGER \"$IMDBLKL\" \"$RATING\" \"$IMDBDST\"" >> $GLLOG
    fi
    if [ ! -z "$SHOWSTAR" ] && [ -z "$BOTONELINE" ] && [ ! -z "$CASTLEADNAME" ]; then
     echo "$DATE $TRIGGER \"$IMDBLKL\" \"Starring.....: $CASTLEADNAME as $CASTLEADCHAR\" \"$IMDBDST\"" >> $GLLOG
    fi
    if [ ! -z "$RUNTIME" ] && [ -z "$BOTONELINE" ]; then
     echo "$DATE $TRIGGER \"$IMDBLKL\" \"$RUNTIME\" \"$IMDBDST\"" >> $GLLOG
    fi
    if [ ! -z "$BUSINESSSHORT" ] && [ -z "$BOTONELINE" ]; then
     echo "$DATE $TRIGGER \"$IMDBLKL\" \"Opening Stats: $BUSINESSSHORT\" \"$IMDBDST\"" | tr '[=$=]' '¤' | sed "s|¤|USD|g" >> $GLLOG
    fi
    if [ ! -z "$PREMIERE" ] && [ -z "$BOTONELINE" ]; then
     echo "$DATE $TRIGGER \"$IMDBLKL\" \"Premiere Date: $PREMIERE\" \"$IMDBDST\"" >> $GLLOG
    fi
    if [ ! -z "$LIMITED" ] && [ -z "$BOTONELINE" ]; then
     echo "$DATE $TRIGGER \"$IMDBLKL\" \"Limited Date.: $LIMITED\" \"$IMDBDST\"" >> $GLLOG
    fi
    if [ ! -z "$TAGLINE" ] && [ ! -z "$PLOT" ] && [ -z "$BOTONELINE" ]; then
     if [ "$TAGPLOT" = "TAG" ] || [ -z "$TAGPLOT" ] ; then
      echo "$DATE $TRIGGER \"$IMDBLKL\" \"$TAGLINE\" \"$IMDBDST\"" >> $GLLOG
     fi
     if [ "$TAGPLOT" = "PLOT" ] || [ -z "$TAGPLOT" ]; then
      echo "$DATE $TRIGGER \"$IMDBLKL\" \"$PLOT\" \"$IMDBDST\"" >> $GLLOG
     fi
    elif [ ! -z "$TAGLINE" ] && [ ! "$TAGPLOT" = "NONE" ] && [ -z "$BOTONELINE" ]; then
     echo "$DATE $TRIGGER \"$IMDBLKL\" \"$TAGLINE\" \"$IMDBDST\"" >> $GLLOG
    elif [ ! -z "$PLOT" ] && [ ! "$TAGPLOT" = "NONE" ] && [ -z "$BOTONELINE" ]; then
     echo "$DATE $TRIGGER \"$IMDBLKL\" \"$PLOT\" \"$IMDBDST\"" >> $GLLOG
    fi
    if [ ! -z "$SHOWCOMMENTSHORT" ] && [ ! "$COMMENTSHORT" = "User Reviews:" ] && [ -z "$BOTONELINE" ]; then
     echo "$DATE $TRIGGER \"$IMDBLKL\" \"$COMMENTSHORT\" \"$IMDBDST\"" >> $GLLOG
    fi
    if  [ ! -z "$BOTONELINE" ]; then
     if [ -z "$LOGFORMAT" ]; then
      echo "$DATE $TRIGGER \"$IMDBLKL\" \"$ONELINE\" \"$IMDBDST\"" >> $GLLOG
     elif [ "$LOGFORMAT" = "MYOWN" ]; then
#      NEWLINE="|"
      MYOWNPAIRS="%imdbdirname|IMDBDIR %imdburl|IMDBURL %imdbtitle|TITLE %imdbgenre|GENRECLEAN %imdbrating|RATINGCLEAN %imdbcountry|COUNTRYCLEAN %imdblanguage|LANGUAGECLEAN %imdbcertification|CERTCLEAN %imdbruntime|RUNTIMECLEAN %imdbdirector|DIRECTORCLEAN %imdbbusinessdata|BUSINESSSHORT %imdbpremiereinfo|PREMIERE %imdblimitedinfo|LIMITED %imdbvotes|RATINGVOTES %imdbscore|RATINGSCORE %imdbname|TITLENAME %imdbyear|TITLEYEAR %imdbnumscreens|BUSINESSSCREENS %imdbislimited|ISLIMITED %imdbcastleadname|CASTLEADNAME %imdbcastleadchar|CASTLEADCHAR %imdbtagline|TAGLINECLEAN %imdbplot|PLOTCLEAN %imdbbar|RATINGBAR %imdbcasting|CASTCLEAN %imdbcommentshort|COMMENTSHORTCLEAN %newline|NEWLINE %bold|BOLD"
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
        echo "$DATE $TRIGGER \"$IMDBLKL\" \"$LINE1\" \"$IMDBDST\"" | tr '[=$=]' '¤' | sed "s|¤|USD|g" >> $GLLOG
        CURTRIG="$TRIGGER"
        [ -n "$IMDBSPLITTRIG" ] && CURTRIG="$IMDBSPLITTRIG"
        echo "$DATE $CURTRIG \"$IMDBLKL\" \"$LINE2\" \"$IMDBDST\"" | tr '[=$=]' '¤' | sed "s|¤|USD|g" >> $GLLOG
       else
        echo "$DATE $TRIGGER \"$IMDBLKL\" \"${MYOWNFORMAT1}\" \"$IMDBDST\"" | tr '[=$=]' '¤' | sed "s|¤|USD|g" >> $GLLOG
       fi
      else
       echo "$DATE $TRIGGER \"$IMDBLKL\" \"${MYOWNFORMAT1}\" \"$IMDBDST\"" | tr '[=$=]' '¤' | sed "s|¤|USD|g" >> $GLLOG
      fi
     else
      echo "$DATE $TRIGGER \"$IMDBLKL\" \"$IMDBDIR\" \"$IMDBURL\" \"$TITLE\" \"$GENRECLEAN\" \"$RATINGCLEAN\" \"$COUNTRYCLEAN\" \"$LANGUAGECLEAN\" \"$CERTCLEAN\" \"$RUNTIMECLEAN\" \"$DIRECTORCLEAN\" \"$BUSINESSSHORT\" \"$PREMIERE\" \"$LIMITED\" \"$RATINGVOTES\" \"$RATINGSCORE\" \"$TITLENAME\" \"$TITLEYEAR\" \"$BUSINESSSCREENS\" \"$ISLIMITED\" \"$CASTLEADNAME\" \"$CASTLEADCHAR\" \"$TAGLINECLEAN\" \"$PLOTCLEAN\" \"$RATINGBAR\" \"$CASTCLEAN\" \"$COMMENTSHORTCLEAN\" \"$IMDBDST\"" | tr '[=$=]' '¤' | sed "s|¤|USD|g" >> $GLLOG
     fi
    fi
   fi
   if [ ! -z "$DOTIMDB" ]; then

# Echo stuff to the .imdb file
##############################

    echo -e "$IMDBHEAD" > "$IMDBLNK"
    OWNER=$(ls -1nl "$GLROOT$IMDBLKL" | tail -n 1 | { read junk junk owner group junk; echo $owner:$group; };)
    echo "Title........: $TITLE" | fold -s -w $IMDBWIDTH | head -n 1 >> "$IMDBLNK"
    echo "-" >> "$IMDBLNK"
    echo "IMDb Link....: $IMDBURL" | head -n 1 >> "$IMDBLNK"
    if [ ! -z "$DIRECTOR" ]; then
     echo "$DIRECTOR" | fold -s -w $IMDBWIDTH | head -n 1 >> "$IMDBLNK"
    fi
    if [ ! -z "$GENRE" ]; then
     echo "$GENRE" | fold -s -w $IMDBWIDTH | head -n 1 >> "$IMDBLNK"
    fi
    if [ ! -z "$RATING" ]; then
     echo "$RATING" | fold -s -w $IMDBWIDTH | head -n 1 >> "$IMDBLNK"
    fi
    if [ ! -z "$TAGLINE" ]; then
     echo "$TAGLINE" | fold -s -w $IMDBWIDTH >> "$IMDBLNK"
    fi
    echo "-" >> "$IMDBLNK"
    if [ ! -z "$COUNTRY" ]; then
     echo "$COUNTRY" | fold -s -w $IMDBWIDTH | head -n 1 >> "$IMDBLNK"
    fi
    if [ ! -z "$LANGUAGE" ]; then
     echo "$LANGUAGE" | fold -s -w $IMDBWIDTH | head -n 1 >> "$IMDBLNK"
    fi
    if [ ! -z "$CERT" ]; then
     echo "Certification:[[SPACE]]$CERT" | fold -s -w $IMDBWIDTH | head -n 1 | sed 's/\[\[SPACE\]\]/ /' >> "$IMDBLNK"
    fi
    if [ ! -z "$PREMIERE" ]; then
     echo "Premiere Date: $PREMIERE" | fold -s -w $IMDBWIDTH | head -n 1 >> "$IMDBLNK"
    fi
    if [ ! -z "$LIMITED" ]; then
     echo "Limited Date.: $LIMITED" | fold -s -w $IMDBWIDTH | head -n 1 >> "$IMDBLNK"
    fi
    if [ ! -z "$RUNTIME" ]; then
     echo "Runtime......: $RUNTIME" | fold -s -w $IMDBWIDTH | head -n 1 >> "$IMDBLNK"
    fi
    if [ ! -z "$CAST" ]; then
     echo "-" >> "$IMDBLNK"
     echo "Credited Cast:" >> "$IMDBLNK"
     echo "$CAST" | fold -s -w $IMDBWIDTH >> "$IMDBLNK"
    fi
    if [ ! -z "$BUSINESS" ]; then
     echo "-" >> "$IMDBLNK"
     echo "Business Data on Opening Weekend:" >> "$IMDBLNK"
     echo "$BUSINESS" | fold -s -w $IMDBWIDTH >> "$IMDBLNK"
    fi
    if [ ! -z "$PLOT" ]; then
     echo "-" >> "$IMDBLNK"
     #echo "$PLOT" | fold -s -w $IMDBWIDTH >> "$IMDBLNK"
     echo "$PLOT" | sed s/"$NEWLINE"//g | fold -s -w $IMDBWIDTH >> "$IMDBLNK"
    fi
    if [ ! -z "$SHOWCOMMENT" ] && [ ! -z "$COMMENT" ]; then
     echo "---" >> "$IMDBLNK"
     echo "User Review:" >> "$IMDBLNK"
     echo "$COMMENT" | sed "s/^\ *//g" | sed "s/\ *$//g" | tr -s ' ' | fold -s -w $IMDBWIDTH >> "$IMDBLNK"
    fi
    echo -e "$IMDBTAIL" >> "$IMDBLNK"
   fi

   if [ ! -z "$INFOTEMPNAME" ] && [ -e "$GLROOT$IMDBLKL/$INFOTEMPNAME" ]; then

# make a file/dir with imdb info in the name 

    INFOGENRES=$(echo $GENRECLEAN | tr '/ ' '\n' |  sed -e /^$/d | wc -l)
    if [ ! $INFOGENRES -gt $INFOGENREMAX ]; then
     let INFOGENREMAXED=INFOGENRES
    else
     let INFOGENREMAXED=INFOGENREMAX
    fi
    if [ ! $INFOGENRES -lt 1 ]; then
     GENREFILE="$(echo $GENRECLEAN | tr '/ ' '\n' |  sed -e /^$/d | head -n $INFOGENREMAX | tr '\n' ' ' | sed "s/ /$INFOGENRESEP/g" | cut -d "$INFOGENRESEP" -f 1-$INFOGENREMAXED)"
    else
     GENREFILE="Unclassified"
    fi
    VOTESFILE="$(echo $RATINGVOTES | tr ',' '.')"
    [[ -z "$VOTESFILE" ]] && VOTESFILE="NA"
    SCOREFILE="$RATINGSCORE"
    [[ -z "$SCOREFILE" ]] && SCOREFILE="NA"
    LIMITEDFILE="$ISLIMITED"
    [[ -z "$LIMITEDFILE" ]] && LIMITEDFILE="unknown"
    NUMSCREENS="$(echo $BUSINESSSCREENS | tr ',' '.')"
    [[ -z "$NUMSCREENS" ]] && NUMSCREENS="unknown"
    RUNTIMEFILE="$RUNTIMECLEAN"
    [[ -z "$RUNTIMEFILE" ]] && RUNTIMEFILE="unknown"
    INFOFILENAMEOLD="$(echo "$INFOFILENAME" | tr -c $INFOVALID $INFOCHARTO | sed "s%VOTES%*%g" | sed "s%SCORE%*%g" | sed "s%GENRE%*%g" | sed "s%RUNTIME%*%g" | sed "s%YEAR%*%g" | sed "s%ISLIMITED%*%g" | sed "s%SCREENS%*%g")"
    INFOFILENAMEOLDA="$(echo "$INFOFILENAMEOLD" | sed "s%*%.*%g")"
    INFOFILENAMEOLDB="$(echo "$INFOFILENAMEOLDA" | tr '\]\[' '.')"
    INFOFILENAMEPRINT="$(echo "$INFOFILENAME" | sed "s%VOTES%$VOTESFILE%g" | sed "s%SCORE%$SCOREFILE%g" | sed "s%GENRE%$GENREFILE%g" | sed "s%RUNTIME%$RUNTIMEFILE%g" | sed "s%YEAR%$TITLEYEAR%g" | sed "s%ISLIMITED%$LIMITEDFILE%g" | sed "s%SCREENS%$NUMSCREENS%g")"
    INFOFILENAMEPRINT="$(echo "$INFOFILENAMEPRINT" | tr -c $INFOVALID $INFOCHARTO)"
    if [ ! -z "$(ls -1 "$GLROOT$IMDBLKL" | grep -a -e "$INFOFILENAMEOLDB")" ]; then
     for OLDINFOFILE in $(ls -1  "$GLROOT$IMDBLKL" | grep -a -e "$INFOFILENAMEOLDB" | tr ' ' '^'); do
      OLDINFOFILE="$(echo $OLDINFOFILE | tr '^' ' ')"
      rm -f "$GLROOT$IMDBLKL/$OLDINFOFILE" >/dev/null 2>&1
      rmdir "$GLROOT$IMDBLKL/$OLDINFOFILE" >/dev/null 2>&1
     done
    fi
    mv "$GLROOT$IMDBLKL/$INFOTEMPNAME" "$GLROOT$IMDBLKL/$INFOFILENAMEPRINT"
   fi

# create a thumbnail?

   if [ "$DOWNLOADTHUMB" = "YES" ]; then
    FILENAME=$(ls -1Ftr "$GLROOT$IMDBLKL" | grep -a -v "/" | grep -a -v "@" | grep -a -e "[.][nN][fF][oO]" | head -n 1)
    TMBNAME=$(echo $FILENAME | sed "s/\.nfo/.jpg/")
    if [ ! -z "$USEWGET" ]; then
     wget $WGETFLAGS -U "$USERAGENT" -O $TMPFILE --timeout=30 $GLROOT$IMDBLKL/$TMBNAME >/dev/null 2>&1
    elif [ ! -z "$USECURL" ]; then
     curl $CURLFLAGS -A "$USERAGENT" -o $TMPFILE --connect-timeout 30 $GLROOT$IMDBLKL/$TMBNAME >/dev/null 2>&1
    fi
   fi

# Should we run any external scripts?

   if [ ! -z "$EXTERNALSCRIPTNAME" ]; then
    FILENAMED=$(ls -1Ftr "$GLROOT$IMDBLKL" | grep -a -v "/" | grep -a -v "@" | grep -a -e "[.][nN][fF][oO]" | head -n 1)
    if [ ! -z "$FILENAMED" ]; then
     touch -acmr "$GLROOT$IMDBLKL/$FILENAMED" "$GLROOT$IMDBLKL" >/dev/null 2>&1
    fi
    for EXTERNALNAME in $EXTERNALSCRIPTNAME; do
     if [ "$DEBUG" = "4" ] && [ ! -z "$(head -n 1 $EXTERNALNAME | grep -a -e "/bin/bash")" ]; then
      bash -x -v $EXTERNALNAME "\"$DATE\" \"$IMDBLNK\" \"$IMDBLKL\" \"$IMDBDIR\" \"$IMDBURL\" \"$TITLE\" \"$GENRECLEAN\" \"$RATINGCLEAN\" \"$COUNTRYCLEAN\" \"$LANGUAGECLEAN\" \"$CERTCLEAN\" \"$RUNTIMECLEAN\" \"$DIRECTORCLEAN\" \"$BUSINESSSHORT\" \"$PREMIERE\" \"$LIMITED\" \"$RATINGVOTES\" \"$RATINGSCORE\" \"$TITLENAME\" \"$TITLEYEAR\" \"$BUSINESSSCREENS\" \"$ISLIMITED\" \"$CASTLEADNAME\" \"$CASTLEADCHAR\" \"$TAGLINECLEAN\" \"$PLOTCLEAN\" \"$RATINGBAR\" \"$CASTCLEAN\" \"$COMMENTSHORTCLEAN\" \"$COMMENTCLEAN\""
     else
      $EXTERNALNAME "\"$DATE\" \"$IMDBLNK\" \"$IMDBLKL\" \"$IMDBDIR\" \"$IMDBURL\" \"$TITLE\" \"$GENRECLEAN\" \"$RATINGCLEAN\" \"$COUNTRYCLEAN\" \"$LANGUAGECLEAN\" \"$CERTCLEAN\" \"$RUNTIMECLEAN\" \"$DIRECTORCLEAN\" \"$BUSINESSSHORT\" \"$PREMIERE\" \"$LIMITED\" \"$RATINGVOTES\" \"$RATINGSCORE\" \"$TITLENAME\" \"$TITLEYEAR\" \"$BUSINESSSCREENS\" \"$ISLIMITED\" \"$CASTLEADNAME\" \"$CASTLEADCHAR\" \"$TAGLINECLEAN\" \"$PLOTCLEAN\" \"$RATINGBAR\" \"$CASTCLEAN\" \"$COMMENTSHORTCLEAN\" \"$COMMENTCLEAN\""
     fi
    done

# restore the releasedir's original date.
#########################################
    FILENAMED=$(ls -1Ftr "$GLROOT$IMDBLKL" | grep -a -v "/" | grep -a -v "@" | grep -a -e "[.][nN][fF][oO]" | head -n 1)
    if [ ! -z "$FILENAMED" ]; then
     touch -acmr "$GLROOT$IMDBLKL/$FILENAMED" "$GLROOT$IMDBLKL" >/dev/null 2>&1
    fi
   fi
  fi

# clean up and make ready for next run.
#######################################

  grep -a -F -v "$IMDBLINE" "$IMDBLOG" > $TMPFILE
  cat $TMPFILE > $IMDBLOG
  > $TMPFILE
 done
 > $TMPRESCANFILE
 > $IMDBPID
fi
exit 0
