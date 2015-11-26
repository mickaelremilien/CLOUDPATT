#!/bin/bash

VOL="/dev/vdb"
VOL_FS_TYPE="ext4"
VOL_MNT_POINT="/mnt/vdb"

echo "  + Stopping DevKit to work"
service nginx stop
gitlab-ctl stop
service jenkins stop
service mongod stop
service slapd stop
sleep 5

echo -n "  + Waiting for volume to attach."
for i in {1..50}; do
  test -b "$VOL" && break || sleep 5
  if [ "$i" == "50" ]; then
    echo "."
    echo "    + Volume attachment not found : exiting"
    exit 1
  else
    echo -n "."
  fi
done
echo "."
echo "    + Volume attachment was found"

if [ ! -d "$VOL_MNT_POINT" ]; then
  echo "  + Mount point absent : creating $VOL_MNT_POINT"
  mkdir $VOL_MNT_POINT
fi

VOL_MNT="$(mount | grep $VOL)"
if [ -z "$VOL_MNT" ]; then
  echo "  + Volume not mounted : mounting $VOL on $VOL_MNT_POINT"
  mount -t $VOL_FS_TYPE $VOL $VOL_MNT_POINT

  if [ "0" -ne "$?" ]; then
    echo "    + Mount failed : checking filesystem"
    VOL_FS_OK="$(blkid | grep $VOL | grep $VOL_FS_TYPE)"
    if [ -z "$VOL_FS_OK" ]; then
      echo "    + Expected filesystem absent: attempting mkfs + mount"
      mkfs -t ext4 $VOL
      if [ "0" -ne "$?" ]; then
        echo "    + mkfs failed : exiting"
        exit 1
      fi

      mount $VOL $VOL_MNT_POINT
      if [ "0" -ne "$?" ]; then
        echo "    + mkfs succeeded but mount failed: exiting"
        exit 1
      fi
    else
      echo "    + Expected filesystem present but mount failed: exiting. Call a human to debug."
      exit 1
    fi
  fi
fi

# SSL Setup
echo "  + Checking SSL Setup..."
if [ ! -d "$VOL_MNT_POINT/ssl" ]; then
  echo "    + $VOL_MNT_POINT/ssl does not exist, setting up SSL"
  mkdir $VOL_MNT_POINT/ssl
  chmod 700 $VOL_MNT_POINT/ssl
  openssl req -new -nodes -x509 -subj "/C=FR/ST=IDF/L=Paris/O=Cloudwatt/CN=DevKit" \
    -days 3650 \
    -keyout $VOL_MNT_POINT/ssl/devkit.key \
    -out $VOL_MNT_POINT/ssl/devkit.crt \
    -extensions v3_ca

  chmod -R 600 $VOL_MNT_POINT/ssl/*

  cp -p /etc/stack_public_entry_point $VOL_MNT_POINT/stack_public_entry_point
fi
cp -pR $VOL_MNT_POINT/ssl/devkit* /etc/devkit/ssl

# GitLab Setup
echo "  + Checking GitLab Setup..."
if [ ! -d "$VOL_MNT_POINT/gitlab" ]; then
  echo "    + $VOL_MNT_POINT/gitlab does not exist, setting up GitLab"
  cp -pR /var/opt/gitlab $VOL_MNT_POINT/

  cp -p /etc/gitlab/gitlab-secrets.json $VOL_MNT_POINT/gitlab/.gitlab-secrets.json
  chmod 600 $VOL_MNT_POINT/gitlab/.gitlab-secrets.json
fi

cp $VOL_MNT_POINT/gitlab/.gitlab-secrets.json /etc/gitlab/gitlab-secrets.json

SUBDIR_MNT="$(mount | grep /var/opt/gitlab)"
if [ ! -z "$SUBDIR_MNT" ]; then
  umount /var/opt/gitlab
fi
mount --bind $VOL_MNT_POINT/gitlab /var/opt/gitlab

# Dokuwiki Setup
echo "  + Checking Dokuwiki Setup..."
if [ ! -d "$VOL_MNT_POINT/dokuwiki" ]; then
  echo "    + $VOL_MNT_POINT/dokuwiki does not exist, setting up Dokuwiki"
  cp -pR /var/www/dokuwiki $VOL_MNT_POINT/
fi

SUBDIR_MNT="$(mount | grep /var/www/dokuwiki)"
if [ ! -z "$SUBDIR_MNT" ]; then
  umount /var/www/dokuwiki
fi
mount --bind $VOL_MNT_POINT/dokuwiki /var/www/dokuwiki

# LDAP Setup
echo "  + Checking LDAP Setup..."
if [ ! -d "$VOL_MNT_POINT/ldap" ]; then
  echo "    + $VOL_MNT_POINT/ldap does not exist, setting up LDAP"
  cp -pR /var/lib/ldap $VOL_MNT_POINT/
fi

SUBDIR_MNT="$(mount | grep /var/lib/ldap)"
if [ ! -z "$SUBDIR_MNT" ]; then
  umount /var/lib/ldap
fi
mount --bind $VOL_MNT_POINT/ldap /var/lib/ldap

# Jenkins Setup
echo "  + Checking Jenkins Setup..."
if [ ! -d "$VOL_MNT_POINT/jenkins" ]; then
  echo "    + $VOL_MNT_POINT/jenkins does not exist, setting up Jenkins"
  cp -pR /var/lib/jenkins $VOL_MNT_POINT/
fi

SUBDIR_MNT="$(mount | grep /var/lib/jenkins)"
if [ ! -z "$SUBDIR_MNT" ]; then
  umount /var/lib/jenkins
fi
mount --bind $VOL_MNT_POINT/jenkins /var/lib/jenkins

# Stack Floating IP Setup
echo "  + Checking Floating IP Setup..."
if [ -f "$VOL_MNT_POINT/stack_public_entry_point" ]; then
  PREVIOUS_IP="$(cat $VOL_MNT_POINT/stack_public_entry_point)"
  CURRENT_IP="$(cat /etc/stack_public_entry_point)"
  if [ "$CURRENT_IP" != "$PREVIOUS_IP" ]; then
    echo "    + Floating IP changed, modifying related files..."
    sed -i "s/$PREVIOUS_IP/$CURRENT_IP/g" /var/opt/gitlab/.gitconfig
    sed -i "s/$PREVIOUS_IP/$CURRENT_IP/g" /etc/nginx/sites-available/devkit.conf
    sed -i "s/$PREVIOUS_IP/$CURRENT_IP/g" /var/opt/gitlab/gitlab-rails/etc/gitlab.yml

    cp -p /etc/stack_public_entry_point $VOL_MNT_POINT/stack_public_entry_point
  fi
fi

# GitLab Refresh Settings
gitlab-ctl start
sleep 10
gitlab-ctl restart
# LDAP Restart
service slapd start
# Jenkins Restart
service jenkins start
# MongoDB (Let's Chat)
service mongod start
# Let's Chat
service lets-chat start
# Nginx Restart
service nginx start
