#!/bin/sh
#
# ldap_ms.sh
# Copyright (C) 2016 Stefano Stella <mprenditore@gmail.com>
#
# LDAP ManagementSystem
#
# Distributed under terms of the GPL license.
#

# DEFAULT
LDAP_SERVER="10.0.0.1"
ADMIN="cn=admin"
DC="dc=domain,dc=dc"
PASSLDAP="-y /etc/pam_ldap.secret" # prompt password for ldap
DEFPASSWD=default_passwd
DEFEMAIL=na@domain.dc
VERBOSE=0
TEST=0
FILTER=''
EXEC=usage

log_it () {
  if [ $1 -le $VERBOSE ]; then
    if [ -z $LOG_FILE ]; then
      echo "$2"
    else
      echo "$2" | tee -a $LOG_FILE
    fi
  fi
}

error () {
  log_it -1 "$1" >&2
}

exec_it () {
  if [ $TEST -eq 0 ]; then
    OUT=`$2 2>&1`
    if [ $? -eq 0 ]; then
      if [ -z "$3" ]; then
        log_it $1 "[SUCCESS] executing: $2"
      else
        log_it $1 "[SUCCESS] $3"
      fi
      printf '%s\n' "$OUT" | while IFS= read -r line
      do
        if [ ! -z "$line" ]; then
          log_it $1 "        --> $line"
        fi
      done
      exit 0
    else
      error "[ERROR] {$2}"
      printf '%s\n' "$OUT" | while IFS= read -r line
      do
        error "        --> $line"
      done
      exit 1
    fi
  else
    error "[TEST_MODE] not executed {$2}"
    exit 2
  fi
}

rm_file () {
  if [ ! -z "$1" ]; then
    exec_it 2 "rm -f $1"
  fi
}

check_req () {
  if [ -z "$1" ]; then
    log_it 0 "[ERROR] the field is required"
  fi
}

get_lastid () {
  LDAP_OUT=`ldapsearch -H ldap://$LDAP_SERVER/ -x -b "$DC" -s sub "objectclass=person" 2>/dev/null`
  if [ $? -eq 0 ]; then
    LASTUIDN=`echo "$LDAP_OUT" | grep uidNumber | awk '{print $2}' | sort -n | tail -1`
    LASTUIDN=`expr $LASTUIDN + 1`
  else
    log_it 0 "[ERROR] Failed connecting to server ldap://$LDAP_SERVER/"
  fi
}

list_uid() {
  LDAP_OUT=`ldapsearch -H ldap://$LDAP_SERVER/ -x -b "$DC" -s sub "objectclass=person" 2>/dev/null`
  if [ $? -eq 0 ]; then
    # LISTUID=`echo "$LDAP_OUT" | grep "$FILTER" | awk '{print $2}' | sort -n`
    LISTUID=`echo "$LDAP_OUT" | grep "$FILTER" | awk '{print $2}'`
    # LISTUID=`echo "$LDAP_OUT" | grep "$FILTER"`
    echo $LISTUID | xargs -n1
  else
    log_it 0 "[ERROR] Failed connecting to server ldap://$LDAP_SERVER/"
  fi
}

read_fname () {
  while [ -z "$FNAME" ]; do
    read -p 'Insert the NAME [required]: ' FNAME
    check_req "$FNAME"
  done
}

read_lname () {
  while [ -z "$LNAME" ]; do
    read -p "Insert the SURNAME [required]: " LNAME
    check_req "$LNAME"
  done
}

read_guid () {
  while [ -z "$GUID" ]; do
    CPU_PATH=`which cpu 2>/dev/null`
    if [ $? -eq 0 ]; then
      GROUPS=`${CPU_PATH} cat | awk '/Group Entries/,0' | grep -v 'Group Entries' | awk -F: '{ print $3 " - " $1}'`
    else
      GROUPS=`getent group| awk -F: '{print $3" - "$1}'| sort -n | egrep "^[2-9][0-9]{3} "`
    fi
    if [ $? -ne 0 ]; then
      log_it 0 "[ERROR] No vailable groups found"
    else
      echo "Chose a group\n"
      echo "GUID - GROUPNAME"
      echo "$GROUPS" | xargs -n3
    fi
    read -p "Insert the GUID [2100]: " GUID
    if [ -z "$GUID" ]; then
      GUID=2100
    fi
  done
}

