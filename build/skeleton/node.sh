#!/bin/bash

#
# utilities
#
check_env()
{
    #echo "Checking OS Version..."
    local OS_VER="$(lsb_release -s -i 2>/dev/null)"
    local OS_VER="$OS_VER-$(lsb_release -s -r 2>/dev/null)"
    if [ "$OS_VER" \< "Ubuntu-16.04" ]; then
        echo "WARNING: recommend a Ubuntu at least 16.04"
    fi

    sudo -n true 2>/dev/null
    if [ "$?" == "0" ]; then
        echo "ERROR: requires a user without sudo permission"
        exit
    fi

    jq --version >/dev/null
    if [ "$?" != "0" ]; then
        echo "ERROR: cannot find jq (https://github.com/stedolan/jq)"
        echo "INFO: sudo apt-get install -y jq"
        exit
    fi
}

public_ip()
{
    curl -s whatismyip.akamai.com
}

#
# all
#
all_init()
{
    ela_init
    did_init
    token_init
    carrier_init
}

all_start()
{
    ela_start
    did_start
    token_start
    carrier_start
}

all_stop()
{
    ela_stop
    did_stop
    token_stop
    carrier_stop
}

all_status()
{
    ela_status
    did_status
    token_status
    carrier_status
}

all_upgrade()
{
    if [ "$1" == "" ]; then
        echo "ERROR: no package supplied"
        return
    fi

    local TGZ=$1

    local VER_TGZ=$(tar xOf $1 node/version.txt)
    local VER=$(cat ${SCRIPT_PATH}/version.txt 2>/dev/null)

    if [ ! "$VER_TGZ" \> "$VER" ]; then
        echo "ERROR: support higher version only"
        return
    fi

    echo "Upgrading to $1..."
    all_stop

    echo "Upgrading ela..."
    cd ${SCRIPT_PATH}/ela
    mkdir -p ${SCRIPT_PATH}/ela
    tar xvf $1 --strip=2 node/ela/ela

    echo "Upgrading ela-cli..."
    cd ${SCRIPT_PATH}/ela
    mkdir -p ${SCRIPT_PATH}/ela
    tar xvf $1 --strip=2 node/ela/ela-cli

    echo "Upgrading did..."
    mkdir -p ${SCRIPT_PATH}/did
    cd ${SCRIPT_PATH}/did
    tar xvf $1 --strip=2 node/did/did

    echo "Upgrading token..."
    mkdir -p ${SCRIPT_PATH}/token
    cd ${SCRIPT_PATH}/token
    tar xvf $1 --strip=2 node/token/token

    echo "Upgrading carrier..."
    mkdir -p ${SCRIPT_PATH}/carrier
    cd ${SCRIPT_PATH}/carrier
    tar xvf $1 --strip=2 node/carrier/ela-bootstrapd

    echo "Upgrading checksum.txt..."
    cd ${SCRIPT_PATH}
    tar xvf $1 --strip=1 node/checksum.txt

    echo "Upgrading commit.txt..."
    cd ${SCRIPT_PATH}
    tar xvf $1 --strip=1 node/commit.txt

    echo "Upgrading node.sh..."
    cd ${SCRIPT_PATH}
    tar xvf $1 --strip=1 node/node.sh

    echo "Upgrading version.txt..."
    cd ${SCRIPT_PATH}
    tar xvf $1 --strip=1 node/version.txt

    all_start
}

