#################################################################################
# ngBot - PreTimeSQL Plug-in (MySQLManager Edition)                             #
#                                                                               #
# Authors:                                                                      #
# - ZarTek-Creole (https://github.com/ZarTek-Creole)                            #
#                                                                               #
#################################################################################
#
# Description:
# - Announces the "pre time" of a release upon NEWDIR events.
# - Uses the centralized MySQLManager for database connections.
# - If a pre time is not found, the standard NEWDIR announce is shown.
#
# Installation:
# 1. Edit the configuration options below.
# 2. Add the following to your eggdrop.conf:
#    source pzs-ng/plugins/PreTimeSQL.tcl
# 3. Add a connection named "pre_db" (or your choice) to MySQLManager.tcl.
# 4. Rehash or restart your eggdrop for the changes to take effect.
#
#################################################################################

namespace eval ::ngBot::plugin::PreTimeSQL {
  variable ns [namespace current]
  variable np [namespace qualifiers [namespace parent]]

  ## Config Settings ###############################
  ##
  ## Name of the MySQLManager connection to use.
  variable conn_name "pre_db"
  ##
  ## Name of the database table for pre times.
  variable table_name "pre_times"
  ##
  ## Column names for the pre time table.
  variable col_release_name "release_name"
  variable col_pre_timestamp "pre_timestamp"
  ##
  ## If a pre time is older than this (in minutes), it is considered "old"
  ## and OLDPRETIME is announced instead of NEWPRETIME.
  variable lateMins 10
  ##
  ## Skip pre time lookup for these directories (glob patterns).
  variable ignoreDirs {cd[0-9] dis[ck][0-9] dvd[0-9] codec cover covers extra extras sample subs vobsub vobsubs proof}
  ##
  ## Disable announces. (0 = No, 1 = Yes)
  set ${np}::disable(NEWPRETIME) 0
  set ${np}::disable(OLDPRETIME) 0
  ##
  ##################################################

  variable version "20250630"
  variable scriptFile [info script]
  variable scriptName ${ns}::LogEvent
}
proc ::ngBot::plugin::init {args} {
  variable np
  variable ns
  variable version
  variable scriptFile
  variable scriptName
  variable ${np}::variables
  variable ${np}::precommand

  if {![namespace exists ::ngBot::ngSQL]} {
    Error "MySQLManager (::ngBot::ngSQL) is not loaded. This plugin cannot function."
    return -code error
  }

  set variables(NEWPRETIME) "%pf %u_name %g_name %u_tagline %preage %predate %pretime"
  set variables(OLDPRETIME) "%pf %u_name %g_name %u_tagline %preage %predate %pretime"

  set theme_file [file normalize "[pwd]/[file rootname $scriptFile].zpt"]
  if {[file isfile $theme_file]} {
    ${np}::loadtheme $theme_file true
  }

  # Create the database table if it doesn't exist.
  if {[catch {${ns}::CreateTable} errMsg]} {
    Error "Failed to create database table: $errMsg"
    return -code error
  }

  lappend precommand(NEWDIR) $scriptName
  Debug "Loaded successfully (Version: $version)."
  return
}

proc ::ngBot::plugin::deinit {args} {
  variable np
  variable scriptName
  variable ${np}::precommand

  if {[info exists precommand(NEWDIR)] && [set pos [lsearch -exact $precommand(NEWDIR) $scriptName]] != -1} {
    set precommand(NEWDIR) [lreplace $precommand(NEWDIR) $pos $pos]
  }
  namespace delete [namespace current]
  return
}

proc ::ngBot::plugin::Debug {msg} { putlog "\[ngBot\] PreTimeSQL :: $msg" }
proc ::ngBot::plugin::Error {error} { putlog "\[ngBot\] PreTimeSQL Error :: $error" }

proc ::ngBot::plugin::CreateTable {} {
  variable conn_name
  variable table_name
  variable col_release_name
  variable col_pre_timestamp

  set sql "CREATE TABLE IF NOT EXISTS `$table_name` (
  `$col_release_name` VARCHAR(255) NOT NULL,
  `$col_pre_timestamp` INT(11) UNSIGNED NOT NULL,
  PRIMARY KEY (`$col_release_name`),
  INDEX `idx_pre_timestamp` (`$col_pre_timestamp`)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;"

  set result [::ngBot::ngSQL::exec $conn_name $sql]
  if {[lindex $result 0] eq "error"} {
    return -code error [lindex $result 1]
  }
  return
}

proc ::ngBot::plugin::LookUp {release_name timeVar} {
  variable conn_name
  variable table_name
  variable col_release_name
  variable col_pre_timestamp
  upvar $timeVar preTime

  set result [::ngBot::ngSQL::select $conn_name $table_name]
  $result where $col_release_name "=" $release_name
  $result columns [list $col_pre_timestamp]
  $result asDict

  set query_result [$result execute]

  if {[llength $query_result] > 0} {
    # Result is a list of dictionaries, get the timestamp from the first row.
    set preTime [dict get [lindex $query_result 0] $col_pre_timestamp]
    return 1
  }
  return 0
}

proc ::ngBot::plugin::LogEvent {event section logData} {
  variable np
  variable ns
  variable lateMins
  variable ignoreDirs
  variable conn_name

  if {![string equal "NEWDIR" $event]} { return 1 }

  if {![::ngBot::ngSQL::ping $conn_name]} {
    Error "MySQL connection '$conn_name' is down. Skipping pre-time."
    return 1
  }

  set release [file tail [lindex $logData 0]]

  foreach ignore $ignoreDirs {
    if {[string match -nocase $ignore $release]} { return 1 }
  }

  if {[${ns}::LookUp $release preTime]} {
    set preAge [expr {[clock seconds] - $preTime}]
    if {$preAge > ($lateMins * 60)} {
      set event "OLDPRETIME"
    } else {
      set event "NEWPRETIME"
    }

    set formatDate [clock format $preTime -format "%m/%d/%y"]
    set formatTime [clock format $preTime -format "%H:%M:%S"]
    lappend logData [${np}::format_duration $preAge] $formatDate $formatTime

    ${np}::sndall $event $section [${np}::ng_format $event $section $logData]
    return 0
  }
  return 1
}
