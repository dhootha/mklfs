#!/bin/bash

### ### ###
### ### ### DEFENSIVE PROGRAMMING
### ### ###

set -o nounset
set -o errexit

### ### ###
### ### ### CONSTANTS
### ### ###

CURR_DIR=`pwd`
LOG_FILE="mklfs.log"
INVOCATION="$0 $*"

### ### ###
### ### ### COLORS
### ### ###

# color variables copied from the Arch Linux Wiki

# Reset
Color_Off='\e[0m'       # Text Reset

# Regular Colors
Black='\e[0;30m'        # Black
Red='\e[0;31m'          # Red
Green='\e[0;32m'        # Green
Yellow='\e[0;33m'       # Yellow
Blue='\e[0;34m'         # Blue
Purple='\e[0;35m'       # Purple
Cyan='\e[0;36m'         # Cyan
White='\e[0;37m'        # White

# Bold
BBlack='\e[1;30m'       # Black
BRed='\e[1;31m'         # Red
BGreen='\e[1;32m'       # Green
BYellow='\e[1;33m'      # Yellow
BBlue='\e[1;34m'        # Blue
BPurple='\e[1;35m'      # Purple
BCyan='\e[1;36m'        # Cyan
BWhite='\e[1;37m'       # White

# Underline
UBlack='\e[4;30m'       # Black
URed='\e[4;31m'         # Red
UGreen='\e[4;32m'       # Green
UYellow='\e[4;33m'      # Yellow
UBlue='\e[4;34m'        # Blue
UPurple='\e[4;35m'      # Purple
UCyan='\e[4;36m'        # Cyan
UWhite='\e[4;37m'       # White

# Background
On_Black='\e[40m'       # Black
On_Red='\e[41m'         # Red
On_Green='\e[42m'       # Green
On_Yellow='\e[43m'      # Yellow
On_Blue='\e[44m'        # Blue
On_Purple='\e[45m'      # Purple
On_Cyan='\e[46m'        # Cyan
On_White='\e[47m'       # White

# High Intensity
IBlack='\e[0;90m'       # Black
IRed='\e[0;91m'         # Red
IGreen='\e[0;92m'       # Green
IYellow='\e[0;93m'      # Yellow
IBlue='\e[0;94m'        # Blue
IPurple='\e[0;95m'      # Purple
ICyan='\e[0;96m'        # Cyan
IWhite='\e[0;97m'       # White

# Bold High Intensity
BIBlack='\e[1;90m'      # Black
BIRed='\e[1;91m'        # Red
BIGreen='\e[1;92m'      # Green
BIYellow='\e[1;93m'     # Yellow
BIBlue='\e[1;94m'       # Blue
BIPurple='\e[1;95m'     # Purple
BICyan='\e[1;96m'       # Cyan
BIWhite='\e[1;97m'      # White

# High Intensity backgrounds
On_IBlack='\e[0;100m'   # Black
On_IRed='\e[0;101m'     # Red
On_IGreen='\e[0;102m'   # Green
On_IYellow='\e[0;103m'  # Yellow
On_IBlue='\e[0;104m'    # Blue
On_IPurple='\e[0;105m'  # Purple
On_ICyan='\e[0;106m'    # Cyan
On_IWhite='\e[0;107m'   # White

### ### ###
### ### ### EXIT CODES
### ### ###

EXIT_GETOPT_INVALID=1
EXIT_GETOPT_MISSING_ARG=2
EXIT_GETOPT_BAD_ARG=3
EXIT_GETOPT_UNKNOWN=4

EXIT_PROMPT_MISSING_ARGS=10
EXIT_PROMPT_BAD_ARG=11
EXIT_PROMPT_GETOPT_INVALID=12
EXIT_PROMPT_GETOPT_MISSARG=13
EXIT_PROMPT_GETOPT_UNKNOWN=14

EXIT_NOTFOUND_VERSIONCHECK=20
EXIT_NOTFOUND_LIBRARYCHECK=21
EXIT_NOTFOUND_WGETLIST_NOKERNEL=25
EXIT_NOTFOUND_MD5SUMS_NOKERNEL=26
EXIT_NOTFOUND_MD5SUM=30
EXIT_NOTFOUND_GPG=31
EXIT_NOTFOUND_XZ=32

EXIT_DOWNLOAD_WGETLIST_NOKERNEL=50
EXIT_DOWNLOAD_KERNEL_GIT=51
EXIT_DOWNLOAD_KERNEL=52
EXIT_DOWNLOAD_KERNEL_KEY=53

EXIT_CHECKSUM_PACKAGES=55
EXIT_CHECKSUM_KERNEL=56

EXIT_SYSTEM_NOT_CONFORMANT=100
EXIT_SYSTEM_NOT_CONFORMANT_LIBS=101

EXIT_SIGINT=200
EXIT_USERFIGOUT_NOCODE=201
EXIT_UNKNOWN=202

### ### ###
### ### ### FUNCTIONS
### ### ###

mklfs_cleanup() {
    stty echo
    cd "$CURR_DIR"
    declare -p LFS
    declare -p LFS_SOURCES
    declare -p PARTS_MPS
}