#
# ela
#
ela_init()
{
    echo "Updating ${SCRIPT_PATH}/ela/config.json..."
    local ELA_RPC_USER=$(openssl rand -base64 100 | shasum | head -c 32)
    local ELA_RPC_PASS=$(openssl rand -base64 100 | shasum | head -c 32)
    jq ".Configuration.RpcConfiguration.User=\"$ELA_RPC_USER\" | \
        .Configuration.RpcConfiguration.Pass=\"$ELA_RPC_PASS\"" \
        ${SCRIPT_PATH}/ela/config.json \
        >${SCRIPT_PATH}/ela/config.json.tmp
    if [ "$?" == "0" ]; then
        mv ${SCRIPT_PATH}/ela/config.json.tmp \
           ${SCRIPT_PATH}/ela/config.json
    fi

    sed -i -e "s/\"IPAddress\":.*/\"IPAddress\": \"$(public_ip)\"/" \
        ${SCRIPT_PATH}/ela/config.json
    echo

    if [ -f ${SCRIPT_PATH}/ela/keystore.dat ]; then
        echo "INFO: keystore exists"
        return
    else
        local KEYSTORE_PASS=

        cd ${SCRIPT_PATH}/ela/
        echo "Please input a password for the keystore,"
        echo "or simply Enter will generate an random one."
        read -s -p 'Password: ' KEYSTORE_PASS
        echo

        if [ "$KEYSTORE_PASS" == "" ]; then
            echo "Generating random password..."
            KEYSTORE_PASS=$(openssl rand -base64 100 | head -c 32)
        else
            read -s -p 'Password (again): ' KEYSTORE_PASS_VERIFY
            echo

            if [ "$KEYSTORE_PASS" != "$KEYSTORE_PASS_VERIFY" ]; then
                echo "ERROR: password mismatch"
                return
            fi

            if [ "$KEYSTORE_PASS" == "$KEYSTORE_PASS_VERIFY" ]; then

                if [[ "${#KEYSTORE_PASS}" -lt 16 ]]   || \
                   [[ ! "$KEYSTORE_PASS" =~ [a-z] ]] || \
                   [[ ! "$KEYSTORE_PASS" =~ [A-Z] ]] || \
                   [[ ! "$KEYSTORE_PASS" =~ [0-9] ]] || \
                   [[ ! "$KEYSTORE_PASS" =~ [^[:alnum:]] ]]; then

                    echo "ERROR: the password does not meet the password policy:"
                    echo
                    echo "  Minimum password length: 16"
                    echo "  Require at least one uppercase letter (A-Z)"
                    echo "  Require at least one lowercase letter (a-z)"
                    echo "  Require at least one digit (0-9)"
                    echo "  Require at least one non-alphanumeric character"
                    return
                fi
            fi
        fi

        echo "Creating keystore.dat..."
        ./ela-cli wallet create -p "$KEYSTORE_PASS" >/dev/null
        if [ "$?" != "0" ]; then
            echo "ERROR: failed to create keystore"
            return
        fi
        echo $KEYSTORE_PASS > ~/.node.conf

        echo
        ./ela-cli wallet account -p "$KEYSTORE_PASS"

        echo
        echo "Please check keystore password via command: cat ~/.node.conf"
        touch ${SCRIPT_PATH}/ela/.init
        echo "Done"
    fi
}

ela_start()
{
    if [ ! -d $SCRIPT_PATH/ela/ ]; then
        echo "ERROR: $SCRIPT_PATH/ela/ is not exist"
        return
    fi
    if [ ! -f $SCRIPT_PATH/ela/.init ]; then
        echo "ERROR: please run '$(basename $BASH_SOURCE) ela init' first"
        return
    fi
    echo "Starting ela..."
    cd $SCRIPT_PATH/ela
    if [ -f ~/.node.conf ]; then
        cat ~/.node.conf | nohup ./ela 1>/dev/null 2>output &
    else
        echo "ERROR: ~/.node.conf is not exist"
        return
    fi
    sleep 1
    ela_status
}

ela_stop()
{
    echo "Stopping ela..."
    while pgrep -x ela 1>/dev/null; do
        killall ela
        sleep 1
    done
    ela_status
}

ela_status()
{
    local PID=$(pgrep -x ela)
    if [ "$PID" == "" ]; then
        echo "ela: Stopped"
        return
    fi

    local ELA_RPC_USER=$(cat $SCRIPT_PATH/ela/config.json | \
        jq -r '.Configuration.RpcConfiguration.User')
    local ELA_RPC_PASS=$(cat $SCRIPT_PATH/ela/config.json | \
        jq -r '.Configuration.RpcConfiguration.Pass')
    local ELA_CLI="$SCRIPT_PATH/ela/ela-cli \
        --rpcuser $ELA_RPC_USER --rpcpassword $ELA_RPC_PASS"

    local ELA_RAM=$(pmap $PID | tail -1 | sed 's/.* //')
    local ELA_UPTIME=$(ps --pid $PID -oetime:1=)
    local ELA_NUM_TCPS=$(lsof -n -a -itcp -p $PID | wc -l)
    local ELA_NUM_FILES=$(lsof -n -p $PID | wc -l)

    local ELA_NUM_PEERS=$($ELA_CLI info getconnectioncount)
    if [[ ! "$ELA_NUM_PEERS" =~ ^[0-9]+$ ]]; then
        ELA_NUM_PEERS=0
    fi
    local ELA_HEIGHT=$($ELA_CLI info getcurrentheight)
    if [[ ! "$ELA_HEIGHT" =~ ^[0-9]+$ ]]; then
        ELA_HEIGHT=N/A
    fi

    echo "ela: Running"
    echo "  PID:    $PID"
    echo "  RAM:    $ELA_RAM"
    echo "  Uptime: $ELA_UPTIME"
    echo "  #TCP:   $ELA_NUM_TCPS"
    echo "  #Files: $ELA_NUM_FILES"
    echo "  #Peers: $ELA_NUM_PEERS"
    echo "  Height: $ELA_HEIGHT"
    echo
}

