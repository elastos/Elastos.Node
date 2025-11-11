#!/bin/bash

#
# utility
#
echo_warn()
{
    if [ -t 1 ]; then
        echo -e "\033[1;33mWARNING:\033[0m $1" 1>&2
    else
        echo "WARNING: $1" 1>&2
    fi
}

echo_error()
{
    if [ -t 1 ]; then
        echo -e "\033[1;31mERROR:\033[0m $1" 1>&2
    else
        echo "ERROR: $1" 1>&2
    fi
}

echo_info()
{
    if [ -t 1 ]; then
        echo -e "\033[1;34mINFO:\033[0m $1"
    else
        echo "INFO: $1"
    fi
}

echo_ok()
{
    if [ -t 1 ]; then
        echo -e "\033[1;32mOK:\033[0m $1"
    else
        echo "OK: $1"
    fi
}

update_script()
{
    local SCRIPT_URL=https://raw.githubusercontent.com/elastos/Elastos.Node/master/build/skeleton/node.sh

    local SCRIPT=$SCRIPT_PATH/$(basename $BASH_SOURCE)
    local SCRIPT_TMP=$SCRIPT.tmp

    echo "Downloading $SCRIPT_URL..."
    curl -# -o $SCRIPT_TMP $SCRIPT_URL
    if [ "$?" != "0" ]; then
        echo_error "curl failed"
        return
    fi

    mv $SCRIPT_TMP $SCRIPT
    chmod a+x $SCRIPT

    echo_ok "$SCRIPT updated"
}

set_env()
{
    # ulimit open files: use system setting if it is greater
    if [ $(ulimit -n) -lt 40960 ]; then
        ulimit -n 40960
    fi
}

check_env()
{
    #echo "Checking OS Version..."
    if [ "$(uname -s)" == "Linux" ]; then
        local DIST_NAME=$(lsb_release -s -i 2>/dev/null)
        local DIST_VER=$(lsb_release -s -r 2>/dev/null)
        if [ "$DIST_NAME" == "Ubuntu" ]; then
            if [ "$DIST_VER" \< "18.04" ]; then
                echo_error "this script requires Ubuntu 18.04 or higher"
                exit
            fi
        else
            echo_error "do not support $(cat /etc/issue)"
            exit
        fi
        if [ "$(uname -m)" == "aarch64" ]; then
            # The ARM64 version has not been fully tested.
            # USE ARM64 BUILD AT YOUR OWN RISK!
            # To enable ARM64 version, set ENABLE_ARM64 to 1 or non-empty.
            local ENABLE_ARM64=
            if [ "$ENABLE_ARM64" == "" ]; then
                echo_error "do not support $(uname -m)"
                exit
            else
                echo_warn "the arm64 build have not been fully-tested"
            fi
        elif [ "$(uname -m)" == "x86_64" ]; then
            true
        else
            echo_error "do not support $(uname -m)"
        fi
    else
        echo_error "do not support $(uname -s)"
        exit
    fi

    #echo "Checking sudo permission..."
    sudo -n true 2>/dev/null
    if [ "$?" == "0" ]; then
        echo_warn "it is better to run as a normal user without sudo permission"
    fi

    if [ "$(which jq)" == "" ]; then
        echo_error "cannot find jq (https://github.com/stedolan/jq)"
        echo_info "sudo apt-get install -y jq"
        exit
    fi

    if [ "$(which lsof)" == "" ]; then
        echo_error "cannot find lsof"
        echo_info "sudo apt-get install -y lsof"
        exit
    fi

    if [ "$(which rotatelogs)" == "" ]; then
        echo_error "cannot find rotatelogs"
        echo_info "sudo apt-get install -y apache2-utils"
        exit
    fi

    if [ "${BASH_ARGV[0]}" == "init" ]; then
        check_env_oracle
    fi
}

check_env_oracle()
{
    if [ "$(uname -sm)" == "Linux aarch64" ]; then
        if [ "$(which make)" == "" ]; then
            echo_error "cannot find make"
            echo_info "sudo apt-get install -y make"
            exit
        fi
        if [ "$(which gcc)" == "" ]; then
            echo_error "cannot find gcc"
            echo_info "sudo apt-get install -y gcc"
            exit
        fi
        if [ "$(which g++)" == "" ]; then
            echo_error "cannot find g++"
            echo_info "sudo apt-get install -y g++"
            exit
        fi
    fi
}

init_config()
{
    local CONFIG_FILE=~/.config/elastos/${SCRIPT_NAME%.*}.json

    if [ -f $CONFIG_FILE ]; then
        echo_error "$CONFIG_FILE exist"
        exit
    fi

    echo "Please select the network:"
    echo
    echo "  1. MainNet"
    echo "  2. TestNet"

    local SELECT=
    while true; do
        echo
        read -p '? Your option: [1] ' SELECT

        if [ "$SELECT" == "" ] || [ "$SELECT" == "1" ]; then
            local CHAIN_TYPE=mainnet
            break
        elif [ "$SELECT" == "2" ]; then
            local CHAIN_TYPE=testnet
            break
        else
            echo_error "no such option: $SELECT"
            continue
        fi
    done

    mkdir -p  $(dirname $CONFIG_FILE)
    chmod 700 $(dirname $CONFIG_FILE)

    touch $CONFIG_FILE
    chmod 600 $CONFIG_FILE
    cat <<EOF >$CONFIG_FILE
{
    "chain-type": "$CHAIN_TYPE"
}
EOF

    echo_info "config file: $CONFIG_FILE"
}

load_config()
{
    local CONFIG_FILE=~/.config/elastos/${SCRIPT_NAME%.*}.json

    if [ ! -f $CONFIG_FILE ]; then
        init_config
        exit
    fi

    export CHAIN_TYPE=$(cat $CONFIG_FILE | jq -r '.["chain-type"]')

    if [ "$CHAIN_TYPE" != "mainnet" ] && \
       [ "$CHAIN_TYPE" != "testnet" ]; then

        echo_error "no chain type selected"
        echo_info "Please edit $CONFIG_FILE and set chain-type as mainnet or testnet"
        exit
    fi
}

set_path()
{
    # bash will not read .profile if .bash_profile exists
    if [ -f ~/.bash_profile ]; then
        local PROFILE_FILE=~/.bash_profile
    elif [ -f ~/.profile ]; then
        local PROFILE_FILE=~/.profile
    else
        touch ~/.profile
        local PROFILE_FILE=~/.profile
    fi

    if [ ! -f $PROFILE_FILE ]; then
        echo "ASSERT: no $PROFILE_FILE found, skip..."
    fi

    grep "export PATH=$SCRIPT_PATH:\$PATH" $PROFILE_FILE >/dev/null
    if [ "$?" != "0" ]; then
        echo "Updating $PROFILE_FILE..."
        echo "export PATH=$SCRIPT_PATH:\$PATH" >>$PROFILE_FILE
        echo_info "please re-login to make PATH effective"
    fi
}

set_cron()
{
    local SP0='[[:space:]]*'
    local SP1='[[:space:]]\+'

    crontab -l 2>/dev/null |
        grep -q "^${SP0}@reboot${SP1}~/node/node.sh${SP1}start${SP0}$"
    if [ "$?" != "0" ]; then
    (
        crontab -l 2>/dev/null
        echo '@reboot      ~/node/node.sh start'
    ) | crontab -
    fi

    crontab -l 2>/dev/null |
        grep -q "^${SP0}\*/10${SP1}\*${SP1}\*${SP1}\*${SP1}\*${SP1}~/node/node.sh${SP1}compress_log${SP0}$"
    if [ "$?" != "0" ]; then
    (
        crontab -l 2>/dev/null
        echo '*/10 * * * * ~/node/node.sh compress_log'
    ) | crontab -
    fi

    crontab -l 2>/dev/null
}

extip()
{
    curl -s https://checkip.amazonaws.com
}

