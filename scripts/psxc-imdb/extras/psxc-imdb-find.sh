#!/bin/bash


##################################################
# PSXC-IMDB-FIND
################
#
# An addon to psxc-imdb.
# Please read the README, then edit config below.
#
# History:
# v0.1  Initial Release
# v2.3  Added a bit more fuzzy search
#       Changed lookup url
#       Added timeout setting to wget
#       Did a jump in version number, since this
#        script is now a part of psxc-imdb.
#       Added better control on arguments passed.
# v2.3f Added support for iMDB IDs.
# v2.5  Fixed a bug with international versions
#        of lynx.
#       Now shows with local url by default.
#       Added support for listing hits. (-l)
#       Added support for disabling url catching.
#       Added support for private lookups.
# v2.5c Now logs data in debug-mode.
# v2.7  Added support for output destination
#        (user or channel)
# v2.7c imdb.com changed url-style. Changed script
#        to match.
# v2.8  imdb.com changed url-style. Changed script
#        to match.
# v2.9  imdb.com changed url-style. Changed script
#        to match.
# v2.9b fixed small bug.
# v2.9h check CHANGELOG
# v2.9q Fix finding a result
# v2.9u Fix finding a result again
# v2.9v Fix finding a result yet again due to https usage
#       Fix searching for imdb number, lower length to 5 digits and
#        only use if it's the only searchword
#       Use https
# v3.0  Rewritten to use imdbapi.dev REST API
# v3.1  Switch to IMDB GraphQL API (graphql.imdb.com)
#       Fix JSON escaping in search query using jq
#       Fix conf path (/mnt/glftpd/etc -> /glftpd/etc)
# v3.2  Extract shared API library (psxc-imdb-lib.sh)
#       Unify VERSION strings across suite
##################################################

########
# CONFIG

# Version. No need to change.
VERSION=3.2

# (full) path to psxc-imdb.conf. Leave empty to auto-discover
# ($GLROOT/etc/psxc-imdb.conf or /etc/psxc-imdb.conf).
PSXC_IMDB_CONF=""
#PSXC_IMDB_CONF=/glftpd/etc/psxc-imdb.conf

# max hits listed
MAXLIST=10

# default number of hits listed
DEFLIST=5

# bold char - set to "" to disable.
BOLD=""

# different (mirc) colors.
WHITE="00"
BLACK="01"
DARKBLUE="02"
GREEN="03"
RED="04"
DARKRED="05"
DARKPURPLE="06"
ORANGE="07"
YELLOW="08"
LIGHTGREEN="09"
BLUEGREEN="10"
CYAN="11"
BLUE="12"
PURPLE="13"
GREY="14"
LIGHTGREY="15"

# color off
COLOROFF=""

# Word before text output
PREWORD="$BOLD""IMDB:""$BOLD"
#PREWORD="${BOLD}${RED}[${BLUE}HUBBA-BUBBA${RED}]${COLOROFF} :${BOLD}"

# Verbose mode. Default is on ("").
VERBOSE=""
#VERBOSE="OFF"

# OBS! Please - turn off DEBUG! It should only be used if you have problems
#      Having DEBUG on may cause problems!


# END OF CONFIG
###############

DESTINATION=$1
shift
IMDBSEARCHORIGA=$(echo -n "$@" | tr -cd 'A-Za-z0-9\-\,+\=\.\ ')
IMDBSEARCHORIG="$(echo $IMDBSEARCHORIGA | tr ' \.' '\n' | grep -v "^-" | grep -v "^$" | tr '\n' ' ')"
if [ -z "$IMDBSEARCHORIG" ]; then
 echo "$PREWORD psxc-imdb channel trigger v$VERSION - argument(s) missing."
 echo "$PREWORD   use ${BOLD}-lXX${BOLD} to ${BOLD}l${BOLD}ist ${BOLD}XX${BOLD} matches (max $MAXLIST, default $DEFLIST)."
 echo "$PREWORD   use ${BOLD}-n${BOLD}   to ${BOLD}n${BOLD}ot search for imdb ID's in the search-string."
 echo "$PREWORD   /msg <botname> <search> will give the results in private."
 echo "$PREWORD   search-words can be separated by spaces or dots."
 echo "$PREWORD   words starting with '-' are ignored."
 exit 0
