#!/bin/bash
# ===========================================================================
# prepare.sh  (hexos/lede-xgp-auto — 适配 coolsnowwolf/lede master 主分支)
#
# 职责：
#   1. 从上游 zzzz0317/lede-xgp-auto-build 同步 files/ overlay 与 xgp.config
#      （这两个是原项目的定制文件与自动生成配置，含二进制图片和超大 defconfig；
#        同步而非复制，保证完整且始终跟随上游更新）
#   2. clone / 更新 coolsnowwolf/lede 主分支（master）
#   3. 生成 feeds.conf 并加入 qmodem feed
#   4. clone 西瓜皮 V3 相关插件包
#   5. [新增] clone at-webserver(UBUS版) 源码，供后续源码编译出 ipk
# ===========================================================================
set -e

UPSTREAM_REPO="https://github.com/zzzz0317/lede-xgp-auto-build.git"
LEDE_REPO="https://github.com/coolsnowwolf/lede.git"
LEDE_BRANCH="master"   # 跟随主分支

id
df -h
free -h
cat /proc/cpuinfo

# ---------------------------------------------------------------------------
# [1] 同步上游定制文件 files/ 与 xgp.config
# ---------------------------------------------------------------------------
echo "== sync upstream files/ and xgp.config =="
rm -rf .upstream
git clone --depth 1 "$UPSTREAM_REPO" .upstream
rm -rf files
cp -r .upstream/files ./files
cp -f .upstream/xgp.config ./xgp.config
rm -rf .upstream

# 适配 master：xgp.config 来自旧主线（锁 6.12），去掉内核版本锁定相关行，
# 让 make defconfig 按 master 当前默认内核（6.18）重新生成，避免新旧 config 冲突。
sed -i -E \
  -e '/^CONFIG_LINUX_[0-9]+_[0-9]+=y$/d' \
  -e '/^CONFIG_TESTING_KERNEL=/d' \
  -e '/^CONFIG_HAS_TESTING_KERNEL=/d' \
  xgp.config

# ---------------------------------------------------------------------------
# [2] clone / 更新 LEDE 主分支
# ---------------------------------------------------------------------------
if [ -d "lede/.git" ]; then
    echo "lede exists, update master"
    cd lede
    git reset --hard
    git checkout "$LEDE_BRANCH"
    git pull --ff-only || { echo "git pull failed"; exit 1; }
    cd ..
else
    echo "clone LEDE $LEDE_BRANCH"
    git clone --depth 1 -b "$LEDE_BRANCH" "$LEDE_REPO" lede || { echo "git clone failed"; exit 1; }
fi

cd lede

# ---------------------------------------------------------------------------
# [3] feeds
# ---------------------------------------------------------------------------
cat feeds.conf.default > feeds.conf
echo "" >> feeds.conf
echo "src-git qmodem https://github.com/FUjr/QModem.git;main" >> feeds.conf

# ---------------------------------------------------------------------------
# [4] 西瓜皮 V3 相关插件包
# ---------------------------------------------------------------------------
clone_or_pull() {
    local url="$1" dir="$2"
    if [ -d "$dir/.git" ]; then
        (cd "$dir" && git reset --hard && git pull) || { echo "pull failed: $dir"; exit 1; }
    else
        rm -rf "$dir"
        git clone "$url" "$dir" || { echo "clone failed: $dir"; exit 1; }
    fi
}
mkdir -p package/zz
clone_or_pull https://github.com/jerrykuku/luci-app-argon-config.git    package/zz/luci-app-argon-config
clone_or_pull https://github.com/derisamedia/luci-theme-alpha.git       package/zz/luci-theme-alpha
clone_or_pull https://github.com/zzzz0317/kmod-fb-tft-gc9307.git        package/zz/kmod-fb-tft-gc9307
clone_or_pull https://github.com/zzzz0317/xgp-v3-screen.git             package/zz/xgp-v3-screen

# ---------------------------------------------------------------------------
# [5] [新增] at-webserver (UBUS 版) 源码
#     0x4ba fork：含「LuCI 缺少 UBUS 选项」「串口配置不生效」修复，与 ubus 版一致。
#     OpenWrt 递归扫描 package/ 下 Makefile，子包位于仓库子目录即可被识别。
# ---------------------------------------------------------------------------
echo "== prepare at-webserver (ubus) source =="
clone_or_pull https://github.com/0x4ba/mt5700webui-openwrt-server.git package/zz/at-webserver-ubus
for pkg in at-webserver luci-app-at-webserver; do
    [ -f "package/zz/at-webserver-ubus/$pkg/Makefile" ] || { echo "ERROR: $pkg/Makefile not found"; exit 1; }
done

echo "prepare done (LEDE $LEDE_BRANCH + upstream files synced + at-webserver staged)"
