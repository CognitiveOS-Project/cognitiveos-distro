#!/bin/sh -e

HOSTNAME="$1"
if [ -z "$HOSTNAME" ]; then
    echo "usage: $0 hostname"
    exit 1
fi

cleanup() {
    rm -rf "$tmp"
}

makefile() {
    OWNER="$1"
    PERMS="$2"
    FILENAME="$3"
    cat > "$FILENAME"
    chown "$OWNER" "$FILENAME"
    chmod "$PERMS" "$FILENAME"
}

rc_add() {
    mkdir -p "$tmp"/etc/runlevels/"$2"
    ln -sf /etc/init.d/"$1" "$tmp"/etc/runlevels/"$2"/"$1"
}

tmp="$(mktemp -d)"
trap cleanup EXIT

# Copy overlay files first (provides config, inittab, hostname, motd, etc.)
if [ -n "$COGNITIVEOS_OVERLAY_DIR" ] && [ -d "$COGNITIVEOS_OVERLAY_DIR" ]; then
    (cd "$COGNITIVEOS_OVERLAY_DIR" && tar -cf - .) | (cd "$tmp" && tar -xf -)
fi

# Fill in any missing base config files
mkdir -p "$tmp/etc"

if [ ! -f "$tmp/etc/hostname" ]; then
    makefile root:root 0644 "$tmp/etc/hostname" <<EOF
$HOSTNAME
EOF
fi

if [ ! -f "$tmp/etc/inittab" ]; then
    makefile root:root 0644 "$tmp/etc/inittab" <<'EOF'
::sysinit:/sbin/openrc sysinit
::sysinit:/sbin/openrc boot
::wait:/sbin/openrc default
::shutdown:/sbin/openrc shutdown
tty1::respawn:/sbin/getty 38400 tty1
tty2::respawn:/sbin/getty 38400 tty2
tty3::respawn:/sbin/getty 38400 tty3
tty4::respawn:/sbin/getty 38400 tty4
tty5::respawn:/sbin/getty 38400 tty5
tty6::respawn:/sbin/getty 38400 tty6
EOF
fi

if [ ! -f "$tmp/etc/motd" ]; then
    makefile root:root 0644 "$tmp/etc/motd" <<'EOF'
Welcome to CognitiveOS
EOF
fi

# Write /etc/apk/world from packages file (defines system packages)
mkdir -p "$tmp/etc/apk"
if [ -n "$COGNITIVEOS_PACKAGES_FILE" ] && [ -f "$COGNITIVEOS_PACKAGES_FILE" ]; then
    makefile root:root 0644 "$tmp/etc/apk/world" < "$COGNITIVEOS_PACKAGES_FILE"
else
    makefile root:root 0644 "$tmp/etc/apk/world" <<'EOF'
alpine-base
busybox
openrc
linux-lts
alsa-utils
alsa-lib
iw
wpa_supplicant
dhcpcd
libgpiod
kbd
mpv
dosfstools
e2fsprogs
squashfs-tools
acpid
EOF
fi

# Set up OpenRC runlevels
rc_add devfs sysinit
rc_add dmesg sysinit
rc_add mdev sysinit
rc_add hwdrivers sysinit
rc_add modloop sysinit
rc_add hwclock boot
rc_add modules boot
rc_add sysctl boot
rc_add hostname boot
rc_add bootmisc boot
rc_add syslog boot
rc_add mount-ro shutdown
rc_add killprocs shutdown
rc_add savecache shutdown
rc_add acpid default

# Create the apkovl tarball in the current directory (DESTDIR)
tar -c -C "$tmp" etc | gzip -9n > "$HOSTNAME.apkovl.tar.gz"
