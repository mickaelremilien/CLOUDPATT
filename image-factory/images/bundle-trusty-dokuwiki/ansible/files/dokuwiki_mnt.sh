#!/bin/bash

VOL="/dev/vdb"
VOL_FS_TYPE="ext4"
VOL_MNT_POINT="/mnt/vdb"

echo "  + Stopping Dokuwiki to work"
sudo service apache2 stop
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
done; echo "."
echo "    + Volume attachment was found"

if [ ! -d "$VOL_MNT_POINT" ]; then
  echo "  + Mount point absent : creating $VOL_MNT_POINT"
  mkdir -p $VOL_MNT_POINT
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

echo "  + Checking if something is already mounted at /var/www/dokuwiki"
SUBDIR_MNT="$(mount | grep /var/www/dokuwiki)"
if [ ! -z "$SUBDIR_MNT" ]; then
  echo "    + Unmounting /var/www/dokuwiki"
  umount /var/www/dokuwiki
fi

echo "  + Checking if volume does not contain Dokuwiki content"
if [ ! -d "$VOL_MNT_POINT/dokuwiki" ]; then
  echo "    + Copying contents of /var/www/dokuwiki to volume"
  cp -pR /var/www/dokuwiki $VOL_MNT_POINT/
  echo "    + Creating SSL Keys"
  mkdir $VOL_MNT_POINT/ssl
  chmod 700 $VOL_MNT_POINT/ssl
  openssl req -new -nodes -x509 -subj "/C=FR/ST=IDF/L=Paris/O=Cloudwatt/CN=DOKUWIKI" \
    -days 3650 \
    -keyout $VOL_MNT_POINT/ssl/dokuwiki.key \
    -out $VOL_MNT_POINT/ssl/dokuwiki.crt \
    -extensions v3_ca

  chmod -R 600 $VOL_MNT_POINT/ssl/*

  echo "    + Copying floating-IP address save file"
  cp -p /etc/stack_public_entry_point $VOL_MNT_POINT/stack_public_entry_point
fi

echo "  + Copying SSL Keys to server"
mkdir -p /etc/dokuwiki/ssl
cp -pR $VOL_MNT_POINT/ssl/dokuwiki* /etc/dokuwiki/ssl

echo "  + Mounting /var/www/dokuwiki"
mount --bind $VOL_MNT_POINT/dokuwiki /var/www/dokuwiki
sudo chown -R www-data:www-data /var/www/dokuwiki

echo "  + Checking if Floating IP has changed."
if [ -f "$VOL_MNT_POINT/stack_public_entry_point" ]; then
  PREVIOUS_IP="$(cat $VOL_MNT_POINT/stack_public_entry_point)"
  CURRENT_IP="$(cat /etc/stack_public_entry_point)"
  if [ "$CURRENT_IP" != "$PREVIOUS_IP" ]; then
    echo "    + Floating IP has changed, making the neccesary modifications"
    # Include any need to insert current IP here
    # sed -i "s/$PREVIOUS_IP/$CURRENT_IP/g" /some/path/needs-floating-ip.conf

    cp -p /etc/stack_public_entry_point $VOL_MNT_POINT/stack_public_entry_point
  fi
fi

echo "  + Restarting Dokuwiki"
# If you'd prefer HTTP rather than HTTPS, switch which line is commented
# a2dissite ssl-dokuwiki && sudo a2ensite dokuwiki
a2dissite dokuwiki && sudo a2ensite ssl-dokuwiki
sudo service apache2 start
