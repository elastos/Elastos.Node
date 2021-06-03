#!/bin/bash

#
# utility
#
echo_warn()
{
    echo -e "\033[1;33mWARNING:\033[0m $1"
}

echo_error()
{
    echo -e "\033[1;31mERROR:\033[0m $1"
}

echo_info()
{
    echo -e "\033[1;34mINFO:\033[0m $1"
}

echo_ok()
{
    echo -e "\033[1;32mOK:\033[0m $1"
}

script_update()
{
    local SCRIPT_URL=https://raw.githubusercontent.com/elastos/Elastos.ELA.Supernode/master/build/skeleton/node.sh

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

check_env()
{
    #echo "Checking OS Version..."
    local OS_VER="$(lsb_release -s -i 2>/dev/null)"
    local OS_VER="$OS_VER-$(lsb_release -s -r 2>/dev/null)"
    if [ "$OS_VER" \< "Ubuntu-18.04" ]; then
        echo_warn "this script requires Ubuntu version 18.04 or higher"
    fi

    #echo "Checking sudo permission..."
    sudo -n true 2>/dev/null
    if [ "$?" == "0" ]; then
        echo_warn "it is better to run as a normal user without sudo permission"
    fi

    jq --version 1>/dev/null 2>/dev/null
    if [ "$?" != "0" ]; then
        echo_error "cannot find jq (https://github.com/stedolan/jq)"
        echo_info "sudo apt-get install -y jq"
        exit
    fi

    if [ "$(which rotatelogs)" == "" ]; then
        echo_error "cannot find rotatelogs"
        echo_info "sudo apt-get install -y apache2-utils"
        exit
    fi
}

extip()
{
    curl -s https://checkip.amazonaws.com
}

trim()
{
    sed -e 's/^[ \t]*//' -e 's/[ \t]*$//'
}

mem_usage()
{
    if [ "$1" == "" ]; then
        return
    fi

    if [ "$(uname -s)" == "Linux" ]; then
        pmap $1 | tail -1 | sed 's/.* //'
    elif [ "$(uname -s)" == "Darwin" ]; then
        vmmap $1 | grep 'Physical footprint:' | sed 's/.* //'
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

#
# common chain functions
#
chain_prepare_stage()
{
    local CHAIN_NAME=$1

    if [ "$CHAIN_NAME" != "ela" -a \
         "$CHAIN_NAME" != "did" -a \
         "$CHAIN_NAME" != "eth" -a \
         "$CHAIN_NAME" != "arbiter" -a \
         "$CHAIN_NAME" != "carrier" -a \
         "$CHAIN_NAME" != "oracle" ]; then
        echo "ERROR: do not support chain: $1"
        return 1
    fi

    if [ "$2" == "" ]; then
        return 1
    fi

    local RELEASE_PLATFORM=$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m)
    local PATH_STAGE=$SCRIPT_PATH/.node-upload/$CHAIN_NAME
    local URL_PREFIX=https://download.elastos.org/elastos-$CHAIN_NAME

    echo "Finding the latest $CHAIN_NAME release..."
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
        read -p "Proceed upgrade (No/Yes)? " ANSWER
        if [ "$ANSWER" != "Yes" ]; then
            echo "Upgrading canceled"
            return 3
        fi
    fi

    if [ "$CHAIN_NAME" != "oracle" ]; then
        local TGZ_LATEST=elastos-${CHAIN_NAME}-${VER_LATEST}-${RELEASE_PLATFORM}.tgz
    else
        local TGZ_LATEST=elastos-${CHAIN_NAME}-${VER_LATEST}.tgz
    fi
    local URL_LATEST=$URL_PREFIX/elastos-${CHAIN_NAME}-${VER_LATEST}/${TGZ_LATEST}

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
    for i in $*; do
        tar xf $TGZ_LATEST $TAR_FLAGS --strip=1 \*/$i
        if [ "$?" != "0" ]; then
            echo "ERROR: failed to extract $TGZ_LATEST"
            return 5
        fi
    done

    return 0
}

chain_backup()
{
    local CHAIN_NAME=$1

    if [ "$CHAIN_NAME" != "ela" -a \
         "$CHAIN_NAME" != "did" -a \
         "$CHAIN_NAME" != "eth" -a \
         "$CHAIN_NAME" != "arbiter" ]; then
        echo "ERROR: do not support chain: $CHAIN_NAME"
        return 1
    fi

    local DIR_BACKUP=$SCRIPT_PATH/.node-backup/$CHAIN_NAME
    local DIR_DEPLOY=$SCRIPT_PATH/$CHAIN_NAME

    if [ -d $DIR_BACKUP ]; then
        echo "Removing $DIR_BACKUP..."
        rm -rf $DIR_BACKUP
    fi

    if [ -d $DIR_DEPLOY ]; then
        echo "Backing up $DIR_DEPLOY to $DIR_BACKUP..."
        mkdir -p $DIR_BACKUP
        rsync -a $DIR_DEPLOY/ $DIR_BACKUP/
        if [ "$?" != "0" ]; then
            echo "ERROR: rsync failed"
            return 2
        fi

        echo "Verifying the backup..."
        diff -r $DIR_DEPLOY $DIR_BACKUP
        if [ "$?" != "0" ]; then
            echo "ERROR: diff failed"
            return 3
        fi
    fi
}

#
# all
#
all_start()
{
    carrier_start
    ela_start
    did_start
    eth_start
    oracle_start
    arbiter_start
}

all_stop()
{
    arbiter_stop
    oracle_stop
    eth_stop
    did_stop
    ela_stop
    carrier_stop
}

all_status()
{
    ela_status
    did_status
    eth_status
    oracle_status
    arbiter_status
    carrier_status
}

all_upgrade()
{
    ela_upgrade
    did_upgrade
    eth_upgrade
    oracle_upgrade
    arbiter_upgrade
    carrier_upgrade
}

all_init()
{
    ela_init
    did_init
    eth_init
    oracle_init
    arbiter_init
    carrier_init
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
    echo "Stopping ela..."
    while pgrep -x ela 1>/dev/null; do
        killall ela
        sleep 1
    done
    ela_status
}

ela_status()
{
    local ELA_VER="ela $($SCRIPT_PATH/ela/ela -v | sed 's/.* //')"

    local PID=$(pgrep -x ela)
    if [ "$PID" == "" ]; then
        echo "$ELA_VER: Stopped"
        return
    fi

    local ELA_RPC_USER=$(cat $SCRIPT_PATH/ela/config.json | \
        jq -r '.Configuration.RpcConfiguration.User')
    local ELA_RPC_PASS=$(cat $SCRIPT_PATH/ela/config.json | \
        jq -r '.Configuration.RpcConfiguration.Pass')
    local ELA_CLI="$SCRIPT_PATH/ela/ela-cli \
        --rpcuser $ELA_RPC_USER --rpcpassword $ELA_RPC_PASS"

    local ELA_RAM=$(mem_usage $PID)
    local ELA_UPTIME=$(ps -oetime= -p $PID | trim)
    local ELA_NUM_TCPS=$(lsof -n -a -itcp -p $PID | wc -l | trim)
    local ELA_NUM_FILES=$(lsof -n -p $PID | wc -l | trim)

    local ELA_NUM_PEERS=$($ELA_CLI info getconnectioncount)
    if [[ ! "$ELA_NUM_PEERS" =~ ^[0-9]+$ ]]; then
        ELA_NUM_PEERS=0
    fi
    local ELA_HEIGHT=$($ELA_CLI info getcurrentheight)
    if [[ ! "$ELA_HEIGHT" =~ ^[0-9]+$ ]]; then
        ELA_HEIGHT=N/A
    fi

    echo "$ELA_VER: Running"
    echo "  PID:    $PID"
    echo "  RAM:    $ELA_RAM"
    echo "  Uptime: $ELA_UPTIME"
    echo "  #TCP:   $ELA_NUM_TCPS"
    echo "  #Files: $ELA_NUM_FILES"
    echo "  #Peers: $ELA_NUM_PEERS"
    echo "  Height: $ELA_HEIGHT"
    echo
}

ela_upgrade()
{
    unset OPTIND
    while getopts "bny" OPTION; do
        case $OPTION in
            b)
                local BACKUP_BEFORE_UPGRADE=1
                ;;
            n)
                local NO_START_AFTER_UPGRADE=1
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

    if [ $BACKUP_BEFORE_UPGRADE ]; then
        chain_backup ela
        if [ "$?" != "0" ]; then
            return
        fi
    fi

    mkdir -p $DIR_DEPLOY
    cp -v $PATH_STAGE/ela $DIR_DEPLOY/
    cp -v $PATH_STAGE/ela-cli $DIR_DEPLOY/

    # Start program, if 1 and 2
    # 1. ela was Running before the upgrade
    # 2. user prefer not start ela explicitly
    if [ $PID ] && [ "$NO_START_AFTER_UPGRADE" == "" ]; then
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
        ela_upgrade -y
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
      "IPAddress": "127.0.0.1"
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

        sed -i -e "s/\"IPAddress\":.*/\"IPAddress\": \"$(extip)\"/" $ELA_CONFIG
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

