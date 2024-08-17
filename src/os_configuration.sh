#!/bin/bash

# Copy install script to drive
sudo mkdir -p "/mnt/${REPO_NAME}"
sudo cp -r "${SCRIPT_HOME}/"* "/mnt/${REPO_NAME}"
command="chown --recursive ${USER_NAME}:${USER_NAME} /${REPO_NAME}"

# default XDG folder
sudo sed -i "s/=Templates/=.templates/" /mnt/etc/xdg/user-dirs.defaults
sudo sed -i "s/^PUBLICSHARE/#PUBLICSHARE/" /mnt/etc/xdg/user-dirs.defaults
sudo sed -i "s/^PICTURES=Pictures/PICTURES=multimedia/" /mnt/etc/xdg/user-dirs.defaults
sudo sed -i "s/^VIDEOS/#VIDEOS/" /mnt/etc/xdg/user-dirs.defaults
sudo sed -i "s/^DOCUMENTS=Documents/DOCUMENTS=documents/" /mnt/etc/xdg/user-dirs.defaults
sudo sed -i "s/^MUSIC=Music/MUSIC=music/" /mnt/etc/xdg/user-dirs.defaults
sudo sed -i "s/^DOWNLOAD=Downloads/DOWNLOAD=downloads/" /mnt/etc/xdg/user-dirs.defaults
sudo sed -i "s/^DESKTOP/#DESKTOP/" /mnt/etc/xdg/user-dirs.defaults
if [[ "${HOST_NAME}" != *"vm"* ]]; then
    text_in_file_append "GAMES=games/" /mnt/etc/xdg/user-dirs.defaults
    text_in_file_append "VIRTUALMACHINES=virtual-machines/" /mnt/etc/xdg/user-dirs.defaults
fi

# hibernation resume
if [[ "${HOST_NAME}" != *"vm"* ]]; then
    # keyring decrypt with luks passphrase
    sudo sed -i "s/luks/luks,keyscript=decrypt_keyctl/" /mnt/etc/crypttab
    text_in_file_append "password        optional        pam_gnome_keyring.so use_authtok" /mnt/etc/pam.d/common-password

    swap_UUID=$(sudo blkid | grep /dev/mapper/data-swap | awk '{print $2}' | sed -r "s/(UUID=\")(.*)(\")/\2/")
    command="kernelstub -a  \"mem_sleep_default=deep resume=UUID=${swap_UUID}\""
    sudo chroot /mnt /bin/bash -c "${command}"
fi

command="sudo sed -i 's|http://us.|http://de.|' /etc/apt/sources.list.d/system.sources"
sudo chroot /mnt /bin/bash -c "${command}"

command="apt update && apt install -y ansible lm-sensors keyutils fprintd libpam-fprintd"
sudo chroot /mnt /bin/bash -c "${command}"

command="apt upgrade -y"
sudo chroot /mnt /bin/bash -c "${command}"

command="apt autoclean"
sudo chroot /mnt /bin/bash -c "${command}"

command="apt purge"
sudo chroot /mnt /bin/bash -c "${command}"

command="apt clean"
sudo chroot /mnt /bin/bash -c "${command}"
