#!/bin/bash -e
#
# Download the ubuntu-base rootfs tarball (arm64) used by mk-rootfs-ubuntu.sh.
#
#   RELEASE=jammy ARCH=arm64 ./mk-base-ubuntu.sh
#
# Environment:
#   RELEASE             ubuntu release name, focal/jammy/noble (default: jammy)
#   ARCH                arm64 (default) / armhf
#   UBUNTU_BASE_MIRROR  base of the cdimage ubuntu-base mirror

RELEASE=${RELEASE:-${RK_UBUNTU_VERSION:-jammy}}
ARCH=${ARCH:-${RK_UBUNTU_ARCH:-arm64}}
MIRRORS="${UBUNTU_BASE_MIRROR:-} https://mirrors.tuna.tsinghua.edu.cn/ubuntu-cdimage/ubuntu-base/releases http://cdimage.ubuntu.com/ubuntu-base/releases"

cd "$(dirname "$(realpath "$BASH_SOURCE")")"

case "$RELEASE" in
	focal) UBUNTU_VER=20.04 ;;
	jammy) UBUNTU_VER=22.04 ;;
	noble) UBUNTU_VER=24.04 ;;
	*)
		echo -e "\e[31mUnsupported RELEASE=$RELEASE, use focal/jammy/noble\e[0m"
		exit 1
		;;
esac

case "$ARCH" in
	arm64|aarch64) ARCH=arm64 ;;
	arm|armhf|arm32) ARCH=armhf ;;
	*)
		echo -e "\e[31mUnsupported ARCH=$ARCH\e[0m"
		exit 1
		;;
esac

if ls ubuntu-base-"$UBUNTU_VER"*-base-"$ARCH".tar.gz >/dev/null 2>&1; then
	echo -e "\e[36mubuntu-base tarball already exists, skip downloading\e[0m"
	ls -lh ubuntu-base-"$UBUNTU_VER"*-base-"$ARCH".tar.gz
	exit 0
fi

for MIRROR in $MIRRORS; do
	LIST_URL="$MIRROR/$UBUNTU_VER/release/"
	echo -e "\e[36mLooking for ubuntu-base $UBUNTU_VER $ARCH at $LIST_URL\e[0m"

	TARBALL=$(curl -fsSL --connect-timeout 10 --max-time 60 "$LIST_URL" 2>/dev/null | \
		grep -oE "ubuntu-base-${UBUNTU_VER}(\.[0-9]+)?-base-${ARCH}\.tar\.gz" | \
		sort -uV | tail -1)

	[ -n "$TARBALL" ] || continue

	echo -e "\e[36mDownloading $LIST_URL$TARBALL ...\e[0m"
	if wget -c -O "$TARBALL" "$LIST_URL$TARBALL"; then
		ls -lh "$TARBALL"
		echo -e "\e[32mDone: ubuntu/$TARBALL\e[0m"
		exit 0
	fi

	echo -e "\e[33mFailed to download from $MIRROR, try next mirror\e[0m"
	rm -f "$TARBALL"
done

echo -e "\e[31mFailed to download ubuntu-base-$UBUNTU_VER $ARCH from all mirrors\e[0m"
exit 1