ela_client()
{
    local ELA_RPC_USER=$(cat $SCRIPT_PATH/ela/config.json | \
        jq -r '.Configuration.RpcConfiguration.User')
    local ELA_RPC_PASS=$(cat $SCRIPT_PATH/ela/config.json | \
        jq -r '.Configuration.RpcConfiguration.Pass')
    local ELA_CLI="$SCRIPT_PATH/ela/ela-cli \
        --rpcuser $ELA_RPC_USER --rpcpassword $ELA_RPC_PASS"

    $ELA_CLI $*
}

#
# did
#
did_init()
{
    echo "Updating ${SCRIPT_PATH}/did/config.json..."
    local DID_RPC_USER=$(openssl rand -base64 100 | shasum | head -c 32)
    local DID_RPC_PASS=$(openssl rand -base64 100 | shasum | head -c 32)
    jq ".RPCUser=\"$DID_RPC_USER\" | .RPCPass=\"$DID_RPC_PASS\"" \
        ${SCRIPT_PATH}/did/config.json \
        >${SCRIPT_PATH}/did/config.json.tmp
    if [ "$?" == "0" ]; then
        mv ${SCRIPT_PATH}/did/config.json.tmp \
           ${SCRIPT_PATH}/did/config.json
    fi
    touch ${SCRIPT_PATH}/did/.init
    echo "Done"
}

did_start()
{
    if [ ! -d $SCRIPT_PATH/did/ ]; then
        echo "ERROR: $SCRIPT_PATH/did/ is not exist"
        return
    fi
    if [ ! -f $SCRIPT_PATH/did/.init ]; then
        echo "ERROR: please run '$(basename $BASH_SOURCE) did init' first"
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
    echo "Stopping did..."
    while pgrep -x did 1>/dev/null; do
        killall did
        sleep 1
    done
    did_status
}

did_status()
{
    local PID=$(pgrep -x did)
    if [ "$PID" == "" ]; then
        echo "did: Stopped"
        return
    fi

    local DID_RPC_USER=$(cat $SCRIPT_PATH/did/config.json | \
        jq -r '.RPCUser')
    local DID_RPC_PASS=$(cat $SCRIPT_PATH/did/config.json | \
        jq -r '.RPCPass')
    local DID_CLI="$SCRIPT_PATH/ela/ela-cli --rpcport 20606 \
        --rpcuser $DID_RPC_USER --rpcpassword $DID_RPC_PASS"

    local DID_RAM=$(pmap $PID | tail -1 | sed 's/.* //')
    local DID_UPTIME=$(ps --pid $PID -oetime:1=)
    local DID_NUM_TCPS=$(lsof -n -a -itcp -p $PID | wc -l)
    local DID_NUM_FILES=$(lsof -n -p $PID | wc -l)

    local DID_NUM_PEERS=$($DID_CLI info getconnectioncount)
    if [[ ! "$DID_NUM_PEERS" =~ ^[0-9]+$ ]]; then
        DID_NUM_PEERS=0
    fi
    local DID_HEIGHT=$($DID_CLI info getcurrentheight)
    if [[ ! "$DID_HEIGHT" =~ ^[0-9]+$ ]]; then
        DID_HEIGHT=N/A
    fi

    echo "did: Running"
    echo "  PID:    $PID"
    echo "  RAM:    $DID_RAM"
    echo "  Uptime: $DID_UPTIME"
    echo "  #TCP:   $DID_NUM_TCPS"
    echo "  #Files: $DID_NUM_FILES"
    echo "  #Peers: $DID_NUM_PEERS"
    echo "  Height: $DID_HEIGHT"
    echo
}

did_client()
{
    local DID_RPC_USER=$(cat $SCRIPT_PATH/did/config.json | \
        jq -r '.RPCUser')
    local DID_RPC_PASS=$(cat $SCRIPT_PATH/did/config.json | \
        jq -r '.RPCPass')
    local DID_CLI="$SCRIPT_PATH/ela/ela-cli --rpcport 20606 \
        --rpcuser $DID_RPC_USER --rpcpassword $DID_RPC_PASS"

    $DID_CLI $*
}

