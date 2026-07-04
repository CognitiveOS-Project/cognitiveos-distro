# shellcheck shell=sh
# shellcheck disable=SC2034
# This file is sourced by aports/scripts/mkimage.sh, not executed directly.
# Variables set here are read by mkimage.sh's build_profile() function.

profile_cognitiveos() {
    apkovl="genapkovl-cognitiveos.sh"
    hostname="cognitiveos"
    modloop_sign=no
    image_name="cognitiveos"

    case "$ARCH" in
        x86_64)
            profile_standard
            title="CognitiveOS"
            desc="AI-native operating system based on Alpine Linux"
            profile_abbrev="cog"
            apkovl="genapkovl-cognitiveos.sh"
            hostname="cognitiveos"
            arch="x86_64"
            modloop_sign=no
            image_name="cognitiveos"
            if [ -n "$COGNITIVEOS_PACKAGES_FILE" ] && [ -f "$COGNITIVEOS_PACKAGES_FILE" ]; then
                apks=$(grep -v '^#' "$COGNITIVEOS_PACKAGES_FILE" | tr '\n' ' ')
            else
                apks="alpine-base busybox openrc linux-lts alsa-utils alsa-lib iw wpa_supplicant dhcpcd libgpiod kbd mpv dosfstools e2fsprogs squashfs-tools acpid"
            fi
            ;;
        aarch64)
            profile_standard
            title="CognitiveOS (RPi)"
            desc="AI-native operating system for Raspberry Pi"
            profile_abbrev="cog"
            apkovl="genapkovl-cognitiveos.sh"
            hostname="cognitiveos"
            arch="aarch64"
            image_name="cognitiveos"
            kernel_flavors="rpi"
            kernel_addons=""
            initfs_cmdline="console=tty0 console=ttyAMA0 modules=loop,squashfs,sd-mod,usb-storage quiet"
            initfs_features="base ext4 keymap mmc squashfs usb"
            modloop_sign=no
            if [ -n "$COGNITIVEOS_PACKAGES_FILE" ] && [ -f "$COGNITIVEOS_PACKAGES_FILE" ]; then
                apks=$(grep -v '^#' "$COGNITIVEOS_PACKAGES_FILE" | tr '\n' ' ')
            else
                apks="alpine-base busybox openrc linux-rpi raspberrypi-bootloader raspberrypi-firmware alsa-utils alsa-lib iw wpa_supplicant dhcpcd libgpiod kbd mpv dosfstools e2fsprogs squashfs-tools acpid"
            fi
            ;;
    esac
}
