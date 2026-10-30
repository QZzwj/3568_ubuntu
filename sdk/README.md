# sdk/ —— 让 SDK 编出这台板子的 Ubuntu 镜像

仓库不包含那个 40 GB 的 Rockchip Linux SDK（原因见文末），只放**本板相对底座的增量**：
一个补丁 + 一批新增文件，用一个脚本贴进任意一份同代 SDK 即可正常编译。

## 底座

| 项 | 值 |
|---|---|
| SDK | Rockchip Linux SDK（Linux 4.19.232 / U-Boot 2017.09） |
| 验证用的底座 | `https://github.com/Rosa1337/rk3568_linux` @ `82ca7e638` |
| 本补丁适配的目录布局 | `device/rockchip/common/`、`device/rockchip/rk356x/`、`kernel/`、`ubuntu/`、`tools/linux/Linux_Pack_Firmware/` |

板厂/官方给的同代 RK3568 Linux SDK 一般也能打上；补丁打不上时先看是不是底座版本不同。

## 内容

### `patches/0001-board-m3568ha-linux.patch`

9 个文件、`+245 / -48`：

| 文件 | 改了什么 |
|---|---|
| `device/rockchip/common/build.sh` | 增加 `ubuntu` 子命令与 `build_ubuntu()`（调用 `ubuntu/mk-rootfs-ubuntu.sh`）；`updateimg` 自动补 `mkupdate.sh` 软链 |
| `device/rockchip/common/mkfirmware.sh` | rootfs 产物按 `RK_ROOTFS_TYPE` 收拢 |
| `device/rockchip/rk356x/BoardConfig-rk3568-evb1-ddr4-v10.mk` | 默认 rootfs 改为 Ubuntu 22.04 |
| `kernel/arch/arm64/boot/dts/rockchip/Makefile` | 加入 `rk3568-m3568ha-{linux,nofiq,evb}.dtb` 编译目标 |
| `kernel/drivers/gpu/drm/rockchip/dw-mipi-dsi.c` | MIPI DSI 时序修正 |
| `kernel/drivers/input/touchscreen/gt1x/*` | GT1X 触摸屏：复位/中断时序、坐标与校验容错 |

### `files/`（23 个文件，按 SDK 根路径镜像）

| 路径 | 说明 |
|---|---|
| `device/rockchip/rk356x/BoardConfig-rk3568-m3568ha.mk` | 板级配置：DTS、分区表、Ubuntu 22.04、AP6275S 固件集 |
| `device/rockchip/rk356x/parameter-m3568ha.txt` | 32 GB eMMC 分区表（rootfs 10 GB） |
| `tools/linux/Linux_Pack_Firmware/rockdev/rk356x-package-file-m3568ha` | 打包清单（不含 recovery） |
| `kernel/arch/arm64/boot/dts/rockchip/rk3568-m3568ha.dtsi` | 板级 DTSI |
| `kernel/arch/arm64/boot/dts/rockchip/rk3568-m3568ha-linux.dts` | Linux 版 DTS（`#include "lcd-dsi0-mipi-m3568ha.dtsi"`） |
| `kernel/arch/arm64/boot/dts/rockchip/rk3568-m3568ha-{nofiq,evb}.dts` | 备用变体 |
| `kernel/arch/arm64/boot/dts/rockchip/lcd-dsi0-mipi-m3568ha.dtsi` | MIPI 屏参（ILI9881C 完整 190 条初始化序列） |
| `kernel/logo.bmp`、`kernel/logo_kernel.bmp` | 开机 Logo（U-Boot / kernel 两级） |
| `ubuntu/mk-base-ubuntu.sh`、`mk-rootfs-ubuntu.sh` | ubuntu-base 拉取 + chroot 装包 + ext4 出包 |
| `ubuntu/overlay/` | rootfs 需要的服务：rkwifibt、resize-rootfs、splash-logo、串口 getty；不含预置 Wi-Fi 连接（密码不进 git，开机用 `nmcli dev wifi connect` 连一次） |

## 用法

```bash
git clone https://github.com/QZzwj/3568_ubuntu.git ~/3568_ubuntu
~/3568_ubuntu/scripts/apply-to-sdk.sh ~/rk3568/rk3568_linux --dry-run   # 先看
~/3568_ubuntu/scripts/apply-to-sdk.sh ~/rk3568/rk3568_linux             # 应用
```

脚本会先探测补丁是否已应用（已应用则跳过），再把 `files/` 覆盖进 SDK。

```bash
cd ~/rk3568/rk3568_linux
./build.sh lunch            # 6 = BoardConfig-rk3568-m3568ha.mk
./build.sh info             # RK_KERNEL_DTS=rk3568-m3568ha-linux
export RK_ROOTFS_SYSTEM=ubuntu USER_NAME=eica USER_PASSWORD=eica DESKTOP=y
./build.sh ubuntu && ./build.sh firmware && ./build.sh updateimg
```

## 为什么不把整个 SDK 推上来

| 项 | 数字 |
|---|---|
| SDK 体积 | 40 GB（`ubuntu/` 19 GB、`external/` 4.3 GB、`kernel/` 3.9 GB） |
| 文件数 | 152 399 个（含 `.git` 4.6 GB） |
| GitHub 单文件上限 | 100 MB —— `rockdev/update.img` 3.1 GB、多份 `ubuntu-rootfs.img.*` 3 GB 全部超限 |
| 二进制分发 | `prebuilts/`、`external/` 里是第三方预编译二进制，不适合再分发 |

所以仓库只放「从底座到可编译」的最小增量：**补丁 502 行 + 23 个文件，9.2 MB**。