#
# token
#
token_init()
{
    echo "Updating ${SCRIPT_PATH}/token/config.json..."
    local TOKEN_RPC_USER=$(openssl rand -base64 100 | shasum | head -c 32)
    local TOKEN_RPC_PASS=$(openssl rand -base64 100 | shasum | head -c 32)
    jq ".RPCUser=\"$TOKEN_RPC_USER\" | .RPCPass=\"$TOKEN_RPC_PASS\"" \
        ${SCRIPT_PATH}/token/config.json \
        >${SCRIPT_PATH}/token/config.json.tmp
    if [ "$?" == "0" ]; then
        mv ${SCRIPT_PATH}/token/config.json.tmp \
           ${SCRIPT_PATH}/token/config.json
    fi
    touch ${SCRIPT_PATH}/token/.init
    echo "Done"
}

token_start()
{
    if [ ! -d $SCRIPT_PATH/token/ ]; then
        echo "ERROR: $SCRIPT_PATH/token/ is not exist"
        return
    fi
    if [ ! -f $SCRIPT_PATH/token/.init ]; then
        echo "ERROR: please run '$(basename $BASH_SOURCE) token init' first"
        return
    fi
    echo "Starting token..."
    cd $SCRIPT_PATH/token
    nohup ./token 1>/dev/null 2>output &
    sleep 1
    token_status
}

token_stop()
{
    echo "Stopping token..."
    while pgrep -x token 1>/dev/null; do
        killall token
        sleep 1
    done
    token_status
}

token_status()
{
    local PID=$(pgrep -x token)
    if [ "$PID" == "" ]; then
        echo "token: Stopped"
        return
    fi

    local TOKEN_RPC_USER=$(cat $SCRIPT_PATH/token/config.json | \
        jq -r '.RPCUser')
    local TOKEN_RPC_PASS=$(cat $SCRIPT_PATH/token/config.json | \
        jq -r '.RPCPass')
    local TOKEN_CLI="$SCRIPT_PATH/ela/ela-cli --rpcport 20616 \
        --rpcuser $TOKEN_RPC_USER --rpcpassword $TOKEN_RPC_PASS"

    local TOKEN_RAM=$(pmap $PID | tail -1 | sed 's/.* //')
    local TOKEN_UPTIME=$(ps --pid $PID -oetime:1=)
    local TOKEN_NUM_TCPS=$(lsof -n -a -itcp -p $PID | wc -l)
    local TOKEN_NUM_FILES=$(lsof -n -p $PID | wc -l)

    local TOKEN_NUM_PEERS=$($TOKEN_CLI info getconnectioncount)
    if [[ ! "$TOKEN_NUM_PEERS" =~ ^[0-9]+$ ]]; then
        TOKEN_NUM_PEERS=0
    fi
    local TOKEN_HEIGHT=$($TOKEN_CLI info getcurrentheight)
    if [[ ! "$TOKEN_HEIGHT" =~ ^[0-9]+$ ]]; then
        TOKEN_HEIGHT=N/A
    fi

    echo "token: Running"
    echo "  PID:    $PID"
    echo "  RAM:    $TOKEN_RAM"
    echo "  Uptime: $TOKEN_UPTIME"
    echo "  #TCP:   $TOKEN_NUM_TCPS"
    echo "  #Files: $TOKEN_NUM_FILES"
    echo "  #Peers: $TOKEN_NUM_PEERS"
    echo "  Height: $TOKEN_HEIGHT"
    echo
}

token_client()
{
    local TOKEN_RPC_USER=$(cat $SCRIPT_PATH/token/config.json | \
        jq -r '.RPCUser')
    local TOKEN_RPC_PASS=$(cat $SCRIPT_PATH/token/config.json | \
        jq -r '.RPCPass')
    local TOKEN_CLI="$SCRIPT_PATH/ela/ela-cli --rpcport 20616 \
        --rpcuser $TOKEN_RPC_USER --rpcpassword $TOKEN_RPC_PASS"

    $TOKEN_CLI $*
}

#
# carrier
#
carrier_init()
{
    echo "Updating ${SCRIPT_PATH}/carrier/bootstrapd.conf..."
    sed -i -e "s/external_ip.*/external_ip = \"$(public_ip)\"/" \
        ${SCRIPT_PATH}/carrier/bootstrapd.conf
    touch ${SCRIPT_PATH}/carrier/.init
    echo "Done"
}

