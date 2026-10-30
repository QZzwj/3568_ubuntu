#!/bin/bash
# 把 overlay/ 铺到当前系统（M-3568HA 桌面套件）
#   sudo ./scripts/apply-overlay.sh            # 实际执行
#   sudo ./scripts/apply-overlay.sh --dry-run  # 只显示会改哪些文件
set -u

USER_NAME="${SUDO_USER:-eica}"
[ "$USER_NAME" = "root" ] && USER_NAME="${TARGET_USER:-eica}"
HOME_DIR="/home/$USER_NAME"

HERE="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$HERE/overlay"
DRY=""
[ "${1:-}" = "--dry-run" ] && DRY="--dry-run"

[ -d "$SRC" ] || { echo "找不到 $SRC"; exit 1; }
[ "$(id -u)" = "0" ] || { echo "请用 sudo 运行"; exit 1; }

echo "== 用户: $USER_NAME  家目录: $HOME_DIR  源: $SRC"

# 1) 铺文件（保留权限位）
rsync -a $DRY --chown=0:0 "$SRC"/ /

# 2) eica 家目录下的文件归还给用户
if [ -z "$DRY" ]; then
    chown -R "$USER_NAME":"$USER_NAME" \
        "$HOME_DIR/.config/gtk-3.0" \
        "$HOME_DIR/.config/xfce4" \
        "$HOME_DIR/.config/picom.conf" \
        "$HOME_DIR/.config/autostart" 2>/dev/null
else
    echo "  [dry] chown -R $USER_NAME:$USER_NAME $HOME_DIR/.config/{gtk-3.0,xfce4,autostart},picom.conf"
fi

# 3) sudoers 权限必须 0440
[ -z "$DRY" ] && chmod 0440 /etc/sudoers.d/50-m3568ha-ctl && visudo -c >/dev/null 2>&1 \
    && echo "  sudoers OK"

# 4) 刷新图标/桌面数据库缓存
if [ -z "$DRY" ]; then
    gtk-update-icon-cache -f -t /usr/share/icons/hicolor >/dev/null 2>&1
    update-desktop-database /usr/share/applications >/dev/null 2>&1
    glib-compile-schemas /usr/share/glib-2.0/schemas >/dev/null 2>&1
    echo "  缓存已刷新"
fi

# 5) 重启面板与合成器（仅在图形会话存在时）
if [ -z "$DRY" ] && pgrep -x xfce4-panel >/dev/null; then
    DISP=":0"
    XAUTH="$HOME_DIR/.Xauthority"
    su "$USER_NAME" -c "DISPLAY=$DISP XAUTHORITY=$XAUTH xfce4-panel -r" >/dev/null 2>&1
    su "$USER_NAME" -c "DISPLAY=$DISP XAUTHORITY=$XAUTH pkill -x picom" >/dev/null 2>&1
    su "$USER_NAME" -c "DISPLAY=$DISP XAUTHORITY=$XAUTH setsid nohup /usr/local/bin/picom-start.sh >/dev/null 2>&1 &" >/dev/null 2>&1
    echo "  面板/picom 已重启"
fi

# 6) 触屏矩阵需要重新登录或重启 X 才生效
echo
echo "完成。触屏矩阵与面板 XML 建议执行："
echo "  sudo systemctl restart lightdm     # 会中断当前图形会话"