read_luid () {
  while [ -z "$LUID" ]; do
    NUID="$(echo $(echo $FNAME | cut -c1)$LNAME | tr -d '[[:space:]]' | tr '[:upper:]' '[:lower:]')"
    read -p "Insert the UID [$NUID]: " LUID
    if [ -z "$LUID" ]; then
      if [ -z "$NUID" ]; then
        check_req "$LUID"
      else
        LUID=$NUID
      fi
    fi
  done
}

read_lcn () {
  while [ -z "$LCN" ]; do
    NCN="$FNAME $LNAME"
    read -p "Insert the CN [$NCN]: " LCN
    if [ -z "$LCN" ]; then
      if [ -z "$NCN" ]; then
        check_req "$LCN"
      else
        LCN=$NCN
      fi
    fi
  done
}

read_lhome () {
  while [ -z "$LHOME" ]; do
    read -p "Insert the LOGIN HOME [/home/$LUID]: " LHOME
    if [ -z "$LHOME" ]; then
      LHOME=/home/$LUID
    fi
  done
}

read_email () {
  while [ -z "$EMAIL" ]; do
    read -p "Insert the EMAIL [$DEFEMAIL]: " EMAIL
    if [ -z "$EMAIL" ]; then
      EMAIL=$DEFEMAIL
    fi
  done
}

read_passwd () {
  while [ -z "$PASSWD" ]; do
    read -p "Insert the PASSWORD [$DEFPASSWD]: " PASSWD
    if [ -z "$PASSWD" ]; then
      PASSWD=$DEFPASSWD
    fi
  done
  echo ""
}

ldif_action () {
  if [ -z "$1" ]; then
    error "[ERROR] No action specified for LDIF"
    exit 1
  else
    TMPFILE=`mktemp`
    case "$1" in
      create_user)
echo "dn: $DN
gidNumber: $GUID
objectClass: top
objectClass: person
objectClass: posixAccount
objectClass: shadowAccount
objectClass: inetOrgPerson
sn: $LNAME
mail: $EMAIL
uidNumber: $LASTUIDN
loginShell: /bin/zsh
homeDirectory: $LHOME
givenName: $FNAME
cn: $LCN
gecos: $LCN
uid: $LUID
shadowMin: -1
shadowMax: 99999
shadowWarning: 7
shadowInactive: -1
shadowExpire: -1
shadowFlag: 134538308" > $TMPFILE
;;
        edit_pass)
echo "dn: $DN
changetype: modify
replace: userPassword
userPassword: $NEWPASS" > $TMPFILE
;;
        convert_dn)
echo "dn: $DN
changetype: modrdn
newrdn: uid=$LUID
deleteoldrdn: 0 " > $TMPFILE
;;
        *) error "[ERROR] Unrecognized action for LDIF"
            exit 1
        ;;
    esac
    echo $TMPFILE
    exit 0
  fi
}

read_vals () {
  VALS="$1"
  for f in $VALS; do
    read_$f
  done
}

check_dn () {
  if [ -z "$1" ]; then
    exit 1
  else
    case "$1" in
      "cn")   read_lcn
              VAR=$LCN
          ;;
      "uid")  read_luid
              VAR=$LUID
          ;;
      *)      error "[ERROR] Wrong user check"
              exit 1
          ;;
    esac
  OUT=`ldapsearch -H ldap://$LDAP_SERVER/ $PASSLDAP -D $ADMIN,$DC -x -b "$1=$VAR,ou=Users,$DC" | grep "dn: $1=$VAR"`
  EXIT=$?
  echo "$OUT"  | cut -d: -f2 | cut -c 2-
  exit $EXIT
  fi
}

get_userinfo () {
  UINFO=`ldapsearch -H ldap://$LDAP_SERVER/ $PASSLDAP -D "$ADMIN,$DC" -x -b "$DN" | grep -v "^#" | grep "$1"`
  if [ $? -eq 0 ]; then
    UINFO=`echo $UINFO | cut -d ' ' -f2`
    echo $UINFO
  else
    error "[ERROR] Field $1 not found"
  fi
  exit $?
}

