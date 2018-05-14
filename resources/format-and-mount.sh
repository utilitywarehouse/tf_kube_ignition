#!/bin/bash

volume_id="$1"
filesystem="$2"
user="$3"
group="$4"
mountpoint="$5"

locations="
  /dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_${volume_id}
  /dev/${volume_id}
  /dev/disk/by-id/google-${volume_id}
"

until mountpoint -q ${mountpoint}; do
  sleep 8
  for device in ${locations}; do
    echo "Looking for device ${device}..."
    if [[ -e "${device}" ]]; then
      echo "Device ${device} found"
      fsck -a ${device} || (
        mkfs.${filesystem} ${device} \
        && mount ${device} /mnt \
        && chown -R ${user}:${group} /mnt \
        && umount /mnt
      )
      mkdir -p ${mountpoint}
      mount -t ${filesystem} ${device} ${mountpoint}
      echo "${device} mounted at ${mountpoint}"
      break
    fi
  done
done
