#!/bin/bash

chkenv()
{
    local OS_VER="$(lsb_release -s -i 2>/dev/null)"
    local OS_VER="${OS_VER}_$(lsb_release -s -r 2>/dev/null)"

    if [ "$(uname -sm)" != "Linux x86_64" ]; then
        echo "ERROR: this script requires Ubuntu 18.04 (x86_64) or higher"
        exit
    fi

    if [ "$OS_VER" \< "Ubuntu_18.04" ]; then
        echo "ERROR: this script requires Ubuntu 18.04 (x86_64) or higher"
        exit
    fi
}

setenv_carrier()
{
    # Ref: https://github.com/elastos/Elastos.NET.Carrier.Bootstrap/blob/master/README.md
    local CARRIER_DEPS="build-essential autoconf automake autopoint \
        libtool bison texinfo pkg-config cmake"
    for i in $CARRIER_DEPS; do
        dpkg -s $i 1>/dev/null 2>/dev/null
        if [ "$?" != "0" ]; then
            sudo apt-get update -yq 1>/dev/null
            sudo apt-get install -yq $i
        fi
    done
}

setenv_go()
{
    if [ "$1" != "1.13.8" ] && \
       [ "$1" != "1.16.5" ]; then
        return
    fi

    local GO_VER=$1

    export GOROOT=$DEV_ROOT/build/go$GO_VER.linux-amd64

    if [ ! -d $GOROOT ]; then
        local GO_TGZ_URL=https://dl.google.com/go/go$GO_VER.linux-amd64.tar.gz
        if [ "$GO_VER" == "1.13.8" ]; then
            local GO_TGZ_SHA256=0567734d558aef19112f2b2873caa0c600f1b4a5827930eb5a7f35235219e9d8
        elif [ "$GO_VER" == "1.16.5" ]; then
            local GO_TGZ_SHA256=b12c23023b68de22f74c0524f10b753e7b08b1504cb7e417eccebdd3fae49061
        fi
        local GO_TGZ=${GO_TGZ_URL##*/}

        cd $DEV_ROOT/build
        echo "Downloading $GO_TGZ..."
        curl -O# $GO_TGZ_URL
        if [ "$?" != "0" ]; then
            echo "ERROR: failed to download"
            exit
        fi

        if [ "$(shasum -a 256 $GO_TGZ | sed 's/ .*//')" != "$GO_TGZ_SHA256" ]; then
            echo "ERROR: malformed package"
            exit
        fi

        echo "Expanding $GO_TGZ..."
        mkdir -pv $GOROOT
        tar xf $GO_TGZ --strip=1 -C $GOROOT
        if [ "$?" != "0" ]; then
            echo "ERROR: failed to extract"
            exit
        fi
    fi

    export PATH=$GOROOT/bin:$PATH
    export GOPATH=$DEV_ROOT

    local GO_VERSION_OUTPUT=$(go version 2>/dev/null)
    if [ "$(go version 2>/dev/null)" == "go version go$GO_VER linux/amd64" ]; then
        echo "INFO: found $GO_VERSION_OUTPUT"
    else
        echo "ERROR: no proper go"
        exit
    fi
}

commit_id()
{
    local BRANCH_TAG_NAME=$(git symbolic-ref -q --short HEAD)
    if [ "$BRANCH_TAG_NAME" == "" ]; then
        local BRANCH_TAG_NAME=$(git describe --tags --exact-match)
    fi

    local COMMIT_ID=$(git rev-parse --short HEAD)
    local DIRTY=$(git diff --quiet || echo '-dirty')

    echo ${BRANCH_TAG_NAME}-${COMMIT_ID}${DIRTY}
}

git_clean_up()
{
    if [ "$1" == "" ]; then
        local BRANCH_NAME=master
    fi

    git clean -fdx
    git checkout .
    git checkout master
    git pull
    git checkout $BRANCH_NAME
    git pull
    git status --ignored
}

build_ela()
{
    if [ "$1" == "" ]; then
        echo "Usage: ${FUNCNAME[0]} Branch|Commit|Tag"
        echo "Build ela"
        return
    fi

    local BRANCH_NAME=$1

    local PATH_OLD=$PATH
    setenv_go 1.13.8

    echo "Building ela..."

    if [ ! -d $DEV_ROOT/src/github.com/elastos/Elastos.ELA ]; then
        mkdir -p $DEV_ROOT/src/github.com/elastos
        cd $DEV_ROOT/src/github.com/elastos
        git clone https://github.com/elastos/Elastos.ELA.git
    fi

    echo "Syncing..."
    cd $DEV_ROOT/src/github.com/elastos/Elastos.ELA
    git_clean_up $BRANCH_NAME
    echo "ela: $(commit_id)" >commit.txt

    echo "Compiling..."
    make
    export PATH=$PATH_OLD
}

build_did()
{
    if [ "$1" == "" ]; then
        echo "Usage: ${FUNCNAME[0]} Branch|Commit|Tag"
        echo "Build did"
        return
    fi

    local BRANCH_NAME=$1

    local PATH_OLD=$PATH
    setenv_go 1.13.8

    echo "Building did..."

    if [ ! -d $DEV_ROOT/src/github.com/elastos/Elastos.ELA.SideChain.ID ]; then
        mkdir -p $DEV_ROOT/src/github.com/elastos
        cd $DEV_ROOT/src/github.com/elastos
        git clone https://github.com/elastos/Elastos.ELA.SideChain.ID.git
    fi

    echo "Syncing..."
    cd $DEV_ROOT/src/github.com/elastos/Elastos.ELA.SideChain.ID
    git_clean_up $BRANCH_NAME
    echo "did: $(commit_id)" >commit.txt

    echo "Compiling..."
    make
    export PATH=$PATH_OLD
}

build_carrier()
{
    if [ "$1" == "" ]; then
        echo "Usage: ${FUNCNAME[0]} Branch|Commit|Tag"
        echo "Build carrier"
        return
    fi

    local BRANCH_NAME=$1

    setenv_carrier

    echo "Building carrier..."

    if [ ! -d $DEV_ROOT/src/github.com/elastos/Elastos.NET.Carrier.Bootstrap ]; then
        mkdir -p $DEV_ROOT/src/github.com/elastos
        cd $DEV_ROOT/src/github.com/elastos
        git clone https://github.com/elastos/Elastos.NET.Carrier.Bootstrap
    fi

    echo "Syncing..."
    cd $DEV_ROOT/src/github.com/elastos/Elastos.NET.Carrier.Bootstrap
    git_clean_up $BRANCH_NAME
    echo "carrier: $(commit_id)" >commit.txt

    cd $DEV_ROOT/src/github.com/elastos/Elastos.NET.Carrier.Bootstrap/build
    mkdir -p linux
    cd linux
    cmake -DCMAKE_INSTALL_PREFIX=outputs ../..
    make install
}

build_esc()
{
    if [ "$1" == "" ]; then
        echo "Usage: ${FUNCNAME[0]} Branch|Commit|Tag"
        echo "Build esc"
        return
    fi

    local BRANCH_NAME=$1

    local PATH_OLD=$PATH
    setenv_go 1.16.5

    echo "Building esc..."

    rm -rf $DEV_ROOT/src/github.com/elastos/Elastos.ELA.SideChain.ESC
    if [ ! -d $DEV_ROOT/src/github.com/elastos/Elastos.ELA.SideChain.ESC ]; then
        mkdir -p $DEV_ROOT/src/github.com/elastos
        cd $DEV_ROOT/src/github.com/elastos
        git clone https://github.com/elastos/Elastos.ELA.SideChain.ESC.git
    fi

    echo "Syncing..."
    cd $DEV_ROOT/src/github.com/elastos/Elastos.ELA.SideChain.ESC
    git_clean_up $BRANCH_NAME
    echo "esc: $(commit_id)" >commit.txt

    echo "Compiling..."
    cd $DEV_ROOT/src/github.com/elastos/Elastos.ELA.SideChain.ESC
    export GO111MODULE=off
    make all
    unset GO111MODULE
    export PATH=$PATH_OLD

    cd $DEV_ROOT/src/github.com/elastos/Elastos.ELA.SideChain.ESC/build/bin
    cp -v geth esc
    cp -v bootnode esc-bootnode
}

build_eid()
{
    if [ "$1" == "" ]; then
        echo "Usage: ${FUNCNAME[0]} Branch|Commit|Tag"
        echo "Build eid"
        return
    fi

    local BRANCH_NAME=$1

    local PATH_OLD=$PATH
    setenv_go 1.16.5

    echo "Building eid..."

    rm -rf $DEV_ROOT/src/github.com/elastos/Elastos.ELA.SideChain.EID
    if [ ! -d $DEV_ROOT/src/github.com/elastos/Elastos.ELA.SideChain.EID ]; then
        mkdir -p $DEV_ROOT/src/github.com/elastos
        cd $DEV_ROOT/src/github.com/elastos
        git clone https://github.com/elastos/Elastos.ELA.SideChain.EID.git
    fi

    echo "Syncing..."
    cd $DEV_ROOT/src/github.com/elastos/Elastos.ELA.SideChain.EID
    git_clean_up $BRANCH_NAME
    echo "eid: $(commit_id)" >commit.txt

    echo "Compiling..."
    export GO111MODULE=off
    make all
    unset GO111MODULE
    export PATH=$PATH_OLD

    cd $DEV_ROOT/src/github.com/elastos/Elastos.ELA.SideChain.EID/build/bin
    cp -v geth eid
    cp -v bootnode eid-bootnode
}

build_arbiter()
{
    if [ "$1" == "" ]; then
        echo "Usage: ${FUNCNAME[0]} Branch|Commit|Tag"
        echo "Build arbiter"
        return
    fi

    local BRANCH_NAME=$1

    local PATH_OLD=$PATH
    setenv_go 1.13.8

    echo "Building arbiter..."

    if [ ! -d $DEV_ROOT/src/github.com/elastos/Elastos.ELA.Arbiter ]; then
        mkdir -p $DEV_ROOT/src/github.com/elastos
        cd $DEV_ROOT/src/github.com/elastos
        git clone https://github.com/elastos/Elastos.ELA.Arbiter.git
    fi

    echo "Syncing..."
    cd $DEV_ROOT/src/github.com/elastos/Elastos.ELA.Arbiter
    git_clean_up $BRANCH_NAME
    echo "arbiter: $(commit_id)" >commit.txt

    echo "Compiling..."
    make
    export PATH=$PATH_OLD
}

pack()
{
    local BUILD_ID=$(TZ=Asia/Shanghai date '+%Y%m%d-%H%M%S')

    local RELEASE_DATE=$(TZ=Asia/Shanghai date '+%Y%m%d')
    local RELEASE_PLATFORM=$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m)
    # alpha, beta, stable
    local RELEASE_TYPE=alpha
    local RELEASE_VER=${RELEASE_DATE}-${RELEASE_PLATFORM}-${RELEASE_TYPE}
    local RELEASE_DIR=$DEV_ROOT/release/$RELEASE_PLATFORM/$BUILD_ID

    local TGZ=${RELEASE_DIR}/elastos-node-${RELEASE_VER}.tgz
    local TGZ_DIGEST=${TGZ}.digest

    if false; then
        echo "DEV_ROOT:         $DEV_ROOT"
        echo "BUILD_ID:         $BUILD_ID"

        echo "RELEASE_DATE:     $RELEASE_DATE"
        echo "RELEASE_PLATFORM: $RELEASE_PLATFORM"
        echo "RELEASE_TYPE:     $RELEASE_TYPE"
        echo "RELEASE_VER:      $RELEASE_VER"
        echo "RELEASE_DIR:      $RELEASE_DIR"

        echo "TGZ:              $TGZ"
        echo "TGZ_DIGEST:       $TGZ_DIGEST"
    fi

    if [ -d $RELEASE_DIR ]; then
        echo "ERROR: $RELEASE_DIR exist"
        exit
    fi

    mkdir -p $RELEASE_DIR

    echo "Copying skeleton..."
    cp -a $DEV_ROOT/build/skeleton $RELEASE_DIR/node

    mkdir -p $RELEASE_DIR/node/carrier/
    mkdir -p $RELEASE_DIR/node/ela/
    mkdir -p $RELEASE_DIR/node/did/
    mkdir -p $RELEASE_DIR/node/esc/
    mkdir -p $RELEASE_DIR/node/esc-oracle/
    mkdir -p $RELEASE_DIR/node/eid/
    mkdir -p $RELEASE_DIR/node/eid-oracle/
    mkdir -p $RELEASE_DIR/node/arbiter/

    echo "Copying binaries..."
    cd $DEV_ROOT/src/github.com/elastos/Elastos.NET.Carrier.Bootstrap/build/linux/src
    cp -v ela-bootstrapd $RELEASE_DIR/node/carrier/

    cd $DEV_ROOT/src/github.com/elastos/Elastos.ELA
    cp -v ela     $RELEASE_DIR/node/ela/
    cp -v ela-cli $RELEASE_DIR/node/ela/

    cd $DEV_ROOT/src/github.com/elastos/Elastos.ELA.SideChain.ID
    cp -v did $RELEASE_DIR/node/did/

    cd $DEV_ROOT/src/github.com/elastos/Elastos.ELA.SideChain.ESC/build/bin
    cp -v esc $RELEASE_DIR/node/esc/

    cd $DEV_ROOT/src/github.com/elastos/Elastos.ELA.SideChain.ESC/oracle
    cp -v \
        checkillegalevidence.js \
        common.js \
        crosschain_oracle.js \
        ctrt.js \
        faileddeposittransactions.js \
        frozen_account.js \
        getblklogs.js \
        getblknum.js \
        getexisttxs.js \
        getfaileddeposittransactionbyhash.js \
        getillegalevidencebyheight.js \
        gettxinfo.js \
        processedinvalidwithdrawtx.js \
        receivedInvaliedwithrawtx.js \
        sendrechargetransaction.js \
        smallcrosschaintransaction.js \
        $RELEASE_DIR/node/esc-oracle/

    cd $DEV_ROOT/src/github.com/elastos/Elastos.ELA.SideChain.EID/build/bin
    cp -v eid $RELEASE_DIR/node/eid/

    cd $DEV_ROOT/src/github.com/elastos/Elastos.ELA.SideChain.EID/oracle
    cp -v \
        checkillegalevidence.js \
        common.js \
        crosschain_eid.js \
        ctrt.js \
        getblklogs.js \
        getblknum.js \
        getexisttxs.js \
        getillegalevidencebyheight.js \
        gettxinfo.js \
        sendrechargetransaction.js \
        $RELEASE_DIR/node/eid-oracle/
    popd

    cd $DEV_ROOT/src/github.com/elastos/Elastos.ELA.Arbiter
    cp -v arbiter $RELEASE_DIR/node/arbiter/

    echo "Generating version.txt..."
    cd $RELEASE_DIR/node
    echo $BUILD_ID >version.txt

    echo "Generating commit.txt..."
    cd $DEV_ROOT/src/github.com/elastos
    cat Elastos.NET.Carrier.Bootstrap/commit.txt  >$RELEASE_DIR/node/commit.txt
    cat Elastos.ELA/commit.txt                   >>$RELEASE_DIR/node/commit.txt
    cat Elastos.ELA.SideChain.ID/commit.txt      >>$RELEASE_DIR/node/commit.txt
    cat Elastos.ELA.SideChain.ESC/commit.txt     >>$RELEASE_DIR/node/commit.txt
    cat Elastos.ELA.SideChain.EID/commit.txt     >>$RELEASE_DIR/node/commit.txt
    cat Elastos.ELA.Arbiter/commit.txt           >>$RELEASE_DIR/node/commit.txt

    echo "Generating checksum.txt..."
    cd $RELEASE_DIR/node
    shasum -a 256 $(find . -type f -executable) >checksum.txt

    echo "Packing tarball..."
    cd $RELEASE_DIR
    tar zcpf $TGZ node

    echo "Generating tarball checksum..."
    cd $RELEASE_DIR
    shasum -a 256 $(basename $TGZ) >$TGZ_DIGEST

    ls -l $TGZ
    ls -l $TGZ_DIGEST
}

