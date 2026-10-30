#!/bin/bash
# 把本仓库 sdk/ 里的板级补丁与文件应用到 Rockchip Linux SDK（rk3568_linux）
#
#   ./scripts/apply-to-sdk.sh ~/rk3568/rk3568_linux            # 实际应用
#   ./scripts/apply-to-sdk.sh ~/rk3568/rk3568_linux --dry-run  # 只看会做什么
#
# sdk/files/ 是按 SDK 根路径镜像的，直接覆盖；sdk/patches/ 是相对 SDK 底座的 git diff。
set -u

SDK="${1:-}"
DRY=""
for a in "$@"; do [ "$a" = "--dry-run" ] && DRY=1; done
if [ -z "$SDK" ] || [ ! -d "$SDK" ]; then
	echo "用法: $0 /path/to/rk3568_linux [--dry-run]"
	exit 1
fi
SDK="$(cd "$SDK" && pwd)"
HERE="$(cd "$(dirname "$0")/.." && pwd)"

echo "== SDK : $SDK"
echo "== 来源: $HERE/sdk"

[ -f "$SDK/device/rockchip/common/build.sh" ] || {
	echo "ERROR: 这不像 Rockchip Linux SDK（缺 device/rockchip/common/build.sh）"; exit 1; }

# 1) 补丁：board / 驱动 / build.sh 的改动
PATCHES=$(ls "$HERE"/sdk/patches/*.patch 2>/dev/null)
if [ -n "$PATCHES" ]; then
	for p in $PATCHES; do
		echo "-- patch $(basename "$p")"
		if ( cd "$SDK" && git apply --check "$p" ) 2>/dev/null; then
			[ -n "$DRY" ] && echo "   [dry-run] 将应用" || {
				( cd "$SDK" && git apply "$p" ) && echo "   applied"; }
		elif ( cd "$SDK" && git apply --check -R "$p" ) 2>/dev/null; then
			echo "   已应用过，跳过"
		elif ( cd "$SDK" && patch -p1 --dry-run -s -f < "$p" ) 2>/dev/null; then
			[ -n "$DRY" ] && echo "   [dry-run] 将用 patch(1) 应用" || {
				( cd "$SDK" && patch -p1 -s < "$p" ) && echo "   applied (patch)"; }
		else
			echo "   ERROR: 补丁打不上（SDK 底座版本不一致？）"; exit 1
		fi
	done
fi

# 2) 新增文件：板级配置 / DTS / 开机 logo / ubuntu rootfs 脚本 / package-file
echo "-- files"
if [ -n "$DRY" ]; then
	( cd "$HERE/sdk/files" && find . -type f -printf '%P\n' ) | sed 's/^/   [dry-run] /'
else
	cp -a "$HERE"/sdk/files/. "$SDK"/
	echo "   copied $(cd "$HERE/sdk/files" && find . -type f | wc -l) files"
fi

echo
echo "== 完成。接着："
echo "   cd $SDK"
echo "   ./build.sh lunch          # 选 BoardConfig-rk3568-m3568ha.mk"
echo "   ./build.sh info           # 确认 RK_KERNEL_DTS=rk3568-m3568ha-linux"
echo "   export RK_ROOTFS_SYSTEM=ubuntu USER_NAME=eica USER_PASSWORD=eica DESKTOP=y"
echo "   ./build.sh ubuntu && ./build.sh firmware && ./build.sh updateimg"
