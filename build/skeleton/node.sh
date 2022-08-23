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
        local OS_VER="$(lsb_release -s -i 2>/dev/null)"
        local OS_VER="$OS_VER-$(lsb_release -s -r 2>/dev/null)"
        if [ "$OS_VER" \< "Ubuntu-18.04" ]; then
            echo_error "this script requires Ubuntu 18.04 or higher"
            exit
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

    for i in $(lsof -nP -iTCP -sTCP:LISTEN -a -p $1 2>/dev/null | sed '1d' | awk '{ print $5 "_" $9 }'); do
        echo -n "$i "
    done
    echo
}

list_udp()
{
    if [ "$1" == "" ]; then
        return
    fi

    for i in $(lsof -nP -iUDP -a -p $1 2>/dev/null | sed '1d' | awk '{ print $5 "_" $9 }'); do
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
        printf "$(tput smul)%-12s%-16s$(tput setaf $FG_COLOR)$(tput bold)%s$(tput sgr0)\n" $1 $2 $3
    else
        printf "%-12s%-16s%s\n" $1 $2 $3
    fi
}

status_info()
{
    if [ -t 1 ]; then
        printf "$(tput bold)%-12s$(tput sgr0)" "$1:"
        if [ "$1" == "DPoS State" ]; then
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
        printf "%-12s%s\n" "$1:" "$2"
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
    if [ "$(uname -s)-$(uname -m)" == "Linux-x86_64" ]; then
        local NODEJS_PLATFORM=linux-x64
    else
        echo "ERROR: do not support $(uname -s)-$(uname -m)"
        return
    fi

    local NODEJS_VER=v14.17.0
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

#
# common chain functions
#
chain_prepare_stage()
{
    local CHAIN_NAME=$1

    if [ "$CHAIN_NAME" != "ela" ] && \
       [ "$CHAIN_NAME" != "did" ] && \
       [ "$CHAIN_NAME" != "esc" ] && \
       [ "$CHAIN_NAME" != "esc-oracle" ] && \
       [ "$CHAIN_NAME" != "eid" ] && \
       [ "$CHAIN_NAME" != "eid-oracle" ] && \
       [ "$CHAIN_NAME" != "arbiter" ] && \
       [ "$CHAIN_NAME" != "carrier" ]; then
        echo "ERROR: do not support chain: $1"
        return 1
    fi

    if [ "$2" == "" ]; then
        return 1
    fi

    local RELEASE_PLATFORM=$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m)
    local PATH_STAGE=$SCRIPT_PATH/.node-upload/$CHAIN_NAME

    echo "Finding the latest $CHAIN_NAME release..."
    local URL_PREFIX=https://download.elastos.io/elastos-$CHAIN_NAME
    local VER_LATEST=$(curl -s "$URL_PREFIX/?F=1" | grep '\[DIR\]' \
        | sed -e 's/.*href="//' -e 's/".*//' -e 's/.*-//' -e 's/\/$//' \
        | sort -Vr | head -n 1)

    if [ "$VER_LATEST" == "" ]; then
        echo "ERROR: no VER_LATEST found"
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
        echo "ERROR: curl failed"
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
            echo "ERROR: failed to extract $TGZ_LATEST"
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
    carrier_installed    && carrier_start
    ela_installed        && ela_start
    did_installed        && did_start
    esc_installed        && esc_start
    esc-oracle_installed && esc-oracle_start
    eid_installed        && eid_start
    eid-oracle_installed && eid-oracle_start
    arbiter_installed    && arbiter_start
}

all_stop()
{
    carrier_installed    && carrier_stop
    arbiter_installed    && arbiter_stop
    ela_installed        && ela_stop
    did_installed        && did_stop
    eid-oracle_installed && eid-oracle_stop
    eid_installed        && eid_stop
    esc-oracle_installed && esc-oracle_stop
    esc_installed        && esc_stop
}

all_status()
{
    ela_installed        && ela_status
    did_installed        && did_status
    esc_installed        && esc_status
    esc-oracle_installed && esc-oracle_status
    eid_installed        && eid_status
    eid-oracle_installed && eid-oracle_status
    arbiter_installed    && arbiter_status
    carrier_installed    && carrier_status
}

all_update()
{
    ela_installed        && ela_update
    did_installed        && did_update
    esc_installed        && esc_update
    esc-oracle_installed && esc-oracle_update
    eid_installed        && eid_update
    eid-oracle_installed && eid-oracle_update
    arbiter_installed    && arbiter_update
    carrier_installed    && carrier_update
}

all_init()
{
    ela_init
    did_init
    esc_init
    esc-oracle_init
    eid_init
    eid-oracle_init
    arbiter_init
    carrier_init
}

all_compress_log()
{
    ela_installed        && ela_compress_log
    did_installed        && did_compress_log
    esc_installed        && esc_compress_log
    esc-oracle_installed && esc-oracle_compress_log
    eid_installed        && eid_compress_log
    eid-oracle_installed && eid-oracle_compress_log
    arbiter_installed    && arbiter_compress_log
}

