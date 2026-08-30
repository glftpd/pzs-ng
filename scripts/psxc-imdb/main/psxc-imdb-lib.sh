#!/bin/bash
# psxc-imdb-lib.sh - Shared API connection library for psxc-imdb suite
# Source this file from psxc-imdb scripts to use common functions.
#
# Usage: . /path/to/psxc-imdb-lib.sh
#        imdb_set_defaults
#        response=$(imdb_request "<query>")

# Set default config values.
# COUNTRY_MAP and LANGUAGE_MAP are only set if unset, so callers can
# override them after sourcing the lib but before calling this function.
# Usage: imdb_set_defaults
imdb_set_defaults() {
  : ${CONFFILE:=/etc/psxc-imdb.conf}
  : ${IMDB_GRAPHQL_URL:=https://graphql.imdb.com/}
  : ${IMDBAPI_TIMEOUT:=5}
  : ${API_RETRY_COUNT:=1}
  : ${API_RETRY_DELAY:=0}
  if [ -z "$JQ_BIN" ]; then
    if   [ -n "$SCRIPT_DIR" ] && [ -x "$SCRIPT_DIR/jq" ]; then JQ_BIN="$SCRIPT_DIR/jq"
    elif [ -x /bin/jq ];        then JQ_BIN=/bin/jq
    elif command -v jq >/dev/null 2>&1; then JQ_BIN="$(command -v jq)"
    else JQ_BIN=/bin/jq
    fi
  fi
  : ${USERAGENT:=Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.3}
  : ${CURLFLAGS:=--max-time 8 -L}
  : ${CERTCOUNTRY:=US}
  : ${PREMIERECOUNTRY:=US}
  : ${AKANUM:=200}   # Max AKAs to fetch for the localized title lookup (USEORIGTITLE empty)

  : ${COUNTRY_MAP:='{"US":"United States","GB":"United Kingdom","AU":"Australia","CA":"Canada","FR":"France","DE":"Germany","IT":"Italy","ES":"Spain","JP":"Japan","KR":"South Korea","CN":"China","IN":"India","RU":"Russia","BR":"Brazil","MX":"Mexico","NL":"Netherlands","SE":"Sweden","NO":"Norway","DK":"Denmark","FI":"Finland","PL":"Poland","CZ":"Czech Republic","AT":"Austria","CH":"Switzerland","BE":"Belgium","PT":"Portugal","IE":"Ireland","NZ":"New Zealand","AR":"Argentina","CL":"Chile","CO":"Colombia","PH":"Philippines","TH":"Thailand","HK":"Hong Kong","SG":"Singapore","TW":"Taiwan","IL":"Israel","TR":"Turkey","ZA":"South Africa","EG":"Egypt","ID":"Indonesia","MY":"Malaysia","VN":"Vietnam","GR":"Greece","HU":"Hungary","RO":"Romania","UA":"Ukraine","HR":"Croatia","RS":"Serbia","IS":"Iceland","LU":"Luxembourg"}'}

  : ${LANGUAGE_MAP:='{"en":"English","fr":"French","de":"German","es":"Spanish","it":"Italian","pt":"Portuguese","ja":"Japanese","ko":"Korean","zh":"Chinese","ru":"Russian","hi":"Hindi","ar":"Arabic","nl":"Dutch","sv":"Swedish","no":"Norwegian","da":"Danish","fi":"Finnish","pl":"Polish","cs":"Czech","hu":"Hungarian","ro":"Romanian","bg":"Bulgarian","uk":"Ukrainian","el":"Greek","tr":"Turkish","th":"Thai","vi":"Vietnamese","id":"Indonesian","ms":"Malay","tl":"Tagalog","he":"Hebrew"}'}
}

# Load psxc-imdb config file with error handling
# Usage: imdb_load_config              # auto-discover from the script's location
#        imdb_load_config "/path/to/psxc-imdb.conf"  # explicit path
imdb_load_config() {
  local config_path="${1:-}"
  if [ -z "$config_path" ]; then
    for c in "$SCRIPT_DIR/../etc/psxc-imdb.conf" "$CONFFILE"; do
      [ -r "$c" ] && config_path="$c" && break
    done
    if [ -z "$config_path" ]; then
      echo "Config file not found. Forced to exit." >&2
      return 1
    fi
  fi
  . "$config_path"
  if [ $? -ne 0 ]; then
    echo "Unable to open config file ($config_path). Forced to exit." >&2
    return 1
  fi
}

# Map release-name language tokens to country codes for AKA title lookup.
# Only declared if bash 4+ (associative array support) is available.
declare -A LANG_TO_COUNTRY=(
  [chinese]="CN" [dutch]="NL" [english]="GB" [finnish]="FI" [french]="FR"
  [german]="DE" [greek]="GR" [hebrew]="IL" [hungarian]="HU" [italian]="IT"
  [japanese]="JP" [korean]="KR" [norwegian]="NO" [polish]="PL" [portuguese]="PT"
  [romanian]="RO" [russian]="RU" [spanish]="ES" [swedish]="SE" [turkish]="TR"
  [nl]="NL" [fr]="FR" [de]="DE" [it]="IT" [es]="ES" [en]="GB"
  [danish]="DK" [icelandic]="IS" [czech]="CZ"
)

# Write to glftpd.log in standard psxc-imdb format
# Usage: imdb_write_log "$message"
#        imdb_write_log "$message" --usd          # also replaces =$= with USD
#        imdb_write_log "$message" --usd "$trig"  # with custom trigger
# Requires: DATE, TRIGGER, IMDBLKL, IMDBDST, GLLOG to be set by caller
imdb_write_log() {
  local msg="$1"
  local use_usd="${2:-}"
  local trig="$TRIGGER"
  if [ "$use_usd" = "--usd" ]; then
    if [ -n "${3:-}" ]; then
      trig="$3"
    fi
    echo "$DATE $trig \"$IMDBLKL\" \"$msg\" \"$IMDBDST\"" | sed 's/\$/USD/g' >> "$GLLOG"
  else
    if [ -n "${2:-}" ] && [ "$2" != "--usd" ]; then
      trig="$2"
    fi
    echo "$DATE $trig \"$IMDBLKL\" \"$msg\" \"$IMDBDST\"" >> "$GLLOG"
  fi
}

# Add an entry to the IMDB lookup queue
# Usage: imdb_queue_lookup "$url" "$dest" "$logfile"
imdb_queue_lookup() {
  local url="$1"
  local dest="$2"
  local logfile="$3"
  echo "$url|$dest" >> "$logfile"
}

# Query IMDB GraphQL API with retries
# Usage: response=$(imdb_request "<query>")
# Returns: JSON response on success, empty on failure
imdb_request() {
  local query="$1"
  local retries=0
  local response=""
  local json_payload

  if [ -n "$JQ_BIN" ] && [ -x "$JQ_BIN" ]; then
    json_payload=$($JQ_BIN -n --arg q "$query" '{query: $q}')
  else
    json_payload="{\"query\": \"$query\"}"
  fi

  while [ $retries -lt $API_RETRY_COUNT ]; do
    response=$(curl $CURLFLAGS -s -A "$USERAGENT" \
      -H "Content-Type: application/json" \
      -H "Origin: https://www.imdb.com" \
      -H "Referer: https://www.imdb.com/" \
      --connect-timeout $IMDBAPI_TIMEOUT \
      -X POST "$IMDB_GRAPHQL_URL" \
      -d "$json_payload" 2>/dev/null)

    if [ $? -eq 0 ] && [ -n "$response" ]; then
      if echo "$response" | $JQ_BIN -e '.data' >/dev/null 2>&1; then
        echo "$response"
        return 0
      fi
    fi
    retries=$((retries + 1))
    sleep $API_RETRY_DELAY
  done
  return 1
}

# Extract IMDB ID from URL
# Usage: id=$(imdb_extract_id "https://www.imdb.com/title/tt11378946")
# Returns: IMDB ID (e.g., tt11378946)
imdb_extract_id() {
  echo "$1" | sed -n 's/.*\(tt[0-9][0-9]*\).*/\1/p' | head -1
}

# Rewrite a canonical IMDB URL to include a locale path segment.
# Usage: localized=$(imdb_localize_url "https://www.imdb.com/title/tt11378946" "de")
# Returns: https://www.imdb.com/de/title/tt11378946
# If locale is empty, returns the URL unchanged.
imdb_localize_url() {
  local url="$1"
  local locale="$2"
  if [ -z "$locale" ]; then
    echo "$url"
  else
    case "$locale" in
      de|fr|es|it|pt|hi)
        echo "$url" | sed "s|https://www.imdb.com/title/|https://www.imdb.com/$locale/title/|"
        ;;
      *)
        echo "$url"
        ;;
    esac
  fi
}