fi
IMDBNOURL=""
if [ ! -z "$(echo $IMDBSEARCHORIGA | grep -e "\-[nN]")" ]; then
 IMDBNOURL="ON"
fi
IMDBPRIVATE=""
IMDBLIST=""
if [ ! -z "$(echo $IMDBSEARCHORIGA | grep -e "\-[lL]")" ]; then
 IMDBLIST="$(echo $IMDBSEARCHORIGA | tr ' ' '\n' | grep -e "\-[lL]" | head -n 1 | tr -cd '0-9')"
 if [ -z "$IMDBLIST" ]; then
  IMDBLIST=$DEFLIST
 else
  if [ $IMDBLIST -eq 0 ]; then
   IMDBLIST=$DEFLIST
  elif [ $IMDBLIST -gt $MAXLIST ]; then
   IMDBLIST=$MAXLIST
  fi
 fi
fi

IMDBSEARCHORIG="$(echo $IMDBSEARCHORIGA | tr ' \.' '\n' | grep -v "^-" | grep -v "^$" | tr '\n' ' ')"
if [ -z "$IMDBSEARCHORIG" ]; then
 echo "$PREWORD psxc-imdb channel trigger v$VERSION - please add something to search for."
 exit 0
fi
URLTOUSE=""
IMDBSEARCHWORDS="$(echo $IMDBSEARCHORIG)"
IMDBSEARCHTITLA=$(echo "$IMDBSEARCHORIG" | sed 's/\([^0-9]*[0-9]\{4\}\).*/\1/')
IMDBSEARCHTITLE="$(echo $IMDBSEARCHTITLA | tr ' ' '+' | sed 's/+$//')"
IMDBSEARCHTITLB=$(echo $IMDBSEARCHTITLA)

# Source shared library for API functions
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/psxc-imdb-lib.sh"
imdb_set_defaults
imdb_load_config "$PSXC_IMDB_CONF"

if [ -z "$IMDBNOURL" ] && [ $(echo "$IMDBSEARCHWORDS" | wc -w) -eq 1 ]; then
 IMDBSEARCHID="$(echo -n "$IMDBSEARCHWORDS" | tr -cd '0-9')"
 if [ ! -z "$IMDBSEARCHID" ]; then
  IMDBIDWC=$(echo -n "$IMDBSEARCHID" | wc -c)
  if [ $IMDBIDWC -ge 5 ] && [ $IMDBIDWC -le 8 ]; then
     URLTOUSE="https://www.imdb.com/title/tt$IMDBSEARCHID"
  fi
 fi
fi

