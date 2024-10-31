#!/bin/bash

export OUR_DISK=/dev/sdb
export OUR_USER=johndoe
export PART_BOOT=${OUR_DISK}1
export PART_ROOT=${OUR_DISK}2
export MP_ROOT=/mnt
export MP_BOOT_EFI=${MP_ROOT}/boot/efi
export SWAP_FILE=${MP_ROOT}/swapfile
export OUR_SWAPSIZE=4G
export UBUNTU_MIRROR=mirror.corbina.net
export ETH_INTERFACE=ens33

stage_prepare() {
  echo -e "\nStage - Prepare\n"
  swapoff ${SWAP_FILE}
  umount ${PART_BOOT}
  umount ${PART_ROOT}
  partprobe && udevadm trigger
}

stage_wipefs() {
  echo -e "\nStage - WipeFS\n"
  wipefs ${OUR_DISK}
}

stage_parted() {
  echo  -e "\nStage - Parted\n"
  #sfdisk --delete ${OUR_DISK}
  parted ${OUR_DISK} --script -- mklabel gpt
  parted -s --align=optimal ${OUR_DISK} mkpart ESP fat32 1MiB 511Mib
  parted -s ${OUR_DISK} set 1 esp on
  parted -s --align=optimal ${OUR_DISK} mkpart xfs 511Mib 100%
  partprobe && udevadm trigger
  parted ${OUR_DISK}  --script -- print
}

stage_mkfs() {
  echo  -e "\nStage - MKFS\n"
  mkfs.fat -F 32 -n EFI ${PART_BOOT}
  mkfs.xfs -L root -f ${PART_ROOT}
}

stage_mount() {
  echo  -e "\nStage - Mount\n"
  mount ${PART_ROOT} ${MP_ROOT}
  mkdir -p ${MP_BOOT_EFI}
  mount -o defaults,nosuid,nodev,relatime,errors=remount-ro ${PART_BOOT} ${MP_BOOT_EFI}
}

stage_swap() {
  echo  -e "\nStage - Swap\n"
  fallocate -l ${OUR_SWAPSIZE} ${SWAP_FILE}
  chmod 600 ${SWAP_FILE}
  mkswap ${SWAP_FILE}
  swapon ${SWAP_FILE}
}

stage_debootstrap() {
  echo -e "\nStage - Debootstrap\n"
  debootstrap --verbose --variant=minbase --arch=amd64 noble ${MP_ROOT} https://${UBUNTU_MIRROR}/ubuntu/
}

stage_pre_configure() {
  echo -e "\nStage - PreConfigure\n"
  genfstab -U ${MP_ROOT} > ${MP_ROOT}/etc/fstab
  cat <<EOF > ${MP_ROOT}/etc/apt/sources.list
deb https://${UBUNTU_MIRROR}/ubuntu noble main restricted universe
deb https://${UBUNTU_MIRROR}/ubuntu noble-security  main restricted universe
deb https://${UBUNTU_MIRROR}/ubuntu noble-updates   main restricted universe
deb https://${UBUNTU_MIRROR}/ubuntu noble-backports main restricted universe
EOF

 cat <<EOF > ${MP_ROOT}/etc/systemd/network/ethernet.network
[Match]
Name=${ETH_INTERFACE}

[Network]
DHCP=yes
EOF
}

stage_chroot_prepare() {
  echo -e "\nStage - CHROOT::Prepare\n"
  arch-chroot ${MP_ROOT} bash <<EOF
  apt update
  DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y --assume-yes \
    linux-{,image-,headers-}generic linux-firmware \
    initramfs-tools efibootmgr xfsprogs \
    tzdata locales keyboard-configuration console-setup \
    grub-efi-amd64-bin grub-efi-amd64 \
    open-vm-tools \
    systemd systemd-resolved netplan.io \
    netcat-openbsd tcpdump telnet iputils-ping iproute2 net-tools \
    sudo at curl dmidecode ethtool gawk git gnupg htop btop man command-not-found \
    needrestart openssh-client openssh-server patch screen software-properties-common zstd neovim bash tmux

  locale-gen en_US.UTF-8 && update-locale LANG=en_US.UTF-8
  dpkg-reconfigure --frontend noninteractive locales tzdata keyboard-configuration console-setup
  apt upgrade --assume-yes

  useradd -mG sudo --shell /bin/bash ${OUR_USER}
  echo ${OUR_USER}:${OUR_USER} | chpasswd
EOF
}

stage_post_configure() {
  echo -e "\nStage - PostConfigure\n"
  cat <<EOF > ${MP_ROOT}/etc/systemd/network/ethernet.network
[Match]
Name=${ETH_INTERFACE}

[Network]
DHCP=ipv4
EOF

#  cat <<EOF > ${MP_ROOT}/etc/netplan/00-installer-config.yaml
#
#network:
#  ethernets:
#    ${ETH_INTERFACE}:
#      dhcp4: true
#  version: 2
#EOF

arch-chroot ${MP_ROOT} bash <<EOF
  systemctl enable systemd-networkd
  systemctl enable systemd-resolved
  systemctl enable ssh
EOF
}

stage_grub() {
  echo -e "\nStage - GRUB\n"
  arch-chroot ${MP_ROOT} bash <<EOF
    grub-install --force --recheck --removable --target=x86_64-efi --boot-directory=/boot \
      --efi-directory=/boot/efi ${OUR_DISK}
    sed -i 's/"quiet splash"$/""/g' /etc/default/grub
    update-grub
EOF
}

stage_prepare
stage_wipefs
stage_parted
stage_mkfs
stage_mount
stage_swap
stage_debootstrap
stage_pre_configure
stage_chroot_prepare
stage_post_configure
stage_grub