# Parse IMDB positional arguments into variables
# Usage: parse_imdb_args "$@"
# Sets: IMDBDATE, IMDBDOTFILE, IMDBRELPATH, IMDBDIRNAME, IMDBURL, IMDBTITLE,
#       IMDBGENRE, IMDBRATING, IMDBCOUNTRY, IMDBLANGUAGE, IMDBCERTIFICATION,
#       IMDBRUNTIME, IMDBDIRECTOR, IMDBBUSINESSDATA, IMDBPREMIERE, IMDBLIMITED,
#       IMDBVOTES, IMDBSCORE, IMDBNAME, IMDBYEAR, IMDBNUMSCREENS, IMDBISLIMITED,
#       IMDBCASTLEADNAME, IMDBCASTLEADCHAR, IMDBTAGLINE, IMDBPLOT, IMDBBAR,
#       IMDBCASTING, IMDBCOMMENTSHORT, IMDBCOMMENTFULL, IMDBMETACRITIC
parse_imdb_args() {
  local OLDIFS="$IFS"
  local c=1
  local a
  local -a b=()
  IFS="^"
  for a in $(echo "$@" | sed "s/^\"//;s/\"$//;s|\" \"|^|g"); do
    b[c]="$a"
    let c=c+1
  done
  IFS="$OLDIFS"

  IMDBDATE="${b[1]:-}"
  IMDBDOTFILE="${b[2]:-}"
  IMDBRELPATH="${b[3]:-}"
  IMDBDIRNAME="${b[4]:-}"
  IMDBURL="${b[5]:-}"
  IMDBTITLE="${b[6]:-}"
  IMDBGENRE="${b[7]:-}"
  IMDBRATING="${b[8]:-}"
  IMDBCOUNTRY="${b[9]:-}"
  IMDBLANGUAGE="${b[10]:-}"
  IMDBCERTIFICATION="${b[11]:-}"
  IMDBRUNTIME="${b[12]:-}"
  IMDBDIRECTOR="${b[13]:-}"
  IMDBBUSINESSDATA="${b[14]:-}"
  IMDBPREMIERE="${b[15]:-}"
  IMDBLIMITED="${b[16]:-}"
  IMDBVOTES="${b[17]:-}"
  IMDBSCORE="${b[18]:-}"
  IMDBNAME="${b[19]:-}"
  IMDBYEAR="${b[20]:-}"
  IMDBNUMSCREENS="${b[21]:-}"
  IMDBISLIMITED="${b[22]:-}"
  IMDBCASTLEADNAME="${b[23]:-}"
  IMDBCASTLEADCHAR="${b[24]:-}"
  IMDBTAGLINE="${b[25]:-}"
  IMDBPLOT="${b[26]:-}"
  IMDBBAR="${b[27]:-}"
  IMDBCASTING="${b[28]:-}"
  IMDBCOMMENTSHORT="${b[29]:-}"
  IMDBCOMMENTFULL="${b[30]:-}"
  IMDBMETACRITIC="${b[31]:-}"
}

