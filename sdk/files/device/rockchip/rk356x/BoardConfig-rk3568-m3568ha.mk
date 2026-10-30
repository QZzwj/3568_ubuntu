#!/bin/bash
#
# Board: M-3568HA (SCH_M-3568HA_2025-01-15.pdf, Rev V1.1)
#   SoC      : RK3568 (on the SOM, DDR4 16bit x2 + eMMC + RK809-5 PMIC/Codec)
#   Ethernet : 2 x Motorcomm YT8531SC-CA, RGMII0 / RGMII1_M1, PHY AD 0x0
#              reset GMAC0_RSTN_GPIO2_D3, GMAC1_RSTN_GPIO2_D1
#   WiFi/BT  : AP6276S (option AP6275S), SDIO = sdmmc2_m0, BT UART = uart8_m0,
#              WL_REGON GPIO3_D5, WL_WAKE GPIO3_D4, BT_REGON GPIO3_A0
#   Camera   : GC8034 MIPI CSI (i2c4_m0, PDN GPIO4_B4, RST GPIO0_D6)
#   Panel    : MIPI DSI0 4Lane / LVDS (LCD0), dual MIPI DSI1, eDP, HDMI2.0
#   TP       : i2c1, INT GPIO0_B5, RST GPIO0_B6
#   Misc     : HYM8563 RTC + MXC6655 G-sensor on i2c5_m0, NCA9555 on i2c3_m0,
#              4G M.2 (USB2_HOST3 + SIM), debug UART2 (ttyFIQ0 @1500000)
#
# Everything below is the standard RK3568 Linux layout; only RK_KERNEL_DTS
# (and the rootfs selection at the bottom) is board specific.

# Target arch
export RK_ARCH=arm64
# Uboot defconfig
export RK_UBOOT_DEFCONFIG=rk3568
# Uboot image format type: fit(flattened image tree)
export RK_UBOOT_FORMAT_TYPE=fit
# Kernel defconfig
export RK_KERNEL_DEFCONFIG=rockchip_linux_defconfig
# Kernel defconfig fragment
export RK_KERNEL_DEFCONFIG_FRAGMENT=
# Kernel dts
export RK_KERNEL_DTS=rk3568-m3568ha-linux
# boot image type
export RK_BOOT_IMG=boot.img
# kernel image path
export RK_KERNEL_IMG=kernel/arch/arm64/boot/Image
# kernel image format type: fit(flattened image tree)
export RK_KERNEL_FIT_ITS=boot.its
# parameter for GPT table (rootfs 6GB + userdata grow, fits 8GB eMMC)
# board specific partition table: 32GB eMMC -> 10GB rootfs + rest to userdata
export RK_PARAMETER=parameter-m3568ha.txt
# Buildroot config
export RK_CFG_BUILDROOT=rockchip_rk3568
# Recovery config
#   Ubuntu-only build: no buildroot based recovery (it would pull in a full
#   buildroot build). Flash/upgrade without recovery, or build buildroot once
#   and re-enable this.
export RK_CFG_RECOVERY=
# package-file without the "recovery" entry (see above)
export RK_PACKAGE_FILE=rk356x-package-file-m3568ha
# Recovery image format type: fit(flattened image tree)
export RK_RECOVERY_FIT_ITS=boot4recovery.its
# ramboot config
export RK_CFG_RAMBOOT=
# Pcba config
export RK_CFG_PCBA=
# Build jobs
export RK_JOBS=12
# target chip
export RK_TARGET_PRODUCT=rk356x
# Set rootfs type, including ext2 ext4 squashfs
export RK_ROOTFS_TYPE=ext4
# Set debian version (debian10: buster, debian11: bullseye)
export RK_DEBIAN_VERSION=buster
# Set ubuntu version (ubuntu20.04: focal, ubuntu22.04: jammy)
export RK_UBUNTU_VERSION=jammy
# WiFi/BT (AP6276S = BCM43752): install Rockchip rkwifibt firmware + rk_wifi_init
#   kernel 4.19 bcmdhd looks for /vendor/etc/firmware/{fw,nvram,clm}, so the
#   rootfs build mirrors /system/etc/firmware to /vendor/etc/firmware.
export RK_WIFIBT=y
export RK_WIFIBT_NVRAM=nvram_ap6275s.txt
# 固件集必须与 wifi5 bcmdhd 驱动(100.10.545.6)配套：rkwifibt deb 里的
# 2021 "release_he" 固件(18.35.387.23.57)会拒绝驱动的 escan v1，返回 -37
# (BCME_VERSION)，表现为扫描不到任何热点。这里钉死用 AP6275S 配套固件。
export RK_WIFIBT_FW_DIR=AP6275S
# Default rootfs of this board is Ubuntu 22.04 (override: export RK_ROOTFS_SYSTEM=buildroot)
export RK_ROOTFS_SYSTEM=${RK_ROOTFS_SYSTEM:-ubuntu}
# yocto machine
export RK_YOCTO_MACHINE=rockchip-rk3568-evb
# rootfs image path
export RK_ROOTFS_IMG=rockdev/rootfs.${RK_ROOTFS_TYPE}
# Set ramboot image type
export RK_RAMBOOT_TYPE=
# Set oem partition type, including ext2 squashfs
export RK_OEM_FS_TYPE=ext2
# Set userdata partition type, including ext2, fat
export RK_USERDATA_FS_TYPE=ext2
#OEM config
export RK_OEM_DIR=oem_normal
# OEM build on buildroot
#export RK_OEM_BUILDIN_BUILDROOT=YES
#userdata config
export RK_USERDATA_DIR=userdata_normal
#misc image
# 不用 wipe_all：它会写 BCB 让 U-Boot 进 recovery(wipe data) 模式。
# 本板不打包 recovery.img，用 wipe_all 会直接掉到 U-Boot 命令行。
export RK_MISC=blank-misc.img
#choose enable distro module
export RK_DISTRO_MODULE=
# Define pre-build script for this board
export RK_BOARD_PRE_BUILD_SCRIPT=app-build.sh
