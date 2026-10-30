#!/bin/sh
# M-3568HA: 等桌面会话起来后再接管合成器（picom 必须在 xfwm4 之后抢 _NET_WM_CM_S0）
sleep 3
exec picom --config /home/eica/.config/picom.conf
