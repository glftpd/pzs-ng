#################################################################################
# ngBot - PreTimeSQL Plug-in (MySQLManager Edition)                             #
#                                                                               #
# Author: ZarTek-Creole (https://github.com/ZarTek-Creole)                      #
# Repo:   https://github.com/ZarTek-Creole/pzs-PreTimeSQL                       #
#                                                                               #
#################################################################################
#
# Description:
# - Announces the "pre time" of a release upon NEWDIR events.
# - Uses the centralized MySQLManager plugin for database connections.
# - Replaces the standard NEWDIR announce with a custom, themable one.
#
# Features:
# - Automatic Table Creation: Creates and indexes the database table on first run.
# - Auto-Add Releases: Can be configured to automatically add new releases to the
#   database if they are not found.
# - Auto-Update Timestamps: Can update releases that exist in the database but
#   have a NULL timestamp.
# - Rich Data Storage: Optionally stores extra information like section, sitename,
#   uploader details, event type, and release group.
# - Highly Configurable: Table and column names can be changed. All features
#   can be toggled.
# - Directory Exclusion: A configurable list to ignore announcements for
#   specific directories (e.g., sample, subs).
#
# Installation:
# 1. Ensure the 'MySQLManager' plugin is installed and loaded BEFORE this one.
# 2. Place PreTimeSQL.tcl and PreTimeSQL.zpt in your pzs-ng/plugins/ folder.
# 3. Add to your eggdrop.conf:
#    source pzs-ng/plugins/PreTimeSQL.tcl
# 4. Configure the variables in the "Config Settings" section below.
# 5. Rehash or restart your eggdrop. The table will be created if it doesn't exist.
#
# Database Schema:
# The plugin automatically creates a table with the following structure.
# Column names can be changed in the config.
#
# CREATE TABLE IF NOT EXISTS `pre_times` (
#   `id` INT(11) UNSIGNED AUTO_INCREMENT NOT NULL,
#   `release_name` VARCHAR(255) NOT NULL,
#   `pre_timestamp` INT(11) UNSIGNED DEFAULT NULL,
#   `section` VARCHAR(255) DEFAULT NULL,
#   `sitename` VARCHAR(255) DEFAULT NULL,
#   `uploader_nick` VARCHAR(255) DEFAULT NULL,
#   `uploader_group` VARCHAR(255) DEFAULT NULL,
#   `event` VARCHAR(50) DEFAULT NULL,
#   `group_name` VARCHAR(255) DEFAULT NULL,
#   PRIMARY KEY (`id`),
#   UNIQUE KEY `idx_release_name` (`release_name`),
#   INDEX `idx_pre_timestamp` (`pre_timestamp`),
#   INDEX `idx_section` (`section`),
#   INDEX `idx_sitename` (`sitename`),
#   INDEX `idx_uploader_nick` (`uploader_nick`),
#   INDEX `idx_uploader_group` (`uploader_group`),
#   INDEX `idx_event` (`event`),
#   INDEX `idx_group_name` (`group_name`)
# ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
#
#################################################################################

namespace eval ::ngBot::plugin::PreTimeSQL {
  variable ns [namespace current]
  variable np [namespace qualifiers [namespace parent]]

