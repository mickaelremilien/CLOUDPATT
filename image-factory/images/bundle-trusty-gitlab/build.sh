#!/bin/sh

IMG_UBUNTU_TRUSTY="ae3082cb-fac1-46b1-97aa-507aaa8f184f"
SELF_PATH=`dirname "$0"`

# bundle-build.sh BASENAME CW_BUNDLE_ID BUNDLE_PATH SRC_IMG IMG_OS [FACTORY_FLAVOR]
bash "$SELF_PATH/../bundle-build.sh" "bundle-trusty-gitlab" "GITLAB" "bundle-trusty-gitlab" "$IMG_UBUNTU_TRUSTY" "Ubuntu" "21"