prompt() {
# How to use:
# `prompt ok   bla bla` -> prints pretty green-colored message "[mklfs] bla bla"
# `prompt warn bla bla` -> the same, but yellow
# `prompt err  bla bla` -> the same again, this time in red
# `prompt -n (ok|warn|err|cmd) bla bla` -> '-n' suppresses the trailing new-line
# `prompt header "bla bla"` -> prints a stylized header (try it out)
# `prompt -n header ...`  -> doesn't work! don't use '-n' with 'header'
# `prompt cmd  bla bla` -> prints a $ dollar sign after the [mklfs] block
# `prompt -r cmd bla bla` -> prints a # hash instead of the dollar sign
# `prompt -c cmd bla bla` -> prints a > greater than sign instead of the dollar
    if [[ $# -lt 1 ]]; then
        printf "  $BIRed[$Color_Off${BRed}mklfs error"
        printf "$Color_Off$BIRed]$Color_Off  $Red"
        printf "prompt() should be called like: "
        printf "\`prompt [-n] (ok|warn|err) [message...]'$Color_Off\n"
        printf "  $BIRed[$Color_Off${BRed}mklfs error"
        printf "$Color_Off$BIRed]$Color_Off  $Red"
        printf "...but prompt() was called with no arguments at all."
        printf "$Color_Off\n\n"
        mklfs_cleanup
        exit $EXIT_PROMPT_MISSING_ARGS
    fi

    endline="\n"
    dollar='$'
    OPTIND=1
    while getopts :nrc opt; do
        case $opt in
        n)
            endline=""
            ;;
        r)
            dollar='#'
            ;;
        c)
            dollar='>'
            ;;
        \?)
            printf "Invalid option to prompt(): -$OPTARG\n\n"
            mklfs_cleanup
            exit $EXIT_PROMPT_GETOPT_INVALID
            ;;
        :)
            printf "Unknown error. Missing arg in prompt?\n\n"
            mklfs_cleanup
            exit $EXIT_PROMPT_GETOPT_MISSARG
            ;;
        *)
            printf "Unknown error in prompt()\n\n"
            mklfs_cleanup
            exit $EXIT_PROMPT_GETOPT_UNKNOWN
            ;;
        esac
    done
    shift "$((OPTIND-1))"

    case $1 in
    ok)
        printf "  $BIGreen[$Color_Off$BGreen"mklfs
        printf "$Color_Off$BIGreen]$Color_Off  $Green"
        ;;
    warn)
        printf "  $BIYellow[$Color_Off$BYellow"mklfs
        printf "$Color_Off$BIYellow]$Color_Off  $Yellow"
        ;;
    err)
        printf "  $BIRed[$Color_Off$BRed"mklfs
        printf "$Color_Off$BIRed]$Color_Off  $Red"
        ;;
    cmd)
        printf "  $BICyan[$Color_Off$BCyan"mklfs
        printf "$Color_Off$BICyan]$dollar$Color_Off $Cyan"
        ;;
    header)
        shift
        #char count
        cc=0
        for prpt_l in "$@"; do
            if [[ ${#prpt_l} -gt $cc ]]; then
                cc=${#prpt_l}
            fi
        done
        cc_spaces=`eval "printf -- ' %.s' {1..$cc}"`
        if [[ $cc -eq 0 ]]; then cc_spaces=""; fi
        printf "  $BPurple[$Color_Off$BPurple"mklfs
        printf "$Color_Off$BPurple]$Color_Off  "
        printf "$On_Purple    $cc_spaces    $Color_Off"
        echo
        printf "  $BPurple[$Color_Off$BPurple"mklfs
        printf "$Color_Off$BPurple]$Color_Off"
        printf "  $On_Purple  $Color_Off  $cc_spaces  $On_Purple  $Color_Off"
        echo
        for prpt_l in "$@"; do
            printf "  $BPurple[$Color_Off$BPurple"mklfs
            printf "$Color_Off$BPurple]$Color_Off"
            printf "  $On_Purple  $Color_Off  ${Purple}%-${cc}s$Color_Off" \
                   "$prpt_l"
            printf "  $On_Purple  $Color_Off"
            echo
        done
        printf "  $BPurple[$Color_Off$BPurple"mklfs
        printf "$Color_Off$BPurple]$Color_Off"
        printf "  $On_Purple  $Color_Off  $cc_spaces  $On_Purple  $Color_Off"
        echo
        printf "  $BPurple[$Color_Off$BPurple"mklfs
        printf "$Color_Off$BPurple]$Color_Off  "
        printf "$On_Purple    $cc_spaces    $Color_Off"
        echo
        return
        ;;
    *)
        printf "  $BIRed[$Color_Off${BRed}mklfs error"
        printf "$Color_Off$BIRed]$Color_Off  $Red"
        printf "prompt(): unknown option: $1"
        printf "$Color_Off\n"
        printf "  $BIRed[$Color_Off${BRed}mklfs error"
        printf "$Color_Off$BIRed]$Color_Off  $Red"
        printf "prompt() should be called like: "
        printf "\`prompt [-n] [-r] (ok|warn|err) [message...]'$Color_Off\n\n"
        mklfs_cleanup
        exit $EXIT_PROMPT_BAD_ARG
        ;;
    esac
    shift
    if [[ $# -lt 1 ]]; then
        printf "%s$Color_Off\n" "$*"
        return
    fi
    printf "%s$Color_Off$endline" "$*"
}

intd() {
    write_log "intd($*)"
    echo ; echo
    prompt err Interrupted! Exiting...
    echo
    mklfs_cleanup
    exit $EXIT_SIGINT
}

termd() {
    write_log "termd($*)"
    echo ; echo
    prompt err Terminated! Exiting...
    echo
    mklfs_cleanup
    exit $EXIT_SIGTERM
}

unknown_err() {
    write_log "unknown_err($*)"
    exit_code=$EXIT_UNKNOWN
    if [[ $# -lt 1 ]]; then
        prompt err "Unknown error!"
    else
        prompt err "Unknown error! Exiting with code ${1}..."
        exit_code=$1
    fi
    mklfs_cleanup
    exit $exit_code
}

user_figout() {
    write_log "user_figout($@)"
    echo
    prompt warn "We'll let you figure this out. Come back when you fix it!"
    mklfs_cleanup
    echo
    if [[ $# -lt 1 ]]; then
        exit $EXIT_USERFIGOUT_NOCODE
    else
        exit $1
    fi
}

write_log() {
    echo "`date +'[%F, %T]'` ${1:-}" >> $LOG_FILE
}

### ### ###
### ### ### BEGIN SCRIPT
### ### ###

echo MakeLFS: Linux From Scratch automated installation tool
echo Written for the LFSv7.6 book
echo Pedro Angelo \<fonini@ufrj.br\>
echo

OPTIND=1
START_CHP=0
START_SCT=0
while getopts :n:l: opt; do
    case $opt in
    n)
        re='^[0-9]+\.[0-9]+$'
        if ! [[ $OPTARG =~ $re ]]; then
            prompt err "Usage:"
            prompt err "    $0 [-n <chapter>.<section>] [-l <logfilename>]"
            echo
            mklfs_cleanup
            exit $EXIT_GETOPT_BAD_ARG
        fi
        START_CHP=${OPTARG%.*}
        START_SCT=${OPTARG#*.}
        ;;
    l)
        LOG_FILE=$OPTARG
        ;;
    \?)
        prompt err "Invalid option: -$OPTARG"
        echo
        mklfs_cleanup
        exit $EXIT_GETOPT_INVALID
        ;;
    :)
        prompt err "Usage:"
        prompt err "    $0 [-n <chapter>.<section>] [-l <logfilename>]"
        echo
        mklfs_cleanup
        exit $EXIT_GETOPT_MISSING_ARG
        ;;
    *)
        unknown_err $EXIT_GETOPT_UNKNOWN
        ;;
    esac
done
shift "$((OPTIND-1))"

trap intd SIGINT
trap termd SIGTERM

cd "$( dirname "${BASH_SOURCE[0]}" )"

(echo; echo; echo; echo) >> $LOG_FILE
write_log "${INVOCATION}"
write_log

### ###     0.7
### ###
if [[ $START_CHP -lt 0 || ( $START_CHP -eq 0 && $START_SCT -le 7 ) ]]; then
prompt header "SECTION vii. of the PREFACE"
echo
if [[ -f mklfs.conf ]]; then
    backup_file='mklfs.conf~'
    while [[ -f $backup_file ]]; do
        backup_file="${backup_file}~";
    done
    mv mklfs.conf $backup_file
fi

prompt ok "You will be  shown  a list of  dependency versions  and other"
prompt ok "    things  on  your system.  You should check  whether  they"
prompt ok "    satisfy the recommendations of the LFS book. When you are"
prompt ok "    finished  checking  (use another terminal!),  hit  \`q' to"
prompt ok "    exit the  \`less' environment.  When you are ready  to see"
prompt -n ok "    the list, hit \`enter': "
read

user_answer=""

while ! [[ "$user_answer" = y* ]]; do
    case "$user_answer" in
    q*)
        write_log "User quit after seeing dependency list."
        write_log "Quitting with EXIT_SYSTEM_NOT_CONFORMANT."
        user_figout $EXIT_SYSTEM_NOT_CONFORMANT
        ;;
    *)
        write_log "Dependency list OK."
        ;;
    esac

    if [[ ! -f version-check.sh ]]; then
        echo
        prompt err \
          "Error!  Couldn't find the file \`version-check.sh'. You should"
        prompt err \
          "    place that file  (get it from the LFS book!)  in the same"
        prompt err "    directory as mklfs.sh:"
        prompt err
        prompt err "        `pwd` ,"
        prompt err
        prompt err "    and then run mklfs.sh again."
        echo
        write_log "Couldn't find version-check.sh."
        write_log "Quitting with EXIT_NOTFOUND_VERSIONCHECK."
        mklfs_cleanup
        exit $EXIT_NOTFOUND_VERSIONCHECK
    fi
    bash version-check.sh | less
    echo

    prompt ok "Is your  host system  OK?  Did you check everything?  Are all"
    prompt ok "    sym/hard-links working?  g++ compilation is fine?  If you"
    prompt ok "    want to procede,  type \`yes'.  If you want to  check once"
    prompt ok "    again, type \`show'. If your system is not OK, you can fix"
    prompt ok "    it before typing \`yes'.  If you want to quit mklfs,  type"
    prompt -n ok "    \`quit': "
    read user_answer
done
echo
write_log "Proceeding after dependency list"

if [[ ! -f library-check.sh ]]; then
    prompt err \
      "Error!  Couldn't find the file \`library-check.sh'. You should"
    prompt err \
      "    place that file  (get it from the LFS book!)  in the same"
    prompt err "    directory as mklfs.sh:"
    prompt err
    prompt err "        `pwd` ,"
    prompt err
    prompt err "    and then run mklfs.sh again."
    echo
    write_log "Couldn't find library-check.sh."
    write_log "Quitting with EXIT_NOTFOUND_LIBRARYCHECK."
    mklfs_cleanup
    exit $EXIT_NOTFOUND_LIBRARYCHECK
fi
found_count=0
l=""
found_reg='\:\sfound$'
while read l; do
    if [[ $l =~ $found_reg ]]; then let found_count+=1; fi
done <<< "`bash library-check.sh`"
write_log "found_count=$found_count"
if [[ ( $found_count -eq 1 ) || ( $found_count -eq 2 ) ]]; then
    prompt warn "The ouput of \`bash library-check.sh' was:"
    bash library-check.sh
    prompt warn "According to the LFS book,  this is an inconsistency,  and it"
    prompt warn \
      "    \"interferes with building some LFS packages\".  You should"
    prompt warn \
      "    follow the book reccomendations,  and then type \`quit' if"
    prompt warn \
      "    you want to quit mklfs.sh, or \`yes' if you have fixed the"
    prompt -n warn "    problem and want to continue: "
    read l
    while [[ ! ( ( "$l" = q* ) || ( "$l" = y* ) ) ]]; do
        prompt -n warn "Type \`quit' to quit mklfs.sh, or \`yes' to continue: "
        read l
    done
    if [[ $l = q* ]]; then
        write_log "library-check.sh was bad. quitting."
        user_figout $EXIT_SYSTEM_NOT_CONFORMANT_LIBS
    fi
else
    write_log "library-check.sh was OK."
    prompt ok "The \`library-check.sh' script found the libraries used by gcc"
    prompt ok "    are consistent."
fi
echo

### ###     2.2
### ###
fi; if [[ $START_CHP -lt 2 || ( $START_CHP -eq 2 && $START_SCT -le 2 ) ]]; then
prompt header "SECTION 2.2. Creating a New Partition"
echo

prompt ok "Now,  you should partition your system  the way  that pleases"
prompt ok "    you.  When you are finished partitioning,  hit \`enter' to"
prompt -n ok "    continue: "
read
echo
write_log "Disk partitioned."

### ###     2.3
### ###
fi; if [[ $START_CHP -lt 2 || ( $START_CHP -eq 2 && $START_SCT -le 3 ) ]]; then
prompt header "SECTION 2.3. Creating a File System on the Partition"
echo

prompt ok "Create filesystems on the partitions you made. When done, hit"
prompt -n ok "    \`enter': "
read
echo
write_log "Filesystems created"

### ###     2.4
### ###
fi; if [[ $START_CHP -lt 2 || ( $START_CHP -eq 2 && $START_SCT -le 4 ) ]]; then
prompt header "SECTION 2.4. Mounting the New Partition"
echo
[[ -f mklfs.conf ]] && . mklfs.conf

prompt ok "Choose  a mountpoint for (the root partition of) the  new LFS"
prompt -n ok "    system [default ${LFS:-/mnt/lfs}]: "
read l
if [[ ! $l ]]; then
    l=${LFS:-/mnt/lfs}
fi
while [[ ! -d $l ]]; do
    prompt -n ok "Create the directory $l, and then hit \`enter': "
    read
done
export LFS="$(realpath -s $l)"
echo "unset LFS; $(declare -p LFS)" >> mklfs.conf
echo
write_log "LFS=$LFS"

pmps_is_set=no
if [[ -v PARTS_MPS[0] ]]; then # PARTitionS and MountPointS
    write_log "PARTS_MPS exists and is array:"
    write_log "$(declare -p PARTS_MPS)"
    re='^\s*$'
    for ix in ${!PARTS_MPS[*]}; do
        if [[ ! ${PARTS_MPS[$ix]} =~ $re ]]; then
            pmps_is_set='yes'
            break
        fi
    done
fi
if [[ $pmps_is_set == 'yes' ]]
then # there is a default
    write_log "found default PARTS_MPS"
    prompt ok "Write down  a list of  partitions and mountpoints to be used."
    prompt ok "    If you leave it blank, the default:"
    prompt ok ""
    for ix in ${!PARTS_MPS[*]}; do
        write_log "going through ix=$ix"
        re='^\s*$'
        if [[ ! ${PARTS_MPS[$ix]} =~ $re ]]; then
            set -- ${PARTS_MPS[$ix]}
            l="$(printf "%-15s %s\n" "$1" "${2:-}")"
            prompt ok "        $l"
        fi
    done
    prompt ok ""
    prompt ok "    taken  from  previous sessions will be used.  Finish your"
    prompt ok "    list with an end-of-file (Ctrl-D)"
    declare -a temp_pmps='()'
    while read l; do
        if [[ $l ]]; then
            temp_pmps+=("$l")
        fi
    done <<<"$(cat)"
    write_log "read part-mps list from user:"
    write_log "$(declare -p temp_pmps)"
    user_left_blank='yes'
    re='^\s*$'
    for ix in ${!temp_pmps[*]}; do
        if [[ ! ${temp_pmps[$ix]} =~ $re ]]; then
            user_left_blank='no'
            break
        fi
    done
    if [[ $user_left_blank == 'no' ]]; then
        PARTS_MPS=("${temp_pmps[@]}")
    else
        write_log "user left \$temp_pmps in blank. Using original parts-mps"
    fi
else # there is no default
    write_log "didn't find a default PARTS_MPS"
    prompt ok "Write down  a list of  partitions and their mountpoints,  one"
    prompt ok "    partition/mountpoint pair per line. Example:"
    prompt ok ""
    prompt ok "        /dev/sdx3    $LFS/"
    prompt ok "        /dev/sdy7    swap"
    prompt ok "        /dev/sdz1    $LFS/home"
    prompt ok ""
    prompt ok "    Finish your list with an end-of-file (Ctrl-D)"
    unset PARTS_MPS
    declare -a PARTS_MPS
    while read l; do
        if [[ $l ]]; then
            PARTS_MPS+=("$l")
        fi
    done <<<"$(cat)"
fi
echo
write_log "parts-mps defined:"
write_log "$(declare -p PARTS_MPS)"
echo "unset PARTS_MPS; $(declare -p PARTS_MPS)" >> mklfs.conf

declare -a IGNORE_PARTS='()' 
prompt ok "Now  mount the root partition in \$LFS,  create the mountpoint"
prompt ok "    directories  for  the  other  partitions  you  made (e.g."
prompt -n ok "    \$LFS/home), and mount them. Hit \`enter' when done."
read
echo
for ix in ${!PARTS_MPS[*]}; do
    set -- ${PARTS_MPS[$ix]}
    if [[ $# -lt 2 || $2 != /* ]]; then
        continue
    fi
    pmps_source="$1"
    pmps_target="$2"
    while ! (
        unset TARGET &&
        eval "$(findmnt -P --source "$pmps_source" -o TARGET)" &&
        [[ -v TARGET && $TARGET == $pmps_target ]]
    ); do
        write_log "detected unmounted partition"
        prompt warn "We detected an unmounted partition: $1"
        prompt warn "It should be mounted at $2"
        prompt -n warn "Mount it and hit \`enter', or type \`ignore': "
        read l
        echo
        if [[ $l == i* ]]; then
            IGNORE_PARTS[$ix]=i
            break
        fi
    done
done
write_log "Partitions mounted."

prompt ok "The LFS book  suggests  checking  if  the partitions  are not"
prompt ok "    \"mounted with permissions that are too restrictive  (such"
prompt ok "    as the \`nosuid' or \`nodev' options)\"."
echo

l="check"
while [[ $l == c* ]]; do
    prompt cmd "tree -Cadp \$LFS"
    tree -Cadp $LFS
    prompt cmd "mount | grep \$LFS"
    (mount | grep $LFS) || true
    echo

    prompt ok "After checking above as suggested,  hit \`enter' to  continue,"
    prompt -n ok "    or type \`check' to check again: "
    read l
    echo
done
write_log "Mounting checked."

### ###     3.1
### ###     3.2
### ###     3.3
### ###
fi; if [[ $START_CHP -lt 3 || ( $START_CHP -eq 3 && $START_SCT -le 3 ) ]]; then
prompt header "SECTION 3.1. Introduction (to \"Packages and Patches\")" \
              "SECTION 3.2. All Packages" \
              "SECTION 3.3. Needed Patches"
echo
[[ -f mklfs.conf ]] && . mklfs.conf
if [[ ! ${LFS:-} ]]; then
    prompt -n ok "Choose a \$LFS [default: /mnt/lfs]: "
    read l
    if [[ ! $l ]]; then
        l=/mnt/lfs
    fi
    while [[ ! -d $l ]]; do
        prompt -n ok "Create the directory $l, and then hit \`enter': "
        read
    done
    export LFS="$(realpath -s $l)"
    echo "unset LFS; $(declare -p LFS)" >> mklfs.conf
    echo
    write_log "LFS=$LFS"
fi
for ix in ${!PARTS_MPS[*]}; do
    set -- ${PARTS_MPS[$ix]}
    if [[ $# -lt 2 || $2 != /* || -v IGNORE_PARTS[$ix] ]]; then
        continue
    fi
    pmps_source="$1"
    pmps_target="$2"
    while ! (
        unset TARGET &&
        eval "$(findmnt -P --source "$pmps_source" -o TARGET | head -n1)" &&
        [[ -v TARGET && $TARGET == $pmps_target ]]
    ); do
        write_log "detected unmounted partition"
        prompt warn "We detected an unmounted partition: $1"
        prompt warn "It should be mounted at $2"
        prompt -n warn "Mount it and hit \`enter', or type \`ignore': "
        read l
        echo
        if [[ $l == i* ]]; then
            IGNORE_PARTS[$ix]=i
            break
        fi
    done
done

prompt -n ok \
  "Choose a sources directory [default ${LFS_SOURCES:-\$LFS/sources}]: "
read l
if [[ ! $l ]]; then
    l="${LFS_SOURCES:-\$LFS/sources}"
fi
l="$(realpath -s $l)"
safe_l="`printf '%q' \"$l\"`"
while [[ ! -d $l ]]; do
    prompt -r cmd "mkdir -pv "$safe_l
    prompt ok "(type in root passwd)"
    su -c "mkdir -pv "$safe_l -
done
export LFS_SOURCES="$l"
safe_LFS_SOURCES=$safe_l
echo "unset LFS_SOURCES; $(declare -p LFS_SOURCES)" >> mklfs.conf
echo
write_log "LFS_SOURCES=$LFS_SOURCES"
write_log "LFS_SOURCES now exists"

should_i_echo=no
while [[ ! -k $LFS_SOURCES ]]; do
    should_i_echo=yes
    prompt -r cmd "chmod -v a+wt "$safe_l
    su -c "chmod -v a+wt "$safe_l -
done
[[ $should_i_echo == 'yes' ]] && echo
write_log "LFS_SOURCES now is sticky"

if ! which md5sum > /dev/null; then
    prompt err "Can't  find  md5sum !  Place it  in  the  same  directory  as"
    prompt err "    mklfs.sh:"
    prompt err ""
    prompt err "        `pwd`"
    prompt err ""
    prompt err "    and then run mklfs.sh again."
    echo
    write_log "Couldn't find md5sum"
    mklfs_cleanup
    exit $EXIT_NOTFOUND_MD5SUM
fi

if [[ ! -f "md5sums-no-kernel" ]]; then
    prompt err "Can't find md5sums-no-kernel ! Place it in the same directory"
    prompt err "    as mklfs.sh:"
    prompt err ""
    prompt err "        `pwd`"
    prompt err ""
    prompt err "    and then run mklfs.sh again."
    echo
    write_log "Couldn't find md5sums-no-kernel"
    mklfs_cleanup
    exit $EXIT_NOTFOUND_MD5SUMS_NOKERNEL
fi

prompt cmd "cp -v md5sums-no-kernel \$LFS_SOURCES/"
cp -v md5sums-no-kernel "$LFS_SOURCES/"
echo

if ! which gpg > /dev/null; then
    prompt err "Can't find gpg !  Place it in the same directory as mklfs.sh:"
    prompt err ""
    prompt err "        `pwd`"
    prompt err ""
    prompt err "    and then run mklfs.sh again."
    echo
    write_log "Couldn't find gpg"
    mklfs_cleanup
    exit $EXIT_NOTFOUND_GPG
fi

if ! which xz > /dev/null; then
    prompt err "Can't find xz !  Place it in the same directory as mklfs.sh:"
    prompt err ""
    prompt err "        `pwd`"
    prompt err ""
    prompt err "    and then run mklfs.sh again."
    echo
    write_log "Couldn't find xz"
    mklfs_cleanup
    exit $EXIT_NOTFOUND_XZ
fi

prompt ok "Downloading kernel signature key..."
prompt cmd "gpg --keyserver \"hkp://keys.gnupg.net\" --recv-keys \"6092693E\""
prompt -n ok "(You can quit now if you want) "
read
echo
tries=0
while ! gpg --keyserver "hkp://keys.gnupg.net" --recv-keys "6092693E"; do
    sleep_time=$((2**tries))
    let tries+=1
    if [[ $tries -gt 6 ]]; then
        write_log "bad wget (kernel key) after 6 tries"
        prompt err "Can't download kernel signature key! Exiting."
        mklfs_cleanup
        exit $EXIT_DOWNLOAD_KERNEL_KEY
    fi
    prompt warn "Failed downloading kernel signature key! :\\"
    prompt -n warn "Trying again after $sleep_time second(s)..."
    sleep $sleep_time
    echo
done

prompt ok "Now, hit \`enter' to download all packages and patches. If you"
prompt -n ok "    want to skip this part, type \`skip': "
read l
echo
if ! [[ $l == s* ]]; then

    if [[ ! -f "wget-list-no-kernel" ]]; then
        prompt err "Can't  find  wget-list-no-kernel !   Place  it  in  the  same"
        prompt err "    directory as mklfs.sh:"
        prompt err ""
        prompt err "        `pwd`"
        prompt err ""
        prompt err "    and then run mklfs.sh again."
        echo
        write_log "Couldn't find wget-list-no-kernel"
        mklfs_cleanup
        exit $EXIT_NOTFOUND_WGETLIST_NOKERNEL
    fi

    prompt ok "We will download everything, except for the linux kernel."
    prompt cmd "wget -nv -N -i wget-list-no-kernel -P \"$LFS_SOURCES\""
    tries=0
    while ! (
        wget -nv -N -i "wget-list-no-kernel" -P "$LFS_SOURCES" &&
        echo && prompt ok "Checking packages..." && echo &&
        cd "$LFS_SOURCES" && md5sum -c md5sums-no-kernel
    ); do
        sleep_time=$((2**tries))
        let tries+=1
        if [[ $tries -gt 6 ]]; then
            write_log "bad wget (list-no-kernel) after 6 tries"
            prompt err "Can't download packages! Exiting."
            mklfs_cleanup
            exit $EXIT_DOWNLOAD_WGETLIST_NOKERNEL
        fi
        prompt warn "Failed downloading packages! :\\"
        prompt -n warn "Trying again after $sleep_time second(s)..."
        sleep $sleep_time
        echo
        prompt cmd "wget -nv -N -i wget-list-no-kernel -P $safe_LFS_SOURCES"
    done
    write_log "downloaded packages (no kernel) after $tries tries"
    echo

    prompt ok "Now, downloading the linux kernel.  First, we have to find the"
    prompt ok "    latest 3.16.x kernel..."
    echo

    kernel_version=''
    while ! which git > /dev/null; do
        write_log "didn't find git; asking to install"
        prompt warn \
            "We need  git  installed  in order  to find  the latest 3.16.x"
        prompt warn \
            "    kernel version.  You  can  (1) install git and  then  hit"
        prompt warn \
            "    \`enter';  or (2) type the kernel version you want to use,"
        prompt -n warn "    e.g., if you want to use 3.16.6 type \`v3.16.6': "
        read l
        if [[ $l == v* ]]; then
            write_log "user chose to specify version $l for the kernel"
            kernel_version="${l#*v}"
            [[ $kernel_version ]] && break
            write_log "bad version specified by user"
        else
            write_log "user has installed git. we'll test it again"
        fi
    done
    if [[ ! $kernel_version ]]; then
        git_kernel_repo="git://git.kernel.org/pub/scm/linux/kernel/git"
        git_kernel_repo="$git_kernel_repo/stable/linux-stable.git"
        tries=0
        write_log "will begin looking for latest supported kernel..."
        while kernel_version=`
            git ls-remote $git_kernel_repo |
            grep -E 'refs\/tags\/v3\.16\.[0-9]+$' |
            sed 's:[a-fA-F0-9]*\s*refs/tags/v3.16.::' |
            sort -rn | head -n1
        `; [[ ! $kernel_version ]]; do
            write_log "tries=$tries and couldn't find latest version"
            sleep_time=$((2**tries))
            let tries+=1
            if [[ $tries -gt 6 ]]; then
                write_log "bad wget (git.kernel.org) after 6 tries"
                prompt err "Can't find latest 3.16.x kernel! Exiting."
                mklfs_cleanup
                exit $EXIT_DOWNLOAD_KERNEL_GIT
            fi
            prompt warn "Failed searching for the latest 3.16.x kernel :\\"
            prompt -n warn "Trying again after $sleep_time second(s)..."
            sleep $sleep_time
            echo
        done
        kernel_version="3.16.$kernel_version"
        write_log "found latest kernel: $kernel_version"
    fi
    write_log "using kernel_version=$kernel_version"

    kernel_tarb="linux-$kernel_version.tar.xz"
    kernel_sig="linux-$kernel_version.tar.sign"
    kernel_url="https://www.kernel.org/pub/linux/kernel/v3.x/$kernel_tarb"
    kernel_sigurl="https://www.kernel.org/pub/linux/kernel/v3.x/$kernel_sig"
    prompt ok "Downloading kernel $kernel_version ..."
    prompt cmd "wget -nv -N -P \"$LFS_SOURCES\" \"$kernel_url\" &&"
    prompt -c cmd "wget -nv -N -P \"$LFS_SOURCES\" \"$kernel_sigurl\""
    tries=0
    while ! (
        wget -nv -N -P "$LFS_SOURCES" "$kernel_url" &&
        wget -nv -N -P "$LFS_SOURCES" "$kernel_sigurl" &&
        echo && prompt ok "Checking kernel..." &&
        echo && cd "$LFS_SOURCES" &&
        xz -cd "$kernel_tarb" | gpg --verify "$kernel_sig" -
    ); do
        sleep_time=$((2**tries))
        let tries+=1
        if [[ $tries -gt 6 ]]; then
            write_log "bad wget (kernel) after 6 tries"
            prompt err "Can't download kernel or kernel signature! Exiting."
            mklfs_cleanup
            exit $EXIT_DOWNLOAD_KERNEL
        fi
        prompt warn "Failed downloading kernel or kernel signature! :\\"
        prompt -n warn "Trying again after $sleep_time second(s)..."
        sleep $sleep_time
        echo
    done

    prompt ok "Kernel $kernel_version downloaded and checked!"
    write_log "kernel downloaded and checked"

else

    write_log "skipped package downloading"

    prompt ok "We will check the packages and patches in $LFS_SOURCES"
    if ! (cd "$LFS_SOURCES" && md5sum -c md5sums-no-kernel); then
        prompt warn "Some packages and/or patches failed the checksum.  If you hit"
        prompt warn "    \`enter',  mklfs.sh will quit,  but  you can type \`yes' to"
        prompt -n warn "    ignore this, and continue: "
        read l
        if [[ $l != y* ]]; then
            user_figout $EXIT_CHECKSUM_PACKAGES
        fi
    fi
    echo

    prompt ok "All patches  and  most packages  checked.  Now,  checking the"
    prompt ok "    kernel tarball."
    #TODO: check the kernel
    #first, find out what's the kernel version
    #$ ls "$LFS_SOURCES" | grep -E '^linux-3\.16\.[0-9]+\.tar\.(gz|bz2|xz)'
    #verificar se esse comando ai em cima da pelo menos um resultado;
    #se sim:
    #   talvez sejam varios resultados; extrair o mais recente
    #se nao:
    #   avisar o user que deu ruim e perguntar se quer sair, ou se quer
    #       especificar um arquivo (e abrir mao do checksum)
    kernel_minor="$(
        ls "$LFS_SOURCES" |
        grep -E '^linux-3\.16\.[0-9]+\.tar\.(gz|bz2|xz)$' |
        sed -r 's/^linux-3\.16\.([0-9]+)\.tar\.(gz|bz2|xz)$/\1/g' |
        sort -rn | head -n1
    )"
    kernel_ext="$(
        ls "$LFS_SOURCES" |
        grep -E '^linux-3\.16\.'"$kernel_minor"'\.tar\.(gz|bz2|xz)$' |
        sed -r 's/^linux-3\.16\.'"$kernel_minor"'\.tar\.(gz|bz2|xz)$/\1/g' |
        head -n1
    )"
    if [[ $kernel_minor && $kernel_ext ]]; then
        # verificar o kernel linux-3.16.${kernel_minor}.tar.${kernel_ext}
        kernel_tarb="linux-3.16.${kernel_minor}.tar.${kernel_ext}"
        kernel_sig="linux-3.16.${kernel_minor}.tar.sign"
        if ! (xz -cd "$kernel_tarb" | gpg --verify "$kernel_sig" -); then
            prompt err "Bad signature on kernel tarball $kernel_tarb !! :\\"
            prompt err "You can try again after re-downloading your linux-* package."
            mklfs_cleanup
            exit $EXIT_CHECKSUM_KERNEL
        fi
    else
        # nao achei o kernel tarball
    fi

    prompt ok "All downloads checked!"

fi
echo
export LFS_KERNEL_PKG="$kernel_tarb"
echo "unset LFS_KERNEL_PKG; $(declare -p LFS_KERNEL_PKG)" >> mklfs.conf
echo
write_log "LFS_KERNEL_PKG=$LFS_KERNEL_PKG"

### ###     4.2
### ###
fi; if [[ $START_CHP -lt 4 || ( $START_CHP -eq 4 && $START_SCT -le 2 ) ]]; then
prompt header "SECTION 4.2. Creating the \$LFS/tools Directory"
echo
[[ -f mklfs.conf ]] && . mklfs.conf
if [[ ! ${LFS:-} ]]; then
    prompt -n ok "Choose a \$LFS [default: /mnt/lfs]: "
    read l
    if [[ ! $l ]]; then
        l=/mnt/lfs
    fi
    while [[ ! -d $l ]]; do
        prompt -n ok "Create the directory $l, and then hit \`enter': "
        read
    done
    export LFS="$(realpath -s $l)"
    echo "unset LFS; $(declare -p LFS)" >> mklfs.conf
    echo
    write_log "LFS=$LFS"
fi
for ix in ${!PARTS_MPS[*]}; do
    set -- ${PARTS_MPS[$ix]}
    if [[ $# -lt 2 || $2 != /* || -v IGNORE_PARTS[$ix] ]]; then
        continue
    fi
    pmps_source="$1"
    pmps_target="$2"
    while ! (
        unset TARGET &&
        eval "$(findmnt -P --source "$pmps_source" -o TARGET | head -n1)" &&
        [[ -v TARGET && $TARGET == $pmps_target ]]
    ); do
        write_log "detected unmounted partition"
        prompt warn "We detected an unmounted partition: $1"
        prompt warn "It should be mounted at $2"
        prompt -n warn "Mount it and hit \`enter', or type \`ignore': "
        read l
        echo
        if [[ $l == i* ]]; then
            IGNORE_PARTS[$ix]=i
            break
        fi
    done
done
#TODO: fazer algo a respeito do LFS_KERNEL_PKG



fi # sections
mklfs_cleanup