#
# did
#
did_start()
{
    if [ ! -f $SCRIPT_PATH/did/did ]; then
        echo "ERROR: $SCRIPT_PATH/did/did is not exist"
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
    # TODO: did support -v; dump version
    local DID_VER="did"

    local PID=$(pgrep -x did)
    if [ "$PID" == "" ]; then
        echo "$DID_VER: Stopped"
        return
    fi

    local DID_RPC_USER=$(cat $SCRIPT_PATH/did/config.json | \
        jq -r '.RPCUser')
    local DID_RPC_PASS=$(cat $SCRIPT_PATH/did/config.json | \
        jq -r '.RPCPass')
    local DID_CLI="$SCRIPT_PATH/ela/ela-cli --rpcport 20606 \
        --rpcuser $DID_RPC_USER --rpcpassword $DID_RPC_PASS"

    local DID_RAM=$(mem_usage $PID)
    local DID_UPTIME=$(ps -oetime= -p $PID | trim)
    local DID_NUM_TCPS=$(lsof -n -a -itcp -p $PID | wc -l | trim)
    local DID_NUM_FILES=$(lsof -n -p $PID | wc -l | trim)

    local DID_NUM_PEERS=$($DID_CLI info getconnectioncount)
    if [[ ! "$DID_NUM_PEERS" =~ ^[0-9]+$ ]]; then
        DID_NUM_PEERS=0
    fi
    local DID_HEIGHT=$($DID_CLI info getcurrentheight)
    if [[ ! "$DID_HEIGHT" =~ ^[0-9]+$ ]]; then
        DID_HEIGHT=N/A
    fi

    echo "$DID_VER: Running"
    echo "  PID:    $PID"
    echo "  RAM:    $DID_RAM"
    echo "  Uptime: $DID_UPTIME"
    echo "  #TCP:   $DID_NUM_TCPS"
    echo "  #Files: $DID_NUM_FILES"
    echo "  #Peers: $DID_NUM_PEERS"
    echo "  Height: $DID_HEIGHT"
    echo
}

