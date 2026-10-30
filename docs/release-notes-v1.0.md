# v1.0 — M-3568HA Ubuntu 桌面层成品镜像

板卡 M-3568HA / SC-3568HA（RK3568），MIPI 屏 720×1280（系统 1280×720），Ubuntu 22.04 + XFCE 4.16。

## 这个镜像里有什么

| 项 | 内容 |
|---|---|
| 显示 | MIPI DSI0 ILI9881C 720×1280 点亮、DSI 时序/背光已调，开机 logo 为协会旗 |
| 桌面 | XFCE + picom 合成器、白色风格面板、mac 风格 dock（docklike）、活动窗口聚焦色 `#1246FF` |
| 触屏 | gt1x 触摸，按屏物理分辨率做了校准矩阵（右下角可点） |
| 网络 | AP6275S（bcmdhd）Wi-Fi 已起；镜像内含实验室 `EICA103` 的自动连接配置（`/etc/NetworkManager/system-connections/EICA103.nmconnection`，含明文 psk，公开发布前建议删掉这个文件） |
| 账号 | `eica` / `eica`，root 密码 `123456`；主机名 `rk3568` |

## 文件

`update.img` 原始大小 3 276 563 018 B（3.05 GiB），超过 GitHub 单个 asset 2 GiB 上限，因此分两卷：

| 文件 | 大小（B） | sha256 |
|---|---|---|
| `update.img0.part` | 1887436800 | `c95dc718ee8eaf9899219fff280a4056fcf9fe75e09d77e39b863c338569b53a` |
| `update.img1.part` | 1389126218 | `1e254e2c41b5634f9e288c99f01a9c2ca0d3fb693c9fa180ed268685207c4006` |

合并后整包 sha256：`011c43c54eeadbb659372a968e9ef586597e75da5faa6af4eb83be46f76b20a7`

```bash
cat update.img0.part update.img1.part > update.img
sha256sum update.img      # 应为 011c43c5...
```

## 烧写

USB 线接板子 OTG 口，按住 recovery 键上电进 loader/maskrom：

```bash
sudo tools/linux/Linux_Upgrade_Tool/Linux_Upgrade_Tool/upgrade_tool uf update.img

# 或者 Windows 上用瑞芯微驱动助手 + RKDevTool，选「升级固件」→ 固件 → 升级
```

## 从源码复现

```bash
git clone -b sdk-source --depth 1 https://github.com/QZzwj/3568_ubuntu.git rk3568_linux
cd rk3568_linux
./build.sh lunch        # 选 6 → BoardConfig-rk3568-m3568ha.mk
./build.sh kernel && ./build.sh firmware && ./build.sh updateimg
```

宿主依赖与不收录目录说明见主 README「构建 Ubuntu 镜像」章节。
