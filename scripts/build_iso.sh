#!/usr/bin/env bash

set -e

HASH="$(openssl passwd -6 -stdin <<<"${ROOT_PASS:?}")"

PKG_LIST=(
  lvm2
  curl
  openssh-server
  pciutils
  iproute2
  firmware-linux-free
  firmware-linux-nonfree
  firmware-bnx2
  firmware-bnx2x
)

mkdir -p /build/rescue-iso
cd /build/rescue-iso || exit

lb config \
  --distribution bookworm \
  --architectures amd64 \
  --debian-installer none \
  --archive-areas "main contrib non-free non-free-firmware" \
  --apt-indices false \
  --memtest none \
  --binary-images iso-hybrid

echo "${PKG_LIST[*]}" >config/package-lists/rescue.list.chroot

mkdir -p config/hooks/live

cat <<EOF >config/hooks/live/01-setup-system.chroot
#!/bin/sh
echo "root:${HASH:?}" | chpasswd -e
sed -i 's/#PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config

mkdir -p /root/.ssh
echo "${SSH_KEY:?}" > /root/.ssh/authorized_keys
chmod 700 /root/.ssh
chmod 600 /root/.ssh/authorized_keys

if [ -f /root/.ssh/authorized_keys ]; then
  echo "SSH Key successfully injected into /root/.ssh/authorized_keys"
else
  echo "ERROR: SSH Key injection failed!"
  exit 1
fi
EOF

chmod +x config/hooks/live/01-setup-system.chroot
lb build
mv live-image-amd64.hybrid.iso /output/rescue-deb-amd64.iso