did_upgrade()
{
    unset OPTIND
    while getopts "bny" OPTION; do
        case $OPTION in
            b)
                local BACKUP_BEFORE_UPGRADE=1
                ;;
            n)
                local NO_START_AFTER_UPGRADE=1
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

    if [ $BACKUP_BEFORE_UPGRADE ]; then
        chain_backup did
        if [ "$?" != "0" ]; then
            return
        fi
    fi

    mkdir -p $DIR_DEPLOY
    cp -v $PATH_STAGE/did $DIR_DEPLOY/

    if [ $PID ] && [ "$NO_START_AFTER_UPGRADE" == "" ]; then
        did_start
    fi
}

did_init()
{
    local DID_CONFIG=${SCRIPT_PATH}/did/config.json

    if [ ! -f ${SCRIPT_PATH}/did/did ]; then
        did_upgrade -y
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

    local PAY_TO_ADDR=
    # TODO: add description
    read -p '? PayToAddr: ' PAY_TO_ADDR

    local MINER_INFO=
    # TODO: add description
    read -p '? MinerInfo: ' MINER_INFO

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
# eth
#
eth_start()
{
    if [ ! -f $SCRIPT_PATH/eth/geth ]; then
        echo "ERROR: $SCRIPT_PATH/eth/geth is not exist"
        return
    fi

    while [ "$1" ]; do
        if [ "$1" == "testnet" ]; then
            local GETH_OPTS=--testnet
        elif [ "$1" == "blockscout" ]; then
            local FOR_BLOCKSCOUT=1
        else
            echo "ERROR: do not support $1"
            return
        fi
        shift
    done

    echo "Starting eth..."
    cd $SCRIPT_PATH/eth
    mkdir -p $SCRIPT_PATH/eth/logs/

    #rm -rf $SCRIPT_PATH/eth/data/geth
    #rm -rf $SCRIPT_PATH/eth/data/header
    #rm -rf $SCRIPT_PATH/eth/data/store
    #rm -rf $SCRIPT_PATH/eth/data/spv_transaction_info.db

    if [ -f ~/.config/elastos/eth.txt ]; then
        nohup $SHELL -c "./geth \
            $GETH_OPTS \
            --allow-insecure-unlock \
            --datadir $SCRIPT_PATH/eth/data \
            --mine \
            --miner.threads 1 \
            --password ~/.config/elastos/eth.txt \
            --pbft.keystore ${SCRIPT_PATH}/ela/keystore.dat \
            --pbft.keystore.password ~/.config/elastos/ela.txt \
            --pbft.net.address '$(extip)' \
            --pbft.net.port 20639 \
            --rpc \
            --rpcaddr '0.0.0.0' \
            --rpcapi 'personal,db,eth,net,web3,txpool,miner' \
            --rpcvhosts '*' \
            --unlock '0x$(cat $SCRIPT_PATH/eth/data/keystore/UTC* | jq -r .address)' \
            2>&1 \
            | rotatelogs $SCRIPT_PATH/eth/logs/geth-%Y-%m-%d-%H_%M_%S.log 20M" &
    elif [ "$FOR_BLOCKSCOUT" ]; then
        nohup $SHELL -c "./geth \
            $GETH_OPTS \
            --datadir $SCRIPT_PATH/eth/data \
            --gcmode archive \
            --nousb \
            --rpc \
            --rpcaddr '0.0.0.0' \
            --rpcapi 'admin,debug,eth,net,personal,txpool,web3' \
            --rpcvhosts '*' \
            --syncmode full \
            --ws \
            --wsaddr '0.0.0.0' \
            --wsorigins '*' \
            2>&1 \
            | rotatelogs $SCRIPT_PATH/eth/logs/geth-%Y-%m-%d-%H_%M_%S.log 20M" &
    else
        nohup $SHELL -c "./geth \
            $GETH_OPTS \
            --datadir $SCRIPT_PATH/eth/data \
            --lightserv 10 \
            --rpc \
            --rpcaddr '0.0.0.0' \
            --rpcapi 'eth,web3,admin,txpool' \
            --rpcvhosts '*' \
            2>&1 \
            | rotatelogs $SCRIPT_PATH/eth/logs/geth-%Y-%m-%d-%H_%M_%S.log 20M" &
    fi

    sleep 3
    eth_status
}

eth_stop()
{
    echo "Stopping eth..."
    while pgrep -x geth 1>/dev/null; do
        local PID=$(pgrep -x geth)
        kill -s SIGINT $PID
        sleep 1
    done
    eth_status
}

eth_status()
{
    # TODO: dump version
    local PID=$(pgrep -x geth)
    if [ "$PID" == "" ]; then
        echo "eth: Stopped"
        return
    fi

    local ETH_CLI=

    local ETH_RAM=$(mem_usage $PID)
    local ETH_UPTIME=$(ps -oetime= -p $PID | trim)
    local ETH_NUM_TCPS=$(lsof -n -a -itcp -p $PID | wc -l | trim)
    local ETH_NUM_FILES=$(lsof -n -p $PID | wc -l | trim)

    local ETH_NUM_PEERS=$(curl -s -H 'Content-Type: application/json' \
        -X POST --data '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' \
        http://127.0.0.1:20636 | jq -r '.result')
    ETH_NUM_PEERS=$(($ETH_NUM_PEERS))
    if [[ ! "$ETH_NUM_PEERS" =~ ^[0-9]+$ ]]; then
        ETH_NUM_PEERS=0
    fi
    local ETH_HEIGHT=$(curl -s -H 'Content-Type: application/json' \
        -X POST --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
        http://127.0.0.1:20636 | jq -r '.result')
    ETH_HEIGHT=$(($ETH_HEIGHT))
    if [[ ! "$ETH_HEIGHT" =~ ^[0-9]+$ ]]; then
        ETH_HEIGHT=N/A
    fi

    echo "eth: Running"
    echo "  PID:    $PID"
    echo "  RAM:    $ETH_RAM"
    echo "  Uptime: $ETH_UPTIME"
    echo "  #TCP:   $ETH_NUM_TCPS"
    echo "  #Files: $ETH_NUM_FILES"
    echo "  #Peers: $ETH_NUM_PEERS"
    echo "  Height: $ETH_HEIGHT"
    echo
}

eth_upgrade()
{
    unset OPTIND
    while getopts "bny" OPTION; do
        case $OPTION in
            b)
                local BACKUP_BEFORE_UPGRADE=1
                ;;
            n)
                local NO_START_AFTER_UPGRADE=1
                ;;
            y)
                local YES_TO_ALL=1
                ;;
        esac
    done

    chain_prepare_stage eth geth
    if [ "$?" != "0" ]; then
        return
    fi

    local PATH_STAGE=$SCRIPT_PATH/.node-upload/eth
    local DIR_DEPLOY=$SCRIPT_PATH/eth

    local PID=$(pgrep -x geth)
    if [ $PID ]; then
        oracle_stop
        eth_stop
    fi

    if [ $BACKUP_BEFORE_UPGRADE ]; then
        chain_backup eth
        if [ "$?" != "0" ]; then
            return
        fi
    fi

    mkdir -p $DIR_DEPLOY
    cp -v $PATH_STAGE/geth $DIR_DEPLOY/

    if [ $PID ] && [ "$NO_START_AFTER_UPGRADE" == "" ]; then
        eth_start
        oracle_start
    fi
}

