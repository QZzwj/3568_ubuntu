#!/bin/bash -e
#
# Build the Rockchip Ubuntu rootfs (ubuntu-base -> binary/ -> ubuntu-rootfs.img)
#
# Normally called by ./build.sh ubuntu, but can be used standalone:
#   RELEASE=jammy ./mk-rootfs-ubuntu.sh
#
# Environment:
#   RELEASE / RK_UBUNTU_VERSION  focal(20.04) / jammy(22.04) / noble(24.04), default jammy
#   ARCH                         arm64, default
#   UBUNTU_MIRROR                apt mirror, default tuna ubuntu-ports
#   DESKTOP=y                    install xubuntu-desktop
#   EXTRA_PKGS="a b c"           extra apt packages
#   WIFIBT=y                     install Rockchip wifi/bt firmware + rk_wifi_init
#   USE_DEBIAN_OVERLAY=y         also copy debian/overlay* (buster content)
#   TARGET_HOSTNAME              default rk3568
#   USER_NAME / USER_PASSWORD    default linaro / linaro
#   ROOT_PASSWORD                default 123456
#   EXTRA_SIZE_MB                extra space of the ext4 image, default 500

RELEASE=${RELEASE:-${RK_UBUNTU_VERSION:-jammy}}
ARCH=${ARCH:-${RK_UBUNTU_ARCH:-arm64}}
UBUNTU_MIRROR=${UBUNTU_MIRROR:-https://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports}
DESKTOP=${DESKTOP:-n}
WIFIBT=${WIFIBT:-n}
RK_WIFIBT_NVRAM=${RK_WIFIBT_NVRAM:-nvram_ap6275s.txt}
EXTRA_PKGS=${EXTRA_PKGS:-}
USE_DEBIAN_OVERLAY=${USE_DEBIAN_OVERLAY:-n}
TARGET_HOSTNAME=${TARGET_HOSTNAME:-rk3568}
USER_NAME=${USER_NAME:-linaro}
USER_PASSWORD=${USER_PASSWORD:-linaro}
ROOT_PASSWORD=${ROOT_PASSWORD:-123456}
EXTRA_SIZE_MB=${EXTRA_SIZE_MB:-500}
JOBS=${JOBS:-$(nproc)}

# 'make' may come from a non-standard PATH (e.g. a host-tools dir without root),
# and 'sudo make' would lose that PATH -> resolve the absolute path once here.
MAKE=${MAKE:-$(command -v make || true)}
if [ -z "$MAKE" ]; then
	echo -e "\e[31mmake not found, install it or add it to PATH\e[0m"
	exit 1
fi

case "$RELEASE" in
	focal) UBUNTU_VER=20.04 ;;
	jammy) UBUNTU_VER=22.04 ;;
	noble) UBUNTU_VER=24.04 ;;
	*)
		echo -e "\e[31mUnsupported RELEASE=$RELEASE, use focal/jammy/noble\e[0m"
		exit 1
		;;
esac

if [ "$ARCH" != "arm64" ]; then
	echo -e "\e[31mOnly arm64 is supported for now (RK3568 Linux uses aarch64 userspace)\e[0m"
	exit 1
fi

UBUNTU_DIR=$(dirname "$(realpath "$BASH_SOURCE")")
TOP_DIR=$(realpath "$UBUNTU_DIR/..")
TARGET_ROOTFS_DIR="$UBUNTU_DIR/binary"
ROOTFSIMAGE="$UBUNTU_DIR/ubuntu-rootfs.img"

TARBALL=$(ls "$UBUNTU_DIR"/ubuntu-base-"$UBUNTU_VER"*-base-"$ARCH".tar.gz 2>/dev/null | sort -V | tail -1 || true)
if [ -z "$TARBALL" ]; then
	echo -e "\e[36mubuntu-base-$UBUNTU_VER not found, downloading it...\e[0m"
	(cd "$UBUNTU_DIR" && RELEASE="$RELEASE" ARCH="$ARCH" ./mk-base-ubuntu.sh)
	TARBALL=$(ls "$UBUNTU_DIR"/ubuntu-base-"$UBUNTU_VER"*-base-"$ARCH".tar.gz 2>/dev/null | sort -V | tail -1 || true)
fi
if [ -z "$TARBALL" ]; then
	echo -e "\e[31mubuntu-base tarball for $UBUNTU_VER is missing\e[0m"
	exit 1
