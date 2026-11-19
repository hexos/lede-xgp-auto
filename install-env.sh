#!/bin/sh
# 安装 LEDE 编译依赖。
# 关键点：新版 GitHub runner 的默认 apt 源里含 azure.archive.ubuntu.com /
# packages.microsoft.com，这些源在该网络环境下会连接超时并让 apt-get update 无限挂起。
# 因此先把 apt 源重置为稳定的 archive.ubuntu.com，再安装。

id

# ---- 1) 重置 apt 源为 archive.ubuntu.com（去掉 azure/microsoft 等会挂起的源） ----
APTSRC=/etc/apt/sources.list.d/ubuntu.sources
if [ -f "$APTSRC" ]; then
    mv "$APTSRC" "${APTSRC}.bak"
fi
# 移除任何 Microsoft / azure 源
rm -f /etc/apt/sources.list.d/microsoft.list /etc/apt/sources.list.d/microsoft-prod.list \
      /etc/apt/sources.list.d/microsoft-prod.sources /etc/apt/sources.list.d/azure*.list \
      /etc/apt/sources.list.d/azure*.sources 2>/dev/null || true

# 写入干净的经典格式源（覆盖系统默认 sources.list）
cat > /etc/apt/sources.list <<'EOF'
deb http://archive.ubuntu.com/ubuntu noble main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu noble-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu noble-backports main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu noble-security main restricted universe multiverse
EOF

# ---- 2) apt 参数：超时 + 重试 + 非交互，避免挂起 ----
APT_OPTS="-o Acquire::http::Timeout=30 -o Acquire::https::Timeout=30 -o Acquire::Retries=3 -o Acquire::http::Pipeline-Depth=0"

# shellcheck disable=SC2086
DEBIAN_FRONTEND=noninteractive apt-get $APT_OPTS update -y || \
  { echo "apt update failed"; exit 1; }

# --no-install-recommends：避免 texinfo/asciidoc 拉入 texlive（数 GB），防止根分区爆满
# shellcheck disable=SC2086
DEBIAN_FRONTEND=noninteractive apt-get $APT_OPTS install -y --no-install-recommends \
ack antlr3 asciidoc autoconf automake autopoint binutils bison build-essential \
bzip2 ccache clang cmake cpio curl device-tree-compiler flex gawk gcc-multilib g++-multilib gettext \
genisoimage git gperf haveged help2man intltool libc6-dev-i386 libelf-dev libfuse-dev libglib2.0-dev \
libgmp3-dev libltdl-dev libmpc-dev libmpfr-dev libncurses5-dev libncursesw5-dev libpython3-dev \
libreadline-dev libssl-dev libtool llvm lrzsz msmtp ninja-build p7zip p7zip-full patch pkgconf \
python3 python3-pyelftools python3-setuptools qemu-utils rsync scons squashfs-tools subversion \
swig texinfo uglifyjs upx-ucl unzip vim wget xmlto xxd zlib1g-dev