eth_init()
{
    if [ ! -f ${SCRIPT_PATH}/ela/.init ]; then
        echo_error "ela not initialzed"
        return
    fi

    local ETH_KEYSTORE=
    local ETH_KEYSTORE_PASS_FILE=~/.config/elastos/eth.txt

    if [ ! -f ${SCRIPT_PATH}/eth/geth ]; then
        eth_upgrade -y
    fi

    if [ -f $SCRIPT_PATH/eth/.init ]; then
        echo_error "eth has already been initialized"
        return
    fi

    local ETH_NUM_ACCOUNTS=$(./geth --datadir "~/node/eth/data/" \
        --nousb --verbosity 0 account list | wc -l)
    if [ $ETH_NUM_ACCOUNTS -ge 1 ]; then
        echo_error "eth keystore file exist"
        return
    fi

    if [ -f "$ETH_KEYSTORE_PASS_FILE" ]; then
        echo_error "$ETH_KEYSTORE_PASS_FILE exist"
        return
    fi

    echo "Creating eth keystore..."
    gen_pass
    if [ "$KEYSTORE_PASS" == "" ]; then
        echo_error "empty password"
        exit
    fi

    echo "Saving eth keystore password..."
    mkdir -p $(dirname $ETH_KEYSTORE_PASS_FILE)
    chmod 700 $(dirname $ETH_KEYSTORE_PASS_FILE)
    echo $KEYSTORE_PASS > $ETH_KEYSTORE_PASS_FILE
    chmod 600 $ETH_KEYSTORE_PASS_FILE

    cd ${SCRIPT_PATH}/eth
    ./geth --datadir "~/node/eth/data/" --verbosity 0 account new \
        --password "$ETH_KEYSTORE_PASS_FILE" >/dev/null
    if [ "$?" != "0" ]; then
        echo "ERROR: failed to create eth keystore"
        return
    fi

    echo "Checking eth keystore..."
    local ETH_KEYSTORE=$(./geth --datadir "~/node/eth/data/" \
        --nousb --verbosity 0 account list | sed 's/.*keystore:\/\///')
    chmod 600 $ETH_KEYSTORE

    echo_info "eth keystore file: $ETH_KEYSTORE"
    echo_info "eth keystore password file: $ETH_KEYSTORE_PASS_FILE"

    touch ${SCRIPT_PATH}/eth/.init
    echo_ok "eth initialized"
    echo
}

