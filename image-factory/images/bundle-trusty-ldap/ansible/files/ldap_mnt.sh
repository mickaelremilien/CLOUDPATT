#!/bin/bash

VOL="/dev/vdb"
VOL_FS_TYPE="ext4"
VOL_MNT_POINT="/mnt/vdb"

echo "  + Stopping LDAP to work"
sudo service apache2 stop
sudo service slapd stop
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

if [ ! -d "$VOL_MNT_POINT/ldap" ]; then
  cp -pR /var/lib/ldap $VOL_MNT_POINT/
  mkdir $VOL_MNT_POINT/ssl
  chmod 700 $VOL_MNT_POINT/ssl
  openssl req -new -nodes -x509 -subj "/C=FR/ST=IDF/L=Paris/O=Cloudwatt/CN=LDAP" \
    -days 3650 \
    -keyout $VOL_MNT_POINT/ssl/ldap.key \
    -out $VOL_MNT_POINT/ssl/ldap.crt \
    -extensions v3_ca

  chmod -R 600 $VOL_MNT_POINT/ssl/*

  cp -p /etc/stack_public_entry_point $VOL_MNT_POINT/stack_public_entry_point
fi


cp -pR $VOL_MNT_POINT/ssl/ldap* /etc/ldap/ssl

SUBDIR_MNT="$(mount | grep /var/lib/ldap)"
if [ ! -z "$SUBDIR_MNT" ]; then
  umount /var/lib/ldap
fi

mount --bind $VOL_MNT_POINT/ldap /var/lib/ldap

if [ -f "$VOL_MNT_POINT/stack_public_entry_point" ]; then
  PREVIOUS_IP="$(cat $VOL_MNT_POINT/stack_public_entry_point)"
  CURRENT_IP="$(cat /etc/stack_public_entry_point)"
  if [ "$CURRENT_IP" != "$PREVIOUS_IP" ]; then
    # Include any need to insert current IP here
    # sed -i "s/$PREVIOUS_IP/$CURRENT_IP/g" /etc/apache2/sites-available/lam.conf

    cp -p /etc/stack_public_entry_point $VOL_MNT_POINT/stack_public_entry_point
  fi
fi

sudo service slapd start
sudo a2ensite ssl-lam
sudo service apache2 start
