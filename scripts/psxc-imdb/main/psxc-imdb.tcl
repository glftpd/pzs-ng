# Installation:
# 1. Copy this file (psxc-imdb.tcl) and the plugin theme (psxc-imdb.zpt) into your
#    pzs-ng sitebots 'plugins' folder.
#
# 2. Edit the configuration options below.
#
# 3. Add the following to your eggdrop.conf:
#    source pzs-ng/plugins/psxc-imdb.tcl
#
# 4. Rehash or restart your eggdrop for the changes to take effect.
#
################################################################################


##
## Addon for psxc-imdb, done/converted by meij.
##
## Used to make !imdb lookups possible, and for pre.
## This version, unlike the old one, also has support for
## channel/user specific lookups, meaning that the channel/
## person did the !imdb will be the receiver of the output.
## The old version only put output in main channel.
##
## Require: dZSbot.vars from pzs-ng v1.0.4 or newer.

namespace eval ::ngBot::plugin::psxc-IMDb {
  variable ns [namespace current]
  variable np [namespace qualifiers [namespace parent]]

  variable psxc

  ## Config Settings ###############################
  ##
  ## location of psxc-imdb.log file (aka IMDBLOG)
  set psxc(IMDBLOG)     "/glftpd/ftp-data/logs/psxc-imdb.log"
  ##
  ## location of the imdb-script
  set psxc(IMDBSCRIPT)  "/glftpd/bin/psxc-imdb.sh"
  ##
  ## location of psxc-moviedata.log file (aka GLLOG)
  ## used only in "full" mode, where this addon will do all
  ## imdb-output to channel.
  ## !! DO NOT USE glftpd.log HERE !!
  set psxc(IMDBMOVIE)   "/glftpd/ftp-data/logs/psxc-moviedata.log"
  ##
  ## announce-channel(s) - separate by space
  ## used only in "full" mode.
  set psxc(IMDBCHANNEL) "#changethis"
  ##
  ## should the lines start with something?
  ## used only in "full" mode.
  set psxc(IMDBTRIG) "\002IMDB:\002"
  ##
  ## location of the .log file used for pre'ing
  set psxc(PRELOG)     "/glftpd/ftp-data/logs/glftpd.log"
  ##set psxc(PRELOG)     "/glftpd/ftp-data/logs/prelog"
  ##
  ## location of the imdb-pre-script. Normally, this is a symlink
  ## to psxc-imdb.sh.
  set psxc(PRESCRIPT)  "/glftpd/bin/psxc-imdb-pre.sh"
  ##
  ## What do you wish to use as a channel trigger to react to
  ## questions about a movie?
  set psxc(FINDTRIG) "!imdb"
  ##
  ## Where is the find script (full path)
  set psxc(FINDSCRIPT) "/glftpd/bin/psxc-imdb-find.sh"
  ##
  ## This char is used to split lines on output. It should be the
  ## same variable you have in psxc-imdb.conf (NEWLINE).
  set psxc(NEWLINE) "|"
  ##
  ##################################################
  ##
  ## this is where you enable/disable the parts of the script.
  ##
  ## Should the script be used to output imdb-info? Normally
  ## you set this to "YES"
  set psxc(USEBOT)  "YES"
  ##
  ## Should the script handle imdb-output? Normally dZsbot.tcl
  ## handles output, but in some cases that doesn't work. This was
  ## before known as "full" mode.
  ## You also set this to "YES" if you wish this addon to handle
  ## all !imdb requests.
  set psxc(USEFULL) "NO"
  ##
  ## Is pre-support wanted?
  set psxc(USEPRE)  "YES"
  ##
  ## Do you wish to answer to !imdb requests? Please read
  ## psxc-imdb-find.README before setting this to YES.
  ## Also REMOVE psxc-imdb-find.tcl from your eggdrop.conf if
  ## you used it!
  set psxc(USEFIND) "YES"
  ##
  ##################################################
  ##
  ## I know a lot of admins dislike the "<[psxc-imdb.sh] <defunct>"
  ## process - I strongly suggest you get used to it, but if you
  ## cannot, set this variable to YES - it will force the bot to wait
  ## for the script to finish. FYI - this can lead to a slow
  ## responding/freezing bot, it may die on occation, it may become
  ## very unstable in fact. But, you're free to test.
  set psxc(NODEFUNCT) "NO"
  ##
  ##################################################
  ##
  ## Disable announces. (0 = No, 1 = Yes)
  set ${np}::disable(IMDB)                   0
  set ${np}::disable(IMDBFIND)               0
  set ${np}::disable(IMDBVAR)                0
  set ${np}::disable(IMDBFINDVAR)            0
  ##
  ## Convert empty or zero variables into something else.
  ## If you use MYOWN these are not used, see psxc-imdb.conf
  set ${np}::zeroconvert(%imdbdirname)       "N/A"
  set ${np}::zeroconvert(%imdburl)           "N/A"
  set ${np}::zeroconvert(%imdbtitle)         "N/A"
  set ${np}::zeroconvert(%imdbgenre)         "N/A"
  set ${np}::zeroconvert(%imdbrating)        "N/A"
  set ${np}::zeroconvert(%imdbcountry)       "N/A"
  set ${np}::zeroconvert(%imdblanguage)      "N/A"
  set ${np}::zeroconvert(%imdbcertification) "N/A"
  set ${np}::zeroconvert(%imdbruntime)       "N/A"
  set ${np}::zeroconvert(%imdbdirector)      "N/A"
  set ${np}::zeroconvert(%imdbbusinessdata)  "N/A"
  set ${np}::zeroconvert(%imdbpremiereinfo)  "N/A"
  set ${np}::zeroconvert(%imdblimitedinfo)   "N/A"
  set ${np}::zeroconvert(%imdbvotes)         "Less than 5"
  set ${np}::zeroconvert(%imdbscore)         "0"
  set ${np}::zeroconvert(%imdbname)          "N/A"
  set ${np}::zeroconvert(%imdbyear)          "N/A"
  set ${np}::zeroconvert(%imdbnumscreens)    "N/A"
  set ${np}::zeroconvert(%imdbislimited)     "No idea."
  set ${np}::zeroconvert(%imdbcastleadname)  "Uknown"
  set ${np}::zeroconvert(%imdbcastleadchar)  "Uknown"
  set ${np}::zeroconvert(%imdbtagline)       "No info found."
  set ${np}::zeroconvert(%imdbplot)          "No info found."
  set ${np}::zeroconvert(%imdbbar)           ".........."
  set ${np}::zeroconvert(%imdbcasting)       "N/A"
  set ${np}::zeroconvert(%imdbcommentshort)  "N/A"
  ##
  ##################################################