convertuser () {
  DN=`check_dn cn`
  if [ $? -ne 0 ]; then
    error "[ERROR] User's CN not found"
    exit 1
  else
    alter_user convert
  fi
}

deluser () {
  checkuser
  exec_it 0 "ldapdelete -H ldap://$LDAP_SERVER/ $PASSLDAP -D $ADMIN,$DC $DN" "User $DN Deleted"
  exit 0
}

changepasswd () {
  checkuser
  read_passwd
  exec_it 0 "ldappasswd -H ldap://$LDAP_SERVER/ -s $PASSWD $PASSLDAP -D $ADMIN,$DC -x $DN" "Password for $LUID changed"
  exit 0
}

checkuser () {
  if [ -z "$DN" ]; then
    DN=`check_dn uid`
    if [ $? -ne 0 ]; then
      error "[ERROR] User's UID not found"
      DN=`check_dn cn`
      if [ $? -ne 0 ]; then
        error "[ERROR] User's CN not found"
        exit 1
      fi
    fi
    log_it 0 "User exist has DN: \"$DN\""
    PASS=`get_userinfo "userPassword"`
    B64PASS=`echo -n $PASS |  base64 -d 2>/dev/null`
    if [ $? -eq 1 ]; then
      B64PASS=`echo -n $PASS= |  base64 -d`
    fi
    ISLOCK=`echo -n $B64PASS | grep "}\!"`
    ISLOCK=$?
    if [ $ISLOCK -eq 0 ]; then error "User is disabled"; else error "User is enabled"; fi
  fi
}

alter_user () {
  if [ -z "$1" ]; then
    error "[ERROR] No action selected for alter_user"
    exit 1
  fi
  checkuser
  if [ $? -eq 0 ]; then
    case "$1" in
      lock) if [ $ISLOCK -eq 1 ]; then
              log_it 2 "User can be lock down"
              NEWPASS=`echo -n $B64PASS | sed 's/{SSHA}/{SSHA}!/i'`
              LDIF=`ldif_action "edit_pass"`
              echo `exec_it 0 "ldapmodify -H ldap://$LDAP_SERVER/ -x $PASSLDAP -D $ADMIN,$DC -f ${LDIF}" "User $LUID locked"`
              rm_file "$LDIF"
            fi
            ;;
      unlock) if [ $ISLOCK -eq 0 ]; then
              log_it 2 "User can be unlock down"
              NEWPASS=`echo -n $B64PASS | sed 's/{SSHA}!/{SSHA}/i'`
              LDIF=`ldif_action "edit_pass"`
              echo `exec_it 0 "ldapmodify -H ldap://$LDAP_SERVER/ -x $PASSLDAP -D $ADMIN,$DC -f ${LDIF}" "User $LUID unlocked"`
              rm_file "$LDIF"
            fi
            ;;
      convert)  OUT=`ldapsearch -H ldap://$LDAP_SERVER/ $PASSLDAP -D $ADMIN,$DC -x -b "$DN" | grep "uid:"`
                LUID=`echo "$OUT"  | cut -d: -f2 | cut -c 2-`
                LDIF=`ldif_action convert_dn`
                echo `exec_it 0 "ldapmodify -H ldap://$LDAP_SERVER/ -x $PASSLDAP -D $ADMIN,$DC -f ${LDIF}" "User $LUID converted"`
                rm_file "$LDIF"
            ;;
      *)  error "[ERROR] Unrecognized $1 option for alter_user"
          exit 1
          ;;
    esac
  fi
}

adduser () {
  VALS="fname lname luid"
  get_lastid
  read_vals "$VALS"
  CHECK=`check_dn uid`
  while [ $? -eq 0 ]; do
    error "[ERROR] UID already present"
    unset LUID
    read_luid
    CHECK=`check_dn uid`
  done
  read_lcn
  CHECK=`check_dn cn`
  while [ $? -eq 0 ]; do
    error "[ERROR] CN already present"
    unset LCN
    read_lcn
    CHECK=`check_dn cn`
  done
  VALS="guid lhome email passwd"
  read_vals "$VALS"
  DN="uid=$LUID,ou=Users,$DC"
  LDIF=`ldif_action "create_user"`
  TMP=`exec_it 0 "ldapadd -H ldap://$LDAP_SERVER/ -x $PASSLDAP -D $ADMIN,$DC -f ${LDIF}" "User $LUID created"`
  RES=$?
  echo $TMP
  `rm_file "$LDIF"`
  if [ $RES -eq 0 ]; then
    exec_it 0 "ldappasswd -H ldap://$LDAP_SERVER/ -s $PASSWD $PASSLDAP -D $ADMIN,$DC -x $DN" "Password for $LUID changed"
  else
    error "[ERROR] Password not changed"
    exit 1
  fi
}

