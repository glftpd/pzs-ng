#################################################################################
# ngBot - NickDbSQL Plug-in (with MySQLManager)                                     #
#################################################################################
#
# Description:
# - Maintains mapping between IRC nicknames and FTP usernames
# - Requires the MySQLManager plugin to handle database connections.
# - Original concept by compieter
#
# Version: 1.0.0
# Author: ZarTek-Creole
# URL: https://github.com/ZarTek-Creole/ng-mysql-manager
#
# Requirements:
# - MySQLManager plugin (MySQLManager.tcl)
# - Tcl 8.6+
#
# Installation:
# 1. Ensure MySQLManager.tcl is installed and configured.
# 2. Add to eggdrop.conf (AFTER MySQLManager.tcl):
#    source pzs-ng/plugins/NickDbSQL.tcl
# 3. Restart or rehash eggdrop.
#
#################################################################################

namespace eval ::ngBot::plugin::NickDbSQL {
  variable ns [namespace current]
  variable np [namespace qualifiers [namespace parent]]

  # --- CONFIGURATION ---
  # Connection name defined in MySQLManager.tcl
  variable db_conn_name "NickDbSQL"

  # Host Management
  variable hostChange True    ;# Enable host masking
  variable hostFormat "%(user).Users.PZS-NG.com" ;# Hostmask pattern
  variable hostExempt "=STAFF =SiTEOPS 1" ;# Exempt groups/accounts
  # ---------------------

  namespace export GetFtpUser GetIrcUser
  variable scriptName [namespace current]::InviteEvent

  bind nick -|- "*" [namespace current]::NickChange
  bind evnt - prerehash [namespace current]::deinit

  interp alias {} IsTrue {} string is true -strict
  interp alias {} IsFalse {} string is false -strict
}

####
# NickDbSQL::CreateTable
# Creates the database table if it doesn't exist
proc ::ngBot::plugin::NickDbSQL::CreateTable {} {
  variable db_conn_name

  set sql {
    CREATE TABLE IF NOT EXISTS UserNames (
    time INT NOT NULL,
    ircUser VARCHAR(255) NOT NULL,
    ftpUser VARCHAR(255) NOT NULL,
    PRIMARY KEY (ftpUser),
    INDEX ircUser_idx (ircUser),
    INDEX time_idx (time)
    )
  }

  set result [::ngBot::ngSQL::exec $db_conn_name $sql]
  if {[lindex $result 0] eq "error"} {
    error "Could not create UserNames table: [lindex $result 1]"
  }
}

####
# NickDbSQL::init
# Plugin initialization
proc ::ngBot::plugin::NickDbSQL::init {args} {
  variable np
  variable scriptName
  variable ${np}::postcommand

  putlog "\[ngBot\] Initializing NickDbSQL (for MySQLManager)"

  # Check if the API namespace exists
  if {![namespace exists ::ngBot::ngSQL]} {
    error "NickDbSQL requires the MySQLManager plugin. Please load it first."
  }

  # Create table if needed
  CreateTable

  lappend postcommand(INVITEUSER) $scriptName
  putlog "\[ngBot\] NickDbSQL: Initialization complete."
}

####
# NickDbSQL::deinit
# Cleanup on script reload or shutdown
proc ::ngBot::plugin::NickDbSQL::deinit {args} {
  variable np
  variable ${np}::postcommand
  variable scriptName

  catch {unbind nick -|- "*" [namespace current]::NickChange}
  catch {unbind evnt - prerehash [namespace current]::deinit}

  if {[info exists postcommand(INVITEUSER)] && \
    [set pos [lsearch -exact $postcommand(INVITEUSER) $scriptName]] != -1} {
    set postcommand(INVITEUSER) [lreplace $postcommand(INVITEUSER) $pos $pos]
  }

  putlog "\[ngBot\] NickDbSQL: Deinitialized."
}

####
# NickDbSQL::StripName
# Sanitizes names for IRC compatibility
proc ::ngBot::plugin::NickDbSQL::StripName {name} {
  return [regsub -all {[^\w\[\]\{\}\-\`\^\\]+} $name {}]
}

####
# NickDbSQL::InviteEvent
# Handles user invitation events
proc ::ngBot::plugin::NickDbSQL::InviteEvent {event ircUser ftpUser ftpGroup ftpFlags} {
  variable np
  variable hostChange
  variable hostExempt
  variable hostFormat
  variable db_conn_name

  if {![string equal "INVITEUSER" $event]} {return 1}

  if {[IsTrue $hostChange] && ![${np}::rightscheck $hostExempt $ftpUser $ftpGroup $ftpFlags]} {
    set stripUser [StripName $ftpUser]
    set stripGroup [StripName $ftpGroup]
    set host [string map [list %(user) $stripUser %(group) $stripGroup] $hostFormat]
    putquick "CHGHOST $ircUser :$host"
  }

  set insert_data [dict create \
    time    [clock seconds] \
    ircUser $ircUser \
    ftpUser $ftpUser \
  ]
set update_data [dict create \
  time    [clock seconds] \
  ircUser $ircUser \
]

set query [::ngBot::ngSQL::insert $db_conn_name "UserNames"]
$query values $insert_data
$query onDuplicateUpdate $update_data
$query execute

return 1
}

####
# NickDbSQL::NickChange
# Updates nicknames in database
proc ::ngBot::plugin::NickDbSQL::NickChange {nick host handle channel newNick} {
  variable db_conn_name

  set query [::ngBot::ngSQL::update $db_conn_name "UserNames"]
  $query set [dict create ircUser $newNick]
  $query where "ircUser" "=" $nick
  $query execute

  return
}

####
# NickDbSQL::GetIrcUser
# Retrieves IRC user for FTP user
proc ::ngBot::plugin::NickDbSQL::GetIrcUser {ftpUser} {
  variable db_conn_name

  set query [::ngBot::ngSQL::select $db_conn_name "UserNames"]
  $query columns [list "ircUser"]
  $query where "ftpUser" "=" $ftpUser
  $query limit 1
  set result [$query execute]

  if {[lindex $result 0] eq "error" || [llength $result] == 0} { return "" }
  return [lindex $result 0 0]
}

####
# NickDbSQL::GetFtpUser
# Retrieves FTP user for IRC user (case-insensitive)
proc ::ngBot::plugin::NickDbSQL::GetFtpUser {ircUser} {
  variable db_conn_name

  set query [::ngBot::ngSQL::select $db_conn_name "UserNames"]
  $query columns [list "ftpUser"]
  $query where "ircUser" "COLLATE utf8mb4_general_ci =" $ircUser
  $query orderBy "time" "DESC"
  $query limit 1
  set result [$query execute]

  if {[lindex $result 0] eq "error" || [llength $result] == 0} { return "" }
  return [lindex $result 0 0]
}

# Initialize plugin
::ngBot::plugin::NickDbSQL::init