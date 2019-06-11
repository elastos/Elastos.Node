#!/bin/bash

setenv()
{
    echo "Checking OS Version..."
    local OS_VER="$(lsb_release -s -i 2>/dev/null)"
    local OS_VER="${OS_VER}_$(lsb_release -s -r 2>/dev/null)"

    # amd64
    if [ "$OS_VER" != "Ubuntu_16.04" ]; then
        echo "ERROR: this script requires Ubuntu 16.04"
        exit
    fi

    #
    # Setup Go Lang
    #
    if [ ! -d $DEV_ROOT/build/go ]; then
        local GO_TGZ_URL=https://dl.google.com/go/go1.10.8.linux-amd64.tar.gz
        local GO_TGZ_SHA256=d8626fb6f9a3ab397d88c483b576be41fa81eefcec2fd18562c87626dbb3c39e
        local GO_TGZ=${GO_TGZ_URL##*/}

        cd $DEV_ROOT/build
        echo "Downloading $GO_TGZ..."
        wget -O $GO_TGZ $GO_TGZ_URL
        if [ "$?" != "0" ]; then
            echo "ERROR: wget failed"
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
    if [ "$GO_VERSION" == "go version go1.10.8 linux/amd64" ]; then
        echo "INFO: found $GO_VERSION"
    elif [ "$GO_VERSION" == "go version go1.10.8 darwin/amd64" ]; then
        echo "INFO: found $GO_VERSION"
    else
        echo "ERROR: no proper go"
        exit
    fi

    #
    # Setup Glide
    #
    if [ ! -d $DEV_ROOT/build/glide ]; then
        local GLIDE_TGZ_URL=https://github.com/Masterminds/glide/releases/download/v0.13.1/glide-v0.13.1-linux-amd64.tar.gz
        local GLIDE_TGZ_SHA256=c403933503ea40308ecfadcff581ff0dc3190c57958808bb9eed016f13f6f32c
        local GLIDE_TGZ=${GLIDE_TGZ_URL##*/}

        cd $DEV_ROOT/build
        echo "Downloading $GLIDE_TGZ..."
        wget -O $GLIDE_TGZ $GLIDE_TGZ_URL
        if [ "$?" != "0" ]; then
            echo "ERROR: wget failed"
            exit
        fi
        if [ "$(shasum -a 256 $GLIDE_TGZ | sed 's/ .*//')" != "$GLIDE_TGZ_SHA256" ]; then
            echo "ERROR: malformed package"
            exit
        fi
        echo "Expanding $GLIDE_TGZ..."
        mkdir -p glide
        cd glide
        tar xf ../$GLIDE_TGZ --strip=1
        if [ "$?" != "0" ]; then
            echo "ERROR: failed to extract"
            exit
        fi
    fi

    export PATH=$DEV_ROOT/build/glide:$PATH

    local GLIDE_VERSION=$(glide -v 2>/dev/null)
    if [ "$GLIDE_VERSION" == "glide version v0.13.1" ]; then
        echo "INFO: found $GLIDE_VERSION"
    elif [ "$GLIDE_VERSION" == "glide version 0.13.1" ]; then
        echo "INFO: found $GLIDE_VERSION"
    else
        echo "ERROR: no proper glide"
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
    local COMMIT_ID=$(git describe --abbrev=6 --dirty --always)
    echo "ela: $COMMIT_ID" >commit.txt

    echo "Installing dependencies..."
    glide cc
    glide update
    glide install

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
    local COMMIT_ID=$(git describe --abbrev=6 --dirty --always)
    echo "did: $COMMIT_ID" >commit.txt

    echo "Installing dependencies..."
    glide cc
    glide update
    glide install

    echo "Compiling..."
    make
}

build_token()
{
    if [ "$1" == "" ]; then
        echo "Usage: ${FUNCNAME[0]} Branch|Commit"
        echo "Build token"
        return
    fi

    local BRANCH_NAME=$1

    echo "Building token..."

    if [ ! -d $DEV_ROOT/src/github.com/elastos/Elastos.ELA.SideChain.Token ]; then
        mkdir -p $DEV_ROOT/src/github.com/elastos
        cd $DEV_ROOT/src/github.com/elastos
        git clone https://github.com/elastos/Elastos.ELA.SideChain.Token
    fi

    echo "Syncing..."
    cd $DEV_ROOT/src/github.com/elastos/Elastos.ELA.SideChain.Token
    git clean -fdx
    git checkout master
    git pull
    git checkout $BRANCH_NAME
    git pull
    git status --ignored
    local COMMIT_ID=$(git describe --abbrev=6 --dirty --always)
    echo "token: $COMMIT_ID" >commit.txt

    echo "Installing dependencies..."
    glide cc
    glide update
    glide install

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
    local COMMIT_ID=$(git describe --abbrev=6 --dirty --always)
    echo "carrier: $COMMIT_ID" >commit.txt

    cd $DEV_ROOT/src/github.com/elastos/Elastos.NET.Carrier.Bootstrap/build
    mkdir -p linux
    cd linux
    cmake -DCMAKE_INSTALL_PREFIX=outputs ../..
    make install
}

pack()
{
    local BUILD_ID=$(TZ=Asia/Shanghai date '+%Y%m%d')
    local RELEASE_DIR=$DEV_ROOT/release/$(uname -s)-$(uname -m)/$BUILD_ID

    # alpha, beta, stable
    local RELEASE_TYPE=alpha

    local TGZ=${RELEASE_DIR}/elastos-supernode-${BUILD_ID}-${RELEASE_TYPE}-$(uname -s)-$(uname -m).tgz
    local TGZ_DIGEST=${TGZ}.digest
    local TGZ_ASC=${TGZ}.asc

    if false; then
        echo "DEV_ROOT:     $DEV_ROOT"
        echo "BUILD_ID:     $BUILD_ID"
        echo "RELEASE_DIR:  $RELEASE_DIR"
        echo "TGZ:          $TGZ"
        echo "TGZ_DIGEST:   $TGZ_DIGEST"
    fi

    #rm -rf $RELEASE_DIR

    if [ -d $RELEASE_DIR ]; then
        echo "ERROR: $RELEASE_DIR exist"
        exit
    fi

    mkdir -p $RELEASE_DIR

    echo "Coping skeleton..."
    cp -a $DEV_ROOT/build/skeleton $RELEASE_DIR/node

    echo "Copying binaries..."
    cp -v $DEV_ROOT/src/github.com/elastos/Elastos.ELA/ela \
        $RELEASE_DIR/node/ela/

    cp -v $DEV_ROOT/src/github.com/elastos/Elastos.ELA/ela-cli \
        $RELEASE_DIR/node/ela/

    cp -v $DEV_ROOT/src/github.com/elastos/Elastos.ELA.SideChain.ID/did \
        $RELEASE_DIR/node/did/

    cp -v $DEV_ROOT/src/github.com/elastos/Elastos.ELA.SideChain.Token/token \
        $RELEASE_DIR/node/token/

    cp -v $DEV_ROOT/src/github.com/elastos/Elastos.NET.Carrier.Bootstrap/build/linux/src/ela-bootstrapd \
        $RELEASE_DIR/node/carrier/

    mkdir -p $RELEASE_DIR/node/carrier/var/lib/ela-bootstrapd
    mkdir -p $RELEASE_DIR/node/carrier/var/lib/ela-bootstrapd/db
    mkdir -p $RELEASE_DIR/node/carrier/var/run/ela-bootstrapd

    echo "Generating version list..."
    cd $DEV_ROOT/src/github.com/elastos
    cat Elastos.ELA/commit.txt                    >$RELEASE_DIR/node/commit.txt
    cat Elastos.ELA.SideChain.ID/commit.txt      >>$RELEASE_DIR/node/commit.txt
    cat Elastos.ELA.SideChain.Token/commit.txt   >>$RELEASE_DIR/node/commit.txt
    cat Elastos.NET.Carrier.Bootstrap/commit.txt >>$RELEASE_DIR/node/commit.txt

    echo "Generating checksum for executables..."
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
    echo "Usage: $0"
    echo "Build Elastos Supernode bundle package"
}

#
# Main
#
DEV_ROOT=$(cd $(dirname $BASH_SOURCE)/..; pwd)

setenv

build_ela master
build_did master
build_token master
build_carrier master

pack