usage()
{
    echo "Usage: $0 CARRIER_VER ELA_VER DID_VER ESC_VER EID_VER ARBITER_VER"
    echo "Build Elastos Node bundle package"
    echo
    echo "Arguments: branch or specific commit of the repositories:"
    echo
    echo "  https://github.com/elastos/Elastos.NET.Carrier.Bootstrap"
    echo "  https://github.com/elastos/Elastos.ELA"
    echo "  https://github.com/elastos/Elastos.ELA.SideChain.ID"
    echo "  https://github.com/elastos/Elastos.ELA.SideChain.ESC"
    echo "  https://github.com/elastos/Elastos.ELA.SideChain.EID"
    echo "  https://github.com/elastos/Elastos.ELA.Arbiter"
    echo
    echo "Examples:"
    echo
    echo "  $0 master master master master master master master"
    echo "  $0 release-v6.0.1 v0.8.3 v0.3.2 v0.1.4.4 v0.2.0 v0.3.1"
    echo
}

#
# Main
#
DEV_ROOT=$(cd $(dirname $BASH_SOURCE)/..; pwd)

if [ "$6" == "" ]; then
    usage
    exit
fi

chkenv

build_carrier $1
build_ela     $2
build_did     $3
build_esc     $4
build_eid     $5
build_arbiter $6

pack
