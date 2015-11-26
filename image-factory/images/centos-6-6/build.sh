#!/bin/sh

. ../../factory-env.sh

BASENAME="CentOS-6"
# TENANT_ID="772be1ffb32e42a28ac8e0205c0b0b90"
BUILDMARK="$(date +%Y-%m-%d-%H%M)"
IMG_NAME="$BASENAME-$BUILDMARK"
TMP_IMG_NAME="$IMG_NAME-tmp"

IMG=CentOS-6-x86_64-GenericCloud.qcow2
IMG_URL=http://cloud.centos.org/centos/6.6/images/$IMG

TMP_DIR=centos-guest

if [ -f "$IMG" ]; then
  echo "rm $IMG"
  rm $IMG
fi

echo "wget -q $IMG_URL"
wget -q $IMG_URL

if [ ! -d "$TMP_DIR" ]; then
  echo "mkdir $TMP_DIR"
  mkdir $TMP_DIR
fi

echo "guestmount -a $IMG -i $TMP_DIR"
guestmount -a $IMG -i $TMP_DIR

if [ "$?" != "0" ]; then
  echo "Failed to guestmount image"
  exit 1
fi

echo "sed -i \"s/name: centos/name: cloud/\" $TMP_DIR/etc/cloud/cloud.cfg"
sed -i "s/name: centos/name: cloud/" $TMP_DIR/etc/cloud/cloud.cfg

echo "guestunmount $TMP_DIR"
guestunmount $TMP_DIR

echo "glance image-create ... $IMG ... $TMP_IMG_NAME"
glance image-create \
       --file $IMG \
       --disk-format qcow2 \
       --container-format bare \
       --name "$TMP_IMG_NAME"

# TMP_IMG_ID="$(glance image-list --owner $TENANT_ID --is-public False | grep $TMP_IMG_NAME | tr "|" " " | tr -s " " | cut -d " " -f2)"
TMP_IMG_ID="$(glance image-list --is-public False | grep $TMP_IMG_NAME | tr "|" " " | tr -s " " | cut -d " " -f2)"
echo "TMP_IMG_ID for image '$TMP_IMG_NAME': $TMP_IMG_ID"

echo "packer build ... source_image=$TMP_IMG_ID ... image_name=$IMG_NAME ..."
packer build -var "source_image=$TMP_IMG_ID" -var "image_name=$IMG_NAME" ../yum-bootstrap.packer.json

if [ "$?" != "0" ]; then
  echo "Packer encountered an error"
  exit 1
fi

echo "glance image-delete $TMP_IMG_ID"
glance image-delete $TMP_IMG_ID

IMG_ID="$(glance image-list --is-public False | grep $IMG_NAME | tr "|" " " | awk '{print $2}')"
echo "IMG_ID for image '$IMG_NAME': $IMG_ID"

echo "script -q -c \"glance image-update ... $IMG_ID ...\" ..."
script -q -c "glance image-update \
    --property cw_os=CentOS \
    --property cw_origin=Cloudwatt \
    --property hw_rng_model=virtio \
    --min-disk 10 \
    --purge-props $IMG_ID 1>&2 > /dev/null" /dev/null

echo "======= Pruning unassociated floating ips"
FREE_FLOATING_IP="$(neutron floatingip-list | grep -v "+" | grep -v "id" | tr -d " " | grep -v -E "^\|.+\|.+\|.+\|.+\|$" | cut -d "|" -f 2)"
FREE_FLOATING_IP="$(neutron floatingip-list | grep -v "+" | grep -v "id" | tr -d " " | grep -v -E "^\|.+\|.+\|.+\|.+\|$" | cut -d "|" -f 2)"
for floating_id in $FREE_FLOATING_IP; do
    neutron floatingip-delete $floating_id
done

echo "======= Deleting deprecated images"
glance image-list | grep -E "$BASENAME-[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{4}" | tr "|" " " | tr -s " " | cut -d " " -f 3 | sort -r | awk 'NR>5' # | xargs -r glance image-delete

glance image-show $IMG_ID

if [ "$?" = "0" ]; then
  URCHIN_IMG_ID=$IMG_ID "$WORKSPACE/test-tools/urchin" -f "$WORKSPACE/test-tools/ubuntu-tests"
fi