all_remove_log()
{
    ela_installed        && ela_remove_log
    did_installed        && did_remove_log
    esc_installed        && esc_remove_log
    esc-oracle_installed && esc-oracle_remove_log
    eid_installed        && eid_remove_log
    eid-oracle_installed && eid-oracle_remove_log
    arbiter_installed    && arbiter_remove_log

}

#
# ela
#
ela_start()
{
    if [ ! -f $SCRIPT_PATH/ela/ela ]; then
        echo "ERROR: $SCRIPT_PATH/ela/ela is not exist"
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
        echo "ela $($SCRIPT_PATH/ela/ela -v | sed 's/.* //')"
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

    local ELA_RPC_PORT=20336

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
            elif [ "$3" == "crosschain" ]; then
                $ELA_CLI --rpcport $ELA_RPC_PORT --rpcuser $ELA_RPC_USER \
                 --rpcpassword $ELA_RPC_PASS $*
            else
                $ELA_CLI --rpcport $ELA_RPC_PORT --rpcuser $ELA_RPC_USER \
                 --rpcpassword $ELA_RPC_PASS $*
            fi
        else
            # showtx, depositaddr, didaddr, crosschainaddr
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

    local ELA_RPC_PORT=20336

    # auto expand single command
    if [[ $1 =~ ^[a-z]+$ ]] && [ "$2" == "" ]; then
        local DATA={\"method\":\"$1\"}
    else
        local DATA=$1
    fi

    curl -s -H 'Content-Type:application/json' \
        -X POST --data $DATA \
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

    local ELA_DPOS_NAME=$(ela_jsonrpc '{"method":"listproducers","params":{"state":"all"}}' | \
        jq -r ".result.producers[] | select(.nodepublickey == \"$ELA_PUB_KEY\") | .nickname" 2>/dev/null)
    if [ "$ELA_DPOS_NAME" == "" ]; then
        ELA_DPOS_NAME=N/A
    fi

    local ELA_DPOS_STATE=$(ela_jsonrpc '{"method":"listproducers","params":{"state":"all"}}' | \
        jq -r ".result.producers[] | select(.nodepublickey == \"$ELA_PUB_KEY\") | .state" 2>/dev/null)
    if [ "$ELA_DPOS_STATE" == "" ]; then
        ELA_DPOS_STATE=N/A
    fi

    local ELA_CRC_NAME=$(ela_jsonrpc '{"method":"listcurrentcrs","params":{"state":"all"}}' | \
        jq -r ".result.crmembersinfo[] | select(.dpospublickey == \"$ELA_PUB_KEY\") | .nickname" 2>/dev/null)
    if [ "$ELA_CRC_NAME" == "" ]; then
        ELA_CRC_NAME=N/A
    fi

    local ELA_CRC_STATE=$(ela_jsonrpc '{"method":"listcurrentcrs","params":{"state":"all"}}' | \
        jq -r ".result.crmembersinfo[] | select(.dpospublickey == \"$ELA_PUB_KEY\") | .state" 2>/dev/null)
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
    status_info "Disk"       "$ELA_DISK_USAGE"
    status_info "Address"    "$ELA_ADDRESS"
    status_info "Public Key" "$ELA_PUB_KEY"
    status_info "Balance"    "$ELA_BALANCE"
    status_info "PID"        "$PID"
    status_info "RAM"        "$ELA_RAM"
    status_info "Uptime"     "$ELA_UPTIME"
    status_info "#Files"     "$ELA_NUM_FILES"
    status_info "TCP Ports"  "$ELA_TCP_LISTEN"
    status_info "#TCP"       "$ELA_NUM_TCPS"
    status_info "#Peers"     "$ELA_NUM_PEERS"
    status_info "Height"     "$ELA_HEIGHT"
    status_info "DPoS Name"  "$ELA_DPOS_NAME"
    status_info "DPoS State" "$ELA_DPOS_STATE"
    status_info "CRC Name"   "$ELA_CRC_NAME"
    status_info "CRC State"  "$ELA_CRC_STATE"
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

    cd ~/node/ela

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
            echo "ERROR: do not support $CHAIN_TYPE"
            return
        fi
    elif [ "$SIDECHAIN" == "eid" ]; then
        if [ "$CHAIN_TYPE" == "mainnet" ]; then
            local SADDRESS=XUgTgCnUEqMUKLFAg3KhGv1nnt9nn8i3wi
        elif [ "$CHAIN_TYPE" == "testnet" ]; then
            local SADDRESS=XPsgiVQC3WucBYDL2DmPixj74Aa9aG3et8
        else
            echo "ERROR: do not support $CHAIN_TYPE"
            return
        fi
    else
        echo "ERROR: do not support sidechain $SIDECHAIN"
        return
    fi

    if [ "$ELA_FEE" == "" ]; then
        local ELA_FEE=0.000001
    fi

    if [ "$ELA_AMOUNT" == "All" ]; then
        local ELA_AMOUNT=$(ela_client wallet balance | awk 'NR == 3 {print $3}')
        local ELA_AMOUNT=$(echo "$ELA_AMOUNT-$ELA_FEE" | bc)
    fi

    cd ~/node/ela

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

ela_activate_dpos()
{
    if [ ! -f ~/.config/elastos/ela.txt ]; then
        return
    fi

    # TODO: test more prerequisites

    cd $SCRIPT_PATH/ela
    local ELA_PUB_KEY=$(ela_client wallet account | sed -n '3 s/^.* //p')

    ela_client wallet buildtx activate --nodepublickey $ELA_PUB_KEY
    ela_client wallet sendtx -f ready_to_send.txn

    # Error message:
    # [ERROR] map[code:-32603 id:<nil> message:Client authenticate failed]
    # [ERROR] map[code:43001 id:<nil> message:transaction validate error: payload content invalid]
}

#
# did
#
did_start()
{
    if [ ! -f $SCRIPT_PATH/did/did ]; then
        echo "ERROR: $SCRIPT_PATH/did/did is not exist"
        return
    fi

    local PID=$(pgrep -x did)
    if [ "$PID" != "" ]; then
        did_status
        return
    fi

    echo "Starting did..."
    cd $SCRIPT_PATH/did
    nohup ./did 1>/dev/null 2>output &
    sleep 1
    did_status
}

did_stop()
{
    local PID=$(pgrep -x did)
    if [ "$PID" != "" ]; then
        echo "Stopping did..."
        kill $PID
        while ps -p $PID 1>/dev/null; do
            echo -n .
            sleep 1
        done
        echo
    fi
    sync
    did_status
}

did_installed()
{
    if [ -f $SCRIPT_PATH/did/did ]; then
        true
    else
        false
    fi
}

did_ver()
{
    if [ -f $SCRIPT_PATH/did/did ]; then
        echo "did $($SCRIPT_PATH/did/did -v 2>&1 | sed 's/.* //')"
    else
        echo "did N/A"
    fi
}

did_client()
{
    if [ ! -f $SCRIPT_PATH/ela/ela-cli ]; then
        return
    fi

    local DID_RPC_USER=$(cat $SCRIPT_PATH/did/config.json | \
        jq -r '.RPCUser')
    local DID_RPC_PASS=$(cat $SCRIPT_PATH/did/config.json | \
        jq -r '.RPCPass')

    local DID_RPC_PORT=20606

    local DID_CLI="$SCRIPT_PATH/ela/ela-cli --rpcport $DID_RPC_PORT \
        --rpcuser $DID_RPC_USER --rpcpassword $DID_RPC_PASS"

    $DID_CLI $*
}

did_jsonrpc()
{
    if [ "$1" == "" ]; then
        return
    fi

    local DID_RPC_USER=$(cat $SCRIPT_PATH/did/config.json | \
        jq -r '.RPCUser')
    local DID_RPC_PASS=$(cat $SCRIPT_PATH/did/config.json | \
        jq -r '.RPCPass')

    local DID_RPC_PORT=20606

    if [[ $1 =~ ^[a-z]+$ ]] && [ "$2" == "" ]; then
        local DATA={\"method\":\"$1\"}
    else
        local DATA=$1
    fi

    curl -s -H 'Content-Type:application/json' \
        -X POST --data $DATA \
        -u $DID_RPC_USER:$DID_RPC_PASS \
        http://127.0.0.1:$DID_RPC_PORT | jq .
}

did_status()
{
    local DID_VER=$(did_ver)

    local DID_DISK_USAGE=$(disk_usage $SCRIPT_PATH/did)

    local PID=$(pgrep -x did)
    if [ "$PID" == "" ]; then
        status_head $DID_VER Stopped
        status_info "Disk" "$DID_DISK_USAGE"
        echo
        return
    fi

    local DID_RAM=$(mem_usage $PID)
    local DID_UPTIME=$(run_time $PID)
    local DID_NUM_TCPS=$(num_tcps $PID)
    local DID_TCP_LISTEN=$(list_tcp $PID)
    local DID_NUM_FILES=$(num_files $PID)

    local DID_NUM_PEERS=$(did_client info getconnectioncount)
    if [[ ! "$DID_NUM_PEERS" =~ ^[0-9]+$ ]]; then
        DID_NUM_PEERS=0
    fi
    local DID_HEIGHT=$(did_client info getcurrentheight)
    if [[ ! "$DID_HEIGHT" =~ ^[0-9]+$ ]]; then
        DID_HEIGHT=N/A
    fi

    status_head $DID_VER Running
    status_info "Disk"      "$DID_DISK_USAGE"
    status_info "PID"       "$PID"
    status_info "RAM"       "$DID_RAM"
    status_info "Uptime"    "$DID_UPTIME"
    status_info "#Files"    "$DID_NUM_FILES"
    status_info "TCP Ports" "$DID_TCP_LISTEN"
    status_info "#TCP"      "$DID_NUM_TCPS"
    status_info "#Peers"    "$DID_NUM_PEERS"
    status_info "Height"    "$DID_HEIGHT"
    echo
}

did_compress_log()
{
    compress_log $SCRIPT_PATH/did/elastos_did/logs
}

did_remove_log()
{
    remove_log $SCRIPT_PATH/did/elastos_did/logs
}

did_update()
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

    chain_prepare_stage did did
    if [ "$?" != "0" ]; then
        return
    fi

    local PATH_STAGE=$SCRIPT_PATH/.node-upload/did
    local DIR_DEPLOY=$SCRIPT_PATH/did

    local PID=$(pgrep -x did)
    if [ $PID ]; then
        did_stop
    fi

    mkdir -p $DIR_DEPLOY
    cp -v $PATH_STAGE/did $DIR_DEPLOY/

    if [ $PID ] && [ "$NO_START_AFTER_UPDATE" == "" ]; then
        did_start
    fi
}

did_init()
{
    local DID_CONFIG=${SCRIPT_PATH}/did/config.json

    if [ ! -f ${SCRIPT_PATH}/did/did ]; then
        did_update -y
    fi

    if [ -f ${SCRIPT_PATH}/did/.init ]; then
        echo_error "did has already been initialized"
        return
    fi

    if [ -f $DID_CONFIG ]; then
        echo_error "$DID_CONFIG exists"
        return
    fi

    echo "Creating did config file..."
    cat >$DID_CONFIG <<EOF
{
  "SPVDisableDNS": false,
  "SPVPermanentPeers": [
    "127.0.0.1:20338"
  ],
  "EnableRPC": true,
  "RPCUser": "USER",
  "RPCPass": "PASSWORD",
  "RPCWhiteList": [
    "127.0.0.1"
  ],
  "PayToAddr": "PAY_TO_ADDR",
  "MinerInfo": "MINER_INFO"
}
EOF

    echo "Generating random userpass for did RPC interface..."
    local DID_RPC_USER=$(openssl rand -base64 100 | shasum | head -c 32)
    local DID_RPC_PASS=$(openssl rand -base64 100 | shasum | head -c 32)

    echo "Please input an ELA address to receive awards."
    local PAY_TO_ADDR=
    while true; do
        read -p '? PayToAddr: ' PAY_TO_ADDR
        if [ "$PAY_TO_ADDR" != "" ]; then
            break
        fi
    done

    local MINER_INFO=
    echo "Please input a miner name that will be persisted in the blockchain."
    while true; do
        read -p '? MinerInfo: ' MINER_INFO
        if [ "$MINER_INFO" != "" ]; then
            break
        fi
    done

    echo "Updating did config file..."
    jq ".RPCUser=\"$DID_RPC_USER\"  | \
        .RPCPass=\"$DID_RPC_PASS\"  | \
        .PayToAddr=\"$PAY_TO_ADDR\" | \
        .MinerInfo=\"$MINER_INFO\"" \
        $DID_CONFIG >$DID_CONFIG.tmp

    if [ "$?" == "0" ]; then
        mv $DID_CONFIG.tmp $DID_CONFIG
    fi

    echo_info "did config file: $DID_CONFIG"

    touch ${SCRIPT_PATH}/did/.init
    echo_ok "did initialized"
    echo
}

#
# esc
#
esc_start()
{
    if [ ! -f $SCRIPT_PATH/esc/esc ]; then
        echo "ERROR: $SCRIPT_PATH/esc/esc is not exist"
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

esc_installed()
{
    if [ -f $SCRIPT_PATH/esc/esc ]; then
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

esc_client()
{
    if [ ! -f $SCRIPT_PATH/esc/esc ]; then
        echo "ERROR: $SCRIPT_PATH/esc/esc is not exist"
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
        esc-oracle_stop
        esc_stop
    fi

    mkdir -p $DIR_DEPLOY
    cp -v $PATH_STAGE/esc $DIR_DEPLOY/

    if [ $PID ] && [ "$NO_START_AFTER_UPDATE" == "" ]; then
        esc_start
        esc-oracle_start
    fi
}

esc_init()
{
    if [ ! -f ${SCRIPT_PATH}/ela/.init ]; then
        echo_error "ela not initialized"
        return
    fi

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
        echo "ERROR: failed to create esc keystore"
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
esc-oracle_start()
{
    if [ ! -f $SCRIPT_PATH/esc-oracle/crosschain_oracle.js ]; then
        echo "ERROR: $SCRIPT_PATH/esc-oracle/crosschain_oracle.js is not exist"
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

    export env=mainnet

    echo "env: $env"
    nodejs_setenv
    nohup $SHELL -c "node crosschain_oracle.js \
        2>$SCRIPT_PATH/esc-oracle/logs/esc-oracle_err.log \
        | rotatelogs $SCRIPT_PATH/esc-oracle/logs/esc-oracle_out-%Y-%m-%d-%H_%M_%S.log 20M" &

    sleep 1
    esc-oracle_status
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

esc-oracle_installed()
{
    if [ -f $SCRIPT_PATH/esc-oracle/crosschain_oracle.js ]; then
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

esc-oracle_compress_log()
{
    compress_log $SCRIPT_PATH/esc-oracle/logs/esc-oracle_out-\*.log
}

esc-oracle_remove_log()
{
    remove_log $SCRIPT_PATH/esc-oracle/logs/esc-oracle_out-\*.log
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

esc-oracle_init()
{
    if [ ! -f ${SCRIPT_PATH}/esc/.init ]; then
        echo_error "esc not initialized"
        return
    fi

    if [ ! -f $SCRIPT_PATH/esc-oracle/crosschain_oracle.js ]; then
        esc-oracle_update -y
    fi

    if [ -f $SCRIPT_PATH/esc-oracle/.init ]; then
        echo_error "esc-oracle has already been initialized"
        return
    fi

    if [ "$(which make)" == "" ] || \
       [ "$(which gcc)"  == "" ] || \
       [ "$(which g++)"  == "" ]; then
        echo_error "requires make, gcc, g++"
        return
    fi

    nodejs_setenv

    mkdir -p $SCRIPT_PATH/esc-oracle
    cd $SCRIPT_PATH/esc-oracle
    npm install web3 express

    touch ${SCRIPT_PATH}/esc-oracle/.init
    echo_ok "esc-oracle initialized"
    echo
}

#
# eid
#
eid_start()
{
    if [ ! -f $SCRIPT_PATH/eid/eid ]; then
        echo "ERROR: $SCRIPT_PATH/eid/eid is not exist"
        return
    fi

    local PID=$(pgrep -f '^\./eid .*--rpc ')
    if [ "$PID" != "" ]; then
        eid_status
        return
    fi

    echo "Starting eid..."
    cd $SCRIPT_PATH/eid
    mkdir -p $SCRIPT_PATH/eid/logs/

    if [ -f ~/.config/elastos/eid.txt ]; then
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
            --rpcapi 'db,eth,miner,net,personal,txpool,web3' \
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
        echo "ERROR: $SCRIPT_PATH/eid/eid is not exist"
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
        eid-oracle_stop
        eid_stop
    fi

    mkdir -p $DIR_DEPLOY
    cp -v $PATH_STAGE/eid $DIR_DEPLOY/

    if [ $PID ] && [ "$NO_START_AFTER_UPDATE" == "" ]; then
        eid_start
        eid-oracle_start
    fi
}

eid_init()
{
    if [ ! -f ${SCRIPT_PATH}/ela/.init ]; then
        echo_error "ela not initialized"
        return
    fi

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
        echo "ERROR: failed to create eid keystore"
        return
    fi

    echo "Checking eid keystore..."
    local EID_KEYSTORE=$(./eid --datadir "$SCRIPT_PATH/eid/data/" \
        --nousb --verbosity 0 account list | sed 's/.*keystore:\/\///')
    chmod 600 $EID_KEYSTORE

    echo_info "eid keystore file: $EID_KEYSTORE"
    echo_info "eid keystore password file: $EID_KEYSTORE_PASS_FILE"

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
eid-oracle_start()
{
    if [ ! -f $SCRIPT_PATH/eid-oracle/crosschain_eid.js ]; then
        echo "ERROR: $SCRIPT_PATH/eid-oracle/crosschain_eid.js is not exist"
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

    export env=mainnet

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

    if [ ! -f $SCRIPT_PATH/eid-oracle/crosschain_eid.js ]; then
        eid-oracle_update -y
    fi

    if [ -f $SCRIPT_PATH/eid-oracle/.init ]; then
        echo_error "eid-oracle has already been initialized"
        return
    fi

    if [ "$(which make)" == "" ] || \
       [ "$(which gcc)"  == "" ] || \
       [ "$(which g++)"  == "" ]; then
        echo_error "requires make, gcc, g++"
        return
    fi

    nodejs_setenv

    mkdir -p $SCRIPT_PATH/eid-oracle
    cd $SCRIPT_PATH/eid-oracle
    npm install web3 express

    touch ${SCRIPT_PATH}/eid-oracle/.init
    echo_ok "eid-oracle initialized"
    echo
}

#
# arbiter
#
arbiter_start()
{
    if [ ! -f $SCRIPT_PATH/arbiter/arbiter ]; then
        echo "ERROR: $SCRIPT_PATH/arbiter/arbiter is not exist"
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
        echo "Waiting for ela, did, esc-oracle, eid-oracle to start..."
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

    local ARBITER_RPC_PORT=20536

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

    local DID_GENESIS=56be936978c261b2e649d58dbfaf3f23d4a868274f5522cd2adb4308a955c4a3
    local ARBITER_DID_HEIGHT=$(arbiter_jsonrpc \
        "{\"method\":\"getsidechainblockheight\",\"params\":{\"hash\":\"$DID_GENESIS\"}}" \
        | jq -r '.result')
    if [[ ! "$ARBITER_DID_HEIGHT" =~ ^[0-9]+$ ]]; then
        ARBITER_DID_HEIGHT=N/A
    fi

    local ESC_GENESIS=6afc2eb01956dfe192dc4cd065efdf6c3c80448776ca367a7246d279e228ff0a
    local ARBITER_ESC_HEIGHT=$(arbiter_jsonrpc \
        "{\"method\":\"getsidechainblockheight\",\"params\":{\"hash\":\"$ESC_GENESIS\"}}" \
        | jq -r '.result')
    if [[ ! "$ARBITER_ESC_HEIGHT" =~ ^[0-9]+$ ]]; then
        ARBITER_ESC_HEIGHT=N/A
    fi

    local EID_GENESIS=7d0702054ad68913eff9137dfa0b0b6ff701d55062359deacad14859561f5567
    local ARBITER_EID_HEIGHT=$(arbiter_jsonrpc \
        "{\"method\":\"getsidechainblockheight\",\"params\":{\"hash\":\"$EID_GENESIS\"}}" \
        | jq -r '.result')
    if [[ ! "$ARBITER_EID_HEIGHT" =~ ^[0-9]+$ ]]; then
        ARBITER_EID_HEIGHT=N/A
    fi

    status_head $ARBITER_VER Running
    status_info "Disk"       "$ARBITER_DISK_USAGE"
    status_info "PID"        "$PID"
    status_info "RAM"        "$ARBITER_RAM"
    status_info "Uptime"     "$ARBITER_UPTIME"
    status_info "#Files"     "$ARBITER_NUM_FILES"
    status_info "TCP Ports"  "$ARBITER_TCP_LISTEN"
    status_info "#TCP"       "$ARBITER_NUM_TCPS"
    status_info "SPV Height" "$ARBITER_SPV_HEIGHT"
    status_info "DID Height" "$ARBITER_DID_HEIGHT"
    status_info "ESC Height" "$ARBITER_ESC_HEIGHT"
    status_info "EID Height" "$ARBITER_EID_HEIGHT"
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

arbiter_init()
{
    if [ ! -f $SCRIPT_PATH/ela/.init ]; then
        echo_error "ela not initialized"
        return
    fi
    if [ ! -f $SCRIPT_PATH/did/.init ]; then
        echo_error "did not initialized"
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

    local ELA_CONFIG=${SCRIPT_PATH}/ela/config.json
    local DID_CONFIG=${SCRIPT_PATH}/did/config.json
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
    "SideNodeList": [{
        "Rpc": {
          "IpAddress": "127.0.0.1",
          "HttpJsonPort": 20606,
          "User": "",
          "Pass": ""
        },
        "SyncStartHeight": 639400,
        "ExchangeRate": 1.0,
        "GenesisBlock": "56be936978c261b2e649d58dbfaf3f23d4a868274f5522cd2adb4308a955c4a3",
        "MiningAddr": "",
        "PowChain": true,
        "PayToAddr": ""
      },
      {
        "Rpc": {
          "IpAddress": "127.0.0.1",
          "HttpJsonPort": 20632
        },
        "SyncStartHeight": 13246000,
        "ExchangeRate": 1.0,
        "GenesisBlock": "6afc2eb01956dfe192dc4cd065efdf6c3c80448776ca367a7246d279e228ff0a",
        "SupportQuickRecharge": true,
        "SupportInvalidDeposit": true,
        "SupportInvalidWithdraw": true,
        "PowChain": false
      },
      {
        "Rpc": {
          "IpAddress": "127.0.0.1",
          "HttpJsonPort": 20642
        },
        "SyncStartHeight": 5932000,
        "ExchangeRate": 1.0,
        "GenesisBlock": "7d0702054ad68913eff9137dfa0b0b6ff701d55062359deacad14859561f5567",
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

    # Arbiter Config: DID
    local DID_RPC_USER=$(cat $DID_CONFIG | jq -r '.RPCUser')
    local DID_RPC_PASS=$(cat $DID_CONFIG | jq -r '.RPCPass')
    local MINING_ADDR_DID=$(./ela-cli wallet add -p $KEYSTORE_PASS | \
        sed -n '3p' | sed 's/ .*//')

    # Arbiter Config: Arbiter RPC
    echo "Generating random userpass for arbiter RPC interface..."
    local ARBITER_RPC_USER=$(openssl rand -base64 100 | shasum | head -c 32)
    local ARBITER_RPC_PASS=$(openssl rand -base64 100 | shasum | head -c 32)

    echo "Please input an ELA address to receive awards."
    local PAY_TO_ADDR=
    while true; do
        read -p '? PayToAddr: ' PAY_TO_ADDR
        if [ "$PAY_TO_ADDR" != "" ]; then
            break
        fi
    done

    echo "Updating arbiter config file..."
    jq ".Configuration.MainNode.Rpc.User=\"$ELA_RPC_USER\"              | \
        .Configuration.MainNode.Rpc.Pass=\"$ELA_RPC_PASS\"              | \
        .Configuration.SideNodeList[0].Rpc.User=\"$DID_RPC_USER\"       | \
        .Configuration.SideNodeList[0].Rpc.Pass=\"$DID_RPC_PASS\"       | \
        .Configuration.SideNodeList[0].MiningAddr=\"$MINING_ADDR_DID\"  | \
        .Configuration.SideNodeList[0].PayToAddr=\"$PAY_TO_ADDR\"       | \
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

#
# carrier
#
carrier_start()
{
    if [ ! -f $SCRIPT_PATH/carrier/ela-bootstrapd ]; then
        echo "ERROR: $SCRIPT_PATH/carrier/ela-bootstrapd is not exist"
        return
    fi
    if [ ! -f $SCRIPT_PATH/carrier/.init ]; then
        echo "ERROR: please run '$SCRIPT_NAME carrier init' first"
        return
    fi

    local PID=$(pgrep -x ela-bootstrapd)
    if [ "$PID" ]; then
        carrier_status
        return
    fi

    echo "Starting carrier..."
    cd $SCRIPT_PATH/carrier
    ./ela-bootstrapd --config=bootstrapd.conf
    sleep 1
    carrier_status
}

carrier_stop()
{
    local PID=$(pgrep -x ela-bootstrapd)
    if [ "$PID" != "" ]; then
        echo "Stopping carrier..."
        kill $PID
        while ps -p $PID 1>/dev/null; do
            echo -n .
            sleep 1
        done
        echo
        rm $SCRIPT_PATH/carrier/var/run/ela-bootstrapd/*.pid 2>/dev/null
    fi
    carrier_status
}

carrier_installed()
{
    if [ -f $SCRIPT_PATH/carrier/ela-bootstrapd ]; then
        true
    else
        false
    fi
}

carrier_ver()
{
    if [ -f $SCRIPT_PATH/carrier/ela-bootstrapd ]; then
        echo "carrier $($SCRIPT_PATH/carrier/ela-bootstrapd -v | tail -1 | sed "s/.* //")"
    else
        echo "carrier N/A"
    fi
}

carrier_status()
{
    local CARRIER_VER=$(carrier_ver)

    local CARRIER_DISK_USAGE=$(disk_usage $SCRIPT_PATH/carrier)

    # the child process only
    local PID=$(pgrep -x -n ela-bootstrapd)
    if [ "$PID" == "" ]; then
        status_head $CARRIER_VER Stopped
        status_info "Disk" "$CARRIER_DISK_USAGE"
        echo
        return
    fi

    local CARRIER_RAM=$(mem_usage $PID)
    local CARRIER_UPTIME=$(run_time $PID)
    local CARRIER_NUM_TCPS=$(num_tcps $PID)
    local CARRIER_TCP_LISTEN=$(list_tcp $PID)
    local CARRIER_UDP_LISTEN=$(list_udp $PID)
    local CARRIER_NUM_FILES=$(num_files $PID)

    status_head $CARRIER_VER Running
    status_info "Disk"      "$CARRIER_DISK_USAGE"
    status_info "PID"       "$PID"
    status_info "RAM"       "$CARRIER_RAM"
    status_info "Uptime"    "$CARRIER_UPTIME"
    status_info "#Files"    "$CARRIER_NUM_FILES"
    status_info "TCP Ports" "$CARRIER_TCP_LISTEN"
    status_info "#TCP"      "$CARRIER_NUM_TCPS"
    status_info "UDP Ports" "$CARRIER_UDP_LISTEN"
    echo
}

carrier_update()
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

    chain_prepare_stage carrier usr/bin/ela-bootstrapd

    if [ "$?" != "0" ]; then
        return
    fi

    local PATH_STAGE=$SCRIPT_PATH/.node-upload/carrier
    local DIR_DEPLOY=$SCRIPT_PATH/carrier

    local PID=$(pgrep -x ela-bootstrapd)
    if [ "$PID" ]; then
        carrier_stop
    fi

    mkdir -p $DIR_DEPLOY
    cp -v $PATH_STAGE/usr/bin/ela-bootstrapd $DIR_DEPLOY/

    if [ "$PID" ] && [ "$NO_START_AFTER_UPDATE" == "" ]; then
        carrier_start
    fi
}

carrier_init()
{
    local CARRIER_CONFIG=${SCRIPT_PATH}/carrier/bootstrapd.conf

    if [ ! -f $SCRIPT_PATH/carrier/ela-bootstrapd ]; then
        carrier_update -y
    fi

    if [ -f ${SCRIPT_PATH}/carrier/.init ]; then
        echo_error "carrier has already been initialized"
        return
    fi

    if [ -f $CARRIER_CONFIG ]; then
        echo_error "$CARRIER_CONFIG exists"
        return
    fi

    echo "Creating carrier config file..."
    cat >$CARRIER_CONFIG <<EOF
// Elastos Carrier bootstrap daemon configuration file.

// Listening port (UDP).
port = 33445

// A key file is like a password, so keep it where no one can read it.
// If there is no key file, a new one will be generated.
// The daemon should have permission to read/write it.
keys_file_path = "var/lib/ela-bootstrapd/keys"

// The PID file written to by the daemon.
// Make sure that the user that daemon runs as has permissions to write to the
// PID file.
pid_file_path = "var/run/ela-bootstrapd/ela-bootstrapd.pid"

// Enable IPv6.
enable_ipv6 = false

// Fallback to IPv4 in case IPv6 fails.
enable_ipv4_fallback = true

// Automatically bootstrap with nodes on local area network.
enable_lan_discovery = true

enable_tcp_relay = true

// While Tox uses 33445 port by default, 443 (https) and 3389 (rdp) ports are very
// common among nodes, so it's encouraged to keep them in place.
tcp_relay_ports = [443, 3389, 33445]

// Reply to MOTD (Message Of The Day) requests.
enable_motd = true

// Just a message that is sent when someone requests MOTD.
// Put anything you want, but note that it will be trimmed to fit into 255 bytes.
motd = "elastos-bootstrapd"

turn = {
  port = 3478
  realm = "elastos.org"
  pid_file_path = "var/run/ela-bootstrapd/turnserver.pid"
  userdb = "var/lib/ela-bootstrapd/db/turndb"
  verbose = true
  external_ip = "$(extip)"
}

// Any number of nodes the daemon will bootstrap itself off.
//
// Remember to replace the provided example with Elastos own bootstrap node list.
//
// address = any IPv4 or IPv6 address and also any US-ASCII domain name.
bootstrap_nodes = (
  {
    address = "13.58.208.50"
    port = 33445
    public-key = "89vny8MrKdDKs7Uta9RdVmspPjnRMdwMmaiEW27pZ7gh"
  },
  {
    address = "18.216.102.47"
    port = 33445
    public-key = "G5z8MqiNDFTadFUPfMdYsYtkUDbX5mNCMVHMZtsCnFeb"
  },
  {
    address = "18.216.6.197"
    port = 33445
    public-key = "H8sqhRrQuJZ6iLtP2wanxt4LzdNrN2NNFnpPdq1uJ9n2"
  },
  {
    address = "52.83.171.135"
    port = 33445
    public-key = "5tuHgK1Q4CYf4K5PutsEPK5E3Z7cbtEBdx7LwmdzqXHL"
  },
  {
    address = "52.83.191.228"
    port = 33445
    public-key = "3khtxZo89SBScAMaHhTvD68pPHiKxgZT6hTCSZZVgNEm"
  }
)
EOF

    mkdir -pv ${SCRIPT_PATH}/carrier/var/lib/ela-bootstrapd
    mkdir -pv ${SCRIPT_PATH}/carrier/var/lib/ela-bootstrapd/db
    mkdir -pv ${SCRIPT_PATH}/carrier/var/run/ela-bootstrapd

    echo_info "carrier config file: $CARRIER_CONFIG"

    touch ${SCRIPT_PATH}/carrier/.init
    echo_ok "carrier initialized"
    echo
}

usage()
{
    echo "Usage: $SCRIPT_NAME [CHAIN] COMMAND [OPTIONS]"
    echo "Manage Elastos Node ($SCRIPT_PATH) [$CHAIN_TYPE]"
    echo
    echo "Available Chains:"
    echo
    for i in $(grep "^[^ ]\+_ver(" $BASH_SOURCE | sed 's/(.*$//'); do
    printf "  %-16s%s\n" $(${i})
    done
    echo
    echo "Available Commands:"
    echo
    echo "  start           Start chain daemon"
    echo "  stop            Stop chain daemon"
    echo "  status          Print chain daemon status"
    echo "  client          Run chain client"
    echo "  jsonrpc         Call JSON-RPC API"
    echo "  update          Install or update chain"
    echo "  init            Install and configure chain"
    echo "  activate_dpos   Activate ELA DPoS"
    echo "  send            Send crypto"
    echo "  transfer        Send crypto crosschain"
    echo "  compress_log    Compress log files to save disk space"
    echo "  remove_log      Remove log files"
    echo
}

#
# Main
#
SCRIPT_PATH=$(cd $(dirname $BASH_SOURCE); pwd)
SCRIPT_NAME=$(basename $BASH_SOURCE)

set_env
check_env
CHAIN_TYPE=mainnet

# script commands
if [ "$1" == "" ]; then
    usage
    exit
elif [ "$1" == "set_path" ]; then
    set_path
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

    if [ "$1" != "ela" ] && \
       [ "$1" != "did" ] && \
       [ "$1" != "esc" ] && \
       [ "$1" != "esc-oracle" ] && \
       [ "$1" != "eid" ] && \
       [ "$1" != "eid-oracle" ] && \
       [ "$1" != "arbiter" ] && \
       [ "$1" != "carrier" ]; then
        echo "ERROR: do not support chain: $1"
        exit
    fi
    CHAIN_NAME=$1

    if [ "$2" == "" ]; then
        # no command specified
        COMMAND=status
    elif [ "$2" == "start"   ] || \
         [ "$2" == "stop"    ] || \
         [ "$2" == "status"  ] || \
         [ "$2" == "client"  ] || \
         [ "$2" == "jsonrpc" ] || \
         [ "$2" == "update"  ] || [ "$2" == "upgrade" ] || \
         [ "$2" == "init"    ] || \
         [ "$2" == "activate_dpos" ] || \
         [ "$2" == "send"          ] || \
         [ "$2" == "transfer"      ] || \
         [ "$2" == "compress_log"  ] || \
         [ "$2" == "remove_log"    ]; then
        COMMAND=$2
    else
        echo "ERROR: do not support command: $2"
        exit
    fi
    # command aliases
    if [ "$COMMAND" == "upgrade" ]; then
        COMMAND=update
    fi

    shift 2

    ${CHAIN_NAME}_${COMMAND} $*
fi