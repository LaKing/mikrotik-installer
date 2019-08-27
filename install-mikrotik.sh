#!/bin/bash
#
# Mikrotik installer script
#
# D250 Laboratories / D250.hu 2014-2019
# Author: István király
# LaKing@D250.hu
# 
## download, update with:
# curl http://d250.hu/scripts/install-mikrotik.sh > install.sh 
## run with bash 
# && bash install.sh
#

## Timestamp
readonly NOW="$(date +%Y.%m.%d-%H:%M:%S)"
## logfile
readonly LOG="$(pwd)/install-mikrotik.log"
## current dir
readonly DIR="$(pwd)"
## temporal backup and work directory
readonly TMP="/temp"
## A general message string 
readonly MSG="## D250 Laboratories $0 @ $NOW"
## Debugging helper
DEBUG=false
## constants

## constants for use everywhere
readonly RED='\e[31m'
readonly GREEN='\e[32m'
readonly YELLOW='\e[33m'
readonly BLUE='\e[34m'
readonly GRAY='\e[37m'
readonly CLEAR='\e[0m'

## Lablib functions

function msg {
    ## message for the user
    echo -e "${GREEN}$*${CLEAR}"
}

function ntc {
    ## notice for the user
    echo -e "${YELLOW}$*${CLEAR}"
}


function log {
    ## create a log entry
    echo -e "${YELLOW}$1${CLEAR}"
    echo "$NOW: $*" >> "$LOG"
}

## silent log
function logs {
    ## create a log entry
    echo "$NOW: $*" >> "$LOG"
}
dbgc=0
function dbg {
    ((dbgc++))
    ## short debug message if debugging is on
    if $DEBUG
    then
        echo -e "${YELLOW}DEBUG #$dbgc ${BASH_SOURCE[1]}#$BASH_LINENO ${FUNCNAME[1]} ${RED} $* ${CLEAR}"
    fi
}
function debug {
    ## tracing debug message
    echo -e "${YELLOW}DEBUG ${BASH_SOURCE[1]}#$BASH_LINENO ${FUNCNAME[1]} ${RED} $*${CLEAR}"
}
function err {
    ## error message
    echo -e "$NOW ERROR ${RED}$*${CLEAR}" >> "$LOG"
    echo -e "${RED}$*${CLEAR}" >&2
}

function run {
    local signum='$'
    if [ "$USER" == root ]
    then
        signum='#'
    fi
    local WDIR
    WDIR="$(basename "$PWD")"
    echo -e "${BLUE}[$USER@${HOSTNAME%%.*} ${WDIR/#$HOME/\~}]$signum ${YELLOW}$*${CLEAR}"

    # shellcheck disable=SC2048
    $*
    eyif "command '$*' returned with an error"
}

## exit if failed
function exif {
    local exif_code="$?"
    if [ "$exif_code" != "0" ]
    then
        if $DEBUG
        then
            ## the first in stack is what we are looking for. (0th is this function itself)
            err "ERROR $exif_code @ ${BASH_SOURCE[1]}#$BASH_LINENO ${FUNCNAME[1]} :: $*"
        else
            err "$*"
        fi
        exit "$exif_code";
    fi
}

## extra yell if failed
function eyif {
    local eyif_code="$?"
    if [ "$eyif_code" != "0" ]
    then
        if $DEBUG
        then
            err "ERROR $eyif_code @ ${BASH_SOURCE[1]}#$BASH_LINENO ${FUNCNAME[1]} :: $*"
        else
            err "$*"
        fi
    fi
}

## Any enemy in sight? :)
clear


msg "$MSG"
mkdir -p "$TMP"




a=0
n=0
h=0

## Basic helper functions

function question {
    ## Add to the question que asq, with counter a

    (( a++ ))
    asq[$a]=$1
    hlp[$a]=$2
    def[$a]=$3
}

