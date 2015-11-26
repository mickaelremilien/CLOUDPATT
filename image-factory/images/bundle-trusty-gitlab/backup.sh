#!/bin/bash

USAGE="\
Usage: backup.sh <STACK_NAME> <PATH_TO_KEYPAIR>

Creates a backup for volume of GitLab Stack"

STACK_NAME="$1"
KEYPAIR="$2"

if [ ! "$STACK_NAME" ]; then
    echo "ERROR: Too few arguments"
    echo "$USAGE"
    exit 1
fi

if [ ! "$KEYPAIR" ]; then
    echo "ERROR: Too few arguments"
    echo "$USAGE"
    exit 1
fi

if [ -n "$3" ]; then
    echo "ERROR: Too many arguments"
    echo "$USAGE"
    exit 1
fi

heat stack-show "$STACK_NAME" > /dev/null
if [ "0" -ne "$?" ]; then
  echo "ERROR: Heat client cannot find a stack of that name"
  echo "$USAGE"
  exit 1
fi

SERVER_ID=`heat resource-list "$STACK_NAME" | grep "| server " | tr -d " " | cut -d"|" -f3`
SERVER_IP="$(heat resource-list "$STACK_NAME" | grep link | awk '{print $4}' | rev | cut -d"-" -f1 | rev)"
VOLUME_ID=`heat resource-list "$STACK_NAME" | grep "| volume " | tr -d " " | cut -d"|" -f3`

if [ ! "$SERVER_ID" ] || [ ! "$VOLUME_ID" ]; then
    echo "ERROR: Stack core resources could not be found"
    echo "$USAGE"
    exit 1
fi

echo "Stopping server..."

ssh cloud@$SERVER_IP -i $KEYPAIR sudo halt
echo "Waiting for server to become available..."
sleep 60
nova stop "$SERVER_ID"

echo "Detaching volume from server..."
nova volume-detach "$SERVER_ID" "$VOLUME_ID"
echo "Waiting for volume to become available..."
while [ "$(cinder list | grep "$VOLUME_ID" | tr -d " " | cut -d"|" -f3)" != "available" ]; do
  sleep 2
done
BACKUP_NAME="$STACK_NAME-backup-$(date "+%Y-%m-%d-%X")"
echo "Creating volume backup..."
cinder backup-create --display-name "$BACKUP_NAME" "$VOLUME_ID"
while [ "$(cinder backup-list | grep "$BACKUP_NAME" | tr -d " " | cut -d"|" -f4)" == "creating" ]; do
  sleep 8
done
VOLUME_STATE="$(cinder backup-list | grep "$BACKUP_NAME" | tr -d " " | cut -d"|" -f4)"
if [ "$VOLUME_STATE" == "available" ]; then
  echo "Volume now available. Attaching volume to server..."
  nova volume-attach "$SERVER_ID" "$VOLUME_ID" "/dev/vdb"
  if [ "0" -ne "$?" ]; then
    echo "Volume attachment encountered an error. Exiting with status 1."
    exit 1
  else
    echo "Volume attached."
  fi
else
  echo "An error has occured: Volume state is currently '$VOLUME_STATE'. Exiting with status 1."
  exit 1
fi
echo "Starting server..."
nova start "$SERVER_ID"
if [ "0" -ne "$?" ]; then
  echo "Server encountered an error. Exiting with status 1."
  exit 1
else
  echo "Server started."
fi