fi

QEMU_BIN=$(which qemu-aarch64-static || true)
if [ -z "$QEMU_BIN" ]; then
	echo -e "\e[31mqemu-aarch64-static not found: sudo apt install qemu-user-static binfmt-support\e[0m"
	exit 1
fi

# cache the sudo credentials once, otherwise the script asks for it many times
sudo -v || {
	echo -e "\e[31msudo is required to unpack/mount the rootfs\e[0m"
	exit 1
}

cleanup() {
	sudo umount "$TARGET_ROOTFS_DIR/dev/pts" 2>/dev/null || true
	sudo umount "$TARGET_ROOTFS_DIR/dev" 2>/dev/null || true
	sudo umount "$TARGET_ROOTFS_DIR/sys" 2>/dev/null || true
	sudo umount "$TARGET_ROOTFS_DIR/proc" 2>/dev/null || true
}
trap cleanup EXIT

echo -e "\e[36m========== Extract $(basename "$TARBALL") ==========\e[0m"
sudo rm -rf "$TARGET_ROOTFS_DIR"
mkdir -p "$TARGET_ROOTFS_DIR"
sudo tar -xpf "$TARBALL" -C "$TARGET_ROOTFS_DIR"

echo -e "\e[36m========== apt sources / qemu ==========\e[0m"
sudo cp "$QEMU_BIN" "$TARGET_ROOTFS_DIR/usr/bin/"

# ubuntu-base has no ca-certificates -> "Certificate verification failed:
# The certificate issuer is unknown" on https mirrors. Copy the host bundle.
if [ -f /etc/ssl/certs/ca-certificates.crt ]; then
	sudo mkdir -p "$TARGET_ROOTFS_DIR/etc/ssl/certs"
	sudo cp /etc/ssl/certs/ca-certificates.crt "$TARGET_ROOTFS_DIR/etc/ssl/certs/"
else
	echo -e "\e[33mWarning: /etc/ssl/certs/ca-certificates.crt not found on host, https mirror may fail\e[0m"
fi

# /etc/resolv.conf on the host is usually a systemd-resolved stub (127.0.0.53),
# which does not exist inside the chroot -> apt would fail to resolve.
sudo rm -f "$TARGET_ROOTFS_DIR/etc/resolv.conf"
awk '/^[[:space:]]*nameserver/ && !/127\.0\.0\.53/ {print}' /etc/resolv.conf 2>/dev/null \
	| sudo tee "$TARGET_ROOTFS_DIR/etc/resolv.conf" >/dev/null
{
	echo "nameserver 223.5.5.5"
	echo "nameserver 114.114.114.114"
} | sudo tee -a "$TARGET_ROOTFS_DIR/etc/resolv.conf" >/dev/null

# do not start daemons while installing packages in the chroot
sudo tee "$TARGET_ROOTFS_DIR/usr/sbin/policy-rc.d" >/dev/null <<'EOF'
#!/bin/sh
exit 101
EOF
sudo chmod +x "$TARGET_ROOTFS_DIR/usr/sbin/policy-rc.d"

sudo tee "$TARGET_ROOTFS_DIR/etc/apt/sources.list" >/dev/null <<EOF
deb $UBUNTU_MIRROR $RELEASE main restricted universe multiverse
deb $UBUNTU_MIRROR $RELEASE-updates main restricted universe multiverse
deb $UBUNTU_MIRROR $RELEASE-backports main restricted universe multiverse
deb $UBUNTU_MIRROR $RELEASE-security main restricted universe multiverse
EOF

sudo mkdir -p "$TARGET_ROOTFS_DIR/etc/apt/sources.list.d"
sudo rm -f "$TARGET_ROOTFS_DIR"/etc/apt/sources.list.d/ubuntu.sources

echo -e "\e[36m========== Rockchip overlay ==========\e[0m"
sudo cp -a "$UBUNTU_DIR/overlay/." "$TARGET_ROOTFS_DIR/"
# 'cp -a' preserves our host uid/gid (1000:1000) on the overlay's own dirs
# (/etc, /etc/systemd, ...), which would leave parts of /etc writable by the
# default user -> force root:root on everything the overlay provides.
(cd "$UBUNTU_DIR/overlay" && find . -mindepth 1 -printf '%P\n') | while IFS= read -r p; do
	sudo chown -h 0:0 "$TARGET_ROOTFS_DIR/$p"
