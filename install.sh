#!/bin/bash

SCRIPT_HOME="$(dirname "${BASH_SOURCE[0]}")"
CONTINUE_SCRIPT="$1"
BOLD="$(tput bold)"
NORMAL="$(tput sgr0)"
AUTOSTART_FILE="/etc/xdg/autostart/continue-install.desktop"
REPO_NAME="popos_install_2404"
GIT_PATH="/home/${USER}/documents/scm/${REPO_NAME}"
SSID="Martin Router King"    # Replace with your WiFi SSID
ENCRYPTED_FILE="${SCRIPT_HOME}/src/wifi_password.gpg"

while getopts u:h:d:p: flag
do
    case "${flag}" in
        u) user_name_arg=${OPTARG};;
        h) host_name_arg=${OPTARG};;
        d) disk_name_arg=${OPTARG};;
        p) password_arg=${OPTARG};;
    esac
done

source "${SCRIPT_HOME}/src/helpers.sh"

# PART 1: DURING LIVE ENVIRONMENT
if [[ -z "${CONTINUE_SCRIPT}" || -z "${CONTINUE_SCRIPT##*[!0-9]*}" ]]; then
    echo -e "\n__________________________________________________________\n"
    echo "${BOLD}Welcome to the custom GSK installer!${NORMAL}"
    echo -e "\n__________________________________________________________\n"

    # TODO: find a better way to detect if inside of live-environment
    if [[ "${USER}" != "pop-os" && "${HOSTNAME}" != "pop-os" ]]; then
        echo "please boot into a live environment"
        exit 1
    fi

    USER_NAME=$(prompt_until_valid username "${user_name_arg}")
    unset user_name_arg
    HOST_NAME=$(prompt_until_valid hostname "${host_name_arg}")
    unset host_name_arg
    DISK_NAME=$(prompt_until_valid drive "${disk_name_arg}")
    unset disk_name_arg
    PASSWORD=$(prompt_password "${password_arg}")
    unset password_arg

    # Control output
    echo "All inputs are valid!"
    echo "Username: ${USER_NAME}"
    echo "Hostname: ${HOST_NAME}"
    echo "Drive: ${DISK_NAME}"
    echo "Password is set."

    check_internet "${SSID}" "${ENCRYPTED_FILE}"  # early to have all user interactions together early

    source "${SCRIPT_HOME}/src/os_install.sh"
    enable_chroot
    unset PASSWORD
    source "${SCRIPT_HOME}/src/os_configuration.sh"

    sudo mkdir -p "/mnt/etc/xdg/autostart/"
    autostart_file "/mnt${AUTOSTART_FILE}" 1
    initiate_reboot
else

    echo -e "\n__________________________________________________________\n"
    echo "${BOLD}Welcome back to the custom GSK installer!${NORMAL}"
    echo -e "\n__________________________________________________________\n"
    HOST_NAME="${HOSTNAME}"
    USER_NAME="${USER}"

    if [[ "${CONTINUE_SCRIPT}" -eq 1 ]]; then

        check_internet "${SSID}" "${ENCRYPTED_FILE}"  # early to have all user interactions together early

        # FIXME remove as soon as cosmic creates keyring and handles encryption pass forwarding
        echo
        echo "${BOLD}Create keyring 'Login' with empty password and set as default keyring${NORMAL}"
        seahorse

        if [[ $(fprintd-list ${USER}) != "No devices available" ]]; then
            fprintd-enroll
            sudo pam-auth-update
        fi

        # Copy install script to drive
        sudo mkdir -p "${GIT_PATH}"
        sudo chown ${USER}:${USER} "${GIT_PATH}/.."
        sudo cp -r "/${REPO_NAME}/"* "${GIT_PATH}"
        sudo chown --recursive ${USER}:${USER} "${GIT_PATH}"

        sudo update-initramfs -k all -c

        sudo nala upgrade -y
        sudo sensors-detect --auto

        # remove autostart file and install script in root
        autostart_file "${AUTOSTART_FILE}"
        sudo rm -r "/${REPO_NAME}"

        tags="gui,home"
        if [[ "${HOST_NAME}" == *"vm"* ]]; then
            tags+=",vm"
        fi
        if command -v dmidecode &> /dev/null; then
            chassis_type=$(sudo dmidecode -s chassis-type)
            case "${chassis_type}" in
                "Notebook" | "Portable" | "Laptop")
                    tags+=",laptop"
                    ;;
                "Desktop" | "Tower" | "Mini Tower" | "Desktop or Tower")
                    tags+=",desktop"
                    ;;
                *)
                    echo "Unknown chassis type: ${chassis_type}"
                    ;;
            esac
        fi
        inventory="${GIT_PATH}/ansible/localhost"
        sudo ansible-playbook "${GIT_PATH}/ansible/main.yml" -i "${inventory}" -t "${tags}" -e main_user=${USER}

        # FIXME initialize dotfiles repo as soon as it exists
        # chezmoi init git@github.com:$GITHUB_USERNAME/dotfiles.git
fi