  set psxc(VERSION) "2.9m"

  variable events [list "IMDB" "IMDBVAR" "IMDBFIND" "IMDBFINDVAR"]
  variable psxcimdb
  variable scriptFile [info script]
  variable scriptName ${ns}::LogEvent

  #bind evnt -|- prerehash ${ns}::deinit
}
proc ::ngBot::plugin::psxc-IMDb::init {} {
  variable ns
  variable np
  variable psxc
  variable events
  variable psxcimdb
  variable scriptName
  variable scriptFile
  variable ${np}::msgtypes
  variable ${np}::variables
  variable ${np}::precommand

  lappend msgtypes(SECTION) "IMDB" "IMDBVAR"
  lappend msgtypes(DEFAULT) "IMDBFIND" "IMDBFINDVAR"
  set variables(IMDB)        "%pf %msg %imdbdestination"
  set variables(IMDBFIND)    "%pf %msg %imdbdestination"
  set variables(IMDBVAR)     "%pf %imdbdirname %imdburl %imdbtitle %imdbgenre %imdbrating %imdbcountry %imdblanguage %imdbcertification %imdbruntime %imdbdirector %imdbbusinessdata %imdbpremiereinfo %imdblimitedinfo %imdbvotes %imdbscore %imdbname %imdbyear %imdbnumscreens %imdbislimited %imdbcastleadname %imdbcastleadchar %imdbtagline %imdbplot %imdbbar %imdbcasting %imdbcommentshort %imdbdestination"
  set variables(IMDBFINDVAR) "%pf %imdbdirname %imdburl %imdbtitle %imdbgenre %imdbrating %imdbcountry %imdblanguage %imdbcertification %imdbruntime %imdbdirector %imdbbusinessdata %imdbpremiereinfo %imdblimitedinfo %imdbvotes %imdbscore %imdbname %imdbyear %imdbnumscreens %imdbislimited %imdbcastleadname %imdbcastleadchar %imdbtagline %imdbplot %imdbbar %imdbcasting %imdbcommentshort %imdbdestination"

  set theme_file [file normalize "[pwd]/[file rootname $scriptFile].zpt"]
  if {[file isfile $theme_file]} {
    ${np}::loadtheme $theme_file true
  }

  ## Register the event handler.
  foreach event $events {
    lappend precommand($event) $scriptName
  }

  set psxc(ERROR) 0
  set psxc(MODES) [list]

  ## Check existance of files and start reading the log
  if {[string is true -strict $psxc(USEBOT)]} {
    if {![file exist $psxc(IMDBLOG)]} {
      ${ns}::Error "IMDBLOG: $psxc(IMDBLOG) not found."
      set psxc(ERROR) 1
    }

    if {![file exist $psxc(IMDBSCRIPT)]} {
      ${ns}::Error "IMDBSCRIPT: $psxc(IMDBSCRIPT) not found."
      set psxc(ERROR) 1
    }

    if {$psxc(ERROR) == 0} {
      set psxcimdb(log) 0

      ${ns}::ReadIMDb

      lappend psxc(MODES) "Logging"
    }
  }

  if {[string is true -strict $psxc(USEFULL)]} {
    if {![file exist $psxc(IMDBMOVIE)]} {
      ${ns}::Error "IMDBMOVIE: $psxc(IMDBMOVIE) not found."
      set psxc(ERROR) 1
    }

    if {$psxc(ERROR) == 0} {
      set psxcimdb(movie) [file size $psxc(IMDBMOVIE)]

      ${ns}::ShowIMDb

      lappend psxc(MODES) "Full"
    }
  }

  if {[string is true -strict $psxc(USEPRE)]} {
    if {![file exist $psxc(PRELOG)]} {
      ${ns}::Error "PRELOG $psxc(PRELOG) not found."
      set psxc(ERROR) 1
    }
    if {![file exist $psxc(PRESCRIPT)]} {
      ${ns}::Error "PRESCRIPT: $psxc(PRESCRIPT) not found."
      set psxc(ERROR) 1
    }

    if {$psxc(ERROR) == 0} {
      set psxcimdb(prelog) 0

      ${ns}::PreIMDb

      lappend psxc(MODES) "Pre"
    }
  }

  if {[string is true -strict $psxc(USEFIND)]} {
    if {![file exist $psxc(FINDSCRIPT)]} {
      ${ns}::Error "FINDSCRIPT: $psxc(FINDSCRIPT) not found."
      set psxc(ERROR) 1
    }

    if {$psxc(ERROR) == 0} {
      bind pub -|- $psxc(FINDTRIG) ${ns}::Search
      bind msg -|- $psxc(FINDTRIG) ${ns}::SearchDcc
      lappend psxc(MODES) "Find"
    }
  }

  if {$psxc(ERROR) != 0} {
    ${ns}::Error "Errors in config - please check."
    return -code -1
  } else {
    if {[llength $psxc(MODES)] == 0} {
      lappend psxc(MODES) "None"
    }

    ${ns}::Debug "Loaded successfully. (Modes Enabled: [join $psxc(MODES) ", "])"
  }
}