trim()
{
    sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

mem_free()
{
    free -mt | sed -n '4 s/.* //p'
}

mem_usage()
{
    if [ "$1" == "" ]; then
        return
    fi

    pmap $1 | tail -1 | sed 's/.* //' | numfmt --from=iec --to=iec
}

run_time()
{
    if [ "$1" == "" ]; then
        return
    fi

    ps -oetime= -p $PID | trim
}

num_tcps()
{
    if [ "$1" == "" ]; then
        return
    fi

    lsof -n -a -itcp -p $PID 2>/dev/null | wc -l | trim
}

num_files()
{
    if [ "$1" == "" ]; then
        return
    fi

    lsof -n -p $PID 2>/dev/null | wc -l | trim
}

disk_usage()
{
    if [ "$1" == "" ] || [ ! -d "$1" ]; then
        echo N/A
        return
    fi

    du -sh $1 | sed 's/^ *//;s/\t.*$//'
}

list_tcp()
{
    if [ "$1" == "" ]; then
        return
    fi

    for i in $(lsof -nP -iTCP -sTCP:LISTEN -a -p $1 2>/dev/null | sed '1d' |
               awk '{ print $5 "_" $9 }' | sort -t ':' -k 2); do
        echo -n "$i "
    done
    echo
}

list_udp()
{
    if [ "$1" == "" ]; then
        return
    fi

    for i in $(lsof -nP -iUDP -a -p $1 2>/dev/null | sed '1d' | awk '{ print $5 "_" $9 }' | sort -u); do
        echo -n "$i "
    done
    echo
}

status_head()
{
    if [ -t 1 ]; then
        if [ "$3" == "Running" ]; then
            local FG_COLOR=2
        elif [ "$3" == "Stopped" ]; then
            local FG_COLOR=1
        else
            local FG_COLOR=8
        fi
        printf "$(tput smul)%-16s%-20s$(tput setaf $FG_COLOR)$(tput bold)%s$(tput sgr0)\n" $1 $2 $3
    else
        printf "%-16s%-20s%s\n" $1 $2 $3
    fi
}

status_info()
{
    if [ -t 1 ]; then
        printf "$(tput bold)%-16s$(tput sgr0)" "$1:"
        if [ "$1" == "BPoS State" ]; then
            if [ "$2" == "Active" ]; then
                echo "$(tput setaf 2)$(tput bold)$2$(tput sgr0)"
            elif [ "$2" == "Canceled" ] || \
                 [ "$2" == "Illegal"  ] || \
                 [ "$2" == "Inactive" ] || \
                 [ "$2" == "Pending"  ] || \
                 [ "$2" == "Returned" ]; then
                echo "$(tput setaf 1)$(tput bold)$2$(tput sgr0)"
            else
                echo "$2"
            fi
        elif [ "$1" == "CRC State" ]; then
            if [ "$2" == "Elected" ]; then
                echo "$(tput setaf 2)$(tput bold)$2$(tput sgr0)"
            elif [ "$2" == "Illegal"    ] || \
                 [ "$2" == "Impeached"  ] || \
                 [ "$2" == "Inactive"   ] || \
                 [ "$2" == "Returned"   ] || \
                 [ "$2" == "Terminated" ]; then
                echo "$(tput setaf 1)$(tput bold)$2$(tput sgr0)"
            else
                echo "$2"
            fi
        else
            echo "$2"
        fi
    else
        printf "%-16s%s\n" "$1:" "$2"
    fi
}

gen_pass()
{
    KEYSTORE_PASS=
    local KEYSTORE_PASS_VERIFY=

    echo "Please input a password (ENTER to use a random one)"
    while true; do
        read -s -p '? Password: ' KEYSTORE_PASS
        echo

        if [ "$KEYSTORE_PASS" == "" ]; then
            echo "Generating random password..."
            KEYSTORE_PASS=$(openssl rand -base64 100 | head -c 32)
            break
        elif [[ "${#KEYSTORE_PASS}" -lt 16 ]]   || \
             [[ ! "$KEYSTORE_PASS" =~ [a-z] ]] || \
             [[ ! "$KEYSTORE_PASS" =~ [A-Z] ]] || \
             [[ ! "$KEYSTORE_PASS" =~ [0-9] ]] || \
             [[ ! "$KEYSTORE_PASS" =~ [^[:alnum:]] ]]; then

            echo_error "the password does not meet the password policy:"
            echo "  - Minimum password length: 16"
            echo "  - Require at least one uppercase letter (A-Z)"
            echo "  - Require at least one lowercase letter (a-z)"
            echo "  - Require at least one digit (0-9)"
            echo "  - Require at least one non-alphanumeric character"
            continue
        else
            read -s -p '? Password (again): ' KEYSTORE_PASS_VERIFY
            echo
            if [ "$KEYSTORE_PASS" == "$KEYSTORE_PASS_VERIFY" ]; then
                break
            else
                echo_error "password mismatch"
                continue
            fi
        fi
    done
}

compress_log()
{
    if [ "$1" == "" ]; then
        return
    fi

    ls $1 1>/dev/null 2>/dev/null
    if [ "$?" != "0" ]; then
        return
    fi

    if [ -d "$1" ]; then
        local LOG_DIR="$1"
        local LOG_PAT=\*.log
    else
        local LOG_DIR=$(dirname "$1")
        local LOG_PAT=$(basename "$1")
    fi

    if [ "$IS_DEBUG" ]; then
        echo "LOG_DIR: $LOG_DIR"
        echo "LOG_PAT: $LOG_PAT"
    fi

    if [ -d $LOG_DIR ]; then
        echo "Compressing log files in $LOG_DIR..."
        cd $LOG_DIR
        for i in $(ls -1 $LOG_PAT 2>/dev/null | sort -r | sed 1d); do
            gzip -v $i
        done
    fi
}

remove_log()
{
    if [ "$1" == "" ]; then
        return
    fi

    ls $1 1>/dev/null 2>/dev/null
    if [ "$?" != "0" ]; then
        return
    fi

    if [ -d "$1" ]; then
        local LOG_DIR="$1"
        local LOG_PAT=\*.log
    else
        local LOG_DIR=$(dirname "$1")
        local LOG_PAT=$(basename "$1")
    fi

    if [ "$IS_DEBUG" ]; then
        echo "LOG_DIR: $LOG_DIR"
        echo "LOG_PAT: $LOG_PAT"
    fi

    if [ -d $LOG_DIR ]; then
        echo "Removing log files in $LOG_DIR..."
        cd $LOG_DIR
        for i in $(ls -1 $LOG_PAT 2>/dev/null | sort -r | sed 1d); do
            rm -v $i
        done
        for i in $(ls -1 $LOG_PAT.gz 2>/dev/null); do
            rm -v $i
        done
    fi
}

nodejs_setenv()
{
    local NODEJS_VER=v23.10.0

    local OS_ARCH=$(uname -sm)

    if [ "$OS_ARCH" == "Linux x86_64" ]; then
        local NODEJS_PLATFORM=linux-x64
    elif [ "$OS_ARCH" == "Linux aarch64" ]; then
        local NODEJS_PLATFORM=linux-arm64
    else
        echo_error "do not support $OS_ARCH"
        return
    fi

    local NODEJS_NAME=node-$NODEJS_VER-$NODEJS_PLATFORM
    local NODEJS_TGZ=$NODEJS_NAME.tar.xz
    local NODEJS_URL=https://nodejs.org/download/release/$NODEJS_VER/$NODEJS_TGZ

    if [ $IS_DEBUG ]; then
        echo "NODEJS_VER:  $NODEJS_VER"
        echo "NODEJS_NAME: $NODEJS_NAME"
        echo "NODEJS_TGZ:  $NODEJS_TGZ"
        echo "NODEJS_URL:  $NODEJS_URL"
    fi

    if [ ! -d $SCRIPT_PATH/extern/$NODEJS_NAME ]; then
        mkdir -p $SCRIPT_PATH/extern
        cd $SCRIPT_PATH/extern
        echo "Downloading $NODEJS_URL..."
        curl -O -# $NODEJS_URL
        tar xf $NODEJS_TGZ
    fi

    PATH=$SCRIPT_PATH/extern/$NODEJS_NAME/bin:$PATH

    echo "nodejs: $(which node)"
}

get_elastos_ver_latest()
{
    # URL_PREFIX
    if [ "$1" == "" ]; then
        return
    fi

    curl -s "$1/?F=1" | grep '\[DIR\]' \
        | sed -e 's/.*href="//' -e 's/".*//' -e 's/.*-//' -e 's/\/$//' \
        | sort -Vr | head -n 1
}

#
# common chain functions
#
chain_prepare_stage()
{
    local CHAIN_NAME=$1

    if [ "$CHAIN_NAME" != "ela" ] && \
       [ "$CHAIN_NAME" != "esc" ] && \
       [ "$CHAIN_NAME" != "esc-oracle" ] && \
       [ "$CHAIN_NAME" != "eid" ] && \
       [ "$CHAIN_NAME" != "eid-oracle" ] && \
       [ "$CHAIN_NAME" != "eco" ] && \
       [ "$CHAIN_NAME" != "eco-oracle" ] && \
       [ "$CHAIN_NAME" != "pgp" ] && \
       [ "$CHAIN_NAME" != "pgp-oracle" ] && \
       [ "$CHAIN_NAME" != "pg" ] && \
       [ "$CHAIN_NAME" != "pg-oracle" ] && \
       [ "$CHAIN_NAME" != "arbiter" ]; then
        echo_error "do not support chain: $1"
        return 1
    fi

    if [ "$2" == "" ]; then
        return 1
    fi

    local OS_ARCH=$(uname -sm)

    if [ "$CHAIN_NAME" == "ela" ] || \
       [ "$CHAIN_NAME" == "esc" ] || \
       [ "$CHAIN_NAME" == "eid" ] || \
       [ "$CHAIN_NAME" == "eco" ] || \
       [ "$CHAIN_NAME" == "pgp" ] || \
       [ "$CHAIN_NAME" == "pg" ] || \
       [ "$CHAIN_NAME" == "arbiter" ]; then
        if [ "$OS_ARCH" == "Linux aarch64" ]; then
            local RELEASE_PLATFORM=linux-arm64
        elif [ "$OS_ARCH" == "Linux x86_64" ]; then
            local RELEASE_PLATFORM=linux-x86_64
        else
            local RELEASE_PLATFORM=nosupport
        fi
    elif [ "$CHAIN_NAME" == "esc-oracle" ] || \
         [ "$CHAIN_NAME" == "eco-oracle" ] || \
         [ "$CHAIN_NAME" == "pgp-oracle" ] || \
         [ "$CHAIN_NAME" == "pg-oracle" ] || \
         [ "$CHAIN_NAME" == "eid-oracle" ]; then
        local RELEASE_PLATFORM=
    else
        local RELEASE_PLATFORM=nosupport
    fi

    local PATH_STAGE=$SCRIPT_PATH/.node-upload/$CHAIN_NAME

    echo "Finding the latest $CHAIN_NAME release..."
    if [ "$CHAIN_TYPE" == "mainnet" ]; then
        local URL_PREFIX=https://download.elastos.io/elastos-$CHAIN_NAME
        local VER_LATEST=$(get_elastos_ver_latest $URL_PREFIX)
    else
        local URL_PREFIX_BETA=https://download-beta.elastos.io/elastos-$CHAIN_NAME
        local VER_LATEST_BETA=$(get_elastos_ver_latest $URL_PREFIX_BETA)

        local URL_PREFIX=https://download.elastos.io/elastos-$CHAIN_NAME
        local VER_LATEST=$(get_elastos_ver_latest $URL_PREFIX)

        local VER_LATEST_HIGHER=$(echo -e "$VER_LATEST_BETA\n$VER_LATEST" |
            sort -Vr | head -n 1)

        # If beta channel has a higher release
        if [ "$VER_LATEST_HIGHER" == "$VER_LATEST_BETA" ]; then
            local URL_PREFIX=$URL_PREFIX_BETA
            local VER_LATEST=$VER_LATEST_BETA
        fi
    fi

    if [ "$VER_LATEST" == "" ]; then
        echo_error "no VER_LATEST found"
        return 2
    fi

    echo_info "Latest version: $VER_LATEST"

    if [ "$YES_TO_ALL" == "" ]; then
        local ANSWER
        read -p "Proceed update (No/Yes)? " ANSWER
        if [ "$ANSWER" != "Yes" ]; then
            echo "Updating canceled"
            return 3
        fi
    fi

    if [ "$CHAIN_NAME" == "esc-oracle" ] || \
       [ "$CHAIN_NAME" == "eco-oracle" ] || \
       [ "$CHAIN_NAME" == "pgp-oracle" ] || \
       [ "$CHAIN_NAME" == "pg-oracle" ] || \
       [ "$CHAIN_NAME" == "eid-oracle" ] ; then
        local TGZ_LATEST=elastos-${CHAIN_NAME}-${VER_LATEST}.tgz
        local URL_LATEST=$URL_PREFIX/elastos-${CHAIN_NAME}-${VER_LATEST}/${TGZ_LATEST}
    else
        local TGZ_LATEST=elastos-${CHAIN_NAME}-${VER_LATEST}-${RELEASE_PLATFORM}.tgz
        local URL_LATEST=$URL_PREFIX/elastos-${CHAIN_NAME}-${VER_LATEST}/${TGZ_LATEST}
    fi

    mkdir -p $PATH_STAGE
    cd $PATH_STAGE

    echo "Downloading $URL_LATEST..."
    curl -O -# $URL_LATEST
    if [ "$?" != "0" ]; then
        echo_error "curl failed"
        return 4
    fi
    # TODO: verify checksum

    tar --version | grep GNU 1>/dev/null
    if [ "$?" == "0" ]; then
        local TAR_FLAGS=--wildcards
    fi

    echo "Extracting $TGZ_LATEST..."
    shift
    set -f
    for i in $*; do
        tar xf $TGZ_LATEST $TAR_FLAGS --strip=1 \*/$i
        if [ "$?" != "0" ]; then
            echo_error "failed to extract $TGZ_LATEST"
            return 5
        fi
    done
    set +f

    return 0
}

#
# all
#
all_start()
{
    ela_installed        && ela_start
    esc_installed        && esc_start
    esc-oracle_installed && esc-oracle_start
    eid_installed        && eid_start
    eid-oracle_installed && eid-oracle_start
    eco_installed        && eco_start
    eco-oracle_installed && eco-oracle_start
    pgp_installed        && pgp_start
    pgp-oracle_installed && pgp-oracle_start
    pg_installed         && pg_start
    pg-oracle_installed  && pg-oracle_start
    arbiter_installed    && arbiter_start
}

all_stop()
{
    arbiter_installed    && arbiter_stop
    ela_installed        && ela_stop
    eid-oracle_installed && eid-oracle_stop
    eid_installed        && eid_stop
    esc-oracle_installed && esc-oracle_stop
    esc_installed        && esc_stop
    eco-oracle_installed && eco-oracle_stop
    pgp_installed        && pgp_stop
    pgp-oracle_installed && pgp-oracle_stop
    pg_installed         && pg_stop
    pg-oracle_installed  && pg-oracle_stop
    eco_installed        && eco_stop
}

all_status()
{
    ela_installed        && ela_status
    esc_installed        && esc_status
    esc-oracle_installed && esc-oracle_status
    eid_installed        && eid_status
    eid-oracle_installed && eid-oracle_status
    eco_installed        && eco_status
    eco-oracle_installed && eco-oracle_status
    pgp_installed        && pgp_status
    pgp-oracle_installed && pgp-oracle_status
    pg_installed         && pg_status
    pg-oracle_installed  && pg-oracle_status
    arbiter_installed    && arbiter_status
}

all_update()
{
    ela_installed        && ela_update
    esc_installed        && esc_update
    esc-oracle_installed && esc-oracle_update
    eid_installed        && eid_update
    eid-oracle_installed && eid-oracle_update
    eco_installed        && eco_update
    eco-oracle_installed && eco-oracle_update
    pgp_installed        && pgp_update
    pgp-oracle_installed && pgp-oracle_update
    pg_installed         && pg_update
    pg-oracle_installed  && pg-oracle_update
    arbiter_installed    && arbiter_update
}

all_init()
{
    ela_init
    esc_init
    esc-oracle_init
    eid_init
    eid-oracle_init
    eco_init
    eco-oracle_init
    pgp_init
    pgp-oracle_init
    pg_init
    pg-oracle_init
    arbiter_init
}

all_compress_log()
{
    ela_installed        && ela_compress_log
    esc_installed        && esc_compress_log
    esc-oracle_installed && esc-oracle_compress_log
    eid_installed        && eid_compress_log
    eid-oracle_installed && eid-oracle_compress_log
    eco_installed        && eco_compress_log
    eco-oracle_installed && eco-oracle_compress_log
    pgp_installed        && pgp_compress_log
    pgp-oracle_installed && pgp-oracle_compress_log
    pg_installed         && pg_compress_log
    pg-oracle_installed  && pg-oracle_compress_log
    arbiter_installed    && arbiter_compress_log
}

all_remove_log()
{
    ela_installed        && ela_remove_log
    esc_installed        && esc_remove_log
    esc-oracle_installed && esc-oracle_remove_log
    eid_installed        && eid_remove_log
    eid-oracle_installed && eid-oracle_remove_log
    eco_installed        && eco_remove_log
    eco-oracle_installed && eco-oracle_remove_log
    pgp_installed        && pgp_remove_log
    pgp-oracle_installed && pgp-oracle_remove_log
    pg_installed         && pg_remove_log
    pg-oracle_installed  && pg-oracle_remove_log
    arbiter_installed    && arbiter_remove_log

}

#
# ela
#
ela_usage()
{
    echo "Usage: $SCRIPT_NAME $CHAIN_NAME COMMAND [OPTIONS]"
    echo "Manage $CHAIN_NAME"
    echo
    echo "Available Commands:"
    echo
    echo "  init            Install and configure $CHAIN_NAME_U"
    echo "  update          Update $CHAIN_NAME_U"
    echo
    echo "  start           Start $CHAIN_NAME_U daemon"
    echo "  stop            Stop $CHAIN_NAME_U daemon"
    echo "  status          Print $CHAIN_NAME_U daemon status"
    echo "  watch           Start $CHAIN_NAME_U daemon and restart a crash"
    echo "  mon             Monitor $CHAIN_NAME_U height and alert a halt"
    echo
    echo "  compress_log    Compress $CHAIN_NAME_U daemon log files"
    echo "  remove_log      Remove $CHAIN_NAME_U daemon log files"
    echo
    echo "  client          Run $CHAIN_NAME_U client"
    echo "  jsonrpc         Call $CHAIN_NAME_U JSON-RPC API"
    echo
    echo "  send            Send crypto in $CHAIN_NAME_U"
    echo "  transfer        Send crypto from $CHAIN_NAME_U to sidechain"
    echo
    echo "  register_bpos   Register $CHAIN_NAME_U BPoS"
    echo "  activate_bpos   Activate $CHAIN_NAME_U BPoS"
    echo "  unregister_bpos Unregister $CHAIN_NAME_U BPoS"
    echo "  vote_bpos       Vote $CHAIN_NAME_U BPoS"
    echo "  stake_bpos      Stake $CHAIN_NAME_U BPoS"
    echo "  unstake_bpos    Unstake $CHAIN_NAME_U BPoS"
    echo "  claim_bpos      Claim rewards $CHAIN_NAME_U BPoS"
    echo
    echo "  register_crc    Register $CHAIN_NAME_U CRC"
    echo "  activate_crc    Activate $CHAIN_NAME_U CRC"
    echo "  unregister_crc  Unregister $CHAIN_NAME_U CRC"
    echo
}

ela_start()
{
    if [ ! -f $SCRIPT_PATH/ela/ela ]; then
        echo_error "$SCRIPT_PATH/ela/ela is not exist"
        return
    fi

    local PID=$(pgrep -x ela)
    if [ "$PID" != "" ]; then
        ela_status
        return
    fi

    echo "Starting ela..."
    cd $SCRIPT_PATH/ela
    if [ -f ~/.config/elastos/ela.txt ]; then
        cat ~/.config/elastos/ela.txt | nohup ./ela 1>/dev/null 2>output &
    else
        nohup ./ela 1>/dev/null 2>output &
    fi
    sleep 1
    ela_status
}

ela_stop()
{
    local PID=$(pgrep -x ela)
    if [ "$PID" != "" ]; then
        echo "Stopping ela..."
        kill $PID
        while ps -p $PID 1>/dev/null; do
            echo -n .
            sleep 1
        done
        echo
    fi
    sync
    ela_status
}

ela_installed()
{
    if [ -f $SCRIPT_PATH/ela/ela ]; then
        true
    else
        false
    fi
}

ela_ver()
{
    if [ -f $SCRIPT_PATH/ela/ela ]; then
        echo "ela $($SCRIPT_PATH/ela/ela -v | sed 's/.*\(v[0-9.][0-9\.]*\).*/\1/')"
    else
        echo "ela N/A"
    fi
}

ela_client()
{
    if [ ! -f $SCRIPT_PATH/ela/ela-cli ]; then
        return
    fi

    local ELA_RPC_USER=$(cat $SCRIPT_PATH/ela/config.json | \
        jq -r '.Configuration.RpcConfiguration.User')
    local ELA_RPC_PASS=$(cat $SCRIPT_PATH/ela/config.json | \
        jq -r '.Configuration.RpcConfiguration.Pass')

    if [ "$CHAIN_TYPE" == "mainnet" ]; then
        local ELA_RPC_PORT=20336
    elif [ "$CHAIN_TYPE" == "testnet" ]; then
        local ELA_RPC_PORT=21336
    else
        echo_error "do not support $CHAIN_TYPE"
        return
    fi

    local ELA_CLI="$SCRIPT_PATH/ela/ela-cli"

    cd $SCRIPT_PATH/ela

    if [ "$1" == "wallet" ]; then
        if [ "$2" == "delete" ]; then
            $ELA_CLI $*
        elif [ "$2" == "create"  ] || [ "$2" == "c" ] || \
             [ "$2" == "account" ] || [ "$2" == "a" ] || \
             [ "$2" == "add"     ] || \
             [ "$2" == "addmultisig" ] || \
             [ "$2" == "import"  ] || \
             [ "$2" == "export"  ] || \
             [ "$2" == "signtx"  ]; then
            $ELA_CLI $* --password "$(cat ~/.config/elastos/ela.txt)"
        elif [ "$2" == "balance" ] || [ "$2" == "b" ] || \
             [ "$2" == "sendtx"  ]; then
            $ELA_CLI --rpcport $ELA_RPC_PORT --rpcuser $ELA_RPC_USER \
                 --rpcpassword $ELA_RPC_PASS $*
        elif [ "$2" == "buildtx" ]; then
            if [ "$3" == "withdraw" ] || \
               [ "$3" == "activate" ] || \
               [ "$3" == "vote"     ]; then
                $ELA_CLI $* --password "$(cat ~/.config/elastos/ela.txt)"
            elif [ "$3" == "crc"               ] || \
                 [ "$3" == "dposv2claimreward" ] || \
                 [ "$3" == "producer"          ] || \
                 [ "$3" == "returnvotes"       ] || \
                 [ "$3" == "unstake"           ]; then
                $ELA_CLI --rpcport $ELA_RPC_PORT --rpcuser $ELA_RPC_USER \
                    --rpcpassword $ELA_RPC_PASS $* \
                    --password "$(cat ~/.config/elastos/ela.txt)"
            elif [ "$3" == "crosschain"    ] || \
                 [ "$3" == "dposv2vote"    ] || \
                 [ "$3" == "exchangevotes" ] || \
                 [ "$3" == "stake"         ]; then
                $ELA_CLI --rpcport $ELA_RPC_PORT --rpcuser $ELA_RPC_USER \
                    --rpcpassword $ELA_RPC_PASS $*
            else
                $ELA_CLI --rpcport $ELA_RPC_PORT --rpcuser $ELA_RPC_USER \
                    --rpcpassword $ELA_RPC_PASS $*
            fi
        else
            # showtx, depositaddr, stakeaddress, didaddr, crosschainaddr
            $ELA_CLI $*
        fi
    elif [ "$1" == "info" ] || \
         [ "$1" == "mine" ]; then
        $ELA_CLI --rpcport $ELA_RPC_PORT --rpcuser $ELA_RPC_USER \
            --rpcpassword $ELA_RPC_PASS $*
    else
        $ELA_CLI $*
    fi
}

ela_jsonrpc()
{
    if [ "$1" == "" ]; then
        return
    fi

    local ELA_RPC_USER=$(cat $SCRIPT_PATH/ela/config.json | \
        jq -r '.Configuration.RpcConfiguration.User')
    local ELA_RPC_PASS=$(cat $SCRIPT_PATH/ela/config.json | \
        jq -r '.Configuration.RpcConfiguration.Pass')

    if [ "$CHAIN_TYPE" == "mainnet" ]; then
        local ELA_RPC_PORT=20336
    elif [ "$CHAIN_TYPE" == "testnet" ]; then
        local ELA_RPC_PORT=21336
    else
        echo_error "do not support $CHAIN_TYPE"
        return
    fi

    if [[ $1 =~ ^[a-z2]+$ ]] && [ "$2" == "" ]; then
        # auto-expand the command without parameters
        local DATA={\"method\":\"$1\"}
    elif [[ $1 =~ ^[a-z2]+$ ]] &&
         [[ $2 =~ ^[a-z]+$  ]] && [[ $3 =~ ^[[:alnum:]]+ ]] &&
         [ "$4" == "" ]; then
        # auto-expand the command with only one parameter
        local DATA="{\"method\":\"$1\",\"params\":{\"$2\":\"$3\"}}"
    elif [[ $1 =~ ^[a-z2]+$ ]] &&
         [[ $2 =~ ^[a-z]+$  ]] && [[ $3 =~ ^[[:alnum:]]+ ]] &&
         [[ $4 =~ ^[a-z]+$  ]] && [[ $5 =~ ^[[:alnum:]]+ ]] &&
         [ "$6" == "" ]; then
        # auto-expand the command with two parameters
        local DATA="{\"method\": \"$1\",
            \"params\": {\"$2\":\"$3\",\"$4\":\"$5\"}}"
    else
        local DATA=$*
    fi

    curl -s -H 'Content-Type:application/json' \
        -X POST --data "$DATA" \
        -u $ELA_RPC_USER:$ELA_RPC_PASS \
        http://127.0.0.1:$ELA_RPC_PORT | jq .
}

ela_status()
{
    local ELA_VER=$(ela_ver)

    local ELA_DISK_USAGE=$(disk_usage $SCRIPT_PATH/ela)

    if [ -f ~/.config/elastos/ela.txt ]; then
        cd $SCRIPT_PATH/ela
        local ELA_ADDRESS=$(ela_client wallet account | sed -n '3 s/ .*$//p')
        local ELA_PUB_KEY=$(ela_client wallet account | sed -n '3 s/^.* //p')
    else
        local ELA_ADDRESS=N/A
        local ELA_PUB_KEY=N/A
    fi

    local PID=$(pgrep -x ela)
    if [ "$PID" == "" ]; then
        status_head $ELA_VER     Stopped
        status_info "Disk"       "$ELA_DISK_USAGE"
        status_info "Address"    "$ELA_ADDRESS"
        status_info "Public Key" "$ELA_PUB_KEY"
        echo
        return
    fi

    local ELA_RAM=$(mem_usage $PID)
    local ELA_UPTIME=$(run_time $PID)
    local ELA_NUM_TCPS=$(num_tcps $PID)
    local ELA_TCP_LISTEN=$(list_tcp $PID)
    local ELA_NUM_FILES=$(num_files $PID)

    local ELA_NUM_PEERS=$(ela_client info getconnectioncount)
    if [[ ! "$ELA_NUM_PEERS" =~ ^[0-9]+$ ]]; then
        ELA_NUM_PEERS=0
    fi
    local ELA_HEIGHT=$(ela_client info getcurrentheight)
    if [[ ! "$ELA_HEIGHT" =~ ^[0-9]+$ ]]; then
        ELA_HEIGHT=N/A
    fi

    local ELA_DPOS_NAME=$(ela_jsonrpc listproducers state all |
        jq -r ".result.producers[]? |
               select(.nodepublickey == \"$ELA_PUB_KEY\") | .nickname")
    if [ "$ELA_DPOS_NAME" == "" ]; then
        ELA_DPOS_NAME=N/A
    fi

    local ELA_DPOS_STATE=$(ela_jsonrpc listproducers state all |
        jq -r ".result.producers[]? |
               select(.nodepublickey == \"$ELA_PUB_KEY\") | .state")
    if [ "$ELA_DPOS_STATE" == "" ]; then
        ELA_DPOS_STATE=N/A
    fi

    local ELA_ADDRESS_STAKE=$(ela_client wallet stakeaddress $ELA_ADDRESS 2>/dev/null)
    local ELA_DPOS_STAKED=$(ela_jsonrpc "{\"method\":\"getvoterights\",
        \"params\":{\"stakeaddresses\":[\"$ELA_ADDRESS_STAKE\"]}}" |
        jq -r '.result[0].remainvoteright[4]'
    )
    if [ "$ELA_DPOS_STAKED" == "" ] || [ "$ELA_DPOS_STAKED" == "null" ]; then
        ELA_DPOS_STAKED=N/A
    fi

    local ELA_DPOS_VOTES=$(ela_jsonrpc listproducers state all |
        jq -r ".result.producers[]? |
               select(.nodepublickey == \"$ELA_PUB_KEY\") |
               if .dposv2votes then .dposv2votes else .votes end")
    if [ "$ELA_DPOS_VOTES" == "" ]; then
        ELA_DPOS_VOTES=N/A
    fi

    local ELA_DPOS_REWARDS=$(ela_jsonrpc dposv2rewardinfo |
        jq -r ".result[]? | select(.address == \"$ELA_ADDRESS\") | .claimable")
    if [ "$ELA_DPOS_REWARDS" == "" ]; then
        ELA_DPOS_REWARDS=N/A
    fi

    local ELA_CRC_NAME=$(ela_jsonrpc listcurrentcrs state all |
        jq -r ".result.crmembersinfo[]? |
               select(.dpospublickey == \"$ELA_PUB_KEY\") | .nickname")
    if [ "$ELA_CRC_NAME" == "" ]; then
        ELA_CRC_NAME=N/A
    fi

    local ELA_CRC_STATE=$(ela_jsonrpc listcurrentcrs state all |
        jq -r ".result.crmembersinfo[]? |
               select(.dpospublickey == \"$ELA_PUB_KEY\") | .state")
    if [ "$ELA_CRC_STATE" == "" ]; then
        ELA_CRC_STATE=N/A
    fi

    local ELA_BALANCE=$(ela_client wallet balance | awk 'NR == 3 {print $3}')
    if [ "$ELA_BALANCE" == "" ]; then
        ELA_BALANCE=N/A
    elif [[ $ELA_BALANCE =~ [^.0-9] ]]; then
        ELA_BALANCE=N/A
    fi

    status_head $ELA_VER Running
    status_info "Disk"         "$ELA_DISK_USAGE"
    status_info "Address"      "$ELA_ADDRESS"
    status_info "Public Key"   "$ELA_PUB_KEY"
    status_info "Balance"      "$ELA_BALANCE"
    status_info "PID"          "$PID"
    status_info "RAM"          "$ELA_RAM"
    status_info "Uptime"       "$ELA_UPTIME"
    status_info "#Files"       "$ELA_NUM_FILES"
    status_info "TCP Ports"    "$ELA_TCP_LISTEN"
    status_info "#TCP"         "$ELA_NUM_TCPS"
    status_info "#Peers"       "$ELA_NUM_PEERS"
    status_info "Height"       "$ELA_HEIGHT"
    status_info "BPoS Name"    "$ELA_DPOS_NAME"
    status_info "BPoS State"   "$ELA_DPOS_STATE"
    status_info "BPoS Staked"  "$ELA_DPOS_STAKED"
    status_info "BPoS Votes"   "$ELA_DPOS_VOTES"
    status_info "BPoS Rewards" "$ELA_DPOS_REWARDS"
    status_info "CRC Name"     "$ELA_CRC_NAME"
    status_info "CRC State"    "$ELA_CRC_STATE"
    echo
}

ela_compress_log()
{
    compress_log $SCRIPT_PATH/ela/elastos/logs/dpos
    compress_log $SCRIPT_PATH/ela/elastos/logs/node
}

ela_remove_log()
{
    remove_log $SCRIPT_PATH/ela/elastos/logs/dpos
    remove_log $SCRIPT_PATH/ela/elastos/logs/node
}

ela_update()
{
    unset OPTIND
    while getopts "npy" OPTION; do
        case $OPTION in
            n)
                local NO_START_AFTER_UPDATE=1
                ;;
            p)
                local PURGE_CHECKPOINTS=1
                ;;
            y)
                local YES_TO_ALL=1
                ;;
        esac
    done

    chain_prepare_stage ela ela ela-cli
    if [ "$?" != "0" ]; then
        return
    fi

    local PATH_STAGE=$SCRIPT_PATH/.node-upload/ela
    local DIR_DEPLOY=$SCRIPT_PATH/ela

    local PID=$(pgrep -x ela)
    if [ $PID ]; then
        ela_stop
    fi

    mkdir -p $DIR_DEPLOY
    cp -v $PATH_STAGE/ela $DIR_DEPLOY/
    cp -v $PATH_STAGE/ela-cli $DIR_DEPLOY/

    if [ $PURGE_CHECKPOINTS ] &&
       [ -d $SCRIPT_PATH/ela/elastos/data/checkpoints ]; then
        echo "Removing $SCRIPT_PATH/ela/elastos/data/checkpoints..."
        rm -rf $SCRIPT_PATH/ela/elastos/data/checkpoints
    fi

    # Start program, if 1 and 2
    # 1. ela was Running before the update
    # 2. user prefer not start ela explicitly
    if [ $PID ] && [ "$NO_START_AFTER_UPDATE" == "" ]; then
        ela_start
    fi
}

ela_init()
{
    local ELA_CONFIG=${SCRIPT_PATH}/ela/config.json
    local ELA_KEYSTORE=${SCRIPT_PATH}/ela/keystore.dat
    local ELA_KEYSTORE_PASS_FILE=~/.config/elastos/ela.txt

    if [ ! -f ${SCRIPT_PATH}/ela/ela ] || \
       [ ! -f ${SCRIPT_PATH}/ela/ela-cli ]; then
        ela_update -y
    fi

    if [ -f ${SCRIPT_PATH}/ela/.init ]; then
        echo_error "ela has already been initialized"
        return
    fi

    if [ -f $ELA_CONFIG ]; then
        echo_error "$ELA_CONFIG exists"
        return
    fi

    if [ -f $ELA_KEYSTORE_PASS_FILE ]; then
        echo_error "$ELA_KEYSTORE_PASS_FILE exists"
        return
    fi

    if [ -f $ELA_KEYSTORE ]; then
        echo_error "$ELA_KEYSTORE exists"
        return
    fi

    if [ ! -f $ELA_CONFIG ]; then
        echo "Creating ela config file..."

        if [ "$CHAIN_TYPE" == "testnet" ]; then
            cat >$ELA_CONFIG <<EOF
{
  "Configuration": {
    "ActiveNet": "testnet",
    "Magic": 2018101,
    "DPoSConfiguration": {
      "EnableArbiter": true,
      "IPAddress": "$(extip)"
    },
    "EnableRPC": true,
    "RpcConfiguration": {
      "User": "USER",
      "Pass": "PASSWORD",
      "WhiteIPList": [
        "127.0.0.1"
      ]
    }
  }
}
EOF
        else
            cat >$ELA_CONFIG <<EOF
{
  "Configuration": {
    "DPoSConfiguration": {
      "EnableArbiter": true,
      "IPAddress": "$(extip)"
    },
    "EnableRPC": true,
    "RpcConfiguration": {
      "User": "USER",
      "Pass": "PASSWORD",
      "WhiteIPList": [
        "127.0.0.1"
      ]
    }
  }
}
EOF
        fi

        echo "Generating random userpass for ela RPC interface..."
        local ELA_RPC_USER=$(openssl rand -base64 100 | shasum | head -c 32)
        local ELA_RPC_PASS=$(openssl rand -base64 100 | shasum | head -c 32)

        echo "Updating ela config file..."
        jq ".Configuration.RpcConfiguration.User=\"$ELA_RPC_USER\" | \
            .Configuration.RpcConfiguration.Pass=\"$ELA_RPC_PASS\"" \
            $ELA_CONFIG >$ELA_CONFIG.tmp
        if [ "$?" == "0" ]; then
            mv $ELA_CONFIG.tmp $ELA_CONFIG
        fi
    fi

    echo "Creating ela keystore..."
    gen_pass
    if [ "$KEYSTORE_PASS" == "" ]; then
        echo_error "empty password"
        exit
    fi
    cd ${SCRIPT_PATH}/ela/
    ./ela-cli wallet create -p "$KEYSTORE_PASS" >/dev/null
    if [ "$?" != "0" ]; then
        echo_error "failed to create ela keystore"
        return
    fi
    chmod 600 $ELA_KEYSTORE

    echo "Saving ela keystore password..."
    mkdir -p $(dirname $ELA_KEYSTORE_PASS_FILE)
    chmod 700 $(dirname $ELA_KEYSTORE_PASS_FILE)
    echo $KEYSTORE_PASS > $ELA_KEYSTORE_PASS_FILE
    chmod 600 $ELA_KEYSTORE_PASS_FILE

    echo "Checking ela keystore..."
    ./ela-cli wallet account -p "$KEYSTORE_PASS"
    if [ "$?" != "0" ]; then
        echo_error "failed to dump public key"
        return
    fi

    echo_info "ela config file: $ELA_CONFIG"
    echo_info "ela keystore file: $ELA_KEYSTORE"
    echo_info "ela keystore password file: $ELA_KEYSTORE_PASS_FILE"

    touch ${SCRIPT_PATH}/ela/.init
    echo_ok "ela initialized"
    echo
}

ela_send()
{
    if [ "$3" == "" ]; then
        echo "Usage: $SCRIPT_NAME ela send FROM TO AMOUNT [FEE]"
        return
    fi

    local ELA_ADDR_FROM=$1
    local ELA_ADDR_TO=$2
    local ELA_AMOUNT=$3
    local ELA_FEE=$4

    if [ "$ELA_FEE" == "" ]; then
        local ELA_FEE=0.000001
    fi

    if [ "$ELA_AMOUNT" == "All" ]; then
        local ELA_AMOUNT=$(ela_client wallet balance | awk 'NR == 3 {print $3}')
        local ELA_AMOUNT=$(echo "$ELA_AMOUNT-$ELA_FEE" | bc)
    fi

    cd $SCRIPT_PATH/ela

    if [ -f to_be_signed.txn ]; then
        echo "Removing to_be_signed.txn..."
        rm to_be_signed.txn
    fi

    if [ -f ready_to_send.txn ]; then
        echo "Removing ready_to_send.txn..."
        rm ready_to_send.txn
    fi

    ela_client wallet buildtx \
        --from $ELA_ADDR_FROM --to $ELA_ADDR_TO \
        --amount $ELA_AMOUNT --fee $ELA_FEE

    ela_client wallet signtx -f to_be_signed.txn
    ela_client wallet sendtx -f ready_to_send.txn
}

ela_transfer()
{
    if [ "$3" == "" ]; then
        echo "Usage: $SCRIPT_NAME ela transfer SIDECHAIN FROM TO AMOUNT [FEE]"
        return
    fi

    local SIDECHAIN=$1
    local ELA_ADDR_FROM=$2
    local ELA_ADDR_TO=$3
    local ELA_AMOUNT=$4
    local ELA_FEE=$5

    if [ "$SIDECHAIN" == "esc" ]; then
        if [ "$CHAIN_TYPE" == "mainnet" ]; then
            local SADDRESS=XVbCTM7vqM1qHKsABSFH4xKN1qbp7ijpWf
        elif [ "$CHAIN_TYPE" == "testnet" ]; then
            local SADDRESS=XWCiyXM1bQyGTawoaYKx9PjRkMUGGocWub
        else
            echo_error "do not support $CHAIN_TYPE"
            return
        fi
    elif [ "$SIDECHAIN" == "eid" ]; then
        if [ "$CHAIN_TYPE" == "mainnet" ]; then
            local SADDRESS=XUgTgCnUEqMUKLFAg3KhGv1nnt9nn8i3wi
        elif [ "$CHAIN_TYPE" == "testnet" ]; then
            local SADDRESS=XPsgiVQC3WucBYDL2DmPixj74Aa9aG3et8
        else
            echo_error "do not support $CHAIN_TYPE"
            return
        fi
    else
        echo_error "do not support sidechain $SIDECHAIN"
        return
    fi

    if [ "$ELA_FEE" == "" ]; then
        local ELA_FEE=0.000001
    fi

    if [ "$ELA_AMOUNT" == "All" ]; then
        local ELA_AMOUNT=$(ela_client wallet balance | awk 'NR == 3 {print $3}')
        local ELA_AMOUNT=$(echo "$ELA_AMOUNT-$ELA_FEE" | bc)
    fi

    cd $SCRIPT_PATH/ela

    if [ -f to_be_signed.txn ]; then
        echo "Removing to_be_signed.txn..."
        rm to_be_signed.txn
    fi

    if [ -f ready_to_send.txn ]; then
        echo "Removing ready_to_send.txn..."
        rm ready_to_send.txn
    fi

    ela_client wallet buildtx crosschain \
        --saddress $SADDRESS \
        --from $ELA_ADDR_FROM --to $ELA_ADDR_TO \
        --amount $ELA_AMOUNT --fee $ELA_FEE

    ela_client wallet signtx -f to_be_signed.txn
    ela_client wallet sendtx -f ready_to_send.txn
}

ela_synced()
{
    local ELA_BEST_BLOCK_HASH=$(ela_jsonrpc getbestblockhash | jq -r '.result')

    local BEST_BLOCK_SEC=$(
        ela_jsonrpc getblock blockhash $ELA_BEST_BLOCK_HASH verbosity 1 |
        jq -r '.result.time'
    )

    local THREE_MIN_BEFORE=$(($(date +%s)-60*3))

    # echo "BEST_BLOCK_SEC:   $BEST_BLOCK_SEC"
    # echo "THREE_MIN_BEFORE: $THREE_MIN_BEFORE"

    # it is considered fully-synchronized if the best block time is within 3 minutes
    if [ $BEST_BLOCK_SEC -gt $THREE_MIN_BEFORE ]; then
        true
    else
        false
    fi
}

ela_register_bpos()
{
    if [ ! -f ~/.config/elastos/ela.txt ]; then
        return
    fi

    if ! ela_synced; then
        echo_error "not fully-synchronized"
        return
    fi

    if [ "$3" == "" ]; then
        echo "Usage: $SCRIPT_NAME ela register_bpos NAME URL BLOCKS [REGION]"
        return
    fi

    local DPOS_NAME=$1
    local DPOS_URL=$2

    if [ "$CHAIN_TYPE" == "mainnet" ]; then
        if [ $3 -lt 7201 ]; then
            echo_error "less than 7,201 blocks (around 10 days)"
            return
        fi
    else
        if [ $3 -lt 21601 ]; then
            echo_error "less than 21,601 blocks (around 30 days)"
            return
        fi
    fi
    local DPOS_LOCK=$3

    local ELA_PUB_KEY=$(ela_client wallet account | sed -n '3 s/^.* //p')
    local IS_EXIST=$(ela_jsonrpc listproducers state all |
        jq -r ".result.producers[]? |
               select(.nodepublickey == \"$ELA_PUB_KEY\") | .nodepublickey")

    # echo "IS_EXIST: $IS_EXIST"

    if [ "$4" == "" ]; then
        local DPOS_EXT_IP=$(extip)
        local DPOS_REGION=$(curl -s https://ipapi.co/$DPOS_EXT_IP/json |
            jq -r '.country_calling_code')
        if [ "$DPOS_REGION" == "null" ]; then
            echo_error "failed to find country code automatically"
            return
        fi
        # Calling codes has a prefix +
        local DPOS_REGION=${DPOS_REGION#+}
    else
        local DPOS_REGION=$4
    fi

    echo "BPOS_NAME:   $DPOS_NAME"
    echo "BPOS_URL:    $DPOS_URL"
    echo "BPOS_REGION: $DPOS_REGION"
    echo "BPOS_LOCK:   $DPOS_LOCK"

    if [ "$YES_TO_ALL" == "" ]; then
        local ANSWER
        if [ ! $IS_EXIST ]; then
            read -p "Proceed registration (No/Yes)? " ANSWER
        else
            read -p "Proceed updating (No/Yes)? " ANSWER
        fi

        if [ "$ANSWER" != "Yes" ]; then
            echo "Canceled"
            return
        fi
    fi

    # TODO: test more prerequisites
    cd $SCRIPT_PATH/ela

    if [ -f to_be_signed.txn ]; then
        echo "Removing to_be_signed.txn..."
        rm to_be_signed.txn
    fi

    if [ -f ready_to_send.txn ]; then
        echo "Removing ready_to_send.txn..."
        rm ready_to_send.txn
    fi

    local ELA_HEIGHT=$(ela_client info getcurrentheight)
    local DPOS_UNTIL=$(($ELA_HEIGHT+$DPOS_LOCK+1))

    echo "ELA_HEIGHT:  $ELA_HEIGHT"
    echo "BPOS_UNTIL:  $DPOS_UNTIL"

    if [ ! $IS_EXIST ]; then
        ela_client wallet buildtx producer register v2 \
            --amount 2000 --fee 0.000001 \
            --nodepublickey $ELA_PUB_KEY \
            --nickname $DPOS_NAME --url $DPOS_URL \
            --location $DPOS_REGION --netaddress 127.0.0.1 \
            --stakeuntil $DPOS_UNTIL
    else
        ela_client wallet buildtx producer update v2 \
            --fee 0.000001 \
            --nodepublickey $ELA_PUB_KEY \
            --nickname $DPOS_NAME --url $DPOS_URL \
            --location $DPOS_REGION --netaddress 127.0.0.1 \
            --stakeuntil $DPOS_UNTIL
    fi

    ela_client wallet signtx -f to_be_signed.txn
    ela_client wallet sendtx -f ready_to_send.txn

    # [ERROR] map[code:43001 id:<nil> message:transaction validate error: payload content invalid:v2 producer StakeUntil less than DPoSV2DepositCoinMinLockTime]
    # [ERROR] map[code:43001 id:<nil> message:transaction validate error: payload content invalid:stake time is smaller than before]
    # [ERROR] map[code:43001 id:<nil> message:transaction validate error: payload content invalid:DPoS 2.0 node has expired]
}

ela_activate_bpos()
{
    if [ ! -f ~/.config/elastos/ela.txt ]; then
        return
    fi

    # TODO: test more prerequisites

    cd $SCRIPT_PATH/ela
    local ELA_PUB_KEY=$(ela_client wallet account | sed -n '3 s/^.* //p')

    if [ -f ready_to_send.txn ]; then
        echo "Removing ready_to_send.txn..."
        rm ready_to_send.txn
    fi

    ela_client wallet buildtx | grep -q activate
    if [ "$?" == "0" ]; then
        ela_client wallet buildtx activate --nodepublickey $ELA_PUB_KEY
    else
        ela_client wallet buildtx producer activate --nodepublickey $ELA_PUB_KEY
    fi

    ela_client wallet sendtx -f ready_to_send.txn

    # Error message:
    # [ERROR] map[code:-32603 id:<nil> message:Client authenticate failed]
    # [ERROR] map[code:43001 id:<nil> message:transaction validate error: payload content invalid]
}

ela_unregister_bpos()
{
    if [ ! -f ~/.config/elastos/ela.txt ]; then
        return
    fi

    # TODO: test more prerequisites

    cd $SCRIPT_PATH/ela

    if [ -f to_be_signed.txn ]; then
        echo "Removing to_be_signed.txn..."
        rm to_be_signed.txn
    fi

    if [ -f ready_to_send.txn ]; then
        echo "Removing ready_to_send.txn..."
        rm ready_to_send.txn
    fi

    local ELA_PUB_KEY=$(ela_client wallet account | sed -n '3 s/^.* //p')

    local AMOUNT=$(ela_jsonrpc getdepositcoin ownerpublickey $ELA_PUB_KEY |
        jq -r '.result.available')

    if [ "$IS_DEBUG" ]; then
        echo "AMOUNT: $AMOUNT"
    fi

    # DPoS 2.0 do not support unregister manually.
    # The command:
    #   ela_client wallet buildtx producer unregister --fee 0.000001
    # will cause sendtx error:
    #   [ERROR] map[code:43001 id:<nil> message:transaction validate error: payload content invalid:can not cancel DPoS V2 producer]

    ela_client wallet buildtx producer returndeposit --amount $AMOUNT --fee 0.000001

    # Too much amount will cause
    #   error: create transaction failed: map[code:45002 id:<nil> message:not enough utxo]

    ela_client wallet signtx -f to_be_signed.txn
    ela_client wallet sendtx -f ready_to_send.txn

    # [ERROR] map[code:43001 id:<nil> message:transaction validate error: payload content invalid:overspend deposit]
}

ela_vote_bpos()
{
    if [ ! -f ~/.config/elastos/ela.txt ]; then
        return
    fi

    if ! ela_synced; then
        echo_error "not fully-synchronized"
        return
    fi

    if [ "$3" == "" ]; then
        echo "Usage: $SCRIPT_NAME ela vote_bpos NAME    AMOUNT BLOCKS"
        echo "Usage: $SCRIPT_NAME ela vote_bpos PUB_KEY AMOUNT BLOCKS"
        return
    fi

    local ELA_DPOS_NAME_OR_PUBKEY=$1

    local ELA_DPOS_NAME=
    local ELA_DPOS_PUBKEY=

    local ELA_DPOS_PUBKEY=$(ela_jsonrpc listproducers |
        jq -r ".result.producers[] |
            select(.nickname == \"$ELA_DPOS_NAME_OR_PUBKEY\") |
            .nodepublickey")

    if [ "$ELA_DPOS_PUBKEY" != "" ]; then
        local ELA_DPOS_NAME=$ELA_DPOS_NAME_OR_PUBKEY
    else
        local ELA_DPOS_NAME=$(ela_jsonrpc listproducers |
            jq -r ".result.producers[] |
                select(.nodepublickey == \"$ELA_DPOS_NAME_OR_PUBKEY\") |
                .nickname")

        if [ "$ELA_DPOS_NAME" != "" ]; then
            local ELA_DPOS_PUBKEY=$ELA_DPOS_NAME_OR_PUBKEY
        else
            echo_error "no such node registered: $ELA_DPOS_NAME_OR_PUBKEY"
            return
        fi
    fi

    local ELA_DPOS_VOTE_AMOUNT=$2
    local BC_OUT=$(echo "$ELA_DPOS_VOTE_AMOUNT>0" | bc 2>/dev/null)
    if [ "$BC_OUT" != "1" ]; then
        echo_error "bad AMOUNT: $ELA_DPOS_VOTE_AMOUNT"
        return
    fi

    if [ $3 -lt 7201 ]; then
        echo_error "less than 7,201 blocks (around 10 days)"
        return
    fi
    if [ $3 -gt 720000 ]; then
        echo_error "greater than 720,000 blocks (around 100 days)"
        return
    fi
    local ELA_DPOS_BLOCKS_LOCK=$3

    local ELA_DPOS_STAKEPOOL=STAKEPooLXXXXXXXXXXXXXXXXXXXpP1PQ2

    cd $SCRIPT_PATH/ela

    local ELA_ADDRESS=$(ela_client wallet account | sed -n '3 s/ .*$//p')
    local ELA_ADDRESS_STAKE=$(ela_client wallet stakeaddress $ELA_ADDRESS)
    local ELA_STAKED=$(ela_jsonrpc "{\"method\":\"getvoterights\",
        \"params\":{\"stakeaddresses\":[\"$ELA_ADDRESS_STAKE\"]}}" |
        jq -r '.result[0].remainvoteright[4]')

    if [ "$IS_DEBUG" ]; then
        echo "ELA_DPOS_NAME:         $ELA_DPOS_NAME"
        echo "ELA_DPOS_PUBKEY:       $ELA_DPOS_PUBKEY"
        echo "ELA_DPOS_VOTE_AMOUNT:  $ELA_DPOS_VOTE_AMOUNT"
        echo "ELA_DPOS_BLOCKS_LOCK:  $ELA_DPOS_BLOCKS_LOCK"
        echo "ELA_DPOS_STAKEPOOL:    $ELA_DPOS_STAKEPOOL"
        echo "ELA_ADDRESS:           $ELA_ADDRESS"
        echo "ELA_ADDRESS_STAKE:     $ELA_ADDRESS_STAKE"
        echo "ELA_STAKED:            $ELA_STAKED"
    fi

    local BC_OUT=$(echo "$ELA_DPOS_VOTE_AMOUNT<=$ELA_STAKED" | bc 2>/dev/null)
    if [ "$BC_OUT" == "1" ]; then
        echo_info "voting rights is enough: $ELA_STAKED"
    elif [ "$BC_OUT" == "0" ]; then
        # voting rights not enough"
        local ELA_STAKE_AMOUNT=$(echo "$ELA_DPOS_VOTE_AMOUNT-$ELA_STAKED" | bc)
        # echo "INFO: voting rights is not enough, an extra ELA_STAKE_AMOUNT is neeeded"
        echo "Staking ELA $ELA_STAKE_AMOUNT..."
        ela_stake_bpos $ELA_STAKE_AMOUNT
        if [ "$?" == "0" ]; then
            echo "OK"
        else
            echo_error "Please wait for at least one new block before re-invoking"
        fi

        echo "Waiting enough vote rights..."
        while true; do
            local ELA_STAKED=$(ela_jsonrpc "{\"method\":\"getvoterights\",
                \"params\":{\"stakeaddresses\":[\"$ELA_ADDRESS_STAKE\"]}}" |
                jq -r '.result[0].remainvoteright[4]')

            local BC_OUT=$(echo "$ELA_DPOS_VOTE_AMOUNT<=$ELA_STAKED" |
                bc 2>/dev/null)
            if [ "$BC_OUT" == "1" ]; then
                echo
                break
            fi
            echo -n .
            sleep 1
        done
    else
        echo_error "bc"
        return
    fi

    if [ -f to_be_signed.txn ]; then
        echo "Removing to_be_signed.txn..."
        rm to_be_signed.txn
    fi

    if [ -f ready_to_send.txn ]; then
        echo "Removing ready_to_send.txn..."
        rm ready_to_send.txn
    fi

    local ELA_HEIGHT=$(ela_client info getcurrentheight)
    local ELA_DPOS_STAKE_UNTIL=$(($ELA_HEIGHT+$ELA_DPOS_BLOCKS_LOCK))

    if [ "$IS_DEBUG" ]; then
        echo "ELA_HEIGHT:            $ELA_HEIGHT"
        echo "ELA_DPOS_STAKE_UNTIL:  $ELA_DPOS_STAKE_UNTIL"
    fi

    echo -e "\n[$(date)]" | tee -a vote_dpos.log
    ela_client wallet buildtx dposv2vote --fee 0.000001 \
        --candidates $ELA_DPOS_PUBKEY --votes $ELA_DPOS_VOTE_AMOUNT \
        --stakeuntils $ELA_DPOS_STAKE_UNTIL --votetype 4 | tee -a vote_dpos.log

    ela_client wallet signtx --file to_be_signed.txn
    ela_client wallet sendtx --file ready_to_send.txn

    # [ERROR] map[code:43001 id:<nil> message:transaction validate error: payload content invalid:invalid DPoS 2.0 votes lock time]
    # [ERROR] map[code:43001 id:<nil> message:slot Stake verify tx error]
    # [ERROR] map[code:43001 id:<nil> message:transaction validate error: payload content invalid:DPoSV2 vote rights not enough]
}

ela_stake_bpos()
{
    if [ ! -f ~/.config/elastos/ela.txt ]; then
        return
    fi

    if [ "$1" == "" ]; then
        echo "Usage: $SCRIPT_NAME ela stake_bpos AMOUNT"
        return
    fi

    local ELA_STAKE_AMOUNT=$1
    local BC_OUT=$(echo "$ELA_STAKE_AMOUNT>0" | bc 2>/dev/null)
    if [ "$BC_OUT" != "1" ]; then
        echo_error "bad AMOUNT: $ELA_STAKE_AMOUNT"
        return
    fi

    if [ "$IS_DEBUG" ]; then
        echo "ELA_STAKE_AMOUNT: $ELA_STAKE_AMOUNT"
    fi

    local ELA_DPOS_STAKEPOOL=STAKEPooLXXXXXXXXXXXXXXXXXXXpP1PQ2

    cd $SCRIPT_PATH/ela

    if [ -f to_be_signed.txn ]; then
        echo "Removing to_be_signed.txn..."
        rm to_be_signed.txn
    fi

    if [ -f ready_to_send.txn ]; then
        echo "Removing ready_to_send.txn..."
        rm ready_to_send.txn
    fi

    ela_client wallet buildtx exchangevotes --amount $ELA_STAKE_AMOUNT \
        --fee 0.000001 --stakepool $ELA_DPOS_STAKEPOOL

    ela_client wallet signtx -f to_be_signed.txn
    ela_client wallet sendtx -f ready_to_send.txn

    # [ERROR] map[code:43001 id:<nil> message:slot Stake verify tx error]
}

ela_unstake_bpos()
{
    if [ ! -f ~/.config/elastos/ela.txt ]; then
        return
    fi

    if [ "$1" == "" ]; then
        echo "Usage: $SCRIPT_NAME ela unstake_bpos AMOUNT [ELA_ADDRESS]"
        return
    fi

    local ELA_UNSTAKE_AMOUNT=$1
    local BC_OUT=$(echo "$ELA_UNSTAKE_AMOUNT>0" | bc 2>/dev/null)
    if [ "$BC_OUT" != "1" ]; then
        echo_error "bad AMOUNT: $ELA_UNSTAKE_AMOUNT"
        return
    fi

    local ELA_ADDRESS=$2
    if [ "$ELA_ADDRESS" == "" ]; then
        local ELA_ADDRESS=$(ela_client wallet account | sed -n '3 s/ .*$//p')
    fi

    if [ "$IS_DEBUG" ]; then
        echo "ELA_UNSTAKE_AMOUNT: $ELA_UNSTAKE_AMOUNT"
        echo "ELA_ADDRESS:        $ELA_ADDRESS"
    fi

    cd $SCRIPT_PATH/ela

    if [ -f to_be_signed.txn ]; then
        echo "Removing to_be_signed.txn..."
        rm to_be_signed.txn
    fi

    if [ -f ready_to_send.txn ]; then
        echo "Removing ready_to_send.txn..."
        rm ready_to_send.txn
    fi

    ela_client wallet buildtx returnvotes --amount $ELA_UNSTAKE_AMOUNT \
        --fee 0.000001 --to $ELA_ADDRESS

    ela_client wallet signtx -f to_be_signed.txn
    ela_client wallet sendtx -f ready_to_send.txn
}

ela_claim_bpos()
{
    if [ ! -f ~/.config/elastos/ela.txt ]; then
        return
    fi

    if [ "$1" == "" ]; then
        echo "Usage: $SCRIPT_NAME ela claim_bpos AMOUNT [ELA_ADDRESS]"
        return
    fi

    local ELA_CLAIM_AMOUNT=$1

    if [ "$ELA_CLAIM_AMOUNT" == "All" ]; then
        local ELA_ADDRESS=$(ela_client wallet account | sed -n '3 s/ .*$//p')
        local ELA_CLAIM_AMOUNT=$(ela_jsonrpc dposv2rewardinfo |
            jq -r ".result[] | select(.address == \"$ELA_ADDRESS\") |
                   .claimable")
    fi

    local BC_OUT=$(echo "$ELA_CLAIM_AMOUNT>0" | bc 2>/dev/null)
    if [ "$BC_OUT" != "1" ]; then
        echo_error "bad AMOUNT: $ELA_CLAIM_AMOUNT"
        return
    fi

    local ELA_ADDRESS=$2
    if [ "$ELA_ADDRESS" == "" ]; then
        local ELA_ADDRESS=$(ela_client wallet account | sed -n '3 s/ .*$//p')
    fi

    if [ "$IS_DEBUG" ]; then
        echo "ELA_CLAIM_AMOUNT: $ELA_CLAIM_AMOUNT"
        echo "ELA_ADDRESS:      $ELA_ADDRESS"
    fi

    cd $SCRIPT_PATH/ela

    if [ -f to_be_signed.txn ]; then
        echo "Removing to_be_signed.txn..."
        rm to_be_signed.txn
    fi

    if [ -f ready_to_send.txn ]; then
        echo "Removing ready_to_send.txn..."
        rm ready_to_send.txn
    fi

    ela_client wallet buildtx dposv2claimreward \
        --claimamount $ELA_CLAIM_AMOUNT --fee 0.000001 --to $ELA_ADDRESS

    ela_client wallet signtx -f to_be_signed.txn
    ela_client wallet sendtx -f ready_to_send.txn

    # Wait for at least 3 blocks to receive the reward.
}

ela_register_crc()
{
    if [ ! -f ~/.config/elastos/ela.txt ]; then
        return
    fi

    if ! ela_synced; then
        echo_error "not fully-synchronized"
        return
    fi

    if [ "$2" == "" ]; then
        echo "Usage: $SCRIPT_NAME ela register_crc NAME URL [REGION]"
        return
    fi

    local CRC_NAME=$1
    local CRC_URL=$2

    local ELA_PUB_KEY=$(ela_client wallet account | sed -n '3 s/^.* //p')
    local IS_EXIST=$(ela_jsonrpc listcurrentcrs state all |
        jq -r ".result.crmembersinfo[]? |
               select(.dpospublickey == \"$ELA_PUB_KEY\") | .dpospublickey")

    if [ $IS_DEBUG ]; then
        echo "IS_EXIST: $IS_EXIST"
    fi

    if [ "$3" == "" ]; then
        local CRC_EXT_IP=$(extip)
        local CRC_REGION=$(curl -s https://ipapi.co/$DPOS_EXT_IP/json |
            jq -r '.country_calling_code')
        # Calling codes has a prefix +
        local CRC_REGION=${CRC_REGION#+}
    fi

    echo "CRC_NAME:   $CRC_NAME"
    echo "CRC_URL:    $CRC_URL"
    echo "CRC_REGION: $CRC_REGION"

    if [ "$YES_TO_ALL" == "" ]; then
        local ANSWER
        if [ ! $IS_EXIST ]; then
            read -p "Proceed registration (No/Yes)? " ANSWER
        else
            read -p "Proceed updating (No/Yes)? " ANSWER
        fi

        if [ "$ANSWER" != "Yes" ]; then
            echo "Canceled"
            return
        fi
    fi

    cd $SCRIPT_PATH/ela

    if [ -f to_be_signed.txn ]; then
        echo "Removing to_be_signed.txn..."
        rm to_be_signed.txn
    fi

    if [ -f ready_to_send.txn ]; then
        echo "Removing ready_to_send.txn..."
        rm ready_to_send.txn
    fi

    if [ ! $IS_EXIST ]; then
        ela_client wallet buildtx crc register \
            --amount 1 --fee 0.000001 \
            --nickname $CRC_NAME --url $CRC_URL \
            --location $CRC_REGION
    else
        ela_client wallet buildtx crc update \
            --amount 1 --fee 0.000001 \
            --nickname $CRC_NAME --url $CRC_URL \
            --location $CRC_REGION
    fi

    ela_client wallet signtx -f to_be_signed.txn
    ela_client wallet sendtx -f ready_to_send.txn

    # [ERROR] map[code:43001 id:<nil> message:transaction validate error:
    #         payload content invalid:should create tx during voting period]
}

ela_activate_crc()
{
    ela_activate_bpos
}

ela_unregister_crc()
{
    if [ ! -f ~/.config/elastos/ela.txt ]; then
        return
    fi

    cd $SCRIPT_PATH/ela

    if [ -f to_be_signed.txn ]; then
        echo "Removing to_be_signed.txn..."
        rm to_be_signed.txn
    fi

    if [ -f ready_to_send.txn ]; then
        echo "Removing ready_to_send.txn..."
        rm ready_to_send.txn
    fi

    ela_client wallet buildtx crc unregister --fee 0.000001
    ela_client wallet signtx -f to_be_signed.txn
    ela_client wallet sendtx -f ready_to_send.txn

    # [ERROR] map[code:43001 id:<nil> message:transaction validate error:
    #         payload content invalid:should create tx during voting period]
}

#
# esc
#
esc_usage()
{
    echo "Usage: $SCRIPT_NAME $CHAIN_NAME COMMAND [OPTIONS]"
    echo "Manage $CHAIN_NAME"
    echo
    echo "Available Commands:"
    echo
    echo "  init            Install and configure $CHAIN_NAME_U"
    echo "  update          Update $CHAIN_NAME_U"
    echo
    echo "  start           Start $CHAIN_NAME_U daemon"
    echo "  stop            Stop $CHAIN_NAME_U daemon"
    echo "  status          Print $CHAIN_NAME_U daemon status"
    echo "  watch           Start $CHAIN_NAME_U daemon and restart a crash"
    echo "  mon             Monitor $CHAIN_NAME_U height and alert a halt"
    echo
    echo "  compress_log    Compress $CHAIN_NAME_U daemon log files"
    echo "  remove_log      Remove $CHAIN_NAME_U daemon log files"
    echo
    echo "  client          Run $CHAIN_NAME_U client"
    echo "  jsonrpc         Call $CHAIN_NAME_U JSON-RPC API"
    echo
    echo "  send            Send crypto in $CHAIN_NAME_U"
    echo
}

esc_start()
{
    if [ ! -f $SCRIPT_PATH/esc/esc ]; then
        echo_error "$SCRIPT_PATH/esc/esc is not exist"
        return
    fi

    if [ "$CHAIN_TYPE" == "mainnet" ]; then
        local ESC_OPTS=
    elif [ "$CHAIN_TYPE" == "testnet" ]; then
        local ESC_OPTS=--testnet
    else
        echo_error "do not support $CHAIN_TYPE"
        return
    fi

    local PID=$(pgrep -f '^\./esc .*--rpc ')
    if [ "$PID" != "" ]; then
        esc_status
        return
    fi

    echo "Starting esc..."
    cd $SCRIPT_PATH/esc
    mkdir -p $SCRIPT_PATH/esc/logs/

    if [ -f ~/.config/elastos/esc.txt ]; then
        if [ -f $SCRIPT_PATH/esc/data/miner_address.txt ]; then
            local ESC_OPTS="$ESC_OPTS --pbft.miner.address $SCRIPT_PATH/esc/data/miner_address.txt"
        fi
        nohup $SHELL -c "./esc \
            $ESC_OPTS \
            --allow-insecure-unlock \
            --datadir $SCRIPT_PATH/esc/data \
            --mine \
            --miner.threads 1 \
            --password ~/.config/elastos/esc.txt \
            --pbft.keystore ${SCRIPT_PATH}/ela/keystore.dat \
            --pbft.keystore.password ~/.config/elastos/ela.txt \
            --pbft.net.address '$(extip)' \
            --pbft.net.port 20639 \
            --rpc \
            --rpcaddr '0.0.0.0' \
            --rpcapi 'db,eth,net,pbft,personal,txpool,web3' \
            --rpcvhosts '*' \
            --syncmode full \
            --unlock '0x$(cat $SCRIPT_PATH/esc/data/keystore/UTC* | jq -r .address)' \
            --ws \
            --wsaddr '0.0.0.0' \
            --wsorigins '*' \
            2>&1 \
            | rotatelogs $SCRIPT_PATH/esc/logs/esc-%Y-%m-%d-%H_%M_%S.log 20M" &
    else
        nohup $SHELL -c "./esc \
            $ESC_OPTS \
            --datadir $SCRIPT_PATH/esc/data \
            --lightserv 10 \
            --rpc \
            --rpcaddr '0.0.0.0' \
            --rpcapi 'admin,eth,net,txpool,web3' \
            --rpcvhosts '*' \
            --ws \
            --wsaddr '0.0.0.0' \
            --wsorigins '*' \
            2>&1 \
            | rotatelogs $SCRIPT_PATH/esc/logs/esc-%Y-%m-%d-%H_%M_%S.log 20M" &
    fi

    sleep 3
    esc_status
}

eco_start()
{
    if [ ! -f $SCRIPT_PATH/eco/eco ]; then
        echo_error "$SCRIPT_PATH/eco/eco is not exist"
        return
    fi

    if [ "$CHAIN_TYPE" == "mainnet" ]; then
        local ECO_OPTS=
    elif [ "$CHAIN_TYPE" == "testnet" ]; then
        local ECO_OPTS=--testnet
    else
        echo_error "do not support $CHAIN_TYPE"
        return
    fi

    local PID=$(pgrep -f '^\./eco .*--rpc ')
    if [ "$PID" != "" ]; then
        eco_status
        return
    fi

    echo "Starting eco..."
    cd $SCRIPT_PATH/eco
    mkdir -p $SCRIPT_PATH/eco/logs/

    if [ -f ~/.config/elastos/eco.txt ]; then
        if [ -f $SCRIPT_PATH/eco/data/miner_address.txt ]; then
            local ECO_OPTS="$ECO_OPTS --pbft.miner.address $SCRIPT_PATH/eco/data/miner_address.txt"
        fi
        nohup $SHELL -c "./eco \
            $ECO_OPTS \
            --allow-insecure-unlock \
            --datadir $SCRIPT_PATH/eco/data \
            --mine \
            --miner.threads 1 \
            --password ~/.config/elastos/eco.txt \
            --pbft.keystore ${SCRIPT_PATH}/ela/keystore.dat \
            --pbft.keystore.password ~/.config/elastos/ela.txt \
            --pbft.net.address '$(extip)' \
            --pbft.net.port 20659 \
            --rpc \
            --rpcaddr '0.0.0.0' \
            --rpcapi 'db,eth,net,pbft,personal,txpool,web3' \
            --rpcvhosts '*' \
            --syncmode full \
            --unlock '0x$(cat $SCRIPT_PATH/eco/data/keystore/UTC* | jq -r .address)' \
            --ws \
            --wsaddr '0.0.0.0' \
            --wsorigins '*' \
            2>&1 \
            | rotatelogs $SCRIPT_PATH/eco/logs/eco-%Y-%m-%d-%H_%M_%S.log 20M" &
    else
        nohup $SHELL -c "./eco \
            $ECO_OPTS \
            --datadir $SCRIPT_PATH/eco/data \
            --lightserv 10 \
            --rpc \
            --rpcaddr '0.0.0.0' \
            --rpcapi 'admin,eth,net,txpool,web3' \
            --rpcvhosts '*' \
            --ws \
            --wsaddr '0.0.0.0' \
            --wsorigins '*' \
            2>&1 \
            | rotatelogs $SCRIPT_PATH/eco/logs/eco-%Y-%m-%d-%H_%M_%S.log 20M" &
    fi

    sleep 3
    eco_status
}

pgp_start()
{
    if [ ! -f $SCRIPT_PATH/pgp/pgp ]; then
        echo_error "$SCRIPT_PATH/pgp/pgp is not exist"
        return
    fi

    if [ "$CHAIN_TYPE" == "mainnet" ]; then
        local PGP_OPTS=
    elif [ "$CHAIN_TYPE" == "testnet" ]; then
        local PGP_OPTS=--testnet
    else
        echo_error "do not support $CHAIN_TYPE"
        return
    fi

    local PID=$(pgrep -f '^\./pgp .*--rpc ')
    if [ "$PID" != "" ]; then
        pgp_status
        return
    fi

    echo "Starting pgp..."
    cd $SCRIPT_PATH/pgp
    mkdir -p $SCRIPT_PATH/pgp/logs/

    if [ -f ~/.config/elastos/pgp.txt ]; then
        if [ -f $SCRIPT_PATH/pgp/data/miner_address.txt ]; then
            local PGP_OPTS="$PGP_OPTS --pbft.miner.address $SCRIPT_PATH/pgp/data/miner_address.txt"
        fi
        nohup $SHELL -c "./pgp \
            $PGP_OPTS \
            --allow-insecure-unlock \
            --datadir $SCRIPT_PATH/pgp/data \
            --mine \
            --miner.threads 1 \
            --password ~/.config/elastos/pgp.txt \
            --pbft.keystore ${SCRIPT_PATH}/ela/keystore.dat \
            --pbft.keystore.password ~/.config/elastos/ela.txt \
            --pbft.net.address '$(extip)' \
            --pbft.net.port 20669 \
            --rpc \
            --rpcaddr '0.0.0.0' \
            --rpcapi 'db,eth,net,pbft,personal,txpool,web3' \
            --rpcvhosts '*' \
            --syncmode full \
            --unlock '0x$(cat $SCRIPT_PATH/pgp/data/keystore/UTC* | jq -r .address)' \
            --ws \
            --wsaddr '0.0.0.0' \
            --wsorigins '*' \
            2>&1 \
            | rotatelogs $SCRIPT_PATH/pgp/logs/pgp-%Y-%m-%d-%H_%M_%S.log 20M" &
    else
        nohup $SHELL -c "./pgp \
            $PGP_OPTS \
            --datadir $SCRIPT_PATH/pgp/data \
            --lightserv 10 \
            --rpc \
            --rpcaddr '0.0.0.0' \
            --rpcapi 'admin,eth,net,txpool,web3' \
            --rpcvhosts '*' \
            --ws \
            --wsaddr '0.0.0.0' \
            --wsorigins '*' \
            2>&1 \
            | rotatelogs $SCRIPT_PATH/pgp/logs/pgp-%Y-%m-%d-%H_%M_%S.log 20M" &
    fi

    sleep 3
    pgp_status
}


pg_start()
{
    if [ ! -f $SCRIPT_PATH/pg/pg ]; then
        echo_error "$SCRIPT_PATH/pg/pg is not exist"
        return
    fi

    if [ "$CHAIN_TYPE" == "mainnet" ]; then
        local PG_OPTS=
    elif [ "$CHAIN_TYPE" == "testnet" ]; then
        local PG_OPTS=--testnet
    else
        echo_error "do not support $CHAIN_TYPE"
        return
    fi

    local PID=$(pgrep -f '^\./pg .*--rpc ')
    if [ "$PID" != "" ]; then
        pg_status
        return
    fi

    echo "Starting pg..."
    cd $SCRIPT_PATH/pg
    mkdir -p $SCRIPT_PATH/pg/logs/

    if [ -f ~/.config/elastos/pg.txt ]; then
        if [ -f $SCRIPT_PATH/pg/data/miner_address.txt ]; then
            local PG_OPTS="$PG_OPTS --pbft.miner.address $SCRIPT_PATH/pg/data/miner_address.txt"
        fi
        nohup $SHELL -c "./pg \
            $PG_OPTS \
            --allow-insecure-unlock \
            --datadir $SCRIPT_PATH/pg/data \
            --mine \
            --miner.threads 1 \
            --password ~/.config/elastos/pg.txt \
            --pbft.keystore ${SCRIPT_PATH}/ela/keystore.dat \
            --pbft.keystore.password ~/.config/elastos/ela.txt \
            --pbft.net.address '$(extip)' \
            --pbft.net.port 20679 \
            --rpc \
            --rpcaddr '0.0.0.0' \
            --rpcapi 'db,eth,net,pbft,personal,txpool,web3' \
            --rpcvhosts '*' \
            --syncmode full \
            --unlock '0x$(cat $SCRIPT_PATH/pg/data/keystore/UTC* | jq -r .address)' \
            --ws \
            --wsaddr '0.0.0.0' \
            --wsorigins '*' \
            2>&1 \
            | rotatelogs $SCRIPT_PATH/pg/logs/pg-%Y-%m-%d-%H_%M_%S.log 20M" &
    else
        nohup $SHELL -c "./pg \
            $PG_OPTS \
            --datadir $SCRIPT_PATH/pg/data \
            --lightserv 10 \
            --rpc \
            --rpcaddr '0.0.0.0' \
            --rpcapi 'admin,eth,net,txpool,web3' \
            --rpcvhosts '*' \
            --ws \
            --wsaddr '0.0.0.0' \
            --wsorigins '*' \
            2>&1 \
            | rotatelogs $SCRIPT_PATH/pg/logs/pg-%Y-%m-%d-%H_%M_%S.log 20M" &
    fi

    sleep 3
    pg_status
}

esc_stop()
{
    local PID=$(pgrep -f '^\./esc .*--rpc ')
    if [ "$PID" != "" ]; then
        echo "Stopping esc..."
        kill -s SIGINT $PID
        while ps -p $PID 1>/dev/null; do
            echo -n .
            sleep 1
        done
        echo
    fi
    sync
    esc_status
}
eco_stop()
{
    local PID=$(pgrep -f '^\./eco .*--rpc ')
    if [ "$PID" != "" ]; then
        echo "Stopping eco..."
        kill -s SIGINT $PID
        while ps -p $PID 1>/dev/null; do
            echo -n .
            sleep 1
        done
        echo
    fi
    sync
    eco_status
}

pgp_stop()
{
    local PID=$(pgrep -f '^\./pgp .*--rpc ')
    if [ "$PID" != "" ]; then
        echo "Stopping pgp..."
        kill -s SIGINT $PID
        while ps -p $PID 1>/dev/null; do
            echo -n .
            sleep 1
        done
        echo
    fi
    sync
    pgp_status
}

pg_stop()
{
    local PID=$(pgrep -f '^\./pg .*--rpc ')
    if [ "$PID" != "" ]; then
        echo "Stopping pg..."
        kill -s SIGINT $PID
        while ps -p $PID 1>/dev/null; do
            echo -n .
            sleep 1
        done
        echo
    fi
    sync
    pg_status
}

esc_installed()
{
    if [ -f $SCRIPT_PATH/esc/esc ]; then
        true
    else
        false
    fi
}

eco_installed()
{
    if [ -f $SCRIPT_PATH/eco/eco ]; then
        true
    else
        false
    fi
}

pgp_installed()
{
    if [ -f $SCRIPT_PATH/pgp/pgp ]; then
        true
    else
        false
    fi
}

pg_installed()
{
    if [ -f $SCRIPT_PATH/pg/pg ]; then
        true
    else
        false
    fi
}

esc_ver()
{
    if [ -f $SCRIPT_PATH/esc/esc ]; then
        echo "esc $($SCRIPT_PATH/esc/esc version | grep 'Git Commit:' | sed 's/.* //' | cut -c1-7)"
    else
        echo "esc N/A"
    fi
}

eco_ver()
{
    if [ -f $SCRIPT_PATH/eco/eco ]; then
        echo "eco $($SCRIPT_PATH/eco/eco version | grep 'Git Commit:' | sed 's/.* //' | cut -c1-7)"
    else
        echo "eco N/A"
    fi
}

pgp_ver()
{
    if [ -f $SCRIPT_PATH/pgp/pgp ]; then
        echo "pgp $($SCRIPT_PATH/pgp/pgp version | grep 'Git Commit:' | sed 's/.* //' | cut -c1-7)"
    else
        echo "pgp N/A"
    fi
}

pg_ver()
{
    if [ -f $SCRIPT_PATH/pg/pg ]; then
        echo "pg $($SCRIPT_PATH/pg/pg version | grep 'Git Commit:' | sed 's/.* //' | cut -c1-7)"
    else
        echo "pg N/A"
    fi
}

esc_client()
{
    if [ ! -f $SCRIPT_PATH/esc/esc ]; then
        echo_error "$SCRIPT_PATH/esc/esc is not exist"
        return
    fi

    cd $SCRIPT_PATH/esc
    if [ "$1" == "" ]; then
        ./esc --datadir $SCRIPT_PATH/esc/data --help
    elif [ "$1" == "attach" ] &&
         [ ! -S $SCRIPT_PATH/esc/data/geth.ipc ]; then
        return
    else
        ./esc --datadir $SCRIPT_PATH/esc/data --nousb $*
    fi
}

eco_client()
{
    if [ ! -f $SCRIPT_PATH/eco/eco ]; then
        echo_error "$SCRIPT_PATH/eco/eco is not exist"
        return
    fi

    cd $SCRIPT_PATH/eco
    if [ "$1" == "" ]; then
        ./eco --datadir $SCRIPT_PATH/eco/data --help
    elif [ "$1" == "attach" ] &&
         [ ! -S $SCRIPT_PATH/eco/data/geth.ipc ]; then
        return
    else
        ./eco --datadir $SCRIPT_PATH/eco/data --nousb $*
    fi
}

pgp_client()
{
    if [ ! -f $SCRIPT_PATH/pgp/pgp ]; then
        echo_error "$SCRIPT_PATH/pgp/pgp is not exist"
        return
    fi

    cd $SCRIPT_PATH/pgp
    if [ "$1" == "" ]; then
        ./esc --datadir $SCRIPT_PATH/pgp/data --help
    elif [ "$1" == "attach" ] &&
         [ ! -S $SCRIPT_PATH/pgp/data/geth.ipc ]; then
        return
    else
        ./pgp --datadir $SCRIPT_PATH/pgp/data --nousb $*
    fi
}

pg_client()
{
    if [ ! -f $SCRIPT_PATH/pg/pg ]; then
        echo_error "$SCRIPT_PATH/pg/pg is not exist"
        return
    fi

    cd $SCRIPT_PATH/pg
    if [ "$1" == "" ]; then
        ./esc --datadir $SCRIPT_PATH/pg/data --help
    elif [ "$1" == "attach" ] &&
         [ ! -S $SCRIPT_PATH/pg/data/geth.ipc ]; then
        return
    else
        ./pg --datadir $SCRIPT_PATH/pg/data --nousb $*
    fi
}

esc_jsonrpc()
{
    if [ "$1" == "" ]; then
        return
    fi

    if [[ $1 =~ ^[_3a-zA-Z]+$ ]] && [ "$2" == "" ]; then
        local DATA="{\"method\":\"$1\",\"id\":0}"
    else
        local DATA=$1
    fi

    curl -s -H 'Content-Type:application/json' -X POST --data $DATA \
        http://127.0.0.1:20636 | jq .
}

eco_jsonrpc()
{
    if [ "$1" == "" ]; then
        return
    fi

    if [[ $1 =~ ^[_3a-zA-Z]+$ ]] && [ "$2" == "" ]; then
        local DATA="{\"method\":\"$1\",\"id\":0}"
    else
        local DATA=$1
    fi

    curl -s -H 'Content-Type:application/json' -X POST --data $DATA \
        http://127.0.0.1:20656 | jq .
}

pgp_jsonrpc()
{
    if [ "$1" == "" ]; then
        return
    fi

    if [[ $1 =~ ^[_3a-zA-Z]+$ ]] && [ "$2" == "" ]; then
        local DATA="{\"method\":\"$1\",\"id\":0}"
    else
        local DATA=$1
    fi

    curl -s -H 'Content-Type:application/json' -X POST --data $DATA \
        http://127.0.0.1:20666 | jq .
}

pg_jsonrpc()
{
    if [ "$1" == "" ]; then
        return
    fi

    if [[ $1 =~ ^[_3a-zA-Z]+$ ]] && [ "$2" == "" ]; then
        local DATA="{\"method\":\"$1\",\"id\":0}"
    else
        local DATA=$1
    fi

    curl -s -H 'Content-Type:application/json' -X POST --data $DATA \
        http://127.0.0.1:20676 | jq .
}

esc_status()
{
    local ESC_VER=$(esc_ver)

    local ESC_DISK_USAGE=$(disk_usage $SCRIPT_PATH/esc)

    if [ -f ~/.config/elastos/esc.txt ]; then
        cd $SCRIPT_PATH/esc
        local ESC_KEYSTORE=$(./esc --datadir "$SCRIPT_PATH/esc/data/" \
            --nousb --verbosity 0 account list | sed -n '1 s/.*keystore:\/\///p')
        if [ $ESC_KEYSTORE ] && [ -f $ESC_KEYSTORE ]; then
            local ESC_ADDRESS=0x$(cat $ESC_KEYSTORE | jq -r .address)
        else
            local ESC_ADDRESS=N/A
        fi
    else
        local ESC_ADDRESS=N/A
    fi

    local ESC_MINER_ADDRESS=$(cat $SCRIPT_PATH/esc/data/miner_address.txt 2>/dev/null)
    if [ "$ESC_MINER_ADDRESS" == "" ]; then
        local ESC_MINER_ADDRESS=$ESC_ADDRESS
    fi

    local PID=$(pgrep -f '^\./esc .*--rpc ')
    if [ "$PID" == "" ]; then
        status_head $ESC_VER  Stopped
        status_info "Disk"    "$ESC_DISK_USAGE"
        status_info "Address" "$ESC_ADDRESS"
        echo
        return
    fi

    local ESC_RAM=$(mem_usage $PID)
    local ESC_UPTIME=$(run_time $PID)
    local ESC_NUM_TCPS=$(num_tcps $PID)
    local ESC_TCP_LISTEN=$(list_tcp $PID)
    local ESC_UDP_LISTEN=$(list_udp $PID)
    local ESC_NUM_FILES=$(num_files $PID)

    local ESC_NUM_PEERS=$(esc_jsonrpc \
        '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' \
        | jq -r '.result')
    ESC_NUM_PEERS=$(($ESC_NUM_PEERS))
    if [[ ! "$ESC_NUM_PEERS" =~ ^[0-9]+$ ]]; then
        ESC_NUM_PEERS=0
    fi
    local ESC_HEIGHT=$(esc_jsonrpc \
        '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
        | jq -r '.result')
    ESC_HEIGHT=$(($ESC_HEIGHT))
    if [[ ! "$ESC_HEIGHT" =~ ^[0-9]+$ ]]; then
        ESC_HEIGHT=N/A
    fi

    local ESC_BALANCE=$(esc_client \
        attach --exec "web3.fromWei(eth.getBalance('$ESC_ADDRESS'),'ether')")
    if [ "$ESC_BALANCE" == "" ]; then
        ESC_BALANCE=N/A
    elif [[ $ESC_BALANCE =~ [^.0-9e-] ]]; then
        ESC_BALANCE=N/A
    fi

    status_head $ESC_VER Running
    status_info "Disk"      "$ESC_DISK_USAGE"
    status_info "Address"   "$ESC_ADDRESS"
    status_info "Balance"   "$ESC_BALANCE"
    status_info "Miner"     "$ESC_MINER_ADDRESS"
    status_info "PID"       "$PID"
    status_info "RAM"       "$ESC_RAM"
    status_info "Uptime"    "$ESC_UPTIME"
    status_info "#Files"    "$ESC_NUM_FILES"
    status_info "TCP Ports" "$ESC_TCP_LISTEN"
    status_info "#TCP"      "$ESC_NUM_TCPS"
    status_info "UDP Ports" "$ESC_UDP_LISTEN"
    status_info "#Peers"    "$ESC_NUM_PEERS"
    status_info "Height"    "$ESC_HEIGHT"
    echo
}

eco_status()
{
    local ECO_VER=$(eco_ver)

    local ECO_DISK_USAGE=$(disk_usage $SCRIPT_PATH/eco)

    if [ -f ~/.config/elastos/eco.txt ]; then
        cd $SCRIPT_PATH/eco
        local ECO_KEYSTORE=$(./eco --datadir "$SCRIPT_PATH/eco/data/" \
            --nousb --verbosity 0 account list | sed -n '1 s/.*keystore:\/\///p')
        if [ $ECO_KEYSTORE ] && [ -f $ECO_KEYSTORE ]; then
            local ECO_ADDRESS=0x$(cat $ECO_KEYSTORE | jq -r .address)
        else
            local ECO_ADDRESS=N/A
        fi
    else
        local ECO_ADDRESS=N/A
    fi

    local ECO_MINER_ADDRESS=$(cat $SCRIPT_PATH/eco/data/miner_address.txt 2>/dev/null)
    if [ "$ECO_MINER_ADDRESS" == "" ]; then
        local ECO_MINER_ADDRESS=$ECO_ADDRESS
    fi

    local PID=$(pgrep -f '^\./eco .*--rpc ')
    if [ "$PID" == "" ]; then
        status_head $ECO_VER  Stopped
        status_info "Disk"    "$ECO_DISK_USAGE"
        status_info "Address" "$ECO_ADDRESS"
        echo
        return
    fi

    local ECO_RAM=$(mem_usage $PID)
    local ECO_UPTIME=$(run_time $PID)
    local ECO_NUM_TCPS=$(num_tcps $PID)
    local ECO_TCP_LISTEN=$(list_tcp $PID)
    local ECO_UDP_LISTEN=$(list_udp $PID)
    local ECO_NUM_FILES=$(num_files $PID)

    local ECO_NUM_PEERS=$(eco_jsonrpc \
        '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' \
        | jq -r '.result')
    ECO_NUM_PEERS=$(($ECO_NUM_PEERS))
    if [[ ! "$ECO_NUM_PEERS" =~ ^[0-9]+$ ]]; then
        ECO_NUM_PEERS=0
    fi
    local ECO_HEIGHT=$(eco_jsonrpc \
        '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
        | jq -r '.result')
    ECO_HEIGHT=$(($ECO_HEIGHT))
    if [[ ! "$ECO_HEIGHT" =~ ^[0-9]+$ ]]; then
        ECO_HEIGHT=N/A
    fi

    local ECO_BALANCE=$(eco_client \
        attach --exec "web3.fromWei(eth.getBalance('$ECO_ADDRESS'),'ether')")
    if [ "$ECO_BALANCE" == "" ]; then
        ECO_BALANCE=N/A
    elif [[ $ECO_BALANCE =~ [^.0-9e-] ]]; then
        ECO_BALANCE=N/A
    fi

    status_head $ECO_VER Running
    status_info "Disk"      "$ECO_DISK_USAGE"
    status_info "Address"   "$ECO_ADDRESS"
    status_info "Balance"   "$ECO_BALANCE"
    status_info "Miner"     "$ECO_MINER_ADDRESS"
    status_info "PID"       "$PID"
    status_info "RAM"       "$ECO_RAM"
    status_info "Uptime"    "$ECO_UPTIME"
    status_info "#Files"    "$ECO_NUM_FILES"
    status_info "TCP Ports" "$ECO_TCP_LISTEN"
    status_info "#TCP"      "$ECO_NUM_TCPS"
    status_info "UDP Ports" "$ECO_UDP_LISTEN"
    status_info "#Peers"    "$ECO_NUM_PEERS"
    status_info "Height"    "$ECO_HEIGHT"
    echo
}


pgp_status()
{
    local PGP_VER=$(pgp_ver)

    local PGP_DISK_USAGE=$(disk_usage $SCRIPT_PATH/pgp)

    if [ -f ~/.config/elastos/pgp.txt ]; then
        cd $SCRIPT_PATH/pgp
        local PGP_KEYSTORE=$(./pgp --datadir "$SCRIPT_PATH/pgp/data/" \
            --nousb --verbosity 0 account list | sed -n '1 s/.*keystore:\/\///p')
        if [ $PGP_KEYSTORE ] && [ -f $PGP_KEYSTORE ]; then
            local PGP_ADDRESS=0x$(cat $PGP_KEYSTORE | jq -r .address)
        else
            local PGP_ADDRESS=N/A
        fi
    else
        local PGP_ADDRESS=N/A
    fi

    local PGP_MINER_ADDRESS=$(cat $SCRIPT_PATH/pgp/data/miner_address.txt 2>/dev/null)
    if [ "$PGP_MINER_ADDRESS" == "" ]; then
        local PGP_MINER_ADDRESS=$PGP_ADDRESS
    fi

    local PID=$(pgrep -f '^\./pgp .*--rpc ')
    if [ "$PID" == "" ]; then
        status_head $PGP_VER  Stopped
        status_info "Disk"    "$PGP_DISK_USAGE"
        status_info "Address" "$PGP_ADDRESS"
        echo
        return
    fi

    local PGP_RAM=$(mem_usage $PID)
    local PGP_UPTIME=$(run_time $PID)
    local PGP_NUM_TCPS=$(num_tcps $PID)
    local PGP_TCP_LISTEN=$(list_tcp $PID)
    local PGP_UDP_LISTEN=$(list_udp $PID)
    local PGP_NUM_FILES=$(num_files $PID)

    local PGP_NUM_PEERS=$(pgp_jsonrpc \
        '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' \
        | jq -r '.result')
    PGP_NUM_PEERS=$(($PGP_NUM_PEERS))
    if [[ ! "$PGP_NUM_PEERS" =~ ^[0-9]+$ ]]; then
        PGP_NUM_PEERS=0
    fi
    local PGP_HEIGHT=$(pgp_jsonrpc \
        '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
        | jq -r '.result')
    PGP_HEIGHT=$(($PGP_HEIGHT))
    if [[ ! "$PGP_HEIGHT" =~ ^[0-9]+$ ]]; then
        PGP_HEIGHT=N/A
    fi

    local PGP_BALANCE=$(pgp_client \
        attach --exec "web3.fromWei(eth.getBalance('$PGP_ADDRESS'),'ether')")
    if [ "$PGP_BALANCE" == "" ]; then
        PGP_BALANCE=N/A
    elif [[ $PGP_BALANCE =~ [^.0-9e-] ]]; then
        PGP_BALANCE=N/A
    fi

    status_head $PGP_VER Running
    status_info "Disk"      "$PGP_DISK_USAGE"
    status_info "Address"   "$PGP_ADDRESS"
    status_info "Balance"   "$PGP_BALANCE"
    status_info "Miner"     "$PGP_MINER_ADDRESS"
    status_info "PID"       "$PID"
    status_info "RAM"       "$PGP_RAM"
    status_info "Uptime"    "$PGP_UPTIME"
    status_info "#Files"    "$PGP_NUM_FILES"
    status_info "TCP Ports" "$PGP_TCP_LISTEN"
    status_info "#TCP"      "$PGP_NUM_TCPS"
    status_info "UDP Ports" "$PGP_UDP_LISTEN"
    status_info "#Peers"    "$PGP_NUM_PEERS"
    status_info "Height"    "$PGP_HEIGHT"
    echo
}

pg_status()
{
    local PG_VER=$(pg_ver)

    local PG_DISK_USAGE=$(disk_usage $SCRIPT_PATH/pg)

    if [ -f ~/.config/elastos/pg.txt ]; then
        cd $SCRIPT_PATH/pg
        local PG_KEYSTORE=$(./pg --datadir "$SCRIPT_PATH/pg/data/" \
            --nousb --verbosity 0 account list | sed -n '1 s/.*keystore:\/\///p')
        if [ $PG_KEYSTORE ] && [ -f $PG_KEYSTORE ]; then
            local PG_ADDRESS=0x$(cat $PG_KEYSTORE | jq -r .address)
        else
            local PG_ADDRESS=N/A
        fi
    else
        local PG_ADDRESS=N/A
    fi

    local PG_MINER_ADDRESS=$(cat $SCRIPT_PATH/pg/data/miner_address.txt 2>/dev/null)
    if [ "$PG_MINER_ADDRESS" == "" ]; then
        local PG_MINER_ADDRESS=$PG_ADDRESS
    fi

    local PID=$(pgrep -f '^\./pg .*--rpc ')
    if [ "$PID" == "" ]; then
        status_head $PG_VER  Stopped
        status_info "Disk"    "$PG_DISK_USAGE"
        status_info "Address" "$PG_ADDRESS"
        echo
        return
    fi

    local PG_RAM=$(mem_usage $PID)
    local P_UPTIME=$(run_time $PID)
    local PG_NUM_TCPS=$(num_tcps $PID)
    local PG_TCP_LISTEN=$(list_tcp $PID)
    local PG_UDP_LISTEN=$(list_udp $PID)
    local PG_NUM_FILES=$(num_files $PID)

    local PG_NUM_PEERS=$(pg_jsonrpc \
        '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' \
        | jq -r '.result')
    PG_NUM_PEERS=$(($PG_NUM_PEERS))
    if [[ ! "$PG_NUM_PEERS" =~ ^[0-9]+$ ]]; then
        PG_NUM_PEERS=0
    fi
    local PG_HEIGHT=$(pg_jsonrpc \
        '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
        | jq -r '.result')
    PG_HEIGHT=$(($PG_HEIGHT))
    if [[ ! "$PG_HEIGHT" =~ ^[0-9]+$ ]]; then
        PG_HEIGHT=N/A
    fi

    local PG_BALANCE=$(pg_client \
        attach --exec "web3.fromWei(eth.getBalance('$PG_ADDRESS'),'ether')")
    if [ "$PG_BALANCE" == "" ]; then
        PG_BALANCE=N/A
    elif [[ $PG_BALANCE =~ [^.0-9e-] ]]; then
        PG_BALANCE=N/A
    fi

    status_head $PG_VER Running
    status_info "Disk"      "$PG_DISK_USAGE"
    status_info "Address"   "$PG_ADDRESS"
    status_info "Balance"   "$PG_BALANCE"
    status_info "Miner"     "$PG_MINER_ADDRESS"
    status_info "PID"       "$PID"
    status_info "RAM"       "$PG_RAM"
    status_info "Uptime"    "$PG_UPTIME"
    status_info "#Files"    "$PG_NUM_FILES"
    status_info "TCP Ports" "$PG_TCP_LISTEN"
    status_info "#TCP"      "$PG_NUM_TCPS"
    status_info "UDP Ports" "$PG_UDP_LISTEN"
    status_info "#Peers"    "$PG_NUM_PEERS"
    status_info "Height"    "$PG_HEIGHT"
    echo
}

esc_compress_log()
{
    compress_log $SCRIPT_PATH/esc/data/geth/logs/dpos
    compress_log $SCRIPT_PATH/esc/data/logs-spv
    compress_log $SCRIPT_PATH/esc/logs
}

esc_remove_log()
{
    remove_log $SCRIPT_PATH/esc/data/geth/logs/dpos
    remove_log $SCRIPT_PATH/esc/data/logs-spv
    remove_log $SCRIPT_PATH/esc/logs
}


eco_compress_log()
{
    compress_log $SCRIPT_PATH/eco/data/eco/logs/dpos
    compress_log $SCRIPT_PATH/eco/data/logs-spv
    compress_log $SCRIPT_PATH/eco/logs
}


pgp_compress_log()
{
    compress_log $SCRIPT_PATH/pgp/data/pgp/logs/dpos
    compress_log $SCRIPT_PATH/pgp/data/logs-spv
    compress_log $SCRIPT_PATH/pgp/logs
}

pg_compress_log()
{
    compress_log $SCRIPT_PATH/pg/data/pg/logs/dpos
    compress_log $SCRIPT_PATH/pg/data/logs-spv
    compress_log $SCRIPT_PATH/pg/logs
}

eco_remove_log()
{
    remove_log $SCRIPT_PATH/eco/data/eco/logs/dpos
    remove_log $SCRIPT_PATH/eco/data/logs-spv
    remove_log $SCRIPT_PATH/eco/logs
}

pgp_remove_log()
{
    remove_log $SCRIPT_PATH/pgp/data/pgp/logs/dpos
    remove_log $SCRIPT_PATH/pgp/data/logs-spv
    remove_log $SCRIPT_PATH/pgp/logs
}


pg_remove_log()
{
    remove_log $SCRIPT_PATH/pg/data/pg/logs/dpos
    remove_log $SCRIPT_PATH/pg/data/logs-spv
    remove_log $SCRIPT_PATH/pg/logs
}

esc_update()
{
    unset OPTIND
    while getopts "ny" OPTION; do
        case $OPTION in
            n)
                local NO_START_AFTER_UPDATE=1
                ;;
            y)
                local YES_TO_ALL=1
                ;;
        esac
    done

    chain_prepare_stage esc esc
    if [ "$?" != "0" ]; then
        return
    fi

    local PATH_STAGE=$SCRIPT_PATH/.node-upload/esc
    local DIR_DEPLOY=$SCRIPT_PATH/esc

    local PID=$(pgrep -f '^\./esc .*--rpc ')
    if [ $PID ]; then
        esc_stop
    fi

    mkdir -p $DIR_DEPLOY
    cp -v $PATH_STAGE/esc $DIR_DEPLOY/

    if [ $PID ] && [ "$NO_START_AFTER_UPDATE" == "" ]; then
        esc_start
    fi
}

eco_update()
{
    unset OPTIND
    while getopts "ny" OPTION; do
        case $OPTION in
            n)
                local NO_START_AFTER_UPDATE=1
                ;;
            y)
                local YES_TO_ALL=1
                ;;
        esac
    done

    chain_prepare_stage eco eco
    if [ "$?" != "0" ]; then
        return
    fi

    local PATH_STAGE=$SCRIPT_PATH/.node-upload/eco
    local DIR_DEPLOY=$SCRIPT_PATH/eco

    local PID=$(pgrep -f '^\./eco .*--rpc ')
    if [ $PID ]; then
        eco_stop
    fi

    mkdir -p $DIR_DEPLOY
    cp -v $PATH_STAGE/eco $DIR_DEPLOY/

    if [ $PID ] && [ "$NO_START_AFTER_UPDATE" == "" ]; then
        eco_start
    fi
}

pgp_update()
{
    unset OPTIND
    while getopts "ny" OPTION; do
        case $OPTION in
            n)
                local NO_START_AFTER_UPDATE=1
                ;;
            y)
                local YES_TO_ALL=1
                ;;
        esac
    done

    chain_prepare_stage pgp pgp
    if [ "$?" != "0" ]; then
        return
    fi

    local PATH_STAGE=$SCRIPT_PATH/.node-upload/pgp
    local DIR_DEPLOY=$SCRIPT_PATH/pgp

    local PID=$(pgrep -f '^\./pgp .*--rpc ')
    if [ $PID ]; then
        pgp_stop
    fi

    mkdir -p $DIR_DEPLOY
    cp -v $PATH_STAGE/pgp $DIR_DEPLOY/

    if [ $PID ] && [ "$NO_START_AFTER_UPDATE" == "" ]; then
        pgp_start
    fi
}

pg_update()
{
    unset OPTIND
    while getopts "ny" OPTION; do
        case $OPTION in
            n)
                local NO_START_AFTER_UPDATE=1
                ;;
            y)
                local YES_TO_ALL=1
                ;;
        esac
    done

    chain_prepare_stage pg pg
    if [ "$?" != "0" ]; then
        return
    fi

    local PATH_STAGE=$SCRIPT_PATH/.node-upload/pg
    local DIR_DEPLOY=$SCRIPT_PATH/pg

    local PID=$(pgrep -f '^\./pg .*--rpc ')
    if [ $PID ]; then
        pg_stop
    fi

    mkdir -p $DIR_DEPLOY
    cp -v $PATH_STAGE/pg $DIR_DEPLOY/

    if [ $PID ] && [ "$NO_START_AFTER_UPDATE" == "" ]; then
        pg_start
    fi
}


esc_init()
{
    if [ $(mem_free) -lt 512 ]; then
        echo_error "free memory not enough"
        return
    fi

    local ESC_KEYSTORE=
    local ESC_KEYSTORE_PASS_FILE=~/.config/elastos/esc.txt

    if [ ! -f ${SCRIPT_PATH}/esc/esc ]; then
        esc_update -y
    fi

    if [ -f $SCRIPT_PATH/esc/.init ]; then
        echo_error "esc has already been initialized"
        return
    fi

    cd $SCRIPT_PATH/esc
    local ESC_NUM_ACCOUNTS=$(./esc --datadir "$SCRIPT_PATH/esc/data/" \
        --nousb --verbosity 0 account list | wc -l)
    if [ $ESC_NUM_ACCOUNTS -ge 1 ]; then
        echo_error "esc keystore file exist"
        return
    fi

    if [ -f "$ESC_KEYSTORE_PASS_FILE" ]; then
        echo_error "$ESC_KEYSTORE_PASS_FILE exist"
        return
    fi

    echo "Creating esc keystore..."
    gen_pass
    if [ "$KEYSTORE_PASS" == "" ]; then
        echo_error "empty password"
        exit
    fi

    echo "Saving esc keystore password..."
    mkdir -p $(dirname $ESC_KEYSTORE_PASS_FILE)
    chmod 700 $(dirname $ESC_KEYSTORE_PASS_FILE)
    echo $KEYSTORE_PASS > $ESC_KEYSTORE_PASS_FILE
    chmod 600 $ESC_KEYSTORE_PASS_FILE

    cd ${SCRIPT_PATH}/esc
    ./esc --datadir "$SCRIPT_PATH/esc/data/" --verbosity 0 account new \
        --password "$ESC_KEYSTORE_PASS_FILE" >/dev/null
    if [ "$?" != "0" ]; then
        echo_error "failed to create esc keystore"
        return
    fi

    echo "Checking esc keystore..."
    local ESC_KEYSTORE=$(./esc --datadir "$SCRIPT_PATH/esc/data/" \
        --nousb --verbosity 0 account list | sed 's/.*keystore:\/\///')
    chmod 600 $ESC_KEYSTORE

    local ESC_MINER_ADDRESS_FILE=$SCRIPT_PATH/esc/data/miner_address.txt
    echo "You can input an alternative esc reward address. (ENTER to skip)"
    local ESC_MINER_ADDRESS=
    read -p '? Miner Address: ' ESC_MINER_ADDRESS
    if [ "$ESC_MINER_ADDRESS" != "" ]; then
        mkdir -p $SCRIPT_PATH/esc/data
        echo $ESC_MINER_ADDRESS | tee $ESC_MINER_ADDRESS_FILE
        chmod 600 $ESC_MINER_ADDRESS_FILE
    fi

    echo_info "esc keystore file: $ESC_KEYSTORE"
    echo_info "esc keystore password file: $ESC_KEYSTORE_PASS_FILE"
    if [ -f $ESC_MINER_ADDRESS_FILE ]; then
        echo_info "esc miner address file: $ESC_MINER_ADDRESS_FILE"
    fi

    touch ${SCRIPT_PATH}/esc/.init
    echo_ok "esc initialized"
    echo
}
eco_init()
{
    if [ $(mem_free) -lt 512 ]; then
        echo_error "free memory not enough"
        return
    fi

    local ECO_KEYSTORE=
    local ECO_KEYSTORE_PASS_FILE=~/.config/elastos/eco.txt

    if [ ! -f ${SCRIPT_PATH}/eco/eco ]; then
        eco_update -y
    fi

    if [ -f $SCRIPT_PATH/eco/.init ]; then
        echo_error "eco has already been initialized"
        return
    fi

    cd $SCRIPT_PATH/eco
    local ECO_NUM_ACCOUNTS=$(./eco --datadir "$SCRIPT_PATH/eco/data/" \
        --nousb --verbosity 0 account list | wc -l)
    if [ $ECO_NUM_ACCOUNTS -ge 1 ]; then
        echo_error "eco keystore file exist"
        return
    fi

    if [ -f "$ECO_KEYSTORE_PASS_FILE" ]; then
        echo_error "$ECO_KEYSTORE_PASS_FILE exist"
        return
    fi

    echo "Creating eco keystore..."
    gen_pass
    if [ "$KEYSTORE_PASS" == "" ]; then
        echo_error "empty password"
        exit
    fi

    echo "Saving eco keystore password..."
    mkdir -p $(dirname $ECO_KEYSTORE_PASS_FILE)
    chmod 700 $(dirname $ECO_KEYSTORE_PASS_FILE)
    echo $KEYSTORE_PASS > $ECO_KEYSTORE_PASS_FILE
    chmod 600 $ECO_KEYSTORE_PASS_FILE

    cd ${SCRIPT_PATH}/eco
    ./eco --datadir "$SCRIPT_PATH/eco/data/" --verbosity 0 account new \
        --password "$ECO_KEYSTORE_PASS_FILE" >/dev/null
    if [ "$?" != "0" ]; then
        echo_error "failed to create eco keystore"
        return
    fi

    echo "Checking eco keystore..."
    local ECO_KEYSTORE=$(./eco --datadir "$SCRIPT_PATH/eco/data/" \
        --nousb --verbosity 0 account list | sed 's/.*keystore:\/\///')
    chmod 600 $ECO_KEYSTORE

    local ECO_MINER_ADDRESS_FILE=$SCRIPT_PATH/eco/data/miner_address.txt
    echo "You can input an alternative eco reward address. (ENTER to skip)"
    local ECO_MINER_ADDRESS=
    read -p '? Miner Address: ' ECO_MINER_ADDRESS
    if [ "$ECO_MINER_ADDRESS" != "" ]; then
        mkdir -p $SCRIPT_PATH/eco/data
        echo $ECO_MINER_ADDRESS | tee $ECO_MINER_ADDRESS_FILE
        chmod 600 $ECO_MINER_ADDRESS_FILE
    fi

    echo_info "eco keystore file: $ECO_KEYSTORE"
    echo_info "eco keystore password file: $ECO_KEYSTORE_PASS_FILE"
    if [ -f $ECO_MINER_ADDRESS_FILE ]; then
        echo_info "eco miner address file: $ECO_MINER_ADDRESS_FILE"
    fi

    touch ${SCRIPT_PATH}/eco/.init
    echo_ok "eco initialized"
    echo
}

pgp_init()
{
    if [ $(mem_free) -lt 512 ]; then
        echo_error "free memory not enough"
        return
    fi

    local PGP_KEYSTORE=
    local PGP_KEYSTORE_PASS_FILE=~/.config/elastos/pgp.txt

    if [ ! -f ${SCRIPT_PATH}/pgp/pgp ]; then
        pgp_update -y
    fi

    if [ -f $SCRIPT_PATH/pgp/.init ]; then
        echo_error "pgp has already been initialized"
        return
    fi

    cd $SCRIPT_PATH/pgp
    local PGP_NUM_ACCOUNTS=$(./pgp --datadir "$SCRIPT_PATH/pgp/data/" \
        --nousb --verbosity 0 account list | wc -l)
    if [ $PGP_NUM_ACCOUNTS -ge 1 ]; then
        echo_error "pgp keystore file exist"
        return
    fi

    if [ -f "$PGP_KEYSTORE_PASS_FILE" ]; then
        echo_error "$PGP_KEYSTORE_PASS_FILE exist"
        return
    fi

    echo "Creating pgp keystore..."
    gen_pass
    if [ "$KEYSTORE_PASS" == "" ]; then
        echo_error "empty password"
        exit
    fi

    echo "Saving pgp keystore password..."
    mkdir -p $(dirname $PGP_KEYSTORE_PASS_FILE)
    chmod 700 $(dirname $PGP_KEYSTORE_PASS_FILE)
    echo $KEYSTORE_PASS > $PGP_KEYSTORE_PASS_FILE
    chmod 600 $PGP_KEYSTORE_PASS_FILE

    cd ${SCRIPT_PATH}/pgp
    ./pgp --datadir "$SCRIPT_PATH/pgp/data/" --verbosity 0 account new \
        --password "$PGP_KEYSTORE_PASS_FILE" >/dev/null
    if [ "$?" != "0" ]; then
        echo_error "failed to create pgp keystore"
        return
    fi

    echo "Checking pgp keystore..."
    local PGP_KEYSTORE=$(./pgp --datadir "$SCRIPT_PATH/pgp/data/" \
        --nousb --verbosity 0 account list | sed 's/.*keystore:\/\///')
    chmod 600 $PGP_KEYSTORE

    local PGP_MINER_ADDRESS_FILE=$SCRIPT_PATH/pgp/data/miner_address.txt
    echo "You can input an alternative pgp reward address. (ENTER to skip)"
    local PGP_MINER_ADDRESS=
    read -p '? Miner Address: ' PGP_MINER_ADDRESS
    if [ "$PGP_MINER_ADDRESS" != "" ]; then
        mkdir -p $SCRIPT_PATH/pgp/data
        echo $PGP_MINER_ADDRESS | tee $PGP_MINER_ADDRESS_FILE
        chmod 600 $PGP_MINER_ADDRESS_FILE
    fi

    echo_info "pgp keystore file: $PGP_KEYSTORE"
    echo_info "pgp keystore password file: $PGP_KEYSTORE_PASS_FILE"
    if [ -f $PGP_MINER_ADDRESS_FILE ]; then
        echo_info "pgp miner address file: $PGP_MINER_ADDRESS_FILE"
    fi

    touch ${SCRIPT_PATH}/pgp/.init
    echo_ok "pgp initialized"
    echo
}

pg_init()
{
    if [ $(mem_free) -lt 512 ]; then
        echo_error "free memory not enough"
        return
    fi

    local PG_KEYSTORE=
    local PG_KEYSTORE_PASS_FILE=~/.config/elastos/pg.txt

    if [ ! -f ${SCRIPT_PATH}/pg/pg ]; then
        pg_update -y
    fi

    if [ -f $SCRIPT_PATH/pg/.init ]; then
        echo_error "pg has already been initialized"
        return
    fi

    cd $SCRIPT_PATH/pg
    local PG_NUM_ACCOUNTS=$(./pg --datadir "$SCRIPT_PATH/pg/data/" \
        --nousb --verbosity 0 account list | wc -l)
    if [ $PG_NUM_ACCOUNTS -ge 1 ]; then
        echo_error "pg keystore file exist"
        return
    fi

    if [ -f "$PG_KEYSTORE_PASS_FILE" ]; then
        echo_error "$PG_KEYSTORE_PASS_FILE exist"
        return
    fi

    echo "Creating pg keystore..."
    gen_pass
    if [ "$KEYSTORE_PASS" == "" ]; then
        echo_error "empty password"
        exit
    fi

    echo "Saving pg keystore password..."
    mkdir -p $(dirname $PG_KEYSTORE_PASS_FILE)
    chmod 700 $(dirname $PG_KEYSTORE_PASS_FILE)
    echo $KEYSTORE_PASS > $PG_KEYSTORE_PASS_FILE
    chmod 600 $PG_KEYSTORE_PASS_FILE

    cd ${SCRIPT_PATH}/pg
    ./pg --datadir "$SCRIPT_PATH/pg/data/" --verbosity 0 account new \
        --password "$PG_KEYSTORE_PASS_FILE" >/dev/null
    if [ "$?" != "0" ]; then
        echo_error "failed to create pg keystore"
        return
    fi

    echo "Checking pg keystore..."
    local PG_KEYSTORE=$(./pg --datadir "$SCRIPT_PATH/pg/data/" \
        --nousb --verbosity 0 account list | sed 's/.*keystore:\/\///')
    chmod 600 $PG_KEYSTORE

    local PG_MINER_ADDRESS_FILE=$SCRIPT_PATH/pg/data/miner_address.txt
    echo "You can input an alternative pg reward address. (ENTER to skip)"
    local PG_MINER_ADDRESS=
    read -p '? Miner Address: ' PG_MINER_ADDRESS
    if [ "$PG_MINER_ADDRESS" != "" ]; then
        mkdir -p $SCRIPT_PATH/pg/data
        echo $PG_MINER_ADDRESS | tee $PG_MINER_ADDRESS_FILE
        chmod 600 $PG_MINER_ADDRESS_FILE
    fi

    echo_info "pg keystore file: $PG_KEYSTORE"
    echo_info "pg keystore password file: $PG_KEYSTORE_PASS_FILE"
    if [ -f $PG_MINER_ADDRESS_FILE ]; then
        echo_info "pg miner address file: $PG_MINER_ADDRESS_FILE"
    fi

    touch ${SCRIPT_PATH}/pg/.init
    echo_ok "pg initialized"
    echo
}

esc_send()
{
    if [ "$3" == "" ]; then
        echo "Usage: $SCRIPT_NAME esc send FROM TO AMOUNT [FEE]"
        return
    fi

    local ESC_ADDR_FROM=$1
    local ESC_ADDR_TO=$2
    local ESC_AMOUNT=$3
    local ESC_FEE=$4

    if [ "$ESC_FEE" == "" ]; then
        local ESC_FEE=21000
    fi
    local ESC_GAS_PRICE=$(esc_client attach --exec "eth.gasPrice")
    local ESC_FEE_WEI=$(echo $ESC_FEE*$ESC_GAS_PRICE | bc)

    if [ "$ESC_AMOUNT" == "All" ]; then
        local ESC_AMOUNT_WEI=$(esc_client attach --exec "eth.getBalance('$ESC_ADDR_FROM')")
        local ESC_AMOUNT_WEI=$(echo "$ESC_AMOUNT_WEI-$ESC_FEE_WEI" | bc)
    else
        local ESC_AMOUNT_WEI=$(echo "$ESC_AMOUNT*10^18" | bc)
    fi

    if [ "$IS_DEBUG" ]; then
        echo "ESC_ADDR_FROM:  $ESC_ADDR_FROM"
        echo "ESC_ADDR_TO:    $ESC_ADDR_TO"
        echo "ESC_AMOUNT:     $ESC_AMOUNT"
        echo "ESC_AMOUNT_WEI: $ESC_AMOUNT_WEI"
        echo "ESC_FEE:        $ESC_FEE"
        echo "ESC_GAS_PRICE:  $ESC_GAS_PRICE"
        echo "ESC_FEE_WEI:    $ESC_FEE_WEI"
    fi

    esc_client attach --exec "eth.sendTransaction({from:'$ESC_ADDR_FROM',to:'$ESC_ADDR_TO',value:$ESC_AMOUNT_WEI,gas:$ESC_FEE,gasPrice:$ESC_GAS_PRICE})"
}

#
# esc-oracle
#
esc-oracle_usage()
{
    echo "Usage: $SCRIPT_NAME $CHAIN_NAME COMMAND [OPTIONS]"
    echo "Manage $CHAIN_NAME"
    echo
    echo "Available Commands:"
    echo
    echo "  init            Install and configure $CHAIN_NAME_U"
    echo "  update          Update $CHAIN_NAME_U"
    echo
    echo "  start           Start $CHAIN_NAME_U daemon"
    echo "  stop            Stop $CHAIN_NAME_U daemon"
    echo "  status          Print $CHAIN_NAME_U daemon status"
    echo
    echo "  compress_log    Compress $CHAIN_NAME_U daemon log files"
    echo "  remove_log      Remove $CHAIN_NAME_U daemon log files"
    echo
}

esc-oracle_start()
{
    if [ ! -f $SCRIPT_PATH/esc-oracle/crosschain_oracle.js ]; then
        echo_error "$SCRIPT_PATH/esc-oracle/crosschain_oracle.js is not exist"
        return
    fi

    local PID=$(pgrep -fx 'node crosschain_oracle.js')
    if [ "$PID" != "" ]; then
        esc-oracle_status
        return
    fi

    echo "Starting esc-oracle..."
    cd $SCRIPT_PATH/esc-oracle
    mkdir -p $SCRIPT_PATH/esc-oracle/logs

    if [ "$CHAIN_TYPE" == "mainnet" ]; then
        export env=mainnet
    elif [ "$CHAIN_TYPE" == "testnet" ]; then
        export env=testnet
    else
        echo_error "do not support $CHAIN_TYPE"
        return
    fi

    echo "env: $env"
    nodejs_setenv
    nohup $SHELL -c "node crosschain_oracle.js \
        2>$SCRIPT_PATH/esc-oracle/logs/esc-oracle_err.log \
        | rotatelogs $SCRIPT_PATH/esc-oracle/logs/esc-oracle_out-%Y-%m-%d-%H_%M_%S.log 20M" &

    sleep 1
    esc-oracle_status
}

eco-oracle_start()
{
    if [ ! -f $SCRIPT_PATH/eco-oracle/crosschain_eco.js ]; then
        echo_error "$SCRIPT_PATH/eco-oracle/crosschain_eco.js is not exist"
        return
    fi

    local PID=$(pgrep -fx 'node crosschain_eco.js')
    if [ "$PID" != "" ]; then
        eco-oracle_status
        return
    fi

    echo "Starting eco-oracle..."
    cd $SCRIPT_PATH/eco-oracle
    mkdir -p $SCRIPT_PATH/eco-oracle/logs

    if [ "$CHAIN_TYPE" == "mainnet" ]; then
        export env=mainnet
    elif [ "$CHAIN_TYPE" == "testnet" ]; then
        export env=testnet
    else
        echo_error "do not support $CHAIN_TYPE"
        return
    fi

    echo "env: $env"
    nodejs_setenv
    nohup $SHELL -c "node crosschain_eco.js \
        2>$SCRIPT_PATH/eco-oracle/logs/eco-oracle_err.log \
        | rotatelogs $SCRIPT_PATH/eco-oracle/logs/eco-oracle_out-%Y-%m-%d-%H_%M_%S.log 20M" &

    sleep 1
    eco-oracle_status
}

pgp-oracle_start()
{
    if [ ! -f $SCRIPT_PATH/pgp-oracle/crosschain_pgp.js ]; then
        echo_error "$SCRIPT_PATH/pgp-oracle/crosschain_pgp.js is not exist"
        return
    fi

    local PID=$(pgrep -fx 'node crosschain_pgp.js')
    if [ "$PID" != "" ]; then
        pgp-oracle_status
        return
    fi

    echo "Starting pgp-oracle..."
    cd $SCRIPT_PATH/pgp-oracle
    mkdir -p $SCRIPT_PATH/pgp-oracle/logs

    if [ "$CHAIN_TYPE" == "mainnet" ]; then
        export env=mainnet
    elif [ "$CHAIN_TYPE" == "testnet" ]; then
        export env=testnet
    else
        echo_error "do not support $CHAIN_TYPE"
        return
    fi

    echo "env: $env"
    nodejs_setenv
    nohup $SHELL -c "node crosschain_pgp.js \
        2>$SCRIPT_PATH/pgp-oracle/logs/pgp-oracle_err.log \
        | rotatelogs $SCRIPT_PATH/pgp-oracle/logs/pgp-oracle_out-%Y-%m-%d-%H_%M_%S.log 20M" &

    sleep 1
    pgp-oracle_status
}

pg-oracle_start()
{
    if [ ! -f $SCRIPT_PATH/pg-oracle/crosschain_pg.js ]; then
        echo_error "$SCRIPT_PATH/pg-oracle/crosschain_pg.js is not exist"
        return
    fi

    local PID=$(pgrep -fx 'node crosschain_pg.js')
    if [ "$PID" != "" ]; then
        pg-oracle_status
        return
    fi

    echo "Starting pg-oracle..."
    cd $SCRIPT_PATH/pg-oracle
    mkdir -p $SCRIPT_PATH/pg-oracle/logs

    if [ "$CHAIN_TYPE" == "mainnet" ]; then
        export env=mainnet
    elif [ "$CHAIN_TYPE" == "testnet" ]; then
        export env=testnet
    else
        echo_error "do not support $CHAIN_TYPE"
        return
    fi

    echo "env: $env"
    nodejs_setenv
    nohup $SHELL -c "node crosschain_pg.js \
        2>$SCRIPT_PATH/pg-oracle/logs/pg-oracle_err.log \
        | rotatelogs $SCRIPT_PATH/pg-oracle/logs/pg-oracle_out-%Y-%m-%d-%H_%M_%S.log 20M" &

    sleep 1
    pg-oracle_status
}

esc-oracle_stop()
{
    local PID=$(pgrep -fx 'node crosschain_oracle.js')
    if [ "$PID" != "" ]; then
        echo "Stopping esc-oracle..."
        kill $PID
        while ps -p $PID 1>/dev/null; do
            echo -n .
            sleep 1
        done
        echo
    fi
    esc-oracle_status
}

eco-oracle_stop()
{
    local PID=$(pgrep -fx 'node crosschain_eco.js')
    if [ "$PID" != "" ]; then
        echo "Stopping eco-oracle..."
        kill $PID
        while ps -p $PID 1>/dev/null; do
            echo -n .
            sleep 1
        done
        echo
    fi
    eco-oracle_status
}

pgp-oracle_stop()
{
    local PID=$(pgrep -fx 'node crosschain_pgp.js')
    if [ "$PID" != "" ]; then
        echo "Stopping pgp-oracle..."
        kill $PID
        while ps -p $PID 1>/dev/null; do
            echo -n .
            sleep 1
        done
        echo
    fi
    pgp-oracle_status
}

pg-oracle_stop()
{
    local PID=$(pgrep -fx 'node crosschain_pg.js')
    if [ "$PID" != "" ]; then
        echo "Stopping pg-oracle..."
        kill $PID
        while ps -p $PID 1>/dev/null; do
            echo -n .
            sleep 1
        done
        echo
    fi
    pg-oracle_status
}

esc-oracle_installed()
{
    if [ -f $SCRIPT_PATH/esc-oracle/crosschain_oracle.js ]; then
        true
    else
        false
    fi
}

eco-oracle_installed()
{
    if [ -f $SCRIPT_PATH/eco-oracle/crosschain_eco.js ]; then
        true
    else
        false
    fi
}

pgp-oracle_installed()
{
    if [ -f $SCRIPT_PATH/pgp-oracle/crosschain_pgp.js ]; then
        true
    else
        false
    fi
}

pg-oracle_installed()
{
    if [ -f $SCRIPT_PATH/pg-oracle/crosschain_pg.js ]; then
        true
    else
        false
    fi
}

esc-oracle_ver()
{
    if [ -f $SCRIPT_PATH/esc-oracle/crosschain_oracle.js ]; then
        echo "esc-oracle $(cat $SCRIPT_PATH/esc-oracle/*.js | shasum | cut -c 1-7)"
    else
        echo "esc-oracle N/A"
    fi
}

eco-oracle_ver()
{
    if [ -f $SCRIPT_PATH/eco-oracle/crosschain_eco.js ]; then
        echo "eco-oracle $(cat $SCRIPT_PATH/eco-oracle/*.js | shasum | cut -c 1-7)"
    else
        echo "eco-oracle N/A"
    fi
}

pgp-oracle_ver()
{
    if [ -f $SCRIPT_PATH/pgp-oracle/crosschain_pgp.js ]; then
        echo "pgp-oracle $(cat $SCRIPT_PATH/pgp-oracle/*.js | shasum | cut -c 1-7)"
    else
        echo "pgp-oracle N/A"
    fi
}

pg-oracle_ver()
{
    if [ -f $SCRIPT_PATH/pg-oracle/crosschain_pg.js ]; then
        echo "pg-oracle $(cat $SCRIPT_PATH/pg-oracle/*.js | shasum | cut -c 1-7)"
    else
        echo "pg-oracle N/A"
    fi
}

esc-oracle_status()
{
    local ESC_ORACLE_VER=$(esc-oracle_ver)

    local ESC_ORACLE_DISK_USAGE=$(disk_usage $SCRIPT_PATH/esc-oracle)

    local PID=$(pgrep -fx 'node crosschain_oracle.js')
    if [ "$PID" == "" ]; then
        status_head $ESC_ORACLE_VER Stopped
        status_info "Disk" "$ESC_ORACLE_DISK_USAGE"
        echo
        return
    fi

    local ESC_ORACLE_RAM=$(mem_usage $PID)
    local ESC_ORACLE_UPTIME=$(run_time $PID)
    local ESC_ORACLE_TCP_LISTEN=$(list_tcp $PID)
    local ESC_ORACLE_NUM_TCPS=$(num_tcps $PID)
    local ESC_ORACLE_NUM_FILES=$(num_files $PID)

    status_head $ESC_ORACLE_VER Running
    status_info "Disk"      "$ESC_ORACLE_DISK_USAGE"
    status_info "PID"       "$PID"
    status_info "RAM"       "$ESC_ORACLE_RAM"
    status_info "Uptime"    "$ESC_ORACLE_UPTIME"
    status_info "#Files"    "$ESC_ORACLE_NUM_FILES"
    status_info "TCP Ports" "$ESC_ORACLE_TCP_LISTEN"
    status_info "#TCP"      "$ESC_ORACLE_NUM_TCPS"
    echo
}

eco-oracle_status()
{
    local ECO_ORACLE_VER=$(eco-oracle_ver)

    local ECO_ORACLE_DISK_USAGE=$(disk_usage $SCRIPT_PATH/eco-oracle)

    local PID=$(pgrep -fx 'node crosschain_eco.js')
    if [ "$PID" == "" ]; then
        status_head $ECO_ORACLE_VER Stopped
        status_info "Disk" "$ECO_ORACLE_DISK_USAGE"
        echo
        return
    fi

    local ECO_ORACLE_RAM=$(mem_usage $PID)
    local ECO_ORACLE_UPTIME=$(run_time $PID)
    local ECO_ORACLE_TCP_LISTEN=$(list_tcp $PID)
    local ECO_ORACLE_NUM_TCPS=$(num_tcps $PID)
    local ECO_ORACLE_NUM_FILES=$(num_files $PID)

    status_head $ECO_ORACLE_VER Running
    status_info "Disk"      "$ECO_ORACLE_DISK_USAGE"
    status_info "PID"       "$PID"
    status_info "RAM"       "$ECO_ORACLE_RAM"
    status_info "Uptime"    "$ECO_ORACLE_UPTIME"
    status_info "#Files"    "$ECO_ORACLE_NUM_FILES"
    status_info "TCP Ports" "$ECO_ORACLE_TCP_LISTEN"
    status_info "#TCP"      "$ECO_ORACLE_NUM_TCPS"
    echo
}

pgp-oracle_status()
{
    local PGP_ORACLE_VER=$(pgp-oracle_ver)

    local PGP_ORACLE_DISK_USAGE=$(disk_usage $SCRIPT_PATH/pgp-oracle)

    local PID=$(pgrep -fx 'node crosschain_pgp.js')
    if [ "$PID" == "" ]; then
        status_head $PGP_ORACLE_VER Stopped
        status_info "Disk" "$PGP_ORACLE_DISK_USAGE"
        echo
        return
    fi

    local PGP_ORACLE_RAM=$(mem_usage $PID)
    local PGP_ORACLE_UPTIME=$(run_time $PID)
    local PGP_ORACLE_TCP_LISTEN=$(list_tcp $PID)
    local PGP_ORACLE_NUM_TCPS=$(num_tcps $PID)
    local PGP_ORACLE_NUM_FILES=$(num_files $PID)

    status_head $PGP_ORACLE_VER Running
    status_info "Disk"      "$PGP_ORACLE_DISK_USAGE"
    status_info "PID"       "$PID"
    status_info "RAM"       "$PGP_ORACLE_RAM"
    status_info "Uptime"    "$PGP_ORACLE_UPTIME"
    status_info "#Files"    "$PGP_ORACLE_NUM_FILES"
    status_info "TCP Ports" "$PGP_ORACLE_TCP_LISTEN"
    status_info "#TCP"      "$PGP_ORACLE_NUM_TCPS"
    echo
}

pg-oracle_status()
{
    local PG_ORACLE_VER=$(pg-oracle_ver)

    local PG_ORACLE_DISK_USAGE=$(disk_usage $SCRIPT_PATH/pg-oracle)

    local PID=$(pgrep -fx 'node crosschain_pg.js')
    if [ "$PID" == "" ]; then
        status_head $PG_ORACLE_VER Stopped
        status_info "Disk" "$PG_ORACLE_DISK_USAGE"
        echo
        return
    fi

    local PG_ORACLE_RAM=$(mem_usage $PID)
    local PG_ORACLE_UPTIME=$(run_time $PID)
    local PG_ORACLE_TCP_LISTEN=$(list_tcp $PID)
    local PG_ORACLE_NUM_TCPS=$(num_tcps $PID)
    local PG_ORACLE_NUM_FILES=$(num_files $PID)

    status_head $PG_ORACLE_VER Running
    status_info "Disk"      "$PG_ORACLE_DISK_USAGE"
    status_info "PID"       "$PID"
    status_info "RAM"       "$PG_ORACLE_RAM"
    status_info "Uptime"    "$PG_ORACLE_UPTIME"
    status_info "#Files"    "$PG_ORACLE_NUM_FILES"
    status_info "TCP Ports" "$PG_ORACLE_TCP_LISTEN"
    status_info "#TCP"      "$PG_ORACLE_NUM_TCPS"
    echo
}

esc-oracle_compress_log()
{
    compress_log $SCRIPT_PATH/esc-oracle/logs/esc-oracle_out-\*.log
}

esc-oracle_remove_log()
{
    remove_log $SCRIPT_PATH/esc-oracle/logs/esc-oracle_out-\*.log
}

eco-oracle_compress_log()
{
    compress_log $SCRIPT_PATH/eco-oracle/logs/eco-oracle_out-\*.log
}

eco-oracle_remove_log()
{
    remove_log $SCRIPT_PATH/eco-oracle/logs/eco-oracle_out-\*.log
}

pgp-oracle_compress_log()
{
    compress_log $SCRIPT_PATH/pgp-oracle/logs/pgp-oracle_out-\*.log
}

pg-oracle_compress_log()
{
    compress_log $SCRIPT_PATH/pg-oracle/logs/pg-oracle_out-\*.log
}

pgp-oracle_remove_log()
{
    remove_log $SCRIPT_PATH/pgp-oracle/logs/pgp-oracle_out-\*.log
}

pg-oracle_update()
{
    unset OPTIND
    while getopts "ny" OPTION; do
        case $OPTION in
            n)
                local NO_START_AFTER_UPDATE=1
                ;;
            y)
                local YES_TO_ALL=1
                ;;
        esac
    done

    chain_prepare_stage pg-oracle '*.js'
    if [ "$?" != "0" ]; then
        return
    fi

    local PATH_STAGE=$SCRIPT_PATH/.node-upload/pg-oracle
    local DIR_DEPLOY=$SCRIPT_PATH/pg-oracle

    local PID=$(pgrep -fx 'node crosschain_pg.js')
    if [ $PID ]; then
        pg-oracle_stop
    fi

    mkdir -p $DIR_DEPLOY
    cp -v $PATH_STAGE/*.js $DIR_DEPLOY/

    if [ $PID ] && [ "$NO_START_AFTER_UPDATE" == "" ]; then
        pg-oracle_start
    fi
}

esc-oracle_update()
{
    unset OPTIND
    while getopts "ny" OPTION; do
        case $OPTION in
            n)
                local NO_START_AFTER_UPDATE=1
                ;;
            y)
                local YES_TO_ALL=1
                ;;
        esac
    done

    chain_prepare_stage esc-oracle '*.js'
    if [ "$?" != "0" ]; then
        return
    fi

    local PATH_STAGE=$SCRIPT_PATH/.node-upload/esc-oracle
    local DIR_DEPLOY=$SCRIPT_PATH/esc-oracle

    local PID=$(pgrep -fx 'node crosschain_oracle.js')
    if [ $PID ]; then
        esc-oracle_stop
    fi

    mkdir -p $DIR_DEPLOY
    cp -v $PATH_STAGE/*.js $DIR_DEPLOY/

    if [ $PID ] && [ "$NO_START_AFTER_UPDATE" == "" ]; then
        esc-oracle_start
    fi
}

eco-oracle_update()
{
    unset OPTIND
    while getopts "ny" OPTION; do
        case $OPTION in
            n)
                local NO_START_AFTER_UPDATE=1
                ;;
            y)
                local YES_TO_ALL=1
                ;;
        esac
    done

    chain_prepare_stage eco-oracle '*.js'
    if [ "$?" != "0" ]; then
        return
    fi

    local PATH_STAGE=$SCRIPT_PATH/.node-upload/eco-oracle
    local DIR_DEPLOY=$SCRIPT_PATH/eco-oracle

    local PID=$(pgrep -fx 'node crosschain_eco.js')
    if [ $PID ]; then
        eco-oracle_stop
    fi

    mkdir -p $DIR_DEPLOY
    cp -v $PATH_STAGE/*.js $DIR_DEPLOY/

    if [ $PID ] && [ "$NO_START_AFTER_UPDATE" == "" ]; then
        eco-oracle_start
    fi
}


pgp-oracle_update()
{
    unset OPTIND
    while getopts "ny" OPTION; do
        case $OPTION in
            n)
                local NO_START_AFTER_UPDATE=1
                ;;
            y)
                local YES_TO_ALL=1
                ;;
        esac
    done

    chain_prepare_stage pgp-oracle '*.js'
    if [ "$?" != "0" ]; then
        return
    fi

    local PATH_STAGE=$SCRIPT_PATH/.node-upload/pgp-oracle
    local DIR_DEPLOY=$SCRIPT_PATH/pgp-oracle

    local PID=$(pgrep -fx 'node crosschain_pgp.js')
    if [ $PID ]; then
        pgp-oracle_stop
    fi

    mkdir -p $DIR_DEPLOY
    cp -v $PATH_STAGE/*.js $DIR_DEPLOY/

    if [ $PID ] && [ "$NO_START_AFTER_UPDATE" == "" ]; then
        pgp-oracle_start
    fi
}

pg-oracle_update()
{
    unset OPTIND
    while getopts "ny" OPTION; do
        case $OPTION in
            n)
                local NO_START_AFTER_UPDATE=1
                ;;
            y)
                local YES_TO_ALL=1
                ;;
        esac
    done

    chain_prepare_stage pg-oracle '*.js'
    if [ "$?" != "0" ]; then
        return
    fi

    local PATH_STAGE=$SCRIPT_PATH/.node-upload/pg-oracle
    local DIR_DEPLOY=$SCRIPT_PATH/pg-oracle

    local PID=$(pgrep -fx 'node crosschain_pg.js')
    if [ $PID ]; then
        pg-oracle_stop
    fi

    mkdir -p $DIR_DEPLOY
    cp -v $PATH_STAGE/*.js $DIR_DEPLOY/

    if [ $PID ] && [ "$NO_START_AFTER_UPDATE" == "" ]; then
        pg-oracle_start
    fi
}

esc-oracle_init()
{
    if [ ! -f ${SCRIPT_PATH}/esc/.init ]; then
        echo_error "esc not initialized"
        return
    fi

    if [ -f $SCRIPT_PATH/esc-oracle/.init ]; then
        echo_error "esc-oracle has already been initialized"
        return
    fi

    check_env_oracle

    if [ ! -f $SCRIPT_PATH/esc-oracle/crosschain_oracle.js ]; then
        esc-oracle_update -y
    fi

    nodejs_setenv

    mkdir -p $SCRIPT_PATH/esc-oracle
    cd $SCRIPT_PATH/esc-oracle
    npm install web3@1.7.3 express@4.18.1

    touch ${SCRIPT_PATH}/esc-oracle/.init
    echo_ok "esc-oracle initialized"
    echo
}

eco-oracle_init()
{
    if [ ! -f ${SCRIPT_PATH}/eco/.init ]; then
        echo_error "eco not initialized"
        return
    fi

    if [ -f $SCRIPT_PATH/eco-oracle/.init ]; then
        echo_error "eco-oracle has already been initialized"
        return
    fi

    check_env_oracle

    if [ ! -f $SCRIPT_PATH/eco-oracle/crosschain_eco.js ]; then
        eco-oracle_update -y
    fi

    nodejs_setenv

    mkdir -p $SCRIPT_PATH/eco-oracle
    cd $SCRIPT_PATH/eco-oracle
    npm install web3@1.7.3 express@4.18.1

    touch ${SCRIPT_PATH}/eco-oracle/.init
    echo_ok "eco-oracle initialized"
    echo
}


pgp-oracle_init()
{
    if [ ! -f ${SCRIPT_PATH}/pgp/.init ]; then
        echo_error "pgp not initialized"
        return
    fi

    if [ -f $SCRIPT_PATH/pgp-oracle/.init ]; then
        echo_error "pgp-oracle has already been initialized"
        return
    fi

    check_env_oracle

    if [ ! -f $SCRIPT_PATH/pgp-oracle/crosschain_pgp.js ]; then
        pgp-oracle_update -y
    fi

    nodejs_setenv

    mkdir -p $SCRIPT_PATH/pgp-oracle
    cd $SCRIPT_PATH/pgp-oracle
    npm install web3@1.7.3 express@4.18.1

    touch ${SCRIPT_PATH}/pgp-oracle/.init
    echo_ok "pgp-oracle initialized"
    echo
}

pg-oracle_init()
{
    if [ ! -f ${SCRIPT_PATH}/pg/.init ]; then
        echo_error "pg not initialized"
        return
    fi

    if [ -f $SCRIPT_PATH/pg-oracle/.init ]; then
        echo_error "pg-oracle has already been initialized"
        return
    fi

    check_env_oracle

    if [ ! -f $SCRIPT_PATH/pg-oracle/crosschain_pg.js ]; then
        pg-oracle_update -y
    fi

    nodejs_setenv

    mkdir -p $SCRIPT_PATH/pg-oracle
    cd $SCRIPT_PATH/pg-oracle
    npm install web3@1.7.3 express@4.18.1

    touch ${SCRIPT_PATH}/pg-oracle/.init
    echo_ok "pg-oracle initialized"
    echo
}

#
# eid
#
eid_usage()
{
    echo "Usage: $SCRIPT_NAME $CHAIN_NAME COMMAND [OPTIONS]"
    echo "Manage $CHAIN_NAME"
    echo
    echo "Available Commands:"
    echo
    echo "  init            Install and configure $CHAIN_NAME_U"
    echo "  update          Update $CHAIN_NAME_U"
    echo
    echo "  start           Start $CHAIN_NAME_U daemon"
    echo "  stop            Stop $CHAIN_NAME_U daemon"
    echo "  status          Print $CHAIN_NAME_U daemon status"
    echo "  watch           Start $CHAIN_NAME_U daemon and restart a crash"
    echo "  mon             Monitor $CHAIN_NAME_U height and alert a halt"
    echo
    echo "  compress_log    Compress $CHAIN_NAME_U daemon log files"
    echo "  remove_log      Remove $CHAIN_NAME_U daemon log files"
    echo
    echo "  client          Run $CHAIN_NAME_U client"
    echo "  jsonrpc         Call $CHAIN_NAME_U JSON-RPC API"
    echo
    echo "  send            Send crypto in $CHAIN_NAME_U"
    echo
}

eid_start()
{
    if [ ! -f $SCRIPT_PATH/eid/eid ]; then
        echo_error "$SCRIPT_PATH/eid/eid is not exist"
        return
    fi

    if [ "$CHAIN_TYPE" == "mainnet" ]; then
        local EID_OPTS=
    elif [ "$CHAIN_TYPE" == "testnet" ]; then
        local EID_OPTS=--testnet
    else
        echo_error "do not support $CHAIN_TYPE"
        return
    fi

    local PID=$(pgrep -f '^\./eid .*--rpc ')
    if [ "$PID" != "" ]; then
        eid_status
        return
    fi

    echo "Starting eid..."
    cd $SCRIPT_PATH/eid

    if [ "$CHAIN_TYPE" == "testnet" ]; then
        if [ ! -f spvconfig.json ]; then
            cat >spvconfig.json <<EOF
{
  "Configuration": {
    "Magic": 2018101
  }
}
EOF
            chmod 600 spvconfig.json
        fi
    fi

    mkdir -p $SCRIPT_PATH/eid/logs/

    if [ -f ~/.config/elastos/eid.txt ]; then
        if [ -f $SCRIPT_PATH/eid/data/miner_address.txt ]; then
            local EID_OPTS="$EID_OPTS --pbft.miner.address $SCRIPT_PATH/eid/data/miner_address.txt"
        fi
        nohup $SHELL -c "./eid \
            $EID_OPTS \
            --allow-insecure-unlock \
            --datadir $SCRIPT_PATH/eid/data \
            --mine \
            --miner.threads 1 \
            --password ~/.config/elastos/eid.txt \
            --pbft.keystore ${SCRIPT_PATH}/ela/keystore.dat \
            --pbft.keystore.password ~/.config/elastos/ela.txt \
            --pbft.net.address '$(extip)' \
            --pbft.net.port 20649 \
            --rpc \
            --rpcaddr '0.0.0.0' \
            --rpcapi 'db,eth,miner,net,pbft,personal,txpool,web3' \
            --rpcvhosts '*' \
            --syncmode full \
            --unlock '0x$(cat $SCRIPT_PATH/eid/data/keystore/UTC* | jq -r .address)' \
            2>&1 \
            | rotatelogs $SCRIPT_PATH/eid/logs/eid-%Y-%m-%d-%H_%M_%S.log 20M" &
    else
        nohup $SHELL -c "./eid \
            $EID_OPTS \
            --datadir $SCRIPT_PATH/eid/data \
            --lightserv 10 \
            --rpc \
            --rpcaddr '0.0.0.0' \
            --rpcapi 'admin,eth,net,txpool,web3' \
            --rpcvhosts '*' \
            2>&1 \
            | rotatelogs $SCRIPT_PATH/eid/logs/eid-%Y-%m-%d-%H_%M_%S.log 20M" &
    fi

    sleep 3
    eid_status
}

eid_stop()
{
    local PID=$(pgrep -f '^\./eid .*--rpc ')
    if [ "$PID" != "" ]; then
        echo "Stopping eid..."
        kill -s SIGINT $PID
        while ps -p $PID 1>/dev/null; do
            echo -n .
            sleep 1
        done
        echo
    fi
    sync
    eid_status
}

eid_installed()
{
    if [ -f $SCRIPT_PATH/eid/eid ]; then
        true
    else
        false
    fi
}

eid_ver()
{
    if [ -f $SCRIPT_PATH/eid/eid ]; then
        echo "eid $($SCRIPT_PATH/eid/eid version | grep 'Git Commit:' | sed 's/.* //' | cut -c1-7)"
    else
        echo "eid N/A"
    fi
}

eid_client()
{
    if [ ! -f $SCRIPT_PATH/eid/eid ]; then
        echo_error "$SCRIPT_PATH/eid/eid is not exist"
        return
    fi

    cd $SCRIPT_PATH/eid
    if [ "$1" == "" ]; then
        ./eid --datadir $SCRIPT_PATH/eid/data --help
    elif [ "$1" == "attach" ] &&
         [ ! -S $SCRIPT_PATH/eid/data/geth.ipc ]; then
        return
    else
        ./eid --datadir $SCRIPT_PATH/eid/data --nousb $*
    fi
}

eid_jsonrpc()
{
    if [ "$1" == "" ]; then
        return
    fi

    if [[ $1 =~ ^[_3a-zA-Z]+$ ]] && [ "$2" == "" ]; then
        local DATA="{\"method\":\"$1\",\"id\":0}"
    else
        local DATA=$1
    fi

    curl -s -H 'Content-Type:application/json' -X POST --data $DATA \
        http://127.0.0.1:20646 | jq .
}

eid_status()
{
    local EID_VER=$(eid_ver)

    local EID_DISK_USAGE=$(disk_usage $SCRIPT_PATH/eid)

    if [ -f ~/.config/elastos/eid.txt ]; then
        cd $SCRIPT_PATH/eid
        local EID_KEYSTORE=$(./eid --datadir "$SCRIPT_PATH/eid/data/" \
            --nousb --verbosity 0 account list | sed -n '1 s/.*keystore:\/\///p')
        if [ $EID_KEYSTORE ] && [ -f $EID_KEYSTORE ]; then
            local EID_ADDRESS=0x$(cat $EID_KEYSTORE | jq -r .address)
        else
            local EID_ADDRESS=N/A
        fi
    else
        local EID_ADDRESS=N/A
    fi

    local EID_MINER_ADDRESS=$(cat $SCRIPT_PATH/eid/data/miner_address.txt 2>/dev/null)
    if [ "$EID_MINER_ADDRESS" == "" ]; then
        local EID_MINER_ADDRESS=$EID_ADDRESS
    fi

    local PID=$(pgrep -f '^\./eid .*--rpc ')
    if [ "$PID" == "" ]; then
        status_head $EID_VER  Stopped
        status_info "Disk"    "$EID_DISK_USAGE"
        status_info "Address" "$EID_ADDRESS"
        echo
        return
    fi

    local EID_RAM=$(mem_usage $PID)
    local EID_UPTIME=$(run_time $PID)
    local EID_NUM_TCPS=$(num_tcps $PID)
    local EID_TCP_LISTEN=$(list_tcp $PID)
    local EID_UDP_LISTEN=$(list_udp $PID)
    local EID_NUM_FILES=$(num_files $PID)

    local EID_NUM_PEERS=$(eid_jsonrpc \
        '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' \
        | jq -r '.result')
    EID_NUM_PEERS=$(($EID_NUM_PEERS))
    if [[ ! "$EID_NUM_PEERS" =~ ^[0-9]+$ ]]; then
        EID_NUM_PEERS=0
    fi
    local EID_HEIGHT=$(eid_jsonrpc \
        '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
        | jq -r '.result')
    EID_HEIGHT=$(($EID_HEIGHT))
    if [[ ! "$EID_HEIGHT" =~ ^[0-9]+$ ]]; then
        EID_HEIGHT=N/A
    fi

    local EID_BALANCE=$(eid_client \
        attach --exec "web3.fromWei(eth.getBalance('$EID_ADDRESS'),'ether')")
    if [ "$EID_BALANCE" == "" ]; then
        EID_BALANCE=N/A
    elif [[ $EID_BALANCE =~ [^.0-9e-] ]]; then
        EID_BALANCE=N/A
    fi

    status_head $EID_VER Running
    status_info "Disk"      "$EID_DISK_USAGE"
    status_info "Address"   "$EID_ADDRESS"
    status_info "Balance"   "$EID_BALANCE"
    status_info "Miner"     "$EID_MINER_ADDRESS"
    status_info "PID"       "$PID"
    status_info "RAM"       "$EID_RAM"
    status_info "Uptime"    "$EID_UPTIME"
    status_info "#Files"    "$EID_NUM_FILES"
    status_info "TCP Ports" "$EID_TCP_LISTEN"
    status_info "#TCP"      "$EID_NUM_TCPS"
    status_info "UDP Ports" "$EID_UDP_LISTEN"
    status_info "#Peers"    "$EID_NUM_PEERS"
    status_info "Height"    "$EID_HEIGHT"
    echo
}

eid_compress_log()
{
    compress_log $SCRIPT_PATH/eid/data/geth/logs/dpos
    compress_log $SCRIPT_PATH/eid/data/logs-spv
    compress_log $SCRIPT_PATH/eid/logs
}

eid_remove_log()
{
    remove_log $SCRIPT_PATH/eid/data/geth/logs/dpos
    remove_log $SCRIPT_PATH/eid/data/logs-spv
    remove_log $SCRIPT_PATH/eid/logs
}

eid_update()
{
    unset OPTIND
    while getopts "ny" OPTION; do
        case $OPTION in
            n)
                local NO_START_AFTER_UPDATE=1
                ;;
            y)
                local YES_TO_ALL=1
                ;;
        esac
    done

    chain_prepare_stage eid eid
    if [ "$?" != "0" ]; then
        return
    fi

    local PATH_STAGE=$SCRIPT_PATH/.node-upload/eid
    local DIR_DEPLOY=$SCRIPT_PATH/eid

    local PID=$(pgrep -f '^\./eid .*--rpc ')
    if [ $PID ]; then
        eid_stop
    fi

    mkdir -p $DIR_DEPLOY
    cp -v $PATH_STAGE/eid $DIR_DEPLOY/

    if [ $PID ] && [ "$NO_START_AFTER_UPDATE" == "" ]; then
        eid_start
    fi
}

eid_init()
{
    if [ $(mem_free) -lt 512 ]; then
        echo_error "free memory not enough"
        return
    fi

    local EID_KEYSTORE=
    local EID_KEYSTORE_PASS_FILE=~/.config/elastos/eid.txt

    if [ ! -f ${SCRIPT_PATH}/eid/eid ]; then
        eid_update -y
    fi

    if [ -f $SCRIPT_PATH/eid/.init ]; then
        echo_error "eid has already been initialized"
        return
    fi

    cd ${SCRIPT_PATH}/eid
    local EID_NUM_ACCOUNTS=$(./eid --datadir "$SCRIPT_PATH/eid/data/" \
        --nousb --verbosity 0 account list | wc -l)
    if [ $EID_NUM_ACCOUNTS -ge 1 ]; then
        echo_error "eid keystore file exist"
        return
    fi

    if [ -f "$EID_KEYSTORE_PASS_FILE" ]; then
        echo_error "$EID_KEYSTORE_PASS_FILE exist"
        return
    fi

    echo "Creating eid keystore..."
    gen_pass
    if [ "$KEYSTORE_PASS" == "" ]; then
        echo_error "empty password"
        exit
    fi

    echo "Saving eid keystore password..."
    mkdir -p $(dirname $EID_KEYSTORE_PASS_FILE)
    chmod 700 $(dirname $EID_KEYSTORE_PASS_FILE)
    echo $KEYSTORE_PASS > $EID_KEYSTORE_PASS_FILE
    chmod 600 $EID_KEYSTORE_PASS_FILE

    cd ${SCRIPT_PATH}/eid
    ./eid --datadir "$SCRIPT_PATH/eid/data/" --verbosity 0 account new \
        --password "$EID_KEYSTORE_PASS_FILE" >/dev/null
    if [ "$?" != "0" ]; then
        echo_error "failed to create eid keystore"
        return
    fi

    echo "Checking eid keystore..."
    local EID_KEYSTORE=$(./eid --datadir "$SCRIPT_PATH/eid/data/" \
        --nousb --verbosity 0 account list | sed 's/.*keystore:\/\///')
    chmod 600 $EID_KEYSTORE

    local EID_MINER_ADDRESS_FILE=$SCRIPT_PATH/eid/data/miner_address.txt
    echo "You can input an alternative eid reward address. (ENTER to skip)"
    local EID_MINER_ADDRESS=
    read -p '? Miner Address: ' EID_MINER_ADDRESS
    if [ "$EID_MINER_ADDRESS" != "" ]; then
        mkdir -p $SCRIPT_PATH/eid/data
        echo $EID_MINER_ADDRESS | tee $EID_MINER_ADDRESS_FILE
        chmod 600 $EID_MINER_ADDRESS_FILE
    fi

    echo_info "eid keystore file: $EID_KEYSTORE"
    echo_info "eid keystore password file: $EID_KEYSTORE_PASS_FILE"
    if [ -f $EID_MINER_ADDRESS_FILE ]; then
        echo_info "eid miner address file: $EID_MINER_ADDRESS_FILE"
    fi

    touch ${SCRIPT_PATH}/eid/.init
    echo_ok "eid initialized"
    echo
}

eid_send()
{
    if [ "$3" == "" ]; then
        echo "Usage: $SCRIPT_NAME eid send FROM TO AMOUNT [FEE]"
        return
    fi

    local EID_ADDR_FROM=$1
    local EID_ADDR_TO=$2
    local EID_AMOUNT=$3
    local EID_FEE=$4

    if [ "$EID_FEE" == "" ]; then
        local EID_FEE=21000
    fi
    local EID_GAS_PRICE=$(eid_client attach --exec "eth.gasPrice")
    local EID_FEE_WEI=$(echo $EID_FEE*$EID_GAS_PRICE | bc)

    if [ "$EID_AMOUNT" == "All" ]; then
        local EID_AMOUNT_WEI=$(eid_client attach --exec "eth.getBalance('$EID_ADDR_FROM')")
        local EID_AMOUNT_WEI=$(echo "$EID_AMOUNT_WEI-$EID_FEE_WEI" | bc)
    else
        local EID_AMOUNT_WEI=$(echo "$EID_AMOUNT*10^18" | bc)
    fi

    if [ "$IS_DEBUG" ]; then
        echo "EID_ADDR_FROM:  $EID_ADDR_FROM"
        echo "EID_ADDR_TO:    $EID_ADDR_TO"
        echo "EID_AMOUNT:     $EID_AMOUNT"
        echo "EID_AMOUNT_WEI: $EID_AMOUNT_WEI"
        echo "EID_FEE:        $EID_FEE"
        echo "EID_GAS_PRICE:  $EID_GAS_PRICE"
        echo "EID_FEE_WEI:    $EID_FEE_WEI"
    fi

    eid_client attach --exec "eth.sendTransaction({from:'$EID_ADDR_FROM',to:'$EID_ADDR_TO',value:$EID_AMOUNT_WEI,gas:$EID_FEE,gasPrice:$EID_GAS_PRICE})"
}

#
# eid-oracle
#
eid-oracle_usage()
{
    echo "Usage: $SCRIPT_NAME $CHAIN_NAME COMMAND [OPTIONS]"
    echo "Manage $CHAIN_NAME"
    echo
    echo "Available Commands:"
    echo
    echo "  init            Install and configure $CHAIN_NAME_U"
    echo "  update          Update $CHAIN_NAME_U"
    echo
    echo "  start           Start $CHAIN_NAME_U daemon"
    echo "  stop            Stop $CHAIN_NAME_U daemon"
    echo "  status          Print $CHAIN_NAME_U daemon status"
    echo
    echo "  compress_log    Compress $CHAIN_NAME_U daemon log files"
    echo "  remove_log      Remove $CHAIN_NAME_U daemon log files"
    echo
}

eid-oracle_start()
{
    if [ ! -f $SCRIPT_PATH/eid-oracle/crosschain_eid.js ]; then
        echo_error "$SCRIPT_PATH/eid-oracle/crosschain_eid.js is not exist"
        return
    fi

    local PID=$(pgrep -fx 'node crosschain_eid.js')
    if [ "$PID" != "" ]; then
        eid-oracle_status
        return
    fi

    echo "Starting eid-oracle..."
    cd $SCRIPT_PATH/eid-oracle
    mkdir -p $SCRIPT_PATH/eid-oracle/logs

    if [ "$CHAIN_TYPE" == "mainnet" ]; then
        export env=mainnet
    elif [ "$CHAIN_TYPE" == "testnet" ]; then
        export env=testnet
    else
        echo_error "do not support $CHAIN_TYPE"
        return
    fi

    echo "env: $env"
    nodejs_setenv
    nohup $SHELL -c "node crosschain_eid.js \
        2>$SCRIPT_PATH/eid-oracle/logs/eid-oracle_err.log \
        | rotatelogs $SCRIPT_PATH/eid-oracle/logs/eid-oracle_out-%Y-%m-%d-%H_%M_%S.log 20M" &

    sleep 1
    eid-oracle_status
}

eid-oracle_stop()
{
    local PID=$(pgrep -fx 'node crosschain_eid.js')
    if [ "$PID" != "" ]; then
        echo "Stopping eid-oracle..."
        kill $PID
        while ps -p $PID 1>/dev/null; do
            echo -n .
            sleep 1
        done
        echo
    fi
    eid-oracle_status
}

eid-oracle_installed()
{
    if [ -f $SCRIPT_PATH/eid-oracle/crosschain_eid.js ]; then
        true
    else
        false
    fi
}

eid-oracle_ver()
{
    if [ -f $SCRIPT_PATH/eid-oracle/crosschain_eid.js ]; then
        echo "eid-oracle $(cat $SCRIPT_PATH/eid-oracle/*.js | shasum | cut -c 1-7)"
    else
        echo "eid-oracle N/A"
    fi
}

eid-oracle_status()
{
    local EID_ORACLE_VER=$(eid-oracle_ver)

    local EID_ORACLE_DISK_USAGE=$(disk_usage $SCRIPT_PATH/eid-oracle)

    local PID=$(pgrep -fx 'node crosschain_eid.js')
    if [ "$PID" == "" ]; then
        status_head $EID_ORACLE_VER Stopped
        status_info "Disk" "$EID_ORACLE_DISK_USAGE"
        echo
        return
    fi

    local EID_ORACLE_RAM=$(mem_usage $PID)
    local EID_ORACLE_UPTIME=$(run_time $PID)
    local EID_ORACLE_TCP_LISTEN=$(list_tcp $PID)
    local EID_ORACLE_NUM_TCPS=$(num_tcps $PID)
    local EID_ORACLE_NUM_FILES=$(num_files $PID)

    status_head $EID_ORACLE_VER Running
    status_info "Disk"      "$EID_ORACLE_DISK_USAGE"
    status_info "PID"       "$PID"
    status_info "RAM"       "$EID_ORACLE_RAM"
    status_info "Uptime"    "$EID_ORACLE_UPTIME"
    status_info "#Files"    "$EID_ORACLE_NUM_FILES"
    status_info "TCP Ports" "$EID_ORACLE_TCP_LISTEN"
    status_info "#TCP"      "$EID_ORACLE_NUM_TCPS"
    echo
}

eid-oracle_compress_log()
{
    compress_log $SCRIPT_PATH/eid-oracle/logs/eid-oracle_out-\*.log
}

eid-oracle_remove_log()
{
    remove_log $SCRIPT_PATH/eid-oracle/logs/eid-oracle_out-\*.log
}

eid-oracle_update()
{
    unset OPTIND
    while getopts "ny" OPTION; do
        case $OPTION in
            n)
                local NO_START_AFTER_UPDATE=1
                ;;
            y)
                local YES_TO_ALL=1
                ;;
        esac
    done

    chain_prepare_stage eid-oracle '*.js'
    if [ "$?" != "0" ]; then
        return
    fi

    local PATH_STAGE=$SCRIPT_PATH/.node-upload/eid-oracle
    local DIR_DEPLOY=$SCRIPT_PATH/eid-oracle

    local PID=$(pgrep -fx 'node crosschain_eid.js')
    if [ $PID ]; then
        eid-oracle_stop
    fi

    mkdir -p $DIR_DEPLOY
    cp -v $PATH_STAGE/*.js $DIR_DEPLOY/

    if [ $PID ] && [ "$NO_START_AFTER_UPDATE" == "" ]; then
        eid-oracle_start
    fi
}

eid-oracle_init()
{
    if [ ! -f ${SCRIPT_PATH}/eid/.init ]; then
        echo_error "eid not initialized"
        return
    fi

    if [ -f $SCRIPT_PATH/eid-oracle/.init ]; then
        echo_error "eid-oracle has already been initialized"
        return
    fi

    check_env_oracle

    if [ ! -f $SCRIPT_PATH/eid-oracle/crosschain_eid.js ]; then
        eid-oracle_update -y
    fi

    nodejs_setenv

    mkdir -p $SCRIPT_PATH/eid-oracle
    cd $SCRIPT_PATH/eid-oracle
    npm install web3@1.7.3 express@4.18.1

    touch ${SCRIPT_PATH}/eid-oracle/.init
    echo_ok "eid-oracle initialized"
    echo
}

#
# arbiter
#
arbiter_usage()
{
    echo "Usage: $SCRIPT_NAME $CHAIN_NAME COMMAND [OPTIONS]"
    echo "Manage $CHAIN_NAME"
    echo
    echo "Available Commands:"
    echo
    echo "  init            Install and configure $CHAIN_NAME_U"
    echo "  update          Update $CHAIN_NAME_U"
    echo
    echo "  start           Start $CHAIN_NAME_U daemon"
    echo "  stop            Stop $CHAIN_NAME_U daemon"
    echo "  status          Print $CHAIN_NAME_U daemon status"
    echo
    echo "  compress_log    Compress $CHAIN_NAME_U daemon log files"
    echo "  remove_log      Remove $CHAIN_NAME_U daemon log files"
    echo
    echo "  jsonrpc         Call $CHAIN_NAME_U JSON-RPC API"
    echo
}

arbiter_start()
{
    if [ ! -f $SCRIPT_PATH/arbiter/arbiter ]; then
        echo_error "$SCRIPT_PATH/arbiter/arbiter is not exist"
        return
    fi

    local PID=$(pgrep -x arbiter)
    if [ "$PID" != "" ]; then
        arbiter_status
        return
    fi

    echo "Starting arbiter..."
    cd $SCRIPT_PATH/arbiter

    until pgrep -x arbiter 1>/dev/null; do
        if [ -f ~/.config/elastos/ela.txt ]; then
            cat ~/.config/elastos/ela.txt | nohup ./arbiter 1>/dev/null 2>output &
        else
            nohup ./arbiter 1>/dev/null 2>output &
        fi
        echo "Waiting for ela, esc-oracle, eid-oracle, eco-oracle to start..."
        sleep 5
    done

    arbiter_status
}

arbiter_stop()
{
    local PID=$(pgrep -x arbiter)
    if [ "$PID" != "" ]; then
        echo "Stopping arbiter..."
        kill $PID
        while ps -p $PID 1>/dev/null; do
            echo -n .
            sleep 1
        done
        echo
    fi
    sync
    arbiter_status
}

arbiter_installed()
{
    if [ -f $SCRIPT_PATH/arbiter/arbiter ]; then
        true
    else
        false
    fi
}

arbiter_ver()
{
    if [ -f $SCRIPT_PATH/arbiter/arbiter ]; then
        echo "arbiter $($SCRIPT_PATH/arbiter/arbiter -v 2>&1 | sed 's/.* //')"
    else
        echo "arbiter N/A"
    fi
}

arbiter_jsonrpc()
{
    if [ "$1" == "" ]; then
        return
    fi

    local ARBITER_RPC_USER=$(cat $SCRIPT_PATH/arbiter/config.json | \
        jq -r '.Configuration.RpcConfiguration.User')
    local ARBITER_RPC_PASS=$(cat $SCRIPT_PATH/arbiter/config.json | \
        jq -r '.Configuration.RpcConfiguration.Pass')

    if [ "$CHAIN_TYPE" == "mainnet" ]; then
        local ARBITER_RPC_PORT=20536
    elif [ "$CHAIN_TYPE" == "testnet" ]; then
        local ARBITER_RPC_PORT=21536
    else
        echo_error "do not support $CHAIN_TYPE"
        return
    fi

    if [[ $1 =~ ^[a-z]+$ ]] && [ "$2" == "" ]; then
        local DATA={\"method\":\"$1\"}
    else
        local DATA=$1
    fi

    curl -s -H 'Content-Type:application/json' \
        -X POST --data $DATA \
        -u $ARBITER_RPC_USER:$ARBITER_RPC_PASS \
        http://127.0.0.1:$ARBITER_RPC_PORT | jq .
}

arbiter_status()
{
    local ARBITER_VER=$(arbiter_ver)

    local ARBITER_DISK_USAGE=$(disk_usage $SCRIPT_PATH/arbiter)

    local PID=$(pgrep -x arbiter)
    if [ "$PID" == "" ]; then
        status_head $ARBITER_VER Stopped
        status_info "Disk" "$ARBITER_DISK_USAGE"
        echo
        return
    fi

    local ARBITER_RAM=$(mem_usage $PID)
    local ARBITER_UPTIME=$(run_time $PID)
    local ARBITER_NUM_TCPS=$(num_tcps $PID)
    local ARBITER_TCP_LISTEN=$(list_tcp $PID)
    local ARBITER_NUM_FILES=$(num_files $PID)

    local ARBITER_SPV_HEIGHT=$(arbiter_jsonrpc '{"method":"getspvheight"}' | jq -r '.result')
    if [[ ! "$ARBITER_SPV_HEIGHT" =~ ^[0-9]+$ ]]; then
        ARBITER_SPV_HEIGHT=N/A
    fi

    if [ "$CHAIN_TYPE" == "mainnet" ]; then
        local ESC_GENESIS=6afc2eb01956dfe192dc4cd065efdf6c3c80448776ca367a7246d279e228ff0a
    elif [ "$CHAIN_TYPE" == "testnet" ]; then
        local ESC_GENESIS=698e5ec133064dabb7c42eb4b2bdfa21e7b7c2326b0b719d5ab7f452ae8f5ee4
    else
        echo_error "do not support $CHAIN_TYPE"
        return
    fi
    local ARBITER_ESC_HEIGHT=$(arbiter_jsonrpc \
        "{\"method\":\"getsidechainblockheight\",\"params\":{\"hash\":\"$ESC_GENESIS\"}}" \
        | jq -r '.result')
    if [[ ! "$ARBITER_ESC_HEIGHT" =~ ^[0-9]+$ ]]; then
        ARBITER_ESC_HEIGHT=N/A
    fi

    if [ "$CHAIN_TYPE" == "mainnet" ]; then
        local EID_GENESIS=7d0702054ad68913eff9137dfa0b0b6ff701d55062359deacad14859561f5567
    elif [ "$CHAIN_TYPE" == "testnet" ]; then
        local EID_GENESIS=3d0f9da9320556f6d58129419e041de28cf515eedc6b59f8dae49df98e3f943c
    else
        echo_error "do not support $CHAIN_TYPE"
        return
    fi
    local ARBITER_EID_HEIGHT=$(arbiter_jsonrpc \
        "{\"method\":\"getsidechainblockheight\",\"params\":{\"hash\":\"$EID_GENESIS\"}}" \
        | jq -r '.result')
    if [[ ! "$ARBITER_EID_HEIGHT" =~ ^[0-9]+$ ]]; then
        ARBITER_EID_HEIGHT=N/A
    fi

    # linda 添加ECO
    if [ "$CHAIN_TYPE" == "mainnet" ]; then
        local ECO_GENESIS=02820c5adc8ee4fb77aad842ac05d95ed8b1041d80c03ba79f8f11c4af60d87c
    elif [ "$CHAIN_TYPE" == "testnet" ]; then
        local ECO_GENESIS=3043bcc03c90a37a292a4357ee972bc392b143e75e1b79205e113688e3bd071b
    else
        echo_error "do not support $CHAIN_TYPE"
        return
    fi
    local ARBITER_ECO_HEIGHT=$(arbiter_jsonrpc \
        "{\"method\":\"getsidechainblockheight\",\"params\":{\"hash\":\"$ECO_GENESIS\"}}" \
        | jq -r '.result')
    if [[ ! "$ARBITER_ECO_HEIGHT" =~ ^[0-9]+$ ]]; then
        ARBITER_ECO_HEIGHT=N/A
    fi
    # linda 添加

    # linda 添加PGP
    :'
    if [ "$CHAIN_TYPE" == "mainnet" ]; then
        local PGP_GENESIS=00b7957fbc9fa62e86d6e664299bebc9a939f108fd015f8de07ce33f4136175e
    elif [ "$CHAIN_TYPE" == "testnet" ]; then
        local PGP_GENESIS=0c2785b9c5bee92aaaa3d8e5a7a579347a9091c6c8c19b7cba7fac69519c58a1
    else
        echo_error "do not support $CHAIN_TYPE"
        return
    fi
    local ARBITER_PGP_HEIGHT=$(arbiter_jsonrpc \
        "{\"method\":\"getsidechainblockheight\",\"params\":{\"hash\":\"$PGP_GENESIS\"}}" \
        | jq -r '.result')
    if [[ ! "$ARBITER_PGP_HEIGHT" =~ ^[0-9]+$ ]]; then
        ARBITER_PGP_HEIGHT=N/A
    fi
    '
    # linda 添加

    # linda 添加PG
    if [ "$CHAIN_TYPE" == "mainnet" ]; then
        local PG_GENESIS=aab1ef4455d93b45f440a8aaed032f2c38da03a06a0843d6f9b059dbfdd2a5b5
    elif [ "$CHAIN_TYPE" == "testnet" ]; then
        local PG_GENESIS=aab1ef4455d93b45f440a8aaed032f2c38da03a06a0843d6f9b059dbfdd2a5b5
    else
        echo_error "do not support $CHAIN_TYPE"
        return
    fi
    local ARBITER_PG_HEIGHT=$(arbiter_jsonrpc \
        "{\"method\":\"getsidechainblockheight\",\"params\":{\"hash\":\"$PG_GENESIS\"}}" \
        | jq -r '.result')
    if [[ ! "$ARBITER_PG_HEIGHT" =~ ^[0-9]+$ ]]; then
        ARBITER_PG_HEIGHT=N/A
    fi
    # linda 添加

    status_head $ARBITER_VER Running
    status_info "Disk"       "$ARBITER_DISK_USAGE"
    status_info "PID"        "$PID"
    status_info "RAM"        "$ARBITER_RAM"
    status_info "Uptime"     "$ARBITER_UPTIME"
    status_info "#Files"     "$ARBITER_NUM_FILES"
    status_info "TCP Ports"  "$ARBITER_TCP_LISTEN"
    status_info "#TCP"       "$ARBITER_NUM_TCPS"
    status_info "SPV Height" "$ARBITER_SPV_HEIGHT"
    status_info "ESC Height" "$ARBITER_ESC_HEIGHT"
    status_info "EID Height" "$ARBITER_EID_HEIGHT"
    # linda 添加
    status_info "ECO Height" "$ARBITER_ECO_HEIGHT"
    # linda 添加
    #status_info "PGP Height" "$ARBITER_PGP_HEIGHT"
    # linda 添加
    status_info "PG Height" "$ARBITER_PG_HEIGHT"
    echo
}

arbiter_compress_log()
{
    compress_log $SCRIPT_PATH/arbiter/elastos_arbiter/logs/arbiter
    compress_log $SCRIPT_PATH/arbiter/elastos_arbiter/logs/spv
}

arbiter_remove_log()
{
    remove_log $SCRIPT_PATH/arbiter/elastos_arbiter/logs/arbiter
    remove_log $SCRIPT_PATH/arbiter/elastos_arbiter/logs/spv
}

arbiter_update()
{
    unset OPTIND
    while getopts "ny" OPTION; do
        case $OPTION in
            n)
                local NO_START_AFTER_UPDATE=1
                ;;
            y)
                local YES_TO_ALL=1
                ;;
        esac
    done

    chain_prepare_stage arbiter arbiter
    if [ "$?" != "0" ]; then
        return
    fi

    local PATH_STAGE=$SCRIPT_PATH/.node-upload/arbiter
    local DIR_DEPLOY=$SCRIPT_PATH/arbiter

    local PID=$(pgrep -x arbiter)
    if [ $PID ]; then
        arbiter_stop
    fi

    mkdir -p $DIR_DEPLOY
    cp -v $PATH_STAGE/arbiter $DIR_DEPLOY/

    if [ $PID ] && [ "$NO_START_AFTER_UPDATE" == "" ]; then
        arbiter_start
    fi
}

arbiter_modify_configfile()
{

  local ARBITER_CONFIG=${SCRIPT_PATH}/arbiter/config.json
  local ARBITER_PGP_CONFIG=${SCRIPT_PATH}/arbiter/pgp_config.json
  local ARBITER_PG_CONFIG=${SCRIPT_PATH}/arbiter/pg_config.json

  if [ ! -f $ARBITER_CONFIG ]; then
        echo_error "$ARBITER_CONFIG not exists"
        return
  fi

  if grep -qi "20672" "$ARBITER_CONFIG"; then
        echo "config file have PG sidechain configuration"
        return
  fi
  
  echo "stop arbiter node"
  local PID=$(pgrep -x arbiter)
  if [ $PID ]; then
        arbiter_stop
  fi

  echo "backup arbiter config file..."
  cp -v ${SCRIPT_PATH}/arbiter/config.json ${SCRIPT_PATH}/arbiter/config_backup_add_pg_before_2025_11_2.json
  echo "modify arbiter config file..."
  if [ "$CHAIN_TYPE" == "testnet" ]; then
    echo "add testnet pg config"
    jq '.Configuration.SideNodeList += [{
        "Rpc": {
          "IpAddress": "127.0.0.1",
          "HttpJsonPort": 20672
        },
        "ExchangeRate": 1,
        "SyncStartHeight":0,
        "GenesisBlock": "aab1ef4455d93b45f440a8aaed032f2c38da03a06a0843d6f9b059dbfdd2a5b5",
        "PowChain": false,
        "Name": "PG",
        "SupportQuickRecharge": false,
        "SupportInvalidDeposit": true,
        "SupportInvalidWithdraw": true,
        "SupportNFT": false
    }]' $ARBITER_CONFIG > $ARBITER_PG_CONFIG && mv $ARBITER_PG_CONFIG ${SCRIPT_PATH}/arbiter/config.json
  else
    echo "add mainnet pg config"
    jq '.Configuration.SideNodeList += [{
        "Name": "PG",
        "Rpc": {
          "IpAddress": "127.0.0.1",
          "HttpJsonPort": 20672
        },
        "SyncStartHeight":0,
        "ExchangeRate": 1,
        "GenesisBlock": "aab1ef4455d93b45f440a8aaed032f2c38da03a06a0843d6f9b059dbfdd2a5b5",
        "SupportQuickRecharge": false,
        "SupportInvalidDeposit": true,
        "SupportInvalidWithdraw": true,
        "SupportNFT": false,
        "PowChain": false
    }]' $ARBITER_CONFIG > $ARBITER_PG_CONFIG && mv $ARBITER_PG_CONFIG ${SCRIPT_PATH}/arbiter/config.json
  fi
  echo_ok "arbiter add PG config completedly"
}

arbiter_remove_sidechain_config()
{

  local ARBITER_CONFIG=${SCRIPT_PATH}/arbiter/config.json
  local ARBITER_PGP_CONFIG=${SCRIPT_PATH}/arbiter/pgp_config.json

  if [ ! -f $ARBITER_CONFIG ]; then
        echo_error "$ARBITER_CONFIG not exists"
        return
  fi

  if ! grep -qi "20662" "$ARBITER_CONFIG"; then
      echo "config file have not PGP sidechain configuration"
      return
  fi

  echo "stop arbiter node"

  local PID=$(pgrep -x arbiter)
  if [ $PID ]; then
        arbiter_stop
  fi

  echo "backup arbiter config file..."
  cp -v ${SCRIPT_PATH}/arbiter/config.json ${SCRIPT_PATH}/arbiter/config_backup_remove_pgp_before_2025_11_11.json

  echo "modify arbiter config file..."

  if [ "$CHAIN_TYPE" == "testnet" ]; then
      echo "testnet do nothing"
  else
      echo "Remove mainnet pgp config"
      jq 'del(.Configuration.SideNodeList[] | select(.Name == "PGP"))' $ARBITER_CONFIG > $ARBITER_PGP_CONFIG && mv $ARBITER_PGP_CONFIG ${SCRIPT_PATH}/arbiter/config.json
  fi

  echo_ok "arbiter Remove PGP config completedly"
}



arbiter_init()
{
    if [ ! -f $SCRIPT_PATH/ela/.init ]; then
        echo_error "ela not initialized"
        return
    fi
    if [ ! -f $SCRIPT_PATH/esc-oracle/.init ]; then
        echo_error "esc-oracle not initialized"
        return
    fi
    if [ ! -f $SCRIPT_PATH/eid-oracle/.init ]; then
        echo_error "eid-oracle not initialized"
        return
    fi
    #linda添加ECO判断
     if [ ! -f $SCRIPT_PATH/eco-oracle/.init ]; then
        echo_error "eco-oracle not initialized"
        return
    fi
    #linda添加
    #linda添加PGP判断
     if [ ! -f $SCRIPT_PATH/pgp-oracle/.init ]; then
        echo_error "pgp-oracle not initialized"
        return
    fi
    #linda添加
    #linda添加PG判断
    if [ ! -f $SCRIPT_PATH/pg-oracle/.init ]; then
        echo_error "pg-oracle not initialized"
        return
    fi
    #linda添加


    local ELA_CONFIG=${SCRIPT_PATH}/ela/config.json
    local ARBITER_CONFIG=${SCRIPT_PATH}/arbiter/config.json

    if [ ! -f ${SCRIPT_PATH}/arbiter/arbiter ]; then
        arbiter_update -y
    fi

    if [ -f $SCRIPT_PATH/arbiter/.init ]; then
        echo_error "arbiter has already been initialized"
        return
    fi

    if [ -f $ARBITER_CONFIG ]; then
        echo_error "$ARBITER_CONFIG exists"
        return
    fi

    echo "Creating arbiter config file..."
    if [ "$CHAIN_TYPE" == "testnet" ]; then
        cat >$ARBITER_CONFIG <<EOF
{
  "Configuration": {
    "ActiveNet": "testnet",
    "MainNode": {
      "Rpc": {
        "IpAddress": "127.0.0.1",
        "HttpJsonPort": 21336,
        "User": "",
        "Pass": ""
      },
      "Magic": 2050102
    },
    "SideNodeList": [
      {
        "Name": "ESC",
        "Rpc": {
          "IpAddress": "127.0.0.1",
          "HttpJsonPort": 20632
        },
        "SyncStartHeight": 17058000,
        "ExchangeRate": 1,
        "GenesisBlock": "698e5ec133064dabb7c42eb4b2bdfa21e7b7c2326b0b719d5ab7f452ae8f5ee4",
        "SupportQuickRecharge": true,
        "SupportInvalidDeposit": true,
        "SupportInvalidWithdraw": true,
        "SupportNFT": true,
        "PowChain": false
      },
      {
        "Name": "EID",
        "Rpc": {
          "IpAddress": "127.0.0.1",
          "HttpJsonPort": 20642
        },
        "SyncStartHeight": 9230000,
        "ExchangeRate": 1,
        "GenesisBlock": "3d0f9da9320556f6d58129419e041de28cf515eedc6b59f8dae49df98e3f943c",
        "SupportQuickRecharge": true,
        "SupportInvalidDeposit": true,
        "SupportInvalidWithdraw": true,
        "PowChain": false
      },
      {
        "Name": "ECO",
        "Rpc": {
          "IpAddress": "127.0.0.1",
          "HttpJsonPort": 20652
        },
        "SyncStartHeight": 0,
        "ExchangeRate": 1,
        "GenesisBlock": "3043bcc03c90a37a292a4357ee972bc392b143e75e1b79205e113688e3bd071b",
        "SupportQuickRecharge": true,
        "SupportInvalidDeposit": true,
        "SupportInvalidWithdraw": true,
        "SupportNFT": false,
        "PowChain": false
      },
      {
        "Name": "PGP",
        "Rpc": {
          "IpAddress": "127.0.0.1",
          "HttpJsonPort": 20662
        },
        "SyncStartHeight": 0,
        "ExchangeRate": 1,
        "GenesisBlock": "0c2785b9c5bee92aaaa3d8e5a7a579347a9091c6c8c19b7cba7fac69519c58a1",
        "SupportQuickRecharge": false,
        "SupportInvalidDeposit": true,
        "SupportInvalidWithdraw": true,
        "SupportNFT": false,
        "PowChain": false
      },
      {
        "Name": "PG",
        "Rpc": {
          "IpAddress": "127.0.0.1",
          "HttpJsonPort": 20672
        },
        "SyncStartHeight": 0,
        "ExchangeRate": 1,
        "GenesisBlock": "aab1ef4455d93b45f440a8aaed032f2c38da03a06a0843d6f9b059dbfdd2a5b5",
        "SupportQuickRecharge": false,
        "SupportInvalidDeposit": true,
        "SupportInvalidWithdraw": true,
        "SupportNFT": false,
        "PowChain": false
      }
    ],
    "RpcConfiguration": {
      "User": "",
      "Pass": "",
      "WhiteIPList": [
        "127.0.0.1"
      ]
    }
  }
}
EOF
    else
        cat >$ARBITER_CONFIG <<EOF
{
  "Configuration": {
    "MainNode": {
      "Rpc": {
        "IpAddress": "127.0.0.1",
        "HttpJsonPort": 20336,
        "User": "",
        "Pass": ""
      }
    },
    "SideNodeList": [
      {
        "Name": "ESC",
        "Rpc": {
          "IpAddress": "127.0.0.1",
          "HttpJsonPort": 20632
        },
        "SyncStartHeight": 17886000,
        "ExchangeRate": 1,
        "GenesisBlock": "6afc2eb01956dfe192dc4cd065efdf6c3c80448776ca367a7246d279e228ff0a",
        "SupportQuickRecharge": true,
        "SupportInvalidDeposit": true,
        "SupportInvalidWithdraw": true,
        "SupportNFT": true,
        "PowChain": false
      },
      {
        "Name": "EID",
        "Rpc": {
          "IpAddress": "127.0.0.1",
          "HttpJsonPort": 20642
        },
        "SyncStartHeight": 9611000,
        "ExchangeRate": 1,
        "GenesisBlock": "7d0702054ad68913eff9137dfa0b0b6ff701d55062359deacad14859561f5567",
        "SupportQuickRecharge": true,
        "SupportInvalidDeposit": true,
        "SupportInvalidWithdraw": true,
        "PowChain": false
      },
      {
        "Name": "ECO",
        "Rpc": {
          "IpAddress": "127.0.0.1",
          "HttpJsonPort": 20652
        },
        "SyncStartHeight": 0,
        "ExchangeRate": 1,
        "GenesisBlock": "02820c5adc8ee4fb77aad842ac05d95ed8b1041d80c03ba79f8f11c4af60d87c",
        "SupportQuickRecharge": true,
        "SupportInvalidDeposit": true,
        "SupportInvalidWithdraw": true,
        "SupportNFT": false,
        "PowChain": false
      },
      {
        "Name": "PGP",
        "Rpc": {
          "IpAddress": "127.0.0.1",
          "HttpJsonPort": 20662
        },
        "SyncStartHeight": 0,
        "ExchangeRate": 1,
        "GenesisBlock": "00b7957fbc9fa62e86d6e664299bebc9a939f108fd015f8de07ce33f4136175e",
        "SupportQuickRecharge": false,
        "SupportInvalidDeposit": true,
        "SupportInvalidWithdraw": true,
        "SupportNFT": false,
        "PowChain": false
      },
      {
        "Name": "PG",
        "Rpc": {
          "IpAddress": "127.0.0.1",
          "HttpJsonPort": 20672
        },
        "SyncStartHeight": 0,
        "ExchangeRate": 1,
        "GenesisBlock": "aab1ef4455d93b45f440a8aaed032f2c38da03a06a0843d6f9b059dbfdd2a5b5",
        "SupportQuickRecharge": false,
        "SupportInvalidDeposit": true,
        "SupportInvalidWithdraw": true,
        "SupportNFT": false,
        "PowChain": false
      }
    ],
    "RpcConfiguration": {
      "User": "",
      "Pass": "",
      "WhiteIPList": [
        "127.0.0.1"
      ]
    }
  }
}
EOF
    fi

    cd ${SCRIPT_PATH}/arbiter/
    ln -s ../ela/ela-cli

    echo "Copying ela keystore..."
    cp -v ${SCRIPT_PATH}/ela/keystore.dat ${SCRIPT_PATH}/arbiter/
    #ln -s ../ela/keystore.dat
    local KEYSTORE_PASS=$(cat ~/.config/elastos/ela.txt)

    #./ela-cli wallet account -p "$KEYSTORE_PASS"

    echo "Updating arbiter config file..."

    # Arbiter Config: ELA
    local ELA_RPC_USER=$(cat $ELA_CONFIG | \
        jq -r '.Configuration.RpcConfiguration.User')
    local ELA_RPC_PASS=$(cat $ELA_CONFIG | \
        jq -r '.Configuration.RpcConfiguration.Pass')

    # Arbiter Config: Arbiter RPC
    echo "Generating random userpass for arbiter RPC interface..."
    local ARBITER_RPC_USER=$(openssl rand -base64 100 | shasum | head -c 32)
    local ARBITER_RPC_PASS=$(openssl rand -base64 100 | shasum | head -c 32)

    echo "Updating arbiter config file..."
    jq ".Configuration.MainNode.Rpc.User=\"$ELA_RPC_USER\"              | \
        .Configuration.MainNode.Rpc.Pass=\"$ELA_RPC_PASS\"              | \
        .Configuration.RpcConfiguration.User=\"$ARBITER_RPC_USER\"      | \
        .Configuration.RpcConfiguration.Pass=\"$ARBITER_RPC_PASS\"" \
        $ARBITER_CONFIG >$ARBITER_CONFIG.tmp

    if [ "$?" == "0" ]; then
        mv $ARBITER_CONFIG.tmp $ARBITER_CONFIG
    fi

    echo_info "arbiter config file: $ARBITER_CONFIG"

    touch ${SCRIPT_PATH}/arbiter/.init
    echo_ok "arbiter initialized"
    echo
}

usage()
{
    echo "Usage: $SCRIPT_NAME [CHAIN] COMMAND [OPTIONS]"
    echo "Manage Elastos Node"
    echo
    echo "Diag Info:"
    echo
    echo "  Deploy Path:    $SCRIPT_PATH"
    echo "  Script SHA1:    $SCRIPT_SHA1"
    echo "  Chains Type:    $CHAIN_TYPE"
    echo
    echo "Available Chains:"
    echo
    for i in $(grep "^[^ ]\+_ver(" $BASH_SOURCE | sed 's/(.*$//'); do
    printf "  %-16s%s\n" $(${i})
    done
    echo
}

#
# Main
#
SCRIPT_PATH=$(cd $(dirname $BASH_SOURCE); pwd)
SCRIPT_NAME=$(basename $BASH_SOURCE)
SCRIPT_SHA1=$(shasum $BASH_SOURCE | cut -c1-7)

set_env
check_env
load_config

# script commands
if [ "$1" == "" ]; then
    usage
    exit
elif [ "$1" == "set_path" ]; then
    set_path
    exit
elif [ "$1" == "set_cron" ]; then
    set_cron
    exit
elif [ "$1" == "update_script" ] || [ "$1" == "script_update" ]; then
    update_script
    exit
fi

# chain commands
if [ "$1" == "init"    ] || \
   [ "$1" == "start"   ] || \
   [ "$1" == "stop"    ] || \
   [ "$1" == "status"  ] || \
   [ "$1" == "update"  ] || [ "$1" == "upgrade" ] || \
   [ "$1" == "compress_log" ] || \
   [ "$1" == "remove_log" ]; then
    # operate on all chains
    COMMAND=$1
    # command aliases
    if [ "$COMMAND" == "upgrade" ]; then
        COMMAND=update
    fi

    all_$COMMAND
else
    # operate on a single chain

    if [ "$1" != "ela"        ] && \
       [ "$1" != "esc"        ] && \
       [ "$1" != "esc-oracle" ] && \
       [ "$1" != "eid"        ] && \
       [ "$1" != "eid-oracle" ] && \
       [ "$1" != "eco"        ] && \
       [ "$1" != "eco-oracle" ] && \
       [ "$1" != "pgp"        ] && \
       [ "$1" != "pgp-oracle" ] && \
       [ "$1" != "pg"         ] && \
       [ "$1" != "pg-oracle"  ] && \
       [ "$1" != "arbiter"    ]; then
        echo_error "do not support chain: $1"
        exit
    fi
    CHAIN_NAME=$1
    CHAIN_NAME_U=$(echo $CHAIN_NAME | tr "[:lower:]" "[:upper:]")

    if [ "$2" == "" ]; then
        # no command specified
        COMMAND=usage
    elif [ "$2" == "start"   ] || \
         [ "$2" == "stop"    ] || \
         [ "$2" == "status"  ] || \
         [ "$2" == "client"  ] || \
         [ "$2" == "jsonrpc" ] || \
         [ "$2" == "update"  ] || [ "$2" == "upgrade" ] || \
         [ "$2" == "init"    ] || \
         [ "$2" == "register_bpos"   ] || \
         [ "$2" == "activate_bpos"   ] || \
         [ "$2" == "unregister_bpos" ] || \
         [ "$2" == "vote_bpos"       ] || \
         [ "$2" == "stake_bpos"      ] || \
         [ "$2" == "unstake_bpos"    ] || \
         [ "$2" == "claim_bpos"      ] || \
         [ "$2" == "register_crc"    ] || \
         [ "$2" == "activate_crc"    ] || \
         [ "$2" == "unregister_crc"  ] || \
         [ "$2" == "send"            ] || \
         [ "$2" == "transfer"        ] || \
         [ "$2" == "compress_log"    ] || \
         [ "$2" == "modify_configfile"    ] || \
         [ "$2" == "remove_sidechain_config"    ] || \
         [ "$2" == "remove_log"      ]; then
        COMMAND=$2
    else
        echo_error "do not support command: $2"
        exit
    fi
    # command aliases
    if [ "$COMMAND" == "upgrade" ]; then
        COMMAND=update
    fi

    shift 2

    ${CHAIN_NAME}_${COMMAND} "$@"
fi
