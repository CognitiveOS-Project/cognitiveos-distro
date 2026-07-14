#!/bin/sh -e

HOSTNAME="${1?usage: $0 hostname}"
cleanup() { rm -rf "$tmp"; }

makefile() {
    OWNER="$1" PERMS="$2" FILENAME="$3"
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

if [ -n "$COGNITIVEOS_OVERLAY_DIR" ] && [ -d "$COGNITIVEOS_OVERLAY_DIR" ]; then
    (cd "$COGNITIVEOS_OVERLAY_DIR" && tar -cf - .) | (cd "$tmp" && tar -xf -)
fi

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

for svc in devfs dmesg mdev hwdrivers modloop; do rc_add "$svc" sysinit; done
for svc in hwclock modules sysctl hostname bootmisc syslog; do rc_add "$svc" boot; done
for svc in mount-ro killprocs savecache; do rc_add "$svc" shutdown; done
rc_add acpid default

# CognitiveOS services
rc_add cograw default
rc_add coginfer default
rc_add cpm-boot-deps default
rc_add cognitiveosd default
rc_add cpm-runtime-deps default

tar -c -C "$tmp" etc | gzip -9n > "$HOSTNAME.apkovl.tar.gz"