#
# oracle
#
oracle_start()
{
    export PATH=~/node/extern/node-v14.17.0-linux-x64/bin:$PATH
    export PATH=~/node/eth/oracle/node_modules/pm2/bin:$PATH

    if [ ! -f $SCRIPT_PATH/eth/oracle/crosschain_oracle.js ]; then
        echo "ERROR: $SCRIPT_PATH/eth/oracle/crosschain_oracle.js is not exist"
        return
    fi

    echo "Starting oracle..."
    cd $SCRIPT_PATH/eth/oracle
    mkdir -p $SCRIPT_PATH/eth/logs

    export env=mainnet
    pm2 -s start $SCRIPT_PATH/eth/oracle/crosschain_oracle.js -i 1 \
        -e $SCRIPT_PATH/eth/logs/oracle_err.log \
        -o $SCRIPT_PATH/eth/logs/oracle_out.log

    sleep 1
    oracle_status
}

oracle_stop()
{
    export PATH=~/node/extern/node-v14.17.0-linux-x64/bin:$PATH
    export PATH=~/node/eth/oracle/node_modules/pm2/bin:$PATH

    if [ ! -f $SCRIPT_PATH/eth/oracle/crosschain_oracle.js ]; then
        echo "ERROR: $SCRIPT_PATH/eth/oracle/crosschain_oracle.js is not exist"
        return
    fi

    echo "Stopping oracle..."
    cd $SCRIPT_PATH/eth/oracle
    mkdir -p $SCRIPT_PATH/eth/logs

    pm2 -s stop $SCRIPT_PATH/eth/oracle/crosschain_oracle.js

    sleep 1
    oracle_status
}

