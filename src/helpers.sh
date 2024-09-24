#!/bin/bash

function validate_input() {
    local type="$1"
    local input="$2"

    case "${type}" in
        "username")
            # Validate username
            if [[ "${input}" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
                return 0
            else
                echo -e "${BOLD}The username must be between 1-32 characters.${NORMAL} It may only contain ASCII lower case letters, digits, underscore (_) and hyphen (-). It may not start with a hyphen" > $(tty)
                return 1
            fi
            ;;
        "hostname")
            # Validate hostname
            if [[ "${input}" =~ ^[a-zA-Z0-9]$|^[a-zA-Z0-9][-a-zA-Z0-9]{0,61}[a-zA-Z0-9]$ ]]; then
                return 0
            else
                echo -e "${BOLD}The hostname must be between 1-63 characters.${NORMAL} It may only contain ASCII letters, digits and hyphen (-). It may not end with a hyphen" > $(tty)
                return 1
            fi
            ;;
        "drive")
            # Validate drive name
            if [[ "${input}" =~ ^(sd[a-z]+|nvme[0-9]+n[0-9]+|hd[a-z]+|mmcblk[0-9]+|md[0-9]+|vd[a-z]+|xvd[a-z]+|loop[0-9]+)$ ]] && [[ -b "/dev/${input}" ]]; then
                return 0
            else
                echo > $(tty)
                lsblk > $(tty)
                echo -e "\n${BOLD}Please enter a disk name from the list above.${NORMAL} The disk will be used for your boot, root and swap partition" > $(tty)
                return 1
            fi
            ;;
        *)
            echo "Invalid validation type" > $(tty)
            return 1
            ;;
    esac
}

# Function to prompt user for input until it's valid
function prompt_until_valid() {
    local type="$1"
    local input="$2"  # Initial value from command-line argument, if any

    while true; do
        if [[ -z "${input}" ]]; then
            read -p "Enter ${type}: ${BOLD}" input
            echo "${NORMAL}" > $(tty)
            input="$(echo ${input} | sed 's/"//g')"
        fi

        if validate_input "${type}" "${input}"; then
            break
        else
            echo "Invalid ${type}, please try again." > $(tty)
            input=""
        fi
    done

    # Return the valid input to use it later if needed
    echo "${input}"
}

# Function to handle password input with confirmation and consent for short passwords
function prompt_password() {
    local password_input="$1"  # Initial value from command-line argument, if any
    local password=""
    local confirm_password=""
    local consent=""

    while true; do
        if [[ -z "${password_input}" ]]; then
            read -s -p "Enter password: " password
            echo > $(tty)

            read -s -p "${BOLD}Confirm password:${NORMAL} " confirm_password
            echo > $(tty)
        else
            password="${password_input}"
            confirm_password="${password_input}"
            password_input=""  # Reset after first use
        fi

        if [[ "${password}" == "${confirm_password}" ]]; then
            if [[ ${#password} -lt 8 ]]; then
                # Consent required for short password
                echo "Your password is less than 8 characters, which is considered less secure." > $(tty)
                read -p "${BOLD}Do you want to continue with this password?${NORMAL} (yes/no): " consent
                if [[ "${consent}" == "yes" ]]; then
                    break
                else
                    echo "Please enter a new password." > $(tty)
                    password_input=""
                fi
            else
                break
            fi
        else
            echo "${BOLD}Passwords do not match.${NORMAL} Please try again." > $(tty)
            password_input=""
        fi
    done

    # Return the valid password
    echo "$password"
}

function text_in_file_append() {
    local text="$1"
    local file="$2"

    if  test -f "${file}" && sudo grep -q "${text}" "${file}" ; then
        echo "" > /dev/null
    else
        echo "${text}" | sudo tee -a "${file}" > /dev/null
    fi
}

function autostart_entry() {
    local part="$1"

    sudo sh -c "cat > ${autostart_file}" << EOF
[Desktop Entry]
Type=Application
Exec=cosmic-term -- bash -c "/${REPO_NAME}/install.sh ${part} ; exec bash" &
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=continue-install
EOF
}

function autostart_file() {
    local autostart_file="$1"
    local part="$2"

    if [[ -e "${autostart_file}" ]]; then
        sudo rm "${autostart_file}"
    fi

    autostart_entry "${part}"
}

function initiate_reboot() {
    # reboot unless stopped by user
    local input

    echo
    echo
    for i in {30..0}; do
        printf "\r${BOLD}Rebooting in $i seconds.${NORMAL} Hit any key to stop."
        read -s -n 1 -t 1 input
        if [[ "$?" -eq 0 ]]; then
            break
        fi
    done

    if [[ "$i" != 0 ]]; then
        echo
        echo
        read -p "${BOLD}Press enter to reboot: ${NORMAL}"
    fi
    reboot
}


function connect_wifi() {
    # Define variables
    local ssid="$1"
    local encrypted_file="$2"

    # Scan for available WiFi networks
    AVAILABLE_NETWORKS=$(nmcli -t -f SSID dev wifi list)

    # Check if the desired SSID is available
    if echo "$AVAILABLE_NETWORKS" | grep -q "^$SSID$"; then
        echo
        echo "Connect to wifi network ${ssid} - ${BOLD}please enter passphrase to decrypt password${NORMAL}"
        # Decrypt the password
        WIFI_PASSWORD=$(gpg --decrypt $ENCRYPTED_FILE 2>/dev/null)
        # Check if decryption was successful
        if [ -z "$WIFI_PASSWORD" ]; then
            echo "Failed to decrypt the WiFi password."
            return
        fi
        # Connect to the WiFi using nmcli
        nmcli dev wifi connect "$SSID" password "$WIFI_PASSWORD"
        sleep 5  # give network some time to connect
    else
        echo "WiFi network '$SSID' is not available."
    fi
}

function check_internet() {
    local ssid="$1"
    local encrypted_file="$2"

    if [[ "${skip}" != 1 ]]; then
        if ! (: >/dev/tcp/8.8.8.8/53) >/dev/null 2>&1; then
            connect_wifi "${ssid}" "${encrypted_file}"
        fi
        while true; do
            if (: >/dev/tcp/8.8.8.8/53) >/dev/null 2>&1; then
                break
            else
                echo "${BOLD}Offline. Please connet to the internet${NORMAL}"
                read -p "Press enter when connected (write - ${BOLD}skip${NORMAL} - and press enter to try without internet): ${BOLD}" input
                echo ${NORMAL}
                if [[ "${input}" == "skip" ]]; then
                    export skip=1
                    break
                fi
            fi
        done
    fi
}

function enable_chroot() {
    # unlock drive and mount
    if [[ "${DISK_NAME}" == *"nvme"* ]]; then
        p="p"
    else
        p=""
    fi
    BOOT_DRIVE="${DISK_NAME}${p}1"
    ROOT_DRIVE="${DISK_NAME}${p}3"
    if [[ "${HOST_NAME}" != *"vm"* ]]; then
        printf "%s\n" "${PASSWORD}" | sudo cryptsetup luksOpen "${ROOT_DRIVE}" encrypted_disk
        while true; do
            if [[ -b "/dev/data/root" ]]; then
                break
            fi
        done
        sudo mount "/dev/data/root" "/mnt"
    else
        sudo mount "${ROOT_DRIVE}" "/mnt"
    fi

    for i in /dev /dev/pts /proc /sys /run; do
        sudo mount -B "$i" /mnt"$i"
    done

    sudo mount "${BOOT_DRIVE}" "/mnt/boot/efi"
}