done
sudo chmod +x "$TARGET_ROOTFS_DIR/etc/init.d/rkwifibt.sh" 2>/dev/null || true
sudo chmod +x "$TARGET_ROOTFS_DIR/usr/sbin/rk-resize-rootfs" 2>/dev/null || true

if [ "$USE_DEBIAN_OVERLAY" = "y" ]; then
	echo -e "\e[33mWarning: debian/overlay* is made for Debian buster, only copy what you need\e[0m"
	sudo cp -a "$TOP_DIR/debian/overlay/." "$TARGET_ROOTFS_DIR/"
fi

if [ "$WIFIBT" = "y" ]; then
	echo -e "\e[36m========== wifi/bt firmware (rkwifibt) ==========\e[0m"
	for deb in "$TOP_DIR"/debian/packages/arm64/rkwifibt/rkwifibt-*firmware*.deb \
		   "$TOP_DIR"/debian/packages/arm64/rkwifibt/rkwifibt-dev-tools_*.deb; do
		[ -f "$deb" ] || continue
		echo "  extracting $(basename "$deb")"
		sudo dpkg-deb -x "$deb" "$TARGET_ROOTFS_DIR"
	done
	# The 4.19 bcmdhd driver hard-codes /vendor/etc/firmware/{fw,nvram,clm}
	# (CONFIG_BCMDHD_FW_PATH/NVRAM_PATH). The debs ship the blobs under
	# /system/etc/firmware, so mirror them to /vendor and pick the nvram
	# matching this board's module (AP6276S == BCM43752).
	FW_SRC="$TARGET_ROOTFS_DIR/system/etc/firmware"
	FW_DST="$TARGET_ROOTFS_DIR/vendor/etc/firmware"
	if [ -d "$FW_SRC" ]; then
		sudo mkdir -p "$TARGET_ROOTFS_DIR/vendor/etc"
		sudo cp -a "$FW_SRC" "$TARGET_ROOTFS_DIR/vendor/etc/"
		if [ -f "$FW_SRC/$RK_WIFIBT_NVRAM" ]; then
			sudo cp -f "$FW_SRC/$RK_WIFIBT_NVRAM" "$FW_DST/nvram.txt"
			echo "  nvram.txt <- $RK_WIFIBT_NVRAM"
		else
			echo -e "\e[33mWarning: $RK_WIFIBT_NVRAM not found in /system/etc/firmware\e[0m"
		fi
	fi

	# The rkwifibt deb ships the 2021 "release_he" (18.35.387.23.57) blobs, which
	# reject the escan v1 request of this 2019 wifi5 bcmdhd (100.10.545.6) with
	# BCME_VERSION (-37) -> "wl_run_escan : Escan set error (-37)".
	# Pin the blobs to the AP6275S set that matches this driver instead.
	FW_PIN="${RK_WIFIBT_FW_DIR:-AP6275S}"
	FW_PIN_SRC="$TOP_DIR/external/rkwifibt/firmware/broadcom/$FW_PIN/wifi"
	if [ -d "$FW_PIN_SRC" ]; then
		echo "  pinning wifi blobs from $FW_PIN ($FW_PIN_SRC)"
		for f in fw_bcm43752a2_ag.bin clm_bcm43752a2_ag.blob "$RK_WIFIBT_NVRAM"; do
			if [ -f "$FW_PIN_SRC/$f" ]; then
				sudo cp -f "$FW_PIN_SRC/$f" "$FW_DST/$f"
				echo "    $f <- $FW_PIN/$(basename "$f")"
			fi
		done
		sudo cp -f "$FW_DST/$RK_WIFIBT_NVRAM" "$FW_DST/nvram.txt"
		echo "    nvram.txt <- $FW_PIN/$RK_WIFIBT_NVRAM"
	fi
fi

echo -e "\e[36m========== Build & install kernel modules ==========\e[0m"
# honour CROSS_COMPILE from build.sh, otherwise look for the SDK toolchains
if [ -z "$CROSS_COMPILE" ]; then
	for t in \
		gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu- \
		gcc-linaro-6.3.1-2017.05-x86_64_aarch64-linux-gnu/bin/aarch64-linux-gnu- \
		gcc-buildroot-9.3.0-2020.03-x86_64_aarch64-rockchip-linux-gnu/bin/aarch64-rockchip-linux-gnu-; do
		if [ -x "$TOP_DIR/prebuilts/gcc/linux-x86/aarch64/$t"gcc ]; then
			CROSS_COMPILE="$TOP_DIR/prebuilts/gcc/linux-x86/aarch64/$t"
			break
		fi
	done