  ## Config Settings ###############################
  ##
  ## Name of the MySQLManager connection to use.
  variable conn_name "default"
  ##
  ## Name of the database table for pre times.
  variable table_name "pre_times"
  ##
  ## Column names for the pre time table.
  variable col_id "id"; # Primary Key
  variable col_release_name "release_name"; # Required
  variable col_pre_timestamp "pre_timestamp"; # Required
  ##
  ## Optional columns for extra information.
  ## Leave the variable empty ("") to disable the column.
  variable col_section_name "section"
  variable col_sitename "sitename"
  variable col_uploader_nick "uploader_nick"
  variable col_uploader_group "uploader_group"; #
  variable col_event_name "event"; # NEWDIR
  variable col_group_name "group_name"; # Extracted from release name
  ##
  ## If a pre time is older than this (in minutes), it is considered "old"
  ## and OLDPRETIME is announced instead of NEWPRETIME.
  variable lateMins 10
  ##
  ## Skip pre time lookup for these directories (glob patterns).
  variable ignoreDirs {cd[0-9] dis[ck][0-9] dvd[0-9] codec cover covers extra extras sample subs vobsub vobsubs proof}
  ##
  ## Automatically add releases to the database if they are not found.
  ## (0 = No, 1 = Yes)
  variable add_missing_releases 1
  ##
  ## If a release exists but has no timestamp, update it.
  ## (0 = No, 1 = Yes)
  variable update_null_timestamp 1
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
proc ::ngBot::plugin::PreTimeSQL::init {args} {
  variable np
  variable ns
  variable version
  variable scriptFile
  variable scriptName
  variable ${np}::variables
  variable ${np}::precommand

  ## Check if MySQLManager is loaded.
  if {![namespace exists ::ngBot::ngSQL]} {
    Error "MySQLManager (::ngBot::ngSQL) is not loaded. This plugin cannot function."
    return -code error
  }

  ## Set the variables for the announce.
  set variables(NEWPRETIME) "%pf %u_name %g_name %u_tagline %preage %predate %pretime"
  set variables(OLDPRETIME) "%pf %u_name %g_name %u_tagline %preage %predate %pretime"

  ## Load the theme file if it exists.
  set theme_file [file normalize "[pwd]/[file rootname $scriptFile].zpt"]
  if {[file isfile $theme_file]} {
    ${np}::loadtheme $theme_file true
  }

  # Create the database table if it doesn't exist.
  if {[catch {${ns}::CreateTable} errMsg]} {
    Error "Failed to create database table: $errMsg"
    return -code error
  }

  ## Register the event handler.
  lappend precommand(NEWDIR) $scriptName
  Debug "Loaded successfully (Version: $version)."
  return
}

proc ::ngBot::plugin::PreTimeSQL::deinit {args} {
  variable np
  variable scriptName
  variable ${np}::precommand

  ## Remove the script event from precommand.
  if {[info exists precommand(NEWDIR)] && [set pos [lsearch -exact $precommand(NEWDIR) $scriptName]] !=  -1} {
    set precommand(NEWDIR) [lreplace $precommand(NEWDIR) $pos $pos]
  }

  ## Delete the namespace.
  namespace delete [namespace current]
  return
}

proc ::ngBot::plugin::PreTimeSQL::Debug {msg} { putlog "\[ngBot\] PreTimeSQL :: $msg" }
proc ::ngBot::plugin::PreTimeSQL::Error {error} { putlog "\[ngBot\] PreTimeSQL Error :: $error" }

proc ::ngBot::plugin::PreTimeSQL::CreateTable {} {
  variable conn_name
  variable table_name
  variable col_id
  variable col_release_name
  variable col_pre_timestamp
  variable col_section_name
  variable col_sitename
  variable col_uploader_nick
  variable col_uploader_group
  variable col_event_name
  variable col_group_name

  set sql "CREATE TABLE IF NOT EXISTS `$table_name` (
  `$col_id` INT(11) UNSIGNED AUTO_INCREMENT NOT NULL,
  `$col_release_name` VARCHAR(255) NOT NULL,
  `$col_pre_timestamp` INT(11) UNSIGNED DEFAULT NULL,"

  if {[string length $col_section_name] > 0}   { append sql "\n  `$col_section_name` VARCHAR(255) DEFAULT NULL," }
  if {[string length $col_sitename] > 0}       { append sql "\n  `$col_sitename` VARCHAR(255) DEFAULT NULL," }
  if {[string length $col_uploader_nick] > 0}  { append sql "\n  `$col_uploader_nick` VARCHAR(255) DEFAULT NULL," }
  if {[string length $col_uploader_group] > 0} { append sql "\n  `$col_uploader_group` VARCHAR(255) DEFAULT NULL," }
  if {[string length $col_event_name] > 0}     { append sql "\n  `$col_event_name` VARCHAR(50) DEFAULT NULL," }
  if {[string length $col_group_name] > 0}     { append sql "\n  `$col_group_name` VARCHAR(255) DEFAULT NULL," }

  append sql "
  PRIMARY KEY (`$col_id`),
  UNIQUE KEY `idx_release_name` (`$col_release_name`),
  INDEX `idx_pre_timestamp` (`$col_pre_timestamp`)"

  if {[string length $col_section_name] > 0}   { append sql ",\n  INDEX `idx_section` (`$col_section_name`)" }
  if {[string length $col_sitename] > 0}       { append sql ",\n  INDEX `idx_sitename` (`$col_sitename`)" }
  if {[string length $col_uploader_nick] > 0}  { append sql ",\n  INDEX `idx_uploader_nick` (`$col_uploader_nick`)" }
  if {[string length $col_uploader_group] > 0} { append sql ",\n  INDEX `idx_uploader_group` (`$col_uploader_group`)" }
  if {[string length $col_event_name] > 0}     { append sql ",\n  INDEX `idx_event` (`$col_event_name`)" }
  if {[string length $col_group_name] > 0}     { append sql ",\n  INDEX `idx_group_name` (`$col_group_name`)" }

  append sql "\n) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;"

  set result [::ngBot::ngSQL::exec $conn_name $sql]
  if {[lindex $result 0] eq "error"} {
    return -code error [lindex $result 1]
  }
  return
}

proc ::ngBot::plugin::PreTimeSQL::AddRelease {release_name pre_timestamp {extra_data {}}} {
  variable conn_name
  variable table_name
  variable col_release_name
  variable col_pre_timestamp
  variable col_section_name
  variable col_sitename
  variable col_uploader_nick
  variable col_uploader_group
  variable col_event_name
  variable col_group_name

  set insert_dict [dict create $col_release_name $release_name $col_pre_timestamp $pre_timestamp]

  if {[string length $col_section_name] > 0 && [dict exists $extra_data section]}         { dict set insert_dict $col_section_name [dict get $extra_data section] }
  if {[string length $col_sitename] > 0 && [dict exists $extra_data sitename]}            { dict set insert_dict $col_sitename [dict get $extra_data sitename] }
  if {[string length $col_uploader_nick] > 0 && [dict exists $extra_data uploader_nick]}  { dict set insert_dict $col_uploader_nick [dict get $extra_data uploader_nick] }
  if {[string length $col_uploader_group] > 0 && [dict exists $extra_data uploader_group]} { dict set insert_dict $col_uploader_group [dict get $extra_data uploader_group] }
  if {[string length $col_event_name] > 0 && [dict exists $extra_data event]}             { dict set insert_dict $col_event_name [dict get $extra_data event] }
  if {[string length $col_group_name] > 0 && [dict exists $extra_data group_name]}       { dict set insert_dict $col_group_name [dict get $extra_data group_name] }

  set query [::ngBot::ngSQL::insert $conn_name $table_name]
  $query values $insert_dict
  set result [$query execute]

  if {[lindex $result 0] eq "error"} {
    return -code error [lindex $result 1]
  }
  return
}

proc ::ngBot::plugin::PreTimeSQL::UpdateReleaseTimestamp {release_name pre_timestamp {extra_data {}}} {
  variable conn_name
  variable table_name
  variable col_release_name
  variable col_pre_timestamp
  variable col_section_name
  variable col_sitename
  variable col_uploader_nick
  variable col_uploader_group
  variable col_event_name
  variable col_group_name

  set update_dict [dict create $col_pre_timestamp $pre_timestamp]

  if {[string length $col_section_name] > 0 && [dict exists $extra_data section]}         { dict set update_dict $col_section_name [dict get $extra_data section] }
  if {[string length $col_sitename] > 0 && [dict exists $extra_data sitename]}            { dict set update_dict $col_sitename [dict get $extra_data sitename] }
  if {[string length $col_uploader_nick] > 0 && [dict exists $extra_data uploader_nick]}  { dict set update_dict $col_uploader_nick [dict get $extra_data uploader_nick] }
  if {[string length $col_uploader_group] > 0 && [dict exists $extra_data uploader_group]} { dict set update_dict $col_uploader_group [dict get $extra_data uploader_group] }
  if {[string length $col_event_name] > 0 && [dict exists $extra_data event]}             { dict set update_dict $col_event_name [dict get $extra_data event] }
  if {[string length $col_group_name] > 0 && [dict exists $extra_data group_name]}       { dict set update_dict $col_group_name [dict get $extra_data group_name] }

  set query [::ngBot::ngSQL::update $conn_name $table_name]
  $query set $update_dict
  $query where $col_release_name "=" $release_name
  set result [$query execute]

  if {[lindex $result 0] eq "error"} {
    return -code error [lindex $result 1]
  }
  return
}

####
# PreTimeSQL::LookUp
#
# Look up the pre time of the release.
# Returns:
#   0 - Release not found.
#   1 - Release found with a valid timestamp.
#   2 - Release found, but timestamp is NULL or invalid.
#
proc ::ngBot::plugin::PreTimeSQL::LookUp {release_name timeVar} {
  variable conn_name
  variable table_name
  variable col_release_name
  variable col_pre_timestamp
  upvar $timeVar preTime

  ## Build the query.
  set result [::ngBot::ngSQL::select $conn_name $table_name]
  $result where $col_release_name "=" $release_name
  $result columns [list $col_pre_timestamp]
  $result asDict

  ## Execute the query.
  set query_result [$result execute]

  ## Check if the query returned any results.
  if {[llength $query_result] > 0} {
    # Result is a list of dictionaries, get the timestamp from the first row.
    set preTime [dict get [lindex $query_result 0] $col_pre_timestamp]

    if {[string is integer -strict $preTime] && $preTime > 0} {
      ## Return 1 to indicate a valid timestamp was found.
      return 1
    } else {
      ## Return 2 to indicate the release was found, but the timestamp is NULL/invalid.
      return 2
    }
  }

  ## Return 0 to indicate that the release was not found.
  return 0
}

####
# PreTimeSQL::LogEvent
#
# Called by the sitebot's event handler on the "NEWDIR" announce.
#
proc ::ngBot::plugin::PreTimeSQL::LogEvent {event section logData} {
  variable np
  variable ns
  variable lateMins
  variable ignoreDirs
  variable conn_name
  variable add_missing_releases
  variable update_null_timestamp

  ## Check if the event is a NEWDIR event.
  if {![string equal "NEWDIR" $event]} { return 1 }

  ## Check if the MySQL connection is up.
  if {![::ngBot::ngSQL::ping $conn_name]} {
    Error "MySQL connection '$conn_name' is down. Skipping pre-time."
    return 1
  }

  ## Log Data:
  ## NEWDIR - path user group tagline
  set release [file tail [lindex $logData 0]]

  ## Extract group name from release name (part after last hyphen).
  set group_name ""
  set last_hyphen [string last "-" $release]
  if {$last_hyphen != -1} {
    set group_name [string range $release [expr {$last_hyphen + 1}] end]
  }

  ## Check if the release is in the ignore list.
  foreach ignore $ignoreDirs {
    if {[string match -nocase $ignore $release]} { return 1 }
  }

  set preTime ""
  set lookup_status [${ns}::LookUp $release preTime]

  switch -- $lookup_status {
    0 {
      # Not found.
      if {![istrue $add_missing_releases]} { return 1 }

      set preTime [clock seconds]
      if {[catch {
        set extra_data [dict create \
          event $event \
          section $section \
          sitename $::ngBot::sitename \
          uploader_nick [lindex $logData 1] \
          uploader_group [lindex $logData 2] \
          group_name $group_name]
        ${ns}::AddRelease $release $preTime $extra_data
      } errMsg]} {
        Error "Failed to add missing release '$release': $errMsg"
        return 1
      }
      Debug "Added missing release '$release' to the database."
    }
    1 {
      # Found with a valid timestamp. The preTime variable is already set by LookUp.
    }
    2 {
      # Found, but with a NULL timestamp.
      if {![istrue $update_null_timestamp]} { return 1 }

      set preTime [clock seconds]
      if {[catch {
        set extra_data [dict create \
          event $event \
          section $section \
          sitename $::ngBot::sitename \
          uploader_nick [lindex $logData 1] \
          uploader_group [lindex $logData 2] \
          group_name $group_name]
        ${ns}::UpdateReleaseTimestamp $release $preTime $extra_data
      } errMsg]} {
        Error "Failed to update timestamp for release '$release': $errMsg"
        return 1
      }
      Debug "Updated NULL timestamp for release '$release'."
    }
    default {
      # Should not happen.
      return 1
    }
  }

  # If we reach here, we have a valid preTime (found, added, or updated).
  # Now we can proceed with the announcement.

  ## Check if the pre is older than the defined time.
  set preAge [expr {[clock seconds] - $preTime}]
  if {$preAge > ($lateMins * 60)} {
    set event "OLDPRETIME"
  } else {
    set event "NEWPRETIME"
  }

  ## Format the pre time and append it to the log data.
  set formatDate [clock format $preTime -format "%m/%d/%y"]
  set formatTime [clock format $preTime -format "%H:%M:%S"]

  lappend logData [${np}::format_duration $preAge] $formatDate $formatTime
  ## We'll announce the event ourself since we'll return zero
  ## to cancel the regular NEWDIR announce.
  ${np}::sndall $event $section [${np}::ng_format $event $section $logData]

  ## Return 0 to indicate that the event was handled.
  return 0
}
