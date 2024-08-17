# Pop!_OS 24.04 install



personal install and configuration script for Pop!_OS 24.04.
It will install Pop!_OS from the live usb environment and then restart to configure the system with [ansible](https://www.ansible.com/) and the user environment with [chezmoi](https://www.chezmoi.io/).
this repo only handles the installation and system configuration (with ansible).
Dotfiles handling and user envirnment configuration is part of the dotfiles repo which is managed with chezmoi

## Preparation

- download [Pop!_OS 24.04 alpha](https://system76.com/cosmic)
- move the iso onto an usb drive
  - I recommend [Ventoy](https://www.ventoy.net/en/index.html)
- (optional) copy project also to an usb drive
- connect usb drive(s) to the desired machine
- boot into Pop!_OS 24.04 live environment

## Install

> [!WARNING]
>
> - the script will format the selected drive
> - this means the drive will be wiped.
> - be warned. I have spoken.

> [!INFO]
>
> the script initiates a reboot. After the reboot password entering is required.
>
>

- there are two paths. Either with `git clone` or having the project on the usb drive and copying from there
- open terminal and execute

```bash
git clone https://github.com/MyNameIs-13/popos_install_2404
# or
cp -r <pathOnUsb>/popos_install_2404 ~/
```

- followed by

```bash
cd popos_install_2404
chmod +x install.sh
```

- finish with one or the other

```bash
./install.sh
# or
./install.sh -u <username> -p <password> -h <hostname> -d <driveToUse>
```

- follow on screen instructions

## TODO

- keyboard layout
- hibernation is untested & button in shutdown menu is missing
- disk encryption forwarding for keyring decryption
- define default applications for file extensions
- [fanctrl](https://github.com/MyNameIs-13/fw-fanctrl/) for framework laptop

Reason for a todo is one of the following:

- As Pop!_OS 24.04 is still an alpha, COSMIC is not yet feature complete. (option might not yet exist)
- Not decided if it is necessary
- Not decided if it should be part of dotfiles