fi
if [ -z "$CROSS_COMPILE" ] && command -v aarch64-linux-gnu-gcc >/dev/null 2>&1; then
	CROSS_COMPILE="$(dirname "$(command -v aarch64-linux-gnu-gcc)")/aarch64-linux-gnu-"
fi
echo "CROSS_COMPILE=${CROSS_COMPILE:-<host gcc>}"

if [ ! -f "$TOP_DIR/kernel/.config" ]; then
	echo "kernel/.config not found, run ./build.sh kernel first or let it use ${RK_KERNEL_DEFCONFIG:-rockchip_linux_defconfig}"
	make -C "$TOP_DIR/kernel" ARCH="$ARCH" CROSS_COMPILE="$CROSS_COMPILE" \
		"${RK_KERNEL_DEFCONFIG:-rockchip_linux_defconfig}"
fi
"$MAKE" -C "$TOP_DIR/kernel" ARCH="$ARCH" CROSS_COMPILE="$CROSS_COMPILE" modules -j"$JOBS"
sudo "$MAKE" -C "$TOP_DIR/kernel" ARCH="$ARCH" CROSS_COMPILE="$CROSS_COMPILE" \
	INSTALL_MOD_PATH="$TARGET_ROOTFS_DIR" modules_install

# rockchip_wlan modules are not covered by modules_install
if [ -d "$TOP_DIR/kernel/drivers/net/wireless/rockchip_wlan" ]; then
	KREL=$(ls "$TARGET_ROOTFS_DIR/lib/modules" | head -1)
	sudo mkdir -p "$TARGET_ROOTFS_DIR/lib/modules/$KREL/kernel/drivers/net/wireless"
	sudo find "$TOP_DIR/kernel/drivers/net/wireless/rockchip_wlan" -name '*.ko' \
		-exec cp {} "$TARGET_ROOTFS_DIR/lib/modules/$KREL/kernel/drivers/net/wireless/" \;
fi

echo -e "\e[36m========== apt install in chroot (this takes a while) ==========\e[0m"
cat > "$UBUNTU_DIR/.chroot-setup.sh" <<'CHROOT_EOF'
#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive
export LC_ALL=C
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

PKGS="ubuntu-minimal ubuntu-standard sudo openssh-server net-tools
network-manager wpasupplicant rfkill udev dbus vim htop curl wget rsync
ca-certificates iputils-ping netcat-openbsd tzdata locales
language-pack-zh-hans alsa-utils bash-completion fdisk e2fsprogs
usbutils pciutils psmisc less"

if [ "$DESKTOP" = "y" ]; then
	PKGS="$PKGS xubuntu-desktop xinit"
fi
if [ -n "$EXTRA_PKGS" ]; then
	PKGS="$PKGS $EXTRA_PKGS"
fi

echo "== apt-get update =="
if ! apt-get update; then
	echo "== https mirror failed, retry over http =="
	sed -i 's|^deb https://|deb http://|' /etc/apt/sources.list
	apt-get update || { echo "apt-get update failed, check the mirror/network"; exit 1; }
fi

echo "== install packages =="
apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" $PKGS

echo "== locale / timezone / hostname =="
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
echo "Asia/Shanghai" > /etc/timezone
locale-gen en_US.UTF-8 zh_CN.UTF-8 || true
update-locale LANG=en_US.UTF-8 || true
echo "$TARGET_HOSTNAME" > /etc/hostname
echo "127.0.0.1	localhost" > /etc/hosts
echo "127.0.1.1	$TARGET_HOSTNAME" >> /etc/hosts

echo "== users =="
if ! id "$TARGET_USER" >/dev/null 2>&1; then
	useradd -m -s /bin/bash -G sudo,audio,video,plugdev,netdev "$TARGET_USER"
fi
echo "$TARGET_USER:$TARGET_USER_PASS" | chpasswd
echo "root:$TARGET_ROOT_PASS" | chpasswd