usage () {
  echo "Usage: $0 -a [options]\n"
  echo "option          long_desc"
  echo "-h              how this help file"
  echo "-t              test it without exec nothing"
  echo "-q              quiet mode, don't show output"
  echo "-v              can be repeted to increment verbose level"
  echo "-f filter       search filter for list command (ex: \"uid:\", \"uid=\", etc)"
  echo "-a action       could be (add, check, chpwd, conv, del, edit, list, lock, unlock)"
  echo "-c cn           specify Firstname for user"
  echo "-n firstname    specify Firstname for user"
  echo "-s surname      specify Surname for user"
  echo "-e email        specify E-Mail for user"
  echo "-u uid          specify UID/LoginName for user"
  echo "-p password     specify Password for user"
  echo "-y passwdfile   specify Password File for LDAP"
  echo "-w passwdldap   specify Password for LDAP"
  echo "-W              prompt Password for LDAP"
  echo "-g guidnum      specify GUID Number for user"
  echo "-H home         specify Home for user"
  echo "-A cn=x         specify LDAP Admin account to connect to"
  echo "-D dc=x,dc=y    specify DC to connect to"
  echo "-S ldap_server  specify LDAP SERVER to connect to"
  echo ""
  echo "Examples:"
  echo "$0 -a add [[-u <username>] [-f <firstname>] [-s <surname>]]"
  echo "$0 -a ck [-u <username>]"
  echo "$0 -a lock"
  exit 1
}

check_action () {
  case $1 in
    add)    EXEC="adduser"
      ;;
    check)  EXEC="checkuser"
      ;;
    chpwd)  EXEC="changepasswd"
      ;;
    conv)   EXEC="convertuser"
      ;;
    del)    EXEC="deluser"
      ;;
    edit)   EXEC="alter_user edit"
      ;;
    list)   EXEC="list_uid"
      ;;
    lock)   EXEC="alter_user lock"
      ;;
    unlock) EXEC="alter_user unlock"
      ;;
    *)      error "Action not found"
            usage
      ;;
  esac
}

# OPTIONS PARSING
while getopts ":A:D:S:c:f:a:n:e:s:u:H:g:p:P:F:tqvlh" opt; do
  case $opt in
    A)
      ADMIN=$OPTARG
      ;;
    D)
      DC=$OPTARG
      ;;
    S)
      LDAP_SERVER=$OPTARG
      ;;
    c)
      LCN=$OPTARG
      ;;
    n)
      FNAME=$OPTARG
      ;;
    e)
      EMAIL=$OPTARG
      ;;
    s)
      LNAME=$OPTARG
      ;;
    u)
      LUID=$OPTARG
      ;;
    H)
      LHOME=$OPTARG
      ;;
    g)
      GUID=$OPTARG
      ;;
    p)
      PASSWD=$OPTARG
      ;;
    y)
      PASSLDAP="-y "$OPTARG
      ;;
    w)
      PASSLDAP="-w "$OPTARG
      ;;
    W)
      PASSLDAP="-W"
      ;;
    q)
      VERBOSE=-1
      ;;
    v)
      VERBOSE=`expr $VERBOSE + 1`
      ;;
    l)
      LOG_FILE=$OPTARG
    ;;
    t)
      TEST=1
      ;;
    f)
      FILTER="$OPTARG"
      ;;
    a)
      check_action "$OPTARG"
      ;;
    h)
      EXEC="usage"
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

log_it 1 "#########################################"
log_it 1 "# Welcome to the LDAP Management Script #"
log_it 1 "#########################################"
log_it 1 "VERBOSE Level: $VERBOSE"
log_it 1 "LDAP SERVER:   $LDAP_SERVER"
log_it 1 "DC:            $DC"
log_it 1 "TEST_MODE:     $TEST"

$EXEC
exit 0