if [ -z "$URLTOUSE" ]; then
  SEARCH_QUERY="query{mainSearch(first:${IMDBLIST:-$DEFLIST},options:{searchTerm:\"$(echo "$IMDBSEARCHTITLE" | sed 's/+/ /g')\"}){edges{node{entity{... on Title{id titleText{text}releaseYear{year}titleType{text}}}}}}}"
  SEARCH_RESPONSE=$(imdb_request "$SEARCH_QUERY")

  if [ -z "$SEARCH_RESPONSE" ]; then
    echo "$PREWORD Internal Error. GraphQL API may be down, or not answering. Try again later."
    exit 0
  fi

  RESULT_COUNT=$($JQ_BIN -r '(.data.mainSearch.edges // []) | length' <<< "$SEARCH_RESPONSE" 2>/dev/null)
  if [ -z "$RESULT_COUNT" ] || [ "$RESULT_COUNT" -eq 0 ]; then
    echo "$PREWORD Sorry, nothing found on '${BOLD}${IMDBSEARCHWORDS}${BOLD}'."
    exit 0
  fi

  if [ -z "$IMDBLIST" ]; then
    FIRST_ID=$($JQ_BIN -r '(.data.mainSearch.edges // [])[0].node.entity.id // empty' <<< "$SEARCH_RESPONSE")
    if [ -n "$FIRST_ID" ]; then
      URLTOUSE="https://www.imdb.com/title/$FIRST_ID"
    fi
  else
    echo "$PREWORD Listing up to $IMDBLIST hits..."
    COUNTER=0
    while [ $COUNTER -lt $IMDBLIST ] && [ $COUNTER -lt $RESULT_COUNT ]; do
      RESULT_ID=$($JQ_BIN -r "(.data.mainSearch.edges // [])[$COUNTER].node.entity.id // empty" <<< "$SEARCH_RESPONSE")
      RESULT_TITLE=$($JQ_BIN -r "(.data.mainSearch.edges // [])[$COUNTER].node.entity.titleText.text // empty" <<< "$SEARCH_RESPONSE")
      RESULT_YEAR=$($JQ_BIN -r "(.data.mainSearch.edges // [])[$COUNTER].node.entity.releaseYear.year // empty" <<< "$SEARCH_RESPONSE")
      RESULT_TYPE=$($JQ_BIN -r "(.data.mainSearch.edges // [])[$COUNTER].node.entity.titleType.text // empty" <<< "$SEARCH_RESPONSE")

      if [ -n "$RESULT_ID" ] && [ -n "$RESULT_TITLE" ]; then
        DISPLAY_NUM=$((COUNTER + 1))
        RESULT_URL="https://www.imdb.com/title/$RESULT_ID"
        if [ ! -z "$LOCALURL" ]; then
          RESULT_URL="$(imdb_localize_url "$RESULT_URL" "$LOCALURL")"
        fi
        if [ -n "$RESULT_YEAR" ]; then
          echo "$PREWORD $DISPLAY_NUM. ($RESULT_URL) $RESULT_TITLE ($RESULT_YEAR) [$RESULT_TYPE]"
        else
          echo "$PREWORD $DISPLAY_NUM. ($RESULT_URL) $RESULT_TITLE [$RESULT_TYPE]"
        fi
      fi
      COUNTER=$((COUNTER + 1))
    done

    if [ $RESULT_COUNT -eq 1 ]; then
      FIRST_ID=$($JQ_BIN -r '(.data.mainSearch.edges // [])[0].node.entity.id // empty' <<< "$SEARCH_RESPONSE")
      URLTOUSE="https://www.imdb.com/title/$FIRST_ID"
    else
      exit 0
    fi
  fi
fi

if [ ! -z "$URLTOUSE" ]; then
 if [ ! -z "$LOCALURL" ]; then
  URLTOUSE="$(imdb_localize_url "$URLTOUSE" "$LOCALURL")"
 fi
 URLTOSHOW=$URLTOUSE
 if [ -z "$VERBOSE" ] && [ -z "$IMDBPRIVATE" ]; then
  if [ -z "$IMDBLIST" ]; then
   echo -n "$PREWORD '$IMDBSEARCHTITLB' found @ ${BOLD}${URLTOSHOW}${BOLD}. "
  else
   echo -n "$PREWORD Only one hit found - "
  fi
  echo "Please wait while gathering details.."
 fi
  if [ ! -z "$DEBUG" ]; then
   echo "$URLTOUSE|/dev/null|$DESTINATION"
  fi
  if [ -z "$IMDBPRIVATE" ]; then
   imdb_queue_lookup "$URLTOUSE" "/dev/null|$DESTINATION" "$IMDBLOG"
  fi
else
 echo "$PREWORD Sorry, nothing found on '${BOLD}${IMDBSEARCHWORDS}${BOLD}'."
fi
exit 0