# Extract the release directory name from a glftpd pre log entry.
# Usage: DIRNAME=$(imdb_extract_pre_dirname "$PRELOG_LINE" "$PRETRIGGER" "$WORDS" "$SEPARATOR")
imdb_extract_pre_dirname() {
  local prelogline="$1"
  local pretrigger="$2"
  local words="$3"
  local separator="$4"
  local dirname="" c="" b count combine word

  for word in $words; do
    count=0
    combine=0
    if [ -z "$prelogline" ]; then
      return 1
    fi
    if [ -n "$pretrigger" ]; then
      word=$((word + 1))
    fi
    for b in $prelogline; do
      if { [ -z "$(echo "$b" | grep "$pretrigger")" ] && [ "$count" -gt 0 ]; } || [ -z "$pretrigger" ]; then
        if [ "$combine" -eq 1 ]; then
          c="$c$b"
        else
          c="$b"
        fi
        if [ -n "$(echo "$c" | grep '^"')" ]; then
          combine=1
        else
          c="$b"
          count=$((count + 1))
        fi
        if [ -n "$(echo "$c" | grep '"$')" ]; then
          combine=0
          count=$((count + 1))
        fi
        if [ "$count" -eq "$word" ]; then
          break
        fi
      else
        if [ "$b" = "$pretrigger" ]; then
          count=1
        fi
      fi
    done
    dirname="$dirname$c"
  done

  echo "$dirname" | sed "s|\"\"|$separator|g" | sed "s|\"||g"
}

# Strip GLROOT prefix from path
# Usage: MYTMPFILE=$(strip_glroot "$TMPFILE")
strip_glroot() {
  local path="$1"
  if [ -n "$GLROOT" ]; then
    echo "${path#$GLROOT}"
  else
    echo "$path"
  fi
}

# Resolve the FIXDIRTIME mtime-snapshot carrier path for the current context.
# The conf's TMPFILE is a host-style path (GLROOT-prefixed); chrooted runs must
# use the GLROOT-stripped form, host runs the host form. Pick whichever
# actually resolves here.
# Usage: DIRDATE_CARRIER=$(imdb_dirdate_carrier)
imdb_dirdate_carrier() {
  if [ -d "$(dirname "$TMPFILE")" ]; then
    echo "${TMPFILE}.dirdate"
  else
    echo "$(strip_glroot "$TMPFILE").dirdate"
  fi
}

# Extract IMDB URL from NFO file with fallback levels
# Usage: IMDBURL=$(extract_imdb_url "$FILENAME" "$RELAXEDURLS")
extract_imdb_url() {
  local filename="$1"
  local relaxed="${2:-}"
  local url=""
  local urls=""

  if [ -z "$relaxed" ]; then
    relaxed=1
  fi
  if [ "$relaxed" = "ON" ]; then
    relaxed=3
  fi

  # Level 0: Standard URL format
  urls="$(grep [Ii][Mm][Dd][Bb] "$filename" | tr ' \|' '\n' | sed -n '/[hH][tT][tT][pP][sS]*:[/][/].*[.][iI][mM][dD][bB][.].*.[0-9]/p' | head -n 1 | tr -c -d '[:alnum:]\:./?')"
  if [ -n "$(echo "$urls" | grep "imdb\.")" ]; then
    url="https://www.imdb.com/title/tt$(echo "$urls" | sed "s/=/-/g" | sed "s/imdb\./=/" | cut -d "=" -f 2 | cut -d "/" -f 2,3 | tr -c -d '[:digit:]')"
    if [ -z "$(echo "$url" | tr -cd '0-9')" ]; then
      url=""
    fi
  fi

  # Level 1: Relaxed URL format
  if [ -z "$url" ] && [ "$relaxed" -ge 1 ]; then
    urls="$(grep [Ii][Mm][Dd][Bb] "$filename" | tr ' \|' '\n' | sed -n '/[hH][tT][tT][pP][sS]*:[/][/].*[iI][mM][dD][bB][.].*.[0-9]/p' | head -n 1 | tr -c -d '[:alnum:]\:./?')"
    if [ -n "$(echo "$urls" | grep "imdb\.")" ]; then
      url="https://www.imdb.com/title/tt$(echo "$urls" | sed "s/=/-/g" | sed "s/imdb\./=/" | cut -d "=" -f 2 | cut -d "/" -f 2,3 | tr -c -d '[:digit:]')"
      if [ -z "$(echo "$url" | tr -cd '0-9')" ]; then
        url=""
      fi
    fi
  fi

  # Level 2: Even more relaxed
  if [ -z "$url" ] && [ "$relaxed" -ge 2 ]; then
    urls="$(grep [Ii][Mm][Dd][Bb] "$filename" | tr ' \|' '\n' | sed -n '/.*[iI][mM][dD][bB][.].*.[0-9]/p' | head -n 1 | tr -c -d '[:alnum:]\:./?')"
    if [ -n "$(echo "$urls" | grep "imdb\.")" ]; then
      url="https://www.imdb.com/title/tt$(echo "$urls" | sed "s/=/-/g" | sed "s/imdb\./=/" | cut -d "=" -f 2 | cut -d "/" -f 2,3 | tr -c -d '[:digit:]')"
      if [ -z "$(echo "$url" | tr -cd '0-9')" ]; then
        url=""
      fi
    fi
  fi

  # Level 3: Numeric extraction
  if [ -z "$url" ] && [ "$relaxed" -ge 3 ]; then
    for urls in $(grep [Ii][Mm][Dd][Bb] "$filename" | tr -c '[:digit:]' '\n' | grep -v "^$"); do
      if [ -n "$(echo "$urls" | tr -cd '0-9')" ]; then
        if [ "$(echo "$urls" | tr -cd '0-9' | wc -c)" -eq 8 ] || [ "$(echo "$urls" | tr -cd '0-9' | wc -c)" -eq 7 ]; then
          url="https://www.imdb.com/title/tt$urls"
          break
        fi
      fi
    done
  fi

  # Level 4: Broad numeric search
  if [ -z "$url" ] && [ "$relaxed" -ge 4 ]; then
    for urls in $(cat "$filename" | tr -c '[:digit:]' '\n' | grep -v "^$"); do
      if [ "$(echo "$urls" | wc -c)" -eq 8 ] || [ "$(echo "$urls" | wc -c)" -eq 7 ]; then
        url="https://www.imdb.com/title/tt$urls"
        break
      fi
    done
  fi

  echo "$url"
}

# Get file/directory modification date components, platform-agnostic.
# Usage: get_file_date "$path"
# Returns: "YEAR MONTH DATE TIME" (e.g. "2026 Aug 15 1430")
get_file_date() {
  local path="$1"
  local findargs=(-printf "%TY %Tb %Td %TH%TM")
  if [ -d "$path" ]; then
    findargs=(-type d -printf "%TY %Tb %Td %TH%TM")
  fi
  if [ "$SORT_BY_DATE_LS" = "bsd" ]; then
    stat -f "%Sm" -t "%Y %b %d %H%M" "$path"
  else
    find "$path" "${findargs[@]}"
  fi
}
