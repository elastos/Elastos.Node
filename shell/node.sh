#!/bin/bash

#
# all
#
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

all_deploy()
{
    ela_deploy
    did_deploy
    token_deploy
    carrier_deploy
}

all_status()
{
    ela_status
    did_status
    token_status
    carrier_status
}

#
# ela
#
ela_start()
{
    if [ ! -d $SCRIPT_PATH/ela/ ]; then
        echo "ERROR: $SCRIPT_PATH/ela/ is not exist"
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

ela_deploy()
{
    if [ ! -d $SCRIPT_PATH/ela/ ]; then
        echo "ERROR: $SCRIPT_PATH/ela/ is not exist"
        return
    fi
    echo "Deploy ela..."
    ela_stop
    cd $SCRIPT_PATH/ela
    cp ~/deploy/ela .
    cp ~/deploy/ela-cli .
    ela_start
}

ela_status()
{
    local PID=$(pgrep -x ela)
    if [ $PID ]; then
        echo "ela: Running, $PID"
    else
        echo "ela: Stopped"
    fi
}

#
# did
#
did_start()
{
    if [ ! -d $SCRIPT_PATH/did/ ]; then
        echo "ERROR: $SCRIPT_PATH/did/ is not exist"
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

did_deploy()
{
    if [ ! -d $SCRIPT_PATH/did/ ]; then
        echo "ERROR: $SCRIPT_PATH/did/ is not exist"
        return
    fi
    echo "Deploy did..."
    did_stop
    cd $SCRIPT_PATH/did
    cp ~/deploy/did .
    did_start
}

did_status()
{
    local PID=$(pgrep -x did)
    if [ $PID ]; then
        echo "did: Running, $PID"
    else
        echo "did: Stopped"
    fi
}

#
# token
#
token_start()
{
    if [ ! -d $SCRIPT_PATH/token/ ]; then
        echo "ERROR: $SCRIPT_PATH/token/ is not exist"
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

token_deploy()
{
    if [ ! -d $SCRIPT_PATH/token/ ]; then
        echo "ERROR: $SCRIPT_PATH/token is not exist"
        return
    fi
    echo "Deploy token..."
    token_stop
    cd $SCRIPT_PATH/token
    cp ~/deploy/token .
    token_start
}

token_status()
{
    local PID=$(pgrep -x token)
    if [ $PID ]; then
        echo "token: Running, $PID"
    else
        echo "token: Stopped"
    fi
}

#
# carrier
#
carrier_start()
{
    if [ ! -d $SCRIPT_PATH/carrier/ ]; then
        echo "ERROR: $SCRIPT_PATH/carrier/ is not exist"
        return
    fi
    echo "Starting carrier..."
    cd $SCRIPT_PATH/carrier
    while [ -f $SCRIPT_PATH/carrier/run/ela-bootstrapd.pid ] || [ -f $SCRIPT_PATH/carrier/run/turnserver.pid ]; do
        carrier_stop
    done
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
    cd $SCRIPT_PATH/carrier/run
    rm *.pid
    carrier_status
}

carrier_deploy()
{
    if [ ! -d $SCRIPT_PATH/carrier/ ]; then
        echo "ERROR: $SCRIPT_PATH/carrier is not exist"
        return
    fi
    echo "Deploy carrier..."
    carrier_stop
    cd $SCRIPT_PATH/carrier
    cp ~/deploy/carrier/ela-bootstrapd .
    carrier_start
}

carrier_status()
{
    local COUNT=$(pgrep -x ela-bootstrapd | wc -l)
    if [ $COUNT -gt 0 ]; then
        echo "carrier: Running, $COUNT"
    else
        echo "carrier: Stopped"
    fi
}

usage()
{
    echo "Usage: $(basename $BASH_SOURCE) CHAIN COMMAND"
    echo "ELA Management ($SCRIPT_PATH)"
    echo
    echo "Avaliable Chain"
    echo
    echo "  all"
    echo "  ela"
    echo "  did"
    echo "  token"
    echo "  carrier"
    echo
    echo "Avaliable Commands:"
    echo
    echo "  start"
    echo "  stop"
    echo "  deploy"
    echo "  status"
    echo
}

init()
{
    echo "=== 1. create keystore.dat ==="
    cd ${SCRIPT_PATH}/ela/
    echo -n "Please enter your password for keystore.dat:"
    stty -echo
    read password
    stty echo

    echo "create keystore.dat"
    ./ela-cli wallet create -p $password
    echo ${password} > ~/.node.conf
    echo
    echo "=== 2. modify the configuration file ==="
    echo -n "Please enter your IP or domain name:"
    read ip
    sed -i -e "/IPAddress/ s/192.168.0.1/${ip}/" ${SCRIPT_PATH}/ela/config.json
    sed -i -e "/external_ip/ s/X.X.X.X/${ip}/" ${SCRIPT_PATH}/carrier/bootstrapd.conf
    echo "Initialization successful"
}

#
# Main
#
SCRIPT_PATH=$(cd $(dirname $BASH_SOURCE); pwd)

if [ "$1" == "" ]; then
    usage
    exit
elif [ "$1" == "init" ]; then
    init
    exit
elif [ "$1" == "start" ]; then
    all_start
    exit
elif [ "$1" == "stop" ]; then
    all_stop
    exit
elif [ "$1" == "status" ]; then
    all_status
    exit
fi

if [ "$1" != "all" -a \
     "$1" != "ela" -a \
     "$1" != "did" -a \
     "$1" != "token" -a \
     "$1" != "carrier" ]; then
    echo "ERROR: do not support chain: $1"
    exit
fi

if [ "$2" != "start" -a \
     "$2" != "stop" -a \
     "$2" != "deploy" -a \
     "$2" != "status" ]; then
    echo "ERROR: do not support command: $2"
    exit
fi

$1_$2