proc ::ngBot::plugin::psxc-IMDb::deinit {} {
  variable ns
  variable np
  variable psxc
  variable events
  variable scriptName
  variable ${np}::precommand

  ## Remove the script event from precommand.
  foreach event $events {
    if {[info exists precommand($event)] && [set pos [lsearch -exact $precommand($event) $scriptName]] !=  -1} {
      set precommand($event) [lreplace $precommand($event) $pos $pos]
    }
  }

  #catch {unbind pub -|- $psxc(FINDTRIG) ${ns}::Search}
  #catch {unbind msg -|- $psxc(FINDTRIG) ${ns}::SearchDcc}
  #catch {unbind evnt -|- prerehash ${ns}::deinit}

  namespace delete $ns
}

proc ::ngBot::plugin::psxc-IMDb::Error {error} {
  putlog "\[ngBot\] psxc-imdb :: Error: $error"
}

proc ::ngBot::plugin::psxc-IMDb::Debug {error} {
  putlog "\[ngBot\] psxc-imdb :: $error"
}

proc ::ngBot::plugin::psxc-IMDb::LogEvent {event section logData} {
  variable np

  set target [lindex $logData end]

  if {[string equal $target ""]} {
    ${np}::sndall $event $section [${np}::ng_format $event $section $logData]
  } else {
    ${np}::sndone $target [${np}::ng_format $event $section $logData] $section
  }

  ## Silence default output.
  return 0
}

