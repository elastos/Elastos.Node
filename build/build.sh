#!/bin/bash

setenv()
{
    local OS_VER="$(lsb_release -s -i 2>/dev/null)"
    local OS_VER="${OS_VER}_$(lsb_release -s -r 2>/dev/null)"

    if [ "$(uname -sm)" != "Linux x86_64" ]; then
        echo "ERROR: this script requires Ubuntu 16.04 (x86_64) or higher"
        exit
    fi

    if [ "$OS_VER" \< "Ubuntu_16.04" ]; then
        echo "ERROR: this script requires Ubuntu 16.04 (x86_64) or higher"
        exit
    fi

    #
    # Setup Go Lang
    #
    if [ ! -d $DEV_ROOT/build/go ]; then
        local GO_TGZ_URL=https://dl.google.com/go/go1.13.8.linux-amd64.tar.gz
        local GO_TGZ_SHA256=0567734d558aef19112f2b2873caa0c600f1b4a5827930eb5a7f35235219e9d8
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
        tar xf $GO_TGZ
        if [ "$?" != "0" ]; then
            echo "ERROR: failed to extract"
            exit
        fi
    fi

    export GOROOT=$DEV_ROOT/build/go
    export PATH=$GOROOT/bin:$PATH
    export GOPATH=$DEV_ROOT

    local GO_VERSION=$(go version 2>/dev/null)
    if [ "$GO_VERSION" == "go version go1.13.8 linux/amd64" ]; then
        echo "INFO: found $GO_VERSION"
    elif [ "$GO_VERSION" == "go version go1.13.8 darwin/amd64" ]; then
        echo "INFO: found $GO_VERSION"
    else
        echo "ERROR: no proper go"
        exit
    fi

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

build_ela()
{
    if [ "$1" == "" ]; then
        echo "Usage: ${FUNCNAME[0]} Branch|Commit"
        echo "Build ela"
        return
    fi

    local BRANCH_NAME=$1

    echo "Building ela..."

    if [ ! -d $DEV_ROOT/src/github.com/elastos/Elastos.ELA ]; then
        mkdir -p $DEV_ROOT/src/github.com/elastos
        cd $DEV_ROOT/src/github.com/elastos
        git clone https://github.com/elastos/Elastos.ELA
    fi

    echo "Syncing..."
    cd $DEV_ROOT/src/github.com/elastos/Elastos.ELA
    git clean -fdx
    git checkout master
    git pull
    git checkout $BRANCH_NAME
    git pull
    git status --ignored
    echo "ela: $(commit_id)" >commit.txt

    echo "Compiling..."
    make
}

build_did()
{
    if [ "$1" == "" ]; then
        echo "Usage: ${FUNCNAME[0]} Branch|Commit"
        echo "Build did"
        return
    fi

    local BRANCH_NAME=$1

    echo "Building did..."

    if [ ! -d $DEV_ROOT/src/github.com/elastos/Elastos.ELA.SideChain.ID ]; then
        mkdir -p $DEV_ROOT/src/github.com/elastos
        cd $DEV_ROOT/src/github.com/elastos
        git clone https://github.com/elastos/Elastos.ELA.SideChain.ID
    fi

    echo "Syncing..."
    cd $DEV_ROOT/src/github.com/elastos/Elastos.ELA.SideChain.ID
    git clean -fdx
    git checkout master
    git pull
    git checkout $BRANCH_NAME
    git pull
    git status --ignored
    echo "did: $(commit_id)" >commit.txt

    echo "Compiling..."
    make
}

build_carrier()
{
    if [ "$1" == "" ]; then
        echo "Usage: ${FUNCNAME[0]} Branch|Commit"
        echo "Build carrier"
        return
    fi

    local BRANCH_NAME=$1

    echo "Building carrier..."

    if [ ! -d $DEV_ROOT/src/github.com/elastos/Elastos.NET.Carrier.Bootstrap ]; then
        mkdir -p $DEV_ROOT/src/github.com/elastos
        cd $DEV_ROOT/src/github.com/elastos
        git clone https://github.com/elastos/Elastos.NET.Carrier.Bootstrap
    fi

    echo "Syncing..."
    cd $DEV_ROOT/src/github.com/elastos/Elastos.NET.Carrier.Bootstrap
    git clean -fdx
    git checkout master
    git pull
    git checkout $BRANCH_NAME
    git pull
    git status --ignored
    echo "carrier: $(commit_id)" >commit.txt

    cd $DEV_ROOT/src/github.com/elastos/Elastos.NET.Carrier.Bootstrap/build
    mkdir -p linux
    cd linux
    cmake -DCMAKE_INSTALL_PREFIX=outputs ../..
    make install
}

build_eth()
{
    if [ "$1" == "" ]; then
        echo "Usage: ${FUNCNAME[0]} Branch|Commit|Tag"
        return
    fi

    local BRANCH_NAME=$1

    echo "Building eth..."

    rm -rf $DEV_ROOT/src/github.com/elastos/Elastos.ELA.SideChain.ETH
    if [ ! -d $DEV_ROOT/src/github.com/elastos/Elastos.ELA.SideChain.ETH ]; then
        mkdir -p $DEV_ROOT/src/github.com/elastos
        cd $DEV_ROOT/src/github.com/elastos
        git clone https://github.com/elastos/Elastos.ELA.SideChain.ETH.git
    fi

    echo "Syncing..."
    cd $DEV_ROOT/src/github.com/elastos/Elastos.ELA.SideChain.ETH
    git clean -fdx
    git checkout .
    git checkout master
    git pull
    git checkout $BRANCH_NAME
    git pull
    git status --ignored
    echo "eth: $(commit_id)" >commit.txt

    echo "Compiling..."
    make all
    #go build ./cmd/geth
    #go build ./cmd/bootnode
}

build_eid()
{
    if [ "$1" == "" ]; then
        echo "Usage: ${FUNCNAME[0]} Branch|Commit|Tag"
        return
    fi

    local BRANCH_NAME=$1

    echo "Building eid..."

    rm -rf $DEV_ROOT/src/github.com/elastos/Elastos.ELA.SideChain.EID
    if [ ! -d $DEV_ROOT/src/github.com/elastos/Elastos.ELA.SideChain.EID ]; then
        mkdir -p $DEV_ROOT/src/github.com/elastos
        cd $DEV_ROOT/src/github.com/elastos
        git clone https://github.com/elastos/Elastos.ELA.SideChain.EID.git
    fi

    echo "Syncing..."
    cd $DEV_ROOT/src/github.com/elastos/Elastos.ELA.SideChain.EID
    git clean -fdx
    git checkout .
    git checkout master
    git pull
    git checkout $BRANCH_NAME
    git pull
    git status --ignored
    echo "eid: $(commit_id)" >commit.txt

    echo "Compiling..."
    make all

    cd $DEV_ROOT/src/github.com/elastos/Elastos.ELA.SideChain.EID/build/bin
    cp -v geth eid
    cp -v bootnode eid-bootnode
}

build_arbiter()
{
    if [ "$1" == "" ]; then
        echo "Usage: ${FUNCNAME[0]} Branch|Commit|Tag"
        return
    fi

    local BRANCH_NAME=$1

    echo "Building arbiter..."

    if [ ! -d $DEV_ROOT/src/github.com/elastos/Elastos.ELA.Arbiter ]; then
        mkdir -p $DEV_ROOT/src/github.com/elastos
        cd $DEV_ROOT/src/github.com/elastos
        git clone https://github.com/elastos/Elastos.ELA.Arbiter.git
    fi

    echo "Syncing..."
    cd $DEV_ROOT/src/github.com/elastos/Elastos.ELA.Arbiter
    git clean -fdx
    git checkout .
    git checkout master
    git pull
    git checkout $BRANCH_NAME
    git pull
    git status --ignored
    echo "arbiter: $(commit_id)" >commit.txt

    echo "Compiling..."
    make
}

pack()
{
    local BUILD_ID=$(TZ=Asia/Shanghai date '+%Y%m%d-%H%M%S')

    local RELEASE_DATE=$(TZ=Asia/Shanghai date '+%Y%m%d')
    local RELEASE_PLATFORM=$(uname -s)-$(uname -m)
    # alpha, beta, stable
    local RELEASE_TYPE=alpha
    local RELEASE_VER=${RELEASE_DATE}-${RELEASE_PLATFORM}-${RELEASE_TYPE}
    local RELEASE_DIR=$DEV_ROOT/release/$RELEASE_PLATFORM/$BUILD_ID

    local TGZ=${RELEASE_DIR}/elastos-supernode-${RELEASE_VER}.tgz
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
    mkdir -p $RELEASE_DIR/node/eth/
    mkdir -p $RELEASE_DIR/node/eid/
    mkdir -p $RELEASE_DIR/node/arbiter/

    echo "Copying binaries..."
    cp -v $DEV_ROOT/src/github.com/elastos/Elastos.NET.Carrier.Bootstrap/build/linux/src/ela-bootstrapd \
        $RELEASE_DIR/node/carrier/

    cp -v $DEV_ROOT/src/github.com/elastos/Elastos.ELA/ela \
        $RELEASE_DIR/node/ela/

    cp -v $DEV_ROOT/src/github.com/elastos/Elastos.ELA/ela-cli \
        $RELEASE_DIR/node/ela/

    cp -v $DEV_ROOT/src/github.com/elastos/Elastos.ELA.SideChain.ID/did \
        $RELEASE_DIR/node/did/

    cp -v $DEV_ROOT/src/github.com/elastos/Elastos.ELA.SideChain.ETH/build/bin/geth \
        $RELEASE_DIR/node/eth/

    cp -v $DEV_ROOT/src/github.com/elastos/Elastos.ELA.SideChain.EID/build/bin/eid \
        $RELEASE_DIR/node/eid/

    cp -v $DEV_ROOT/src/github.com/elastos/Elastos.ELA.Arbiter/arbiter \
        $RELEASE_DIR/node/arbiter/

    echo "Generating version.txt..."
    cd $RELEASE_DIR/node
    echo $BUILD_ID >version.txt

    echo "Generating commit.txt..."
    cd $DEV_ROOT/src/github.com/elastos
    cat Elastos.NET.Carrier.Bootstrap/commit.txt  >$RELEASE_DIR/node/commit.txt
    cat Elastos.ELA/commit.txt                   >>$RELEASE_DIR/node/commit.txt
    cat Elastos.ELA.SideChain.ID/commit.txt      >>$RELEASE_DIR/node/commit.txt
    cat Elastos.ELA.SideChain.ETH/commit.txt     >>$RELEASE_DIR/node/commit.txt
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
    echo "Usage: $0 CARRIER_VER ELA_VER DID_VER ETH_VER EID_VER ARBITER_VER"
    echo "Build Elastos Supernode bundle package"
    echo
    echo "Arguments: branch or specific commit of the repositories:"
    echo
    echo "  https://github.com/elastos/Elastos.NET.Carrier.Bootstrap"
    echo "  https://github.com/elastos/Elastos.ELA"
    echo "  https://github.com/elastos/Elastos.ELA.SideChain.ID"
    echo "  https://github.com/elastos/Elastos.ELA.SideChain.ETH"
    echo "  https://github.com/elastos/Elastos.ELA.SideChain.EID"
    echo "  https://github.com/elastos/Elastos.ELA.Arbiter"
    echo
    echo "Examples:"
    echo
    echo "  $0 master master master master master master"
    echo "  $0 release-v6.0.1 v0.7.0 v0.3.1 v0.1.3.2 v0.1.0 v0.2.3"
    echo
}

#
# Main
#
DEV_ROOT=$(cd $(dirname $BASH_SOURCE)/..; pwd)

if [ "$5" == "" ]; then
    usage
    exit
fi

setenv

build_carrier $1
build_ela $2
build_did $3
build_eth $4
build_eid $5
build_arbiter $6

pack
