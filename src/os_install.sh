FS="/cdrom/casper/filesystem.squashfs"
REMOVE="/cdrom/casper/filesystem.manifest-remove"
if [[ "${HOST_NAME}" != *"vm"* ]]; then
    SWAP_SIZE="$(grep MemTotal /proc/meminfo | awk '{print $2}')"
    if [ "${SWAP_SIZE}" -ge 32000000 ]; then
        SWAP_SIZE=34816  # 32GB + 2GB
    elif [ "${SWAP_SIZE}" -ge 16000000 ]; then
        SWAP_SIZE=18432  # 16GB + 2GB    
    elif [ "${SWAP_SIZE}" -ge 8000000 ]; then
        SWAP_SIZE=10240  # 8GB + 2GB
    else
        SWAP_SIZE=5102  # 4GB + 1GB
    fi
fi


DISK_NAME="/dev/${DISK_NAME}"
if ! test "${DISK_NAME}"; then
    echo "must provide a block device as an argument"
    exit 1
fi

if ! test -b "${DISK_NAME}"; then
    echo "provided argument is not a block device"
    exit 1
fi

for file in "$FS" "$REMOVE"; do
    if ! test -e "${file}"; then
        echo "failed to find ${file}"
        exit 1
    fi
done

if [[ "${HOST_NAME}" != *"vm"* ]]; then
    echo "${PASSWORD}" | sudo distinst \
        -s "${FS}" \
        -r "${REMOVE}" \
        -h "${HOST_NAME}" \
        -k "us" \
        -l "en_US.UTF-8" \
        -b "${DISK_NAME}" \
        -t "${DISK_NAME}:gpt" \
        -n "${DISK_NAME}:primary:start:512M:fat32:mount=/boot/efi:flags=esp" \
        -n "${DISK_NAME}:primary:512M:4608M:fat32:mount=/recovery" \
        -n "${DISK_NAME}:primary:4608M:end:enc=encrypted_disk,data,pass=${PASSWORD}" \
        --logical "data:root:-${SWAP_SIZE}M:ext4:mount=/" \
        --logical "data:swap:${SWAP_SIZE}M:swap" \
        --username "${USER_NAME}" \
        --realname "${USER_NAME}" \
        --profile_icon "/usr/share/pixmaps/faces/pop-robot.png" \
        --tz "Europe/Brussels" \
        --hardware-support
else
    echo "${PASSWORD}" | sudo distinst \
        -s "${FS}" \
        -r "${REMOVE}" \
        -h "${HOST_NAME}" \
        -k "us" \
        -l "en_US.UTF-8" \
        -b "${DISK_NAME}" \
        -t "${DISK_NAME}:gpt" \
        -n "${DISK_NAME}:primary:start:512M:fat32:mount=/boot/efi:flags=esp" \
        -n "${DISK_NAME}:primary:512M:4608M:fat32:mount=/recovery" \
        -n "${DISK_NAME}:primary:4608M:end:ext4:mount=/" \
        --username "${USER_NAME}" \
        --realname "${USER_NAME}" \
        --profile_icon "/usr/share/pixmaps/faces/pop-robot.png" \
        --tz "Europe/Brussels" \
        --hardware-support
fi