echo "== fstab =="
cat > /etc/fstab <<FSTAB
/dev/root		/		ext4	rw,noatime	0	1
proc			/proc		proc	defaults	0	0
devpts			/dev/pts	devpts	defaults,gid=5,mode=620	0	0
tmpfs			/dev/shm	tmpfs	mode=0777	0	0
tmpfs			/tmp		tmpfs	mode=1777	0	0
tmpfs			/run		tmpfs	mode=0755,nosuid,nodev	0	0
sysfs			/sys		sysfs	defaults	0	0
PARTLABEL=oem		/oem		ext2	defaults	0	2
PARTLABEL=userdata	/userdata	ext2	defaults	0	2
FSTAB
mkdir -p /oem /userdata

echo "== services =="
systemctl enable NetworkManager >/dev/null 2>&1 || true
systemctl enable ssh >/dev/null 2>&1 || true
systemctl enable serial-getty@ttyFIQ0.service >/dev/null 2>&1 || true
# 屏幕只显示开机 logo: 不要在 tty1 上起 getty, 否则 fbcon 会盖掉画面
systemctl mask getty@tty1.service autovt@tty1.service >/dev/null 2>&1 || true
systemctl enable splash-logo.service >/dev/null 2>&1 || true
# 关掉 systemd-backlight 的"开机恢复亮度": 它会在启动时把亮度拉回上次保存值,
# 配合 40kHz PWM 调光会出现"开机闪一下/背光呼吸"的现象。
systemctl mask systemd-backlight@.service >/dev/null 2>&1 || true
systemctl enable rk-resize-rootfs.service >/dev/null 2>&1 || true
systemctl disable systemd-networkd.service systemd-networkd.socket >/dev/null 2>&1 || true
systemctl mask systemd-networkd-wait-online.service >/dev/null 2>&1 || true
if [ "$WIFIBT" = "y" ]; then
	systemctl enable rkwifibt.service >/dev/null 2>&1 || true
fi

echo "== depmod =="
for m in /lib/modules/*/; do
	depmod -a "${m%/}" || true
done

echo "== clean =="
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /root/.bash_history /usr/sbin/policy-rc.d
CHROOT_EOF

sudo cp "$UBUNTU_DIR/.chroot-setup.sh" "$TARGET_ROOTFS_DIR/tmp/chroot-setup.sh"
sudo mount -t proc /proc "$TARGET_ROOTFS_DIR/proc"
sudo mount -t sysfs /sys "$TARGET_ROOTFS_DIR/sys"
sudo mount -o bind /dev "$TARGET_ROOTFS_DIR/dev"
sudo mount -o bind /dev/pts "$TARGET_ROOTFS_DIR/dev/pts"
sudo chroot "$TARGET_ROOTFS_DIR" /usr/bin/env \
	DESKTOP="$DESKTOP" WIFIBT="$WIFIBT" EXTRA_PKGS="$EXTRA_PKGS" \
	TARGET_HOSTNAME="$TARGET_HOSTNAME" \
	TARGET_USER="$USER_NAME" TARGET_USER_PASS="$USER_PASSWORD" \
	TARGET_ROOT_PASS="$ROOT_PASSWORD" \
	/bin/bash /tmp/chroot-setup.sh
sudo rm -f "$TARGET_ROOTFS_DIR/tmp/chroot-setup.sh" "$UBUNTU_DIR/.chroot-setup.sh"

cleanup
trap - EXIT

sudo rm -f "$TARGET_ROOTFS_DIR/usr/bin/$(basename "$QEMU_BIN")"

echo -e "\e[36m========== Create ext4 image ==========\e[0m"
IMAGE_SIZE_MB=$(( $(sudo du -sm "$TARGET_ROOTFS_DIR" | cut -f1) + EXTRA_SIZE_MB ))
echo "rootfs size: ${IMAGE_SIZE_MB}MB (extra ${EXTRA_SIZE_MB}MB)"

rm -f "$ROOTFSIMAGE"
dd if=/dev/zero of="$ROOTFSIMAGE" bs=1M count=0 seek="$IMAGE_SIZE_MB" status=none
sudo mkfs.ext4 -q -L rootfs -d "$TARGET_ROOTFS_DIR" "$ROOTFSIMAGE"

echo -e "\e[32mDone: ubuntu/ubuntu-rootfs.img ($(du -h "$ROOTFSIMAGE" | cut -f1))\e[0m"