oracle_status()
{
    export PATH=~/node/extern/node-v14.17.0-linux-x64/bin:$PATH
    export PATH=~/node/eth/oracle/node_modules/pm2/bin:$PATH

    cd $SCRIPT_PATH/eth/oracle
    echo "oracle:"
    pm2 status
    echo
}

oracle_upgrade()
{
    unset OPTIND
    while getopts "ny" OPTION; do
        case $OPTION in
            n)
                local NO_START_AFTER_UPGRADE=1
                ;;
            y)
                local YES_TO_ALL=1
                ;;
        esac
    done

    chain_prepare_stage oracle '*.js' '*.sh'
    if [ "$?" != "0" ]; then
        return
    fi

    local PATH_STAGE=$SCRIPT_PATH/.node-upload/oracle
    local DIR_DEPLOY=$SCRIPT_PATH/eth/oracle

    mkdir -p $DIR_DEPLOY
    cp -v $PATH_STAGE/*.js $DIR_DEPLOY/
    cp -v $PATH_STAGE/*.sh $DIR_DEPLOY/

    if [ $PID ] && [ "$NO_START_AFTER_UPGRADE" == "" ]; then
        oracle_start
    fi
}

oracle_init()
{
    if [ ! -f ${SCRIPT_PATH}/eth/.init ]; then
        echo_error "eth not initialzed"
        return
    fi

    if [ ! -f $SCRIPT_PATH/eth/oracle/crosschain_oracle.js ]; then
        oracle_upgrade -y
    fi

    if [ -f $SCRIPT_PATH/eth/oracle/.init ]; then
        echo_error "oracle has already been initialized"
        return
    fi

    if [ ! -d ~/node/extern/node-v14.17.0-linux-x64 ]; then
        mkdir -p ~/node/extern
        cd ~/node/extern
        curl -O -# https://nodejs.org/download/release/latest-v14.x/node-v14.17.0-linux-x64.tar.xz
        tar xf node-v14.17.0-linux-x64.tar.xz
    fi

    export PATH=~/node/extern/node-v14.17.0-linux-x64/bin:$PATH

    mkdir -p $SCRIPT_PATH/eth/oracle
    cd $SCRIPT_PATH/eth/oracle
    npm install pm2 web3 express

    touch ${SCRIPT_PATH}/eth/oracle/.init
    echo_ok "oracle initialized"
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

    echo "Starting arbiter..."
    cd $SCRIPT_PATH/arbiter

    until pgrep -x arbiter 1>/dev/null; do
        if [ -f ~/.config/elastos/ela.txt ]; then
            cat ~/.config/elastos/ela.txt | nohup ./arbiter 1>/dev/null 2>output &
        else
            nohup ./arbiter 1>/dev/null 2>output &
        fi
        echo "Waiting ela, did, oracle..."
        sleep 5
    done

    arbiter_status
}

arbiter_stop()
{
    echo "Stopping arbiter..."
    while pgrep -x arbiter 1>/dev/null; do
        killall arbiter
        sleep 1
    done
    arbiter_status
}

# issue: peers 0, height 0
arbiter_status()
{
    local ARBITER_VER="arbiter"
    # TODO: did support -v; dump version
    local PID=$(pgrep -x arbiter)
    if [ "$PID" == "" ]; then
        echo "$ARBITER_VER: Stopped"
        return
    fi

    local ARBITER_RPC_USER=$(cat $SCRIPT_PATH/arbiter/config.json | \
        jq -r '.Configuration.RpcConfiguration.User')
    local ARBITER_RPC_PASS=$(cat $SCRIPT_PATH/arbiter/config.json | \
        jq -r '.Configuration.RpcConfiguration.Pass')
    local ARBITER_CLI="$SCRIPT_PATH/ela/ela-cli --rpcport 20536 \
        --rpcuser $ARBITER_RPC_USER --rpcpassword $ARBITER_RPC_PASS"

    local ARBITER_RAM=$(mem_usage $PID)
    local ARBITER_UPTIME=$(ps -oetime= -p $PID | trim)
    local ARBITER_NUM_TCPS=$(lsof -n -a -itcp -p $PID | wc -l | trim)
    local ARBITER_NUM_FILES=$(lsof -n -p $PID | wc -l | trim)

    local ARBITER_NUM_PEERS=$($ARBITER_CLI info getconnectioncount)
    if [[ ! "$ARBITER_NUM_PEERS" =~ ^[0-9]+$ ]]; then
        ARBITER_NUM_PEERS=0
    fi
    local ARBITER_HEIGHT=$($ARBITER_CLI info getcurrentheight)
    if [[ ! "$ARBITER_HEIGHT" =~ ^[0-9]+$ ]]; then
        ARBITER_HEIGHT=N/A
    fi

    echo "$ARBITER_VER: Running"
    echo "  PID:    $PID"
    echo "  RAM:    $ARBITER_RAM"
    echo "  Uptime: $ARBITER_UPTIME"
    echo "  #TCP:   $ARBITER_NUM_TCPS"
    echo "  #Files: $ARBITER_NUM_FILES"
    echo "  #Peers: $ARBITER_NUM_PEERS"
    echo "  Height: $ARBITER_HEIGHT"
    echo
}

arbiter_upgrade()
{
    unset OPTIND
    while getopts "bny" OPTION; do
        case $OPTION in
            b)
                local BACKUP_BEFORE_UPGRADE=1
                ;;
            n)
                local NO_START_AFTER_UPGRADE=1
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

    if [ $BACKUP_BEFORE_UPGRADE ]; then
        chain_backup arbiter
        if [ "$?" != "0" ]; then
            return
        fi
    fi

    mkdir -p $DIR_DEPLOY
    cp -v $PATH_STAGE/arbiter $DIR_DEPLOY/

    if [ $PID ] && [ "$NO_START_AFTER_UPGRADE" == "" ]; then
        arbiter_start
    fi
}

arbiter_init()
{
    if [ ! -f $SCRIPT_PATH/ela/.init ]; then
        echo_error "ela not initialzed"
        return
    fi
    if [ ! -f $SCRIPT_PATH/did/.init ]; then
        echo_error "did not initialzed"
        return
    fi
    if [ ! -f $SCRIPT_PATH/eth/oracle/.init ]; then
        echo_error "oracle not initialzed"
        return
    fi

    local ELA_CONFIG=${SCRIPT_PATH}/ela/config.json
    local DID_CONFIG=${SCRIPT_PATH}/did/config.json
    local ARBITER_CONFIG=${SCRIPT_PATH}/arbiter/config.json

    if [ ! -f ${SCRIPT_PATH}/arbiter/arbiter ]; then
        arbiter_upgrade -y
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
        "SyncStartHeight": 401000,
        "ExchangeRate": 1.0,
        "GenesisBlock": "56be936978c261b2e649d58dbfaf3f23d4a868274f5522cd2adb4308a955c4a3",
        "MiningAddr": "",
        "PowChain": true,
        "PayToAddr": ""
      },
      {
        "Rpc": {
          "IpAddress": "127.0.0.1",
          "HttpJsonPort": 20632,
          "User": "",
          "Pass": ""
        },
        "SyncStartHeight": 2515000,
        "ExchangeRate": 1.0,
        "GenesisBlock": "6afc2eb01956dfe192dc4cd065efdf6c3c80448776ca367a7246d279e228ff0a",
        "MiningAddr": "",
        "PowChain": false,
        "PayToAddr": ""
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

    # Arbiter Config: ETH
    local MINING_ADDR_ETH=$(./ela-cli wallet add -p $KEYSTORE_PASS | \
        sed -n '3p' | sed 's/ .*//')

    # Arbiter Config: Arbiter RPC
    echo "Generating random userpass for arbiter RPC interface..."
    local ARBITER_RPC_USER=$(openssl rand -base64 100 | shasum | head -c 32)
    local ARBITER_RPC_PASS=$(openssl rand -base64 100 | shasum | head -c 32)

    local PAY_TO_ADDR=
    # TODO: add description
    read -p '? PayToAddr: ' PAY_TO_ADDR

    echo "Updating arbiter config file..."
    jq ".Configuration.MainNode.Rpc.User=\"$ELA_RPC_USER\"              | \
        .Configuration.MainNode.Rpc.Pass=\"$ELA_RPC_PASS\"              | \
        .Configuration.SideNodeList[0].Rpc.User=\"$DID_RPC_USER\"       | \
        .Configuration.SideNodeList[0].Rpc.Pass=\"$DID_RPC_PASS\"       | \
        .Configuration.SideNodeList[0].MiningAddr=\"$MINING_ADDR_DID\"  | \
        .Configuration.SideNodeList[0].PayToAddr=\"$PAY_TO_ADDR\"       | \
        .Configuration.SideNodeList[1].MiningAddr=\"$MINING_ADDR_ETH\"  | \
        .Configuration.SideNodeList[1].PayToAddr=\"$PAY_TO_ADDR\"       | \
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
    local CARRIER_VER="carrier $($SCRIPT_PATH/carrier/ela-bootstrapd -v | tail -1 | sed "s/.* //")"

    local PID=$(pgrep -x -d ', ' ela-bootstrapd)
    if [ "$PID" == "" ]; then
        echo "$CARRIER_VER: Stopped"
        return
    fi

    local CARRIER_PID=$(pgrep -x ela-bootstrapd | tail -1)
    local CARRIER_RAM=$(pmap $CARRIER_PID | tail -1 | sed 's/.* //')
    local CARRIER_UPTIME=$(ps --pid $CARRIER_PID -oetime:1=)
    local CARRIER_NUM_TCPS=$(lsof -n -a -itcp -p $CARRIER_PID | wc -l)
    local CARRIER_NUM_FILES=$(lsof -n -p $CARRIER_PID | wc -l)

    echo "$CARRIER_VER: Running"
    echo "  PID:    $CARRIER_PID"
    echo "  RAM:    $CARRIER_RAM"
    echo "  Uptime: $CARRIER_UPTIME"
    echo "  #TCP:   $CARRIER_NUM_TCPS"
    echo "  #Files: $CARRIER_NUM_FILES"
    echo
}