carrier_start()
{
    if [ ! -d $SCRIPT_PATH/carrier/ ]; then
        echo "ERROR: $SCRIPT_PATH/carrier/ is not exist"
        return
    fi
    if [ ! -f $SCRIPT_PATH/carrier/.init ]; then
        echo "ERROR: please run '$(basename $BASH_SOURCE) carrier init' first"
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
    echo "Stopping carrier..."
    while pgrep -x ela-bootstrapd 1>/dev/null; do
        killall ela-bootstrapd
        sleep 1
    done
    rm $SCRIPT_PATH/carrier/var/run/ela-bootstrapd/*.pid 2>/dev/null
    carrier_status
}

carrier_status()
{
    local PID=$(pgrep -x -d ', ' ela-bootstrapd)
    if [ "$PID" == "" ]; then
        echo "carrier: Stopped"
        return
    fi

    local CARRIER_PID=$(pgrep -x ela-bootstrapd | tail -1)

    local TOKEN_RAM=$(pmap $CARRIER_PID | tail -1 | sed 's/.* //')
    local TOKEN_UPTIME=$(ps --pid $CARRIER_PID -oetime:1=)
    local TOKEN_NUM_TCPS=$(lsof -n -a -itcp -p $CARRIER_PID | wc -l)
    local TOKEN_NUM_FILES=$(lsof -n -p $CARRIER_PID | wc -l)

    echo "carrier: Running"
    echo "  PID:    $PID"
    echo "  RAM:    $TOKEN_RAM"
    echo "  Uptime: $TOKEN_UPTIME"
    echo "  #TCP:   $TOKEN_NUM_TCPS"
    echo "  #Files: $TOKEN_NUM_FILES"
    echo
}

usage()
{
    echo "Usage: $(basename $BASH_SOURCE) [Module] Command"
    echo "Elastos Node Management ($SCRIPT_PATH)"
    echo
    echo "Avaliable Modules:"
    echo
    echo "  ela"
    echo "  did"
    echo "  token"
    echo "  carrier"
    echo
    echo "Avaliable Commands:"
    echo
    echo "  init"
    echo "  start"
    echo "  stop"
    echo "  status"
    echo "  client"
    echo "  upgrade"
    echo
    echo "If no module is specified, all modules are operated."
}

#
# Main
#
SCRIPT_PATH=$(cd $(dirname $BASH_SOURCE); pwd)

check_env

if [ "$1" == "" ]; then
    usage

elif [ "$1" == "init" ]; then
    all_$1
elif [ "$1" == "all"     -a "$2" == "init" ]; then
    $1_$2
elif [ "$1" == "ela"     -a "$2" == "init" ]; then
    $1_$2
elif [ "$1" == "did"     -a "$2" == "init" ]; then
    $1_$2
elif [ "$1" == "token"   -a "$2" == "init" ]; then
    $1_$2
elif [ "$1" == "carrier" -a "$2" == "init" ]; then
    $1_$2

elif [ "$1" == "start" ]; then
    all_$1
elif [ "$1" == "all"     -a "$2" == "start" ]; then
    $1_$2
elif [ "$1" == "ela"     -a "$2" == "start" ]; then
    $1_$2
elif [ "$1" == "did"     -a "$2" == "start" ]; then
    $1_$2
elif [ "$1" == "token"   -a "$2" == "start" ]; then
    $1_$2
elif [ "$1" == "carrier" -a "$2" == "start" ]; then
    $1_$2

elif [ "$1" == "stop" ]; then
    all_$1
elif [ "$1" == "all"     -a "$2" == "stop" ]; then
    $1_$2
elif [ "$1" == "ela"     -a "$2" == "stop" ]; then
    $1_$2
elif [ "$1" == "did"     -a "$2" == "stop" ]; then
    $1_$2
elif [ "$1" == "token"   -a "$2" == "stop" ]; then
    $1_$2
elif [ "$1" == "carrier" -a "$2" == "stop" ]; then
    $1_$2

elif [ "$1" == "status" ]; then
    all_$1
elif [ "$1" == "all"     -a "$2" == "status" ]; then
    $1_$2
elif [ "$1" == "ela"     -a "$2" == "status" ]; then
    $1_$2
elif [ "$1" == "did"     -a "$2" == "status" ]; then
    $1_$2
elif [ "$1" == "token"   -a "$2" == "status" ]; then
    $1_$2
elif [ "$1" == "carrier" -a "$2" == "status" ]; then
    $1_$2

elif [ "$1" == "ela"     -a "$2" == "client" ]; then
    $1_$2 ${@:3}
elif [ "$1" == "did"     -a "$2" == "client" ]; then
    $1_$2 ${@:3}
elif [ "$1" == "token"   -a "$2" == "client" ]; then
    $1_$2 ${@:3}

elif [ "$1" == "upgrade" ]; then
    all_$1 $2
elif [ "$1" == "all"     -a "$2" == "upgrade" ]; then
    $1_$2 $3

else
    echo "ERROR: do not support: $1 $2"
fi