proc ::ngBot::plugin::psxc-IMDb::ReadIMDb {} {
  variable ns
  variable psxc
  variable psxcimdb

  utimer 5 [list ${ns}::ReadIMDb]

  set psxclogsize [file size $psxc(IMDBLOG)]

  if {$psxclogsize == $psxcimdb(log)} {
    return 0
  }

  if {$psxclogsize < $psxcimdb(log)} {
    set psxcimdb(log) 0
  }

  if {![string is true -strict $psxc(NODEFUNCT)]} {
    set result [catch {exec $psxc(IMDBSCRIPT) &} psxcaout]
  } else {
    set result [catch {exec $psxc(IMDBSCRIPT)} psxcaout]
  }

  if {$result != 0} {
    ${ns}::Error $psxcaout
  }

  set psxcimdb(log) [file size $psxc(IMDBLOG)]

  return 0
}

proc ::ngBot::plugin::psxc-IMDb::ShowIMDb {} {
  variable ns
  variable psxc
  variable psxcimdb

  utimer 5 [list ${ns}::ShowIMDb]

  set psxcmoviesize [file size $psxc(IMDBMOVIE)]

  if {$psxcmoviesize == $psxcimdb(movie)} {
    return 0
  }

  if {$psxcmoviesize  < $psxcimdb(movie)} {
    set psxcimdb(movie) 0
  }

  if {[catch {open $psxc(IMDBMOVIE) r} fp] != 0} {
    return 0
  }

  seek $fp $psxcimdb(movie)

  while {![eof $fp]} {
    set psxcline [gets $fp]

    if {[string equal $psxcline ""]} {
      continue
    }

    set psxcthr [lindex $psxcline 7]
    set psxcdst [lindex $psxcline 8]

    if {[string equal $psxcdst ""]} {
      foreach psxcimdbchan $psxc(IMDBCHANNEL) {
        foreach psxcln [split $psxcthr "$psxc(NEWLINE)"] {
          putserv "PRIVMSG $psxcimdbchan :$psxc(IMDBTRIG) $psxcln"
        }
      }
    } else {
      foreach psxcln [split $psxcthr "$psxc(NEWLINE)"] {
        putserv "PRIVMSG $psxcdst :$psxc(IMDBTRIG) $psxcln"
      }
    }
  }

  close $fp

  set psxcimdb(movie) [file size $psxc(IMDBMOVIE)]

  return 0
}

proc ::ngBot::plugin::psxc-IMDb::PreIMDb {} {
  variable ns
  variable psxc
  variable psxcimdb

  utimer 5 [list ${ns}::PreIMDb]

  set psxcpresize [file size $psxc(PRELOG)]

  if {$psxcpresize == $psxcimdb(prelog)} {
    return 0
  }

  if {$psxcpresize < $psxcimdb(prelog)} {
    set psxcimdb(prelog) 0
  }

  if {[catch {exec $psxc(PRESCRIPT)} psxccout] != 0} {
    ${ns}::Error $psxccout
    return
  }

  set psxcimdb(prelog) [file size $psxc(PRELOG)]

  return 0
}

proc ::ngBot::plugin::psxc-IMDb::Search {nick uhost handle chan text} {
  variable ns
  variable psxc

  if {[catch {exec $psxc(FINDSCRIPT) $chan $text} psxcimdbfindlog] != 0} {
    ${ns}::Error $psxcimdbfindlog
    putserv "PRIVMSG $chan :Error..."
    return
  }

  foreach psxcline [split $psxcimdbfindlog "\n"] {
    putserv "PRIVMSG $chan :$psxcline"
  }
}

proc SearchDcc {nick uhost handle text} {
  variable ns
  variable psxc

  set psxcexec $psxc(FINDSCRIPT)
  if {![string equal $text ""]} {
    #set result [catch {exec $psxcexec $nick $text -p -l1} psxcimdbfindlog]
    set result [catch {exec $psxcexec $nick $text} psxcimdbfindlog]
  } else {
    set result [catch {exec $psxcexec} psxcimdbfindlog]
  }

  if {$result != 0} {
    ${ns}::Error $psxcimdbfindlog
    putserv "PRIVMSG $nick :Error..."
    return
  }

  foreach psxcline [split $psxcimdbfindlog "\n"] {
    putserv "PRIVMSG $nick :$psxcline"
  }
}

