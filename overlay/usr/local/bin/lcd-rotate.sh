#!/bin/sh
# M-3568HA: MIPI 面板物理方向是竖屏(720x1280)，X 里旋转 90° 得到横向桌面
sleep 1
xrandr --output DSI-1 --rotate right 2>/dev/null || \
  xrandr --output DSI-1 --rotate right
