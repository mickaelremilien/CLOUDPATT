#!/bin/sh

. ../../factory-env.sh

LOG="./build.debug.log"
BASENAME="ubuntu-12.04"
TENANT_ID="772be1ffb32e42a28ac8e0205c0b0b90"
BUILDMARK="$(date +%Y-%m-%d-%H%M)"
IMG_NAME="$BASENAME-$BUILDMARK"
TMP_IMG_NAME="$IMG_NAME-tmp"

PANGOLIN="21023fb9-0a28-43a2-bcd9-2fca85670888"

LOG="./build.debug.log"
BASENAME="ubuntu-14.04"
TENANT_ID="772be1ffb32e42a28ac8e0205c0b0b90"
BUILDMARK="$(date +%Y-%m-%d-%H%M)"
IMG_NAME="$BASENAME-$BUILDMARK"
TMP_IMG_NAME="$IMG_NAME-tmp"

IMG=ubuntu-12.04-server-cloudimg-amd64-disk1.img
IMG_URL=http://cloud-images.ubuntu.com/releases/precise/release/$IMG

TMP_DIR=guest


if [ -f "$IMG" ]; then
    rm $IMG
fi

wget -q $IMG_URL

if [ ! -d "$TMP_DIR" ]; then
    mkdir $TMP_DIR
fi

guestmount -a $IMG -i $TMP_DIR

sed -i "/preserve_hostname/a manage_etc_hosts: true" $TMP_DIR/etc/cloud/cloud.cfg
sed -i "s#user: ubuntu#user: cloud#" $TMP_DIR/etc/cloud/cloud.cfg
sed -i "s#ubuntu#cloud#g" $TMP_DIR/etc/passwd $TMP_DIR/etc/shadow $TMP_DIR/etc/group $TMP_DIR/etc/sudoers.d/90-cloudimg-ubuntu

mv $TMP_DIR/home/ubuntu $TMP_DIR/home/cloud
sed -i "s#HostKey /etc/ssh/ssh_host_ed25519_key#\#HostKey /etc/ssh/ssh_host_ed25519_key#" $TMP_DIR/etc/ssh/sshd_config
sed -i "s#LABEL=cloudimg-rootfs#/dev/vda1#" $TMP_DIR/etc/fstab $TMP_DIR/boot/grub/menu.lst $TMP_DIR/boot/grub/grub.cfg
sed -i "s/#GRUB_DISABLE_LINUX_UUID/GRUB_DISABLE_LINUX_UUID/" $TMP_DIR/etc/default/grub

guestunmount $TMP_DIR

glance image-create \
       --file $IMG \
       --disk-format qcow2 \
       --container-format bare \
       --name "$TMP_IMG_NAME"

TMP_IMG_ID="$(openstack image list | grep $TMP_IMG_NAME | tr "|" " " | tr -s " " | cut -d " " -f2)"


sleep 20
packer build -var "playbook=bootstrap.yml" -var "user=cloud" -var "source_image=$TMP_IMG_ID" -var "image_name=$IMG_NAME" apt-bootstrap.packer.json

if [ "$?" != "0" ]; then
  echo "======= Packer failed on first pass. Temporary image kept for investigation: $TMP_IMG_ID"
  exit 1
fi

IMG_ID="$(openstack image list --private | grep $IMG_NAME | tr "|" " " | tr -s " " | cut -d " " -f2)"


# get all properties name except the mandatory ones
# openstack image show -f value -c properties 205230b8-cd8c-4eb8-bf6f-28bde8495c7e | tr ", " "\n" | grep -v "^$" | cut -d"=" -f1 | grep -v -E "(cw_os|cw_origin|hw_rng_model)"


# building the remove
# openstack image show -f value -c properties 205230b8-cd8c-4eb8-bf6f-28bde8495c7e | tr ", " "\n" | grep -v "^$" | cut -d"=" -f1 | grep -v -E "(cw_os|cw_origin|hw_rng_model)" | sed 's/^/--remove-property /g' | tr "\n" " "

# glance image-update $(openstack image show -f value -c properties 205230b8-cd8c-4eb8-bf6f-28bde8495c7e | tr ", " "\n" | grep -v "^$" | cut -d"=" -f1 | grep -v -E "(cw_os|cw_origin|hw_rng_model)" | sed 's/^/--remove-property /g' | tr "\n" " ")  205230b8-cd8c-4eb8-bf6f-28bde8495c7e


echo "======= Cleaning image properties"
script -q -c "glance image-update \
    --property cw_os=Ubuntu \
    --property cw_origin=Cloudwatt \
    --property hw_rng_model=virtio \
    --min-disk 10 \
    --purge-props $IMG_ID 1>&2 > /dev/null" /dev/null

echo "======= Cleaning unassociated floating ips..."

FREE_FLOATING_IP="$(neutron floatingip-list | grep -v "+" | grep -v "id" | tr -d " " | grep -v -E "^\|.+\|.+\|.+\|.+\|$" | cut -d "|" -f 2)"

for floating_id in $FREE_FLOATING_IP; do
    neutron floatingip-delete $floating_id >> $LOG 2>&1
done

echo "======= Cleaning old images..."

glance image-list | grep $BASENAME | tr "|" " " | tr -s " " |cut -d " " -f 3 | sort -r | awk 'NR>5' | xargs glance image-delete >> $LOG 2>&1

glance image-show $IMG_ID >> $LOG 2>&1

echo "======= Validation testing..."

URCHIN_IMG_ID=$IMG_ID $WORKSPACE/test-tools/urchin $WORKSPACE/test-tools/ubuntu-tests