carrier_upgrade()
{
    unset OPTIND
    while getopts "bny" OPTION; do
        case $OPTION in
            b)
                local BACKUP_BEFORE_UPGRADE=1
                ;;
            n)
                local NO_START_AFTER_UPGRADE=1
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

    local PID=$(pgrep -x -d ', ' ela-bootstrapd)
    if [ $PID ]; then
        carrier_stop
    fi

    if [ $BACKUP_BEFORE_UPGRADE ]; then
        chain_backup carrier
        if [ "$?" != "0" ]; then
            return
        fi
    fi

    mkdir -p $DIR_DEPLOY
    cp -v $PATH_STAGE/usr/bin/ela-bootstrapd $DIR_DEPLOY/

    if [ $PID ] && [ "$NO_START_AFTER_UPGRADE" == "" ]; then
        carrier_start
    fi
}

carrier_init()
{
    local CARRIER_CONFIG=${SCRIPT_PATH}/carrier/bootstrapd.conf

    if [ ! -f $SCRIPT_PATH/carrier/ela-bootstrapd ]; then
        carrier_upgrade -y
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
    echo "Usage: $(basename $BASH_SOURCE) [CHAIN] COMMAND [OPTIONS]"
    echo "ELA Management ($SCRIPT_PATH)"
    echo
    echo "Available Chains:"
    echo
    echo "  all"
    echo "  ela"
    echo "  did"
    echo "  eth"
    echo "  oracle"
    echo "  arbiter"
    echo "  carrier"
    echo
    echo "Available Commands:"
    echo
    echo "  start"
    echo "  stop"
    echo "  status"
    echo "  upgrade [-b] [-y] [-n]"
    echo "  init"
    echo
}

