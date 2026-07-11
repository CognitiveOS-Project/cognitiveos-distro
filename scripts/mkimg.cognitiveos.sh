# shellcheck shell=sh
# shellcheck disable=SC2034,SC2153
# This file is sourced by aports/scripts/mkimage.sh — not executed directly.

profile_cognitiveos() {
    profile_standard
    title="CognitiveOS"
    desc="AI-native operating system based on Alpine Linux"
    profile_abbrev="cog"
    apkovl="genapkovl-cognitiveos.sh"
    hostname="cognitiveos"
    modloop_sign=no
    image_name="cognitiveos"
    image_ext="iso"

    case "$ARCH" in
        x86_64)
            arch="x86_64"
            ;;
        aarch64)
            arch="aarch64"
            kernel_flavors="rpi"
            kernel_addons=""
            initfs_cmdline="console=tty0 console=ttyAMA0 modules=loop,squashfs,sd-mod,usb-storage quiet"
            initfs_features="base ext4 keymap mmc squashfs usb"
            ;;
        armv7)
            arch="armv7"
            kernel_flavors="rpi"
            kernel_addons=""
            initfs_cmdline="console=tty0 console=ttyAMA0 modules=loop,squashfs,sd-mod,usb-storage quiet"
            initfs_features="base ext4 keymap mmc squashfs usb"
            ;;
    esac

    if [ -n "$COGNITIVEOS_PACKAGES_FILE" ] && [ -f "$COGNITIVEOS_PACKAGES_FILE" ]; then
        apks=$(grep -v '^#' "$COGNITIVEOS_PACKAGES_FILE" | tr '\n' ' ')
    fi
}
