#!/bin/bash

#
# Main
#
DEV_ROOT=$(cd $(dirname $BASH_SOURCE)/..; pwd)

BUILD_ID=$(TZ=Asia/Shanghai date '+%Y%m%d')
RELEASE_DIR=$DEV_ROOT/release/node/$(uname -s)-$(uname -m)

# alpha, beta, stable
RELEASE_TYPE=alpha

NODE_TGZ=$RELEASE_DIR/elastos-supernode-${BUILD_ID}-${RELEASE_TYPE}-$(uname -s)-$(uname -m).tgz
NODE_TGZ_DIGEST=$NODE_TGZ.digest
NODE_TGZ_ASC=$NODE_TGZ.asc

echo "DEV_ROOT:        $DEV_ROOT"
echo "BUILD_ID:        $BUILD_ID"
echo "RELEASE_DIR:     $RELEASE_DIR"

echo "NODE_TGZ:        $NODE_TGZ"
echo "NODE_TGZ_DIGEST: $NODE_TGZ_DIGEST"
echo "NODE_TGZ_ASC:    $NODE_TGZ_ASC"

# TODO
