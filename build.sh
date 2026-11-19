#!/bin/bash
# ===========================================================================
# build.sh  (hexos/lede-xgp-auto — 适配 coolsnowwolf/lede master 主分支)
#
# 基于 zzzz0317/lede-xgp-auto-build 原版 build.sh 改造：
#   [新增 1] 集成 999-add-TD-TECH-option-id.patch 到内核（动态适配实际内核版本）
#   [新增 2] 打开 at-webserver / luci-app-at-webserver 包
#   [适配]  不锁定内核版本，跟随 master 默认（defconfig 自行决定 6.18/后续）
#   [修复]  cache@v3 弃用问题在 workflow 中修复
# ===========================================================================
set -e
cd lede

echo "== update feeds =="
./scripts/feeds update -a || { echo "update feeds failed"; exit 1; }
echo "== install feeds =="
./scripts/feeds install -a || { echo "install feeds failed"; exit 1; }
./scripts/feeds install -a -f -p qmodem || { echo "install qmodem feeds failed"; exit 1; }

echo "== load config =="
cat ../xgp.config > .config

# [新增 2] 打开插件包（config 里的内核版本行已在 prepare.sh 去除，此处按 master 默认值）
cat >> .config <<'EOF'

# --- injected by hexos/lede-xgp-auto ---
CONFIG_PACKAGE_at-webserver=y
CONFIG_PACKAGE_luci-app-at-webserver=y
EOF

echo "== make defconfig =="
make defconfig || { echo "defconfig failed"; exit 1; }

# 校验关键配置生效
grep -Fxq "CONFIG_TARGET_rockchip_armv8_DEVICE_nlnet_xiguapi-v3=y" .config || { echo "ERROR: device config missing"; exit 1; }
for pkg in at-webserver luci-app-at-webserver; do
    grep -q "CONFIG_PACKAGE_${pkg}=y" .config \
        || { echo "ERROR: ${pkg} not enabled after defconfig (source missing or dep fail)"; exit 1; }
    echo "  OK: CONFIG_PACKAGE_${pkg}=y"
done
KVER=$(grep -oE 'CONFIG_LINUX_[0-9]+_[0-9]+=y' .config | head -n1 | sed -E 's/CONFIG_LINUX_//;s/=y//;s/_/./g')
echo "  active kernel: ${KVER:-unknown} (master default)"

echo "== config diff vs upstream =="
diff ../xgp.config .config || true

# qmodem 默认配置
echo "== apply qmodem default setting =="
cat feeds/qmodem/application/qmodem/files/etc/config/qmodem > files/etc/config/qmodem
cat >> files/etc/config/qmodem << 'EOF'

config modem-slot 'wwan'
	option type 'usb'
	option slot '8-1'
	option net_led 'blue:net'
	option alias 'wwan'

config modem-slot 'mpcie1'
	option type 'pcie'
	option slot '0001:11:00.0'
	option net_led 'blue:net'
	option alias 'mpcie1'

config modem-slot 'mpcie2'
	option type 'pcie'
	option slot '0002:21:00.0'
	option net_led 'blue:net'
	option alias 'mpcie2'
EOF

# 版本信息
year=$(date +%y); month=$(date +%-m); day=$(date +%-d); hour=$(date +%-H)
zz_build_date=$(date "+%Y-%m-%d %H:%M:%S %z")
zz_build_uuid=$(uuidgen)
cat >> files/etc/uci-defaults/zzzz-version << EOF
echo "DISTRIB_REVISION='R${year}.${month}.${day}.${hour}'" >> /etc/openwrt_release
/bin/sync
EOF
echo "ZZ_BUILD_ID='${zz_build_uuid}'" > files/etc/zz_build_id
echo "ZZ_BUILD_HOST='$(hostname)'" >> files/etc/zz_build_id
echo "ZZ_BUILD_USER='$(whoami)'" >> files/etc/zz_build_id
echo "ZZ_BUILD_DATE='${zz_build_date}'" >> files/etc/zz_build_id
echo "ZZ_BUILD_REPO_HASH='$(cd .. && git rev-parse HEAD 2>/dev/null || echo unknown)'" >> files/etc/zz_build_id
echo "ZZ_BUILD_LEDE_HASH='$(git rev-parse HEAD)'" >> files/etc/zz_build_id

echo "== make download =="
make download -j8 || { echo "download failed"; exit 1; }

# ---------------------------------------------------------------------------
# [新增 1] 安装 TD-TECH 内核补丁（标准 patches 目录机制，动态适配内核版本）
# ---------------------------------------------------------------------------
echo "== install TD-TECH option.c patch =="
PATCH_SRC="../999-add-TD-TECH-option-id.patch"
[ -f "$PATCH_SRC" ] || { echo "ERROR: $PATCH_SRC not found"; exit 1; }

KDIR=""
if   grep -q "CONFIG_LINUX_6_12=y" .config; then KDIR="target/linux/rockchip/patches-6.12"
elif grep -q "CONFIG_LINUX_6_18=y" .config; then KDIR="target/linux/rockchip/patches-6.18"
elif [ -n "$KVER" ]; then KDIR="target/linux/rockchip/patches-${KVER}"
fi
[ -n "$KDIR" ] || { echo "ERROR: cannot detect kernel patch dir"; exit 1; }
mkdir -p "$KDIR"
cp -f "$PATCH_SRC" "$KDIR/999-add-TD-TECH-option-id.patch"
echo "  patch placed in $KDIR"

echo "== prepare kernel (apply patches) =="
make target/linux/prepare -j$(nproc) || { echo "ERROR: kernel prepare failed (TD-TECH patch may not apply)"; exit 1; }

KSRC=$(find build_dir -maxdepth 3 -type d -name 'linux-6.*' -path '*rockchip*' 2>/dev/null | head -n1)
if [ -n "$KSRC" ] && grep -q "TDTECH_VENDOR_ID" "$KSRC/drivers/usb/serial/option.c" 2>/dev/null; then
    echo "  OK: TDTECH_VENDOR_ID present in option.c"
else
    echo "  ERROR: TD-TECH patch not reflected in option.c"; exit 1
fi

echo "== make =="
make V=0 -j$(nproc) || { echo "make failed"; exit 1; }
