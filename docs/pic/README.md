# M-3568HA / RK3568 Ubuntu 桌面效果图

板卡：M-3568HA（RK3568），系统：Ubuntu 22.04 + XFCE 4.16（X11 + picom）

显示：MIPI DSI0，面板 720x1280 竖屏，系统层面按 1280x720 横屏使用

主题：浅色白底，主色 `#1246FF`，辅色深蓝 `#2b3b5c`，正文 `#16233d`

## 截图清单

| 文件 | 内容 |
|---|---|
| `01-desktop.png` | 主界面：白色渐变壁纸 + 校徽/协会 Logo，顶部状态栏，底部 Dock |
| `02-launchpad.png` | 启动台：搜索框、分类标签（全部/网络/开发/图形/设置/系统）、7x4 图标网格、分页点 |
| `03-control-center.png` | 控制中心：亮度滑杆（直控背光 PWM）、声音输出通路切换 |
| `04-calendar.png` | 顶栏日历，当天以 `#1246FF` 高亮 |
| `05-desktop-menu.png` | 桌面右键菜单 |
| `06-topbar.png` | 顶栏特写：开始按钮、Wi-Fi/音量/时钟/电源，聚焦与悬停为 `#1246FF` |
| `07-dock.png` | Dock 特写：6 个 Papirus 48px 图标，悬停放大 1.3 倍 |

## 相关源码与配置（板端路径）

| 用途 | 路径 |
|---|---|
| 全局 GTK3 样式 | `/home/eica/.config/gtk-3.0/gtk.css` |
| 启动台 | `/usr/local/bin/m3568ha-launchpad` |
| 控制中心 | `/usr/local/bin/m3568ha-quickpanel` |
| 面板布局 | `/home/eica/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml` |
| 触屏旋转+边缘补偿 | `/etc/X11/xorg.conf.d/60-touchscreen-m3568ha.conf` |
| 壁纸 | `/usr/share/backgrounds/m3568ha-desk-light.png` |

## 截图方式

在板端用 Xlib 抓 root 窗口的 32bpp 原始数据，再用 ImageMagick 转 PNG：

```bash
python3 -c "
from Xlib import display, X
d=display.Display(); r=d.screen().root
open('/tmp/shot.raw','wb').write(r.get_image(0,0,1280,720,X.ZPixmap,0xffffffff).data)"
convert -size 1280x720 -depth 8 bgra:/tmp/shot.raw shot.png
```
