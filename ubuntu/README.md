# Ubuntu rootfs for RK3568 (Ubuntu 22.04 / jammy by default)

`ubuntu` is the 4th rootfs type of this SDK, next to `buildroot` / `debian` / `yocto`.
It is driven by `build.sh` exactly like the other ones, and its product ends up in
`rockdev/` together with uboot/kernel/recovery images.

## Quick start

```bash
cd <sdk>
sudo apt install qemu-user-static binfmt-support     # once
./build.sh lunch                                     # choose the board (5 = evb1-ddr4-v10)
export RK_ROOTFS_SYSTEM=ubuntu
./build.sh                                           # uboot + kernel + modules + rootfs
./build.sh firmware                                  # -> rockdev/ (parameter, boot.img, rootfs.ext4 ...)
./build.sh updateimg                                 # -> rockdev/update.img
```

Only (re)build the rootfs:

```bash
export RK_ROOTFS_SYSTEM=ubuntu
./build.sh ubuntu
```

## Directories

```
ubuntu/
├── mk-base-ubuntu.sh          # download ubuntu-base-<ver>-base-arm64.tar.gz
├── mk-rootfs-ubuntu.sh        # unpack -> chroot apt -> modules -> ubuntu-rootfs.img
├── overlay/                   # board files only Ubuntu needs
│   ├── etc/init.d/rkwifibt.sh
│   └── etc/systemd/system/ (rkwifibt.service, serial-getty@ttyFIQ0.service.d/override.conf)
├── binary/                    # unpacked rootfs (generated)
└── ubuntu-rootfs.img          # flashable ext4 (generated)
```

## Environment variables

* `RK_UBUNTU_VERSION` (board config, default `jammy`), `UBUNTU_RELEASE` (command line override)
  - `focal` = 20.04, `jammy` = 22.04, `noble` = 24.04
* `UBUNTU_MIRROR` - apt mirror inside the rootfs, default `https://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports`
* `DESKTOP=y` - install `xubuntu-desktop`
* `WIFIBT=y` - install Rockchip wifi/bt firmware + `rk_wifi_init` (from `debian/packages/arm64/rkwifibt/`)
* `EXTRA_PKGS="git python3-pip"` - extra apt packages
* `TARGET_HOSTNAME` - default `rk3568`
* `USER_NAME` / `USER_PASSWORD` - default `linaro` / `linaro`
* `ROOT_PASSWORD` - default `123456`
* `USE_DEBIAN_OVERLAY=y` - also copy `debian/overlay` (buster content, use with care)
* `EXTRA_SIZE_MB` - extra space of the ext4 image, default `500`

## What the rootfs contains

* `ubuntu-minimal` + `ubuntu-standard`, NetworkManager, ssh, 中文语言包, 上海时区
* kernel modules of the current `kernel/` build (`modules_install` + `rockchip_wlan` ko)
* `/etc/fstab` matching the SDK partition layout (`PARTLABEL=oem`, `PARTLABEL=userdata`)
* serial console on `ttyFIQ0` at **1500000** baud with root autologin (same as the Debian image)
* root password `123456`, user `linaro/linaro`, hostname `rk3568`

## Notes

* `parameter-buildroot-fit.txt` gives the rootfs partition 6GB, `mkfirmware.sh`
  checks the image size against it.
* `debian/packages/arm64/{libmali,rga,mpp,gst-rkmpp,...}` are Debian buster builds and
  are not installed here. On Ubuntu install the matching Ubuntu builds yourself if you
  need GPU / video decode / RGA.
* bootargs come from `rk3568-linux.dtsi`: `root=PARTUUID=614e0000-0000 ... rootwait`,
  do not change the rootfs partition entry of `parameter-*.txt` unless you change it too.
