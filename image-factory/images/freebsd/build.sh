#!/bin/sh

. ../../factory-env.sh

BASENAME="freebsd"
TENANT_ID="772be1ffb32e42a28ac8e0205c0b0b90"
BUILDMARK="$(date +%Y-%m-%d-%H%M)"
IMG_NAME="$BASENAME-$BUILDMARK"
TMP_IMG_NAME="$IMG_NAME-tmp"

IMG_ID="dbde0f12-7935-4729-8b88-9b8e799a509c"
URCHIN_IMG_ID=$IMG_ID $WORKSPACE/test-tools/urchin -f "$WORKSPACE/test-tools/ubuntu-tests"