function run_in_que {
    ## run the question que. Default answer is no, y is the only other option
    ## y-answered question are added to the executation que
    echo ''
    echo "${hlp[h]}"

    key=
    echo -n "$1? " | tr '_' ' '

    default_key=${def[h]:0:1}
    default_str="y/N"

    if [[ $default_key == y* ]]; then
      default_str="Y/n"
    else
      default_str="y/N"
    fi
     # shellcheck disable=SC2034
    read -s -r -p " [$default_str] " -n 1 -i "y" key

    ## Check for default action
    if [ ${#key} -eq 0 ]; then
     ## Enter was hit"
     key=$default_key
    fi

    ## Makre it an ordenary string
    if [[ $key == y ]]; then
     key="yes"
    else
     key="no";
    fi

    echo $key

    ## Que the action if yes
    if [[ $key == y* ]]; then
      echo "$1" >> "$LOG"
      (( n++ ))
      que[$n]=$1 
    fi
}

function bak {
    ## create a backup of the file, with the same name, same location .bak extension
    ## filename=$1
    echo "$MSG" >> "$1.bak"
    cat "$1" >> "$1.bak"
    #echo "$1 has a .bak file"
}

function set_file {
    ## cerate a file with the content overwriting everything
    ## filename=$1 content=$2

    if [[ -f $1 ]]
    then 
          bak "$1"
    fi
    echo "creating $1"
    echo "$2" > "$1"
}

function sed_file {
    ## used to replace a line in a file
    ## filename=$1 old line=$2 new line=$3
    bak "$1"
    cat "$1" > "$1.tmp"
    sed "s|$2|$3|" "$1.tmp" > "$1"
    rm "$1.tmp"
}

function add_conf {
    ## check if the content string is present, and add if necessery. Single-line content only.
    ## filename=$1 content=$2

    if [[ -f $1 ]]
    then 
          bak "$1"
    fi

    if grep -q "$2" "$1"
    then
     echo "$1 already has $2"
    else
     echo "adding $2"
     echo "$2" >> "$1"
    fi
}



function finalize {
## run the que's, and do the job's. This is the main function.
  msg "=== Confirmation for ${#asq[*]} commands. [Ctrl-C to abort] ==="
  for item in ${asq[*]}
  do
    (( h++ ))
    run_in_que "$item" #?
  done

  msg "=== Running the Que of ${#que[*]} commands. ==="
  for item in ${que[*]}
  do
    msg "== $item started! =="
    ntc "$item"
    $item
    msg "== $item finished =="
  done

  msg "=== Post-processing tasks ===";
  for item in ${que[*]}
  do
    if [ "$item" == "install_and_finetune_gnome_desktop" ] 
    then
     # run this graphical tool at the end
     if [ -z "$USER" ]; then echo "No user to tune gnome, skipping question." >> "$LOG"; else
        ntc "Starting the gnome Tweak tool."
        su "$USER" -c gnome-tweaks
     fi
    fi 
  done
  echo "Finished. $MSG" >> "$LOG"
}

ROUTEROS_USER=$(echo $1 | cut -d "@" -f 1)
ROUTEROS_HOST=$(echo $1 | cut -d "@" -f 2)

### You can override this here, especially if you use custom ports.
#ROUTEROS_USER=$1
#ROUTEROS_HOST=$2
#ROUTEROS_SSH_PORT=$3

if ! [[ $ROUTEROS_HOST ]]
then
    ROUTEROS_HOST="192.168.88.1"
fi

if ! [[ $ROUTEROS_USER ]]
then
    ROUTEROS_USER="admin"
fi

if ! [[ $ROUTEROS_SSH_PORT ]]
then
    ROUTEROS_SSH_PORT="22"
fi

log "Connecting to $ROUTEROS_HOST.."

echo "ssh $ROUTEROS_USER@$ROUTEROS_HOST -p $ROUTEROS_SSH_PORT system identity print"
echo ""
if ssh "$ROUTEROS_USER@$ROUTEROS_HOST" -p "$ROUTEROS_SSH_PORT" 'system identity print'
then
    ntc ".. Connected!"
else
    err "Could not connect to router."
    exit
fi

function execute_file() {
    FILE=$1
    ntc "Transfer and import file: $FILE"
    scp -P "$ROUTEROS_SSH_PORT" "$FILE" "$ROUTEROS_USER"@"$ROUTEROS_HOST":"$FILE"
    ssh "$ROUTEROS_USER@$ROUTEROS_HOST" -p "$ROUTEROS_SSH_PORT" /import verbose=yes "$FILE"
}

function execute() {
    ntc "# $1"
    ssh "$ROUTEROS_USER@$ROUTEROS_HOST" -p "$ROUTEROS_SSH_PORT" "$1"
}



## NOTE: question / function should be consistent
question enable-publickey 'Enable publickey access via RSA keys for user $ROUTEROS_USER.' yes
function enable-publickey {

if [[ -f ~/.ssh/id_rsa.pub ]]
then
    ntc "using public key from $USER for $ROUTEOS_USER"
else
    ssh-keygen -t rsa
fi

if [[ -f ~/.ssh/id_rsa.pub ]]
then
    ntc "upload publickey id_rsa.pub"
    scp -P "$ROUTEROS_SSH_PORT" ~/.ssh/id_rsa.pub "$ROUTEROS_USER"@"$ROUTEROS_HOST":"id_rsa.pub"
    execute "/user ssh-keys import public-key-file=id_rsa.pub user=$ROUTEROS_USER"
else
    err "No publickey"
fi
}

question enable-https 'Enable https port.' yes
function enable-https {

    FILE=enable-https
cat << EOF > "$FILE"
       certificate add name=root-cert common-name=root-certificate days-valid=3650 key-usage=key-cert-sign,crl-sign
       certificate sign root-cert
       certificate add name=https-cert common-name=https-certificate days-valid=3650
       certificate sign ca=root-cert https-cert
       ip service set www-ssl certificate=https-cert disabled=no
EOF
    execute_file "$FILE"
}


question https-on-8443 'Set https www-ssl to port 8443.' yes
function https-on-8443 {
    execute "ip service set www-ssl disabled=no port=8443"
}

## Windows is considered insecure, therfore winbox is too.
question disable-insecure-services 'Disable insecure services: http based www, api, ftp, telnet, winbox.' yes
function disable-insecure-services {

    FILE=disable-services
cat << EOF > "$FILE"
    ip service set api disabled=yes
    ip service set ftp disabled=yes
    ip service set telnet disabled=yes
    ip service set winbox disabled=yes
    ip service set www disabled=yes
EOF
    execute_file "$FILE"
}



question add-local-user "Use a local user $USER / or a custom user. Enable ssh key if present." yes
function add-local-user {

    # Read Username
    echo -n "Username ($USER):"
    read username

    # Read Password
    echo -n "Password: "
    read -s password
    echo ''

    if [[ ! $username ]]
    then
       username=$USER
    fi

    if [[ $password ]] 
    then
       execute "/user add name=$username password=$password group=full"
    else
       execute "/user add name=$username group=full"
    fi

    if [[ -f ~/.ssh/id_rsa.pub ]]
    then
        ntc "upload id_rsa.pub as $username-id_rsa.pub"
        scp -P "$ROUTEROS_SSH_PORT" ~/.ssh/id_rsa.pub "$ROUTEROS_USER"@"$ROUTEROS_HOST":"$username-id_rsa.pub"

        execute "/user ssh-keys import public-key-file=$username-id_rsa.pub user=$username"
    else
        err "No publickey"
    fi

    ntc "Continue as $username"
    ROUTEROS_USER=$username
}


question remove-admin "Remove default admin user." yes
function remove-admin {
        execute "/user remove admin"
}

for f in install-mikrotik-*.sh
do
    echo "Loading $f"
    if [[ -f $f ]]
    then
	source "$f"
    fi
done


## Finalize will do the job!
finalize
exit