#
# Main
#
SCRIPT_PATH=$(cd $(dirname $BASH_SOURCE); pwd)

check_env

if [ "$1" == "" ]; then
    usage
    exit
fi

if [ "$1" == "script_update" ]; then
    script_update
    exit
fi

if [ "$1" == "init"    ] || \
   [ "$1" == "start"   ] || \
   [ "$1" == "stop"    ] || \
   [ "$1" == "status"  ] || \
   [ "$1" == "upgrade" ]; then

    # operate on all chains
    all_$1
else
    # operate on a single chain

    if [ "$1" != "ela" -a \
         "$1" != "did" -a \
         "$1" != "eth" -a \
         "$1" != "oracle" -a \
         "$1" != "arbiter" -a \
         "$1" != "carrier" ]; then
        echo "ERROR: do not support chain: $1"
        exit
    fi
    CHAIN_NAME=$1

    if [ "$2" == "" ]; then
        echo "ERROR: no command specified"
        exit
    elif [ "$2" != "start" -a \
           "$2" != "stop" -a \
           "$2" != "status" -a \
           "$2" != "upgrade" -a \
           "$2" != "init" ]; then
        echo "ERROR: do not support command: $2"
        exit
    fi
    COMMAND=$2

    shift 2

    ${CHAIN_NAME}_${COMMAND} $*
fi