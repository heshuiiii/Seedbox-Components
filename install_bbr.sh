#!/bin/bash
tput sgr0; clear

# ============================================================
#  独立 BBR 安装脚本
#  支持: BBRx / BBRy / BBRz
#  用法: ./install_bbr.sh [-x|-y|-z]
#        不带参数时进入交互式菜单
# ============================================================

## ── 颜色 / 输出函数 ─────────────────────────────────────────
info() {
    tput sgr0; tput setaf 2; tput bold
    echo "$1"
    tput sgr0
}
info_2() {
    tput sgr0; tput setaf 2
    echo "    $1"
    tput sgr0
}
warn() {
    tput sgr0; tput setaf 3
    echo "$1" 1>&2
    tput sgr0
}
fail() {
    tput sgr0; tput setaf 1; tput bold
    echo "$1" 1>&2
    tput sgr0
}
fail_exit() {
    tput sgr0; tput setaf 1; tput bold
    echo "$1" 1>&2
    tput sgr0
    exit 1
}
need_input() {
    tput sgr0; tput setaf 6; tput bold
    echo "$1" 1>&2
    tput sgr0
}
seperator() {
    echo -e "\n"
    echo "$(printf '%*s' "$(tput cols)" | tr ' ' '=')"
    echo -e "\n"
}

## ── 环境检查 ─────────────────────────────────────────────────
info "Checking Installation Environment"

# Root 权限检查
if [ "$(id -u)" -ne 0 ]; then
    fail_exit "This script needs root permission to run"
fi

# 发行版检查
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
elif type lsb_release >/dev/null 2>&1; then
    OS=$(lsb_release -si)
    VER=$(lsb_release -sr)
elif [ -f /etc/lsb-release ]; then
    . /etc/lsb-release
    OS=$DISTRIB_ID
    VER=$DISTRIB_RELEASE
elif [ -f /etc/debian_version ]; then
    OS=Debian
    VER=$(cat /etc/debian_version)
else
    OS=$(uname -s)
    VER=$(uname -r)
fi

if [[ ! "$OS" =~ "Debian" ]] && [[ ! "$OS" =~ "Ubuntu" ]]; then
    fail "$OS $VER is not supported"
    fail_exit "Only Debian 10+ and Ubuntu 20.04+ are supported"
fi

if [[ "$OS" =~ "Debian" ]]; then
    if [[ ! "$VER" =~ "10" ]] && [[ ! "$VER" =~ "11" ]] && [[ ! "$VER" =~ "12" ]]; then
        fail "$OS $VER is not supported"
        fail_exit "Only Debian 10/11/12 are supported"
    fi
fi

if [[ "$OS" =~ "Ubuntu" ]]; then
    if [[ ! "$VER" =~ "20" ]] && [[ ! "$VER" =~ "22" ]] && [[ ! "$VER" =~ "23" ]] && [[ ! "$VER" =~ "24" ]]; then
        fail "$OS $VER is not supported"
        fail_exit "Only Ubuntu 20.04+ is supported"
    fi
fi

## ── 内核安装辅助函数 ─────────────────────────────────────────
install_kernel_headers_() {
    local variant="$1"
    if [[ "$OS" =~ "Debian" ]]; then
        if [ "$(uname -m)" == "x86_64" ]; then
            apt-get -y install linux-image-amd64 linux-headers-amd64
        elif [ "$(uname -m)" == "aarch64" ]; then
            apt-get -y install linux-image-arm64 linux-headers-arm64
        else
            fail "Unsupported architecture: $(uname -m)"
            return 1
        fi
    elif [[ "$OS" =~ "Ubuntu" ]]; then
        apt-get -y install linux-image-generic linux-headers-generic
    else
        fail "Unsupported OS"
        return 1
    fi

    if [ $? -ne 0 ]; then
        fail "${variant} kernel/headers installation failed"
        return 1
    fi
    return 0
}

register_bbr_service_() {
    local script_path="$1"   # e.g. /root/BBRx.sh
    cat << EOF > /etc/systemd/system/bbrinstall.service
[Unit]
Description=BBRinstall
After=network.target

[Service]
Type=oneshot
ExecStart=${script_path}
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF
    systemctl enable bbrinstall.service
}

## ── BBRx 安装 ────────────────────────────────────────────────
install_bbrx_() {
    if [[ -n "$(lsmod | grep bbrx)" ]]; then
        warn "BBRx is already loaded"
        return 0
    fi

    install_kernel_headers_ "BBRx" || return 1

    wget -q https://raw.githubusercontent.com/heshuiiii/Seedbox-Components/main/BBR/BBRx/BBRx.sh \
        -O /root/BBRx.sh && chmod +x /root/BBRx.sh
    if [ ! -f /root/BBRx.sh ]; then
        fail "BBRx script download failed"
        return 1
    fi

    register_bbr_service_ "/root/BBRx.sh"
    return 0
}

## ── BBRy 安装 ────────────────────────────────────────────────
install_bbry_() {
    if [[ -n "$(lsmod | grep bbry)" ]]; then
        warn "BBRy is already loaded"
        return 0
    fi

    install_kernel_headers_ "BBRy" || return 1

    wget -q https://raw.githubusercontent.com/heshuiiii/Seedbox-Components/main/BBR/BBRx/BBRy.sh \
        -O /root/BBRy.sh && chmod +x /root/BBRy.sh
    if [ ! -f /root/BBRy.sh ]; then
        fail "BBRy script download failed"
        return 1
    fi

    register_bbr_service_ "/root/BBRy.sh"
    return 0
}

## ── BBRz 安装 ────────────────────────────────────────────────
install_bbrz_() {
    if [[ -n "$(lsmod | grep bbrz)" ]]; then
        warn "BBRz is already loaded"
        return 0
    fi

    install_kernel_headers_ "BBRz" || return 1

    wget -q https://raw.githubusercontent.com/heshuiiii/Seedbox-Components/main/BBR/BBRx/BBRz.sh \
        -O /root/BBRz.sh && chmod +x /root/BBRz.sh
    if [ ! -f /root/BBRz.sh ]; then
        fail "BBRz script download failed"
        return 1
    fi

    register_bbr_service_ "/root/BBRz.sh"
    return 0
}

## ── 通用安装包装 ─────────────────────────────────────────────
do_install_() {
    local variant="$1"   # x / y / z
    local func="install_bbr${variant}_"
    local label="BBR${variant^^}"

    info_2 "Installing ${label} ..."
    ${func}
    if [ $? -eq 0 ]; then
        tput sgr0; tput setaf 2
        echo "    ${label} installed successfully."
        echo "    Please REBOOT the server for it to take effect."
        tput sgr0
    else
        fail "    ${label} installation FAILED. Check output above for details."
        exit 1
    fi
}

## ── 参数解析 ─────────────────────────────────────────────────
bbr_choice=""

while getopts "xyzhH" opt; do
    case ${opt} in
        x) bbr_choice="x" ;;
        y) bbr_choice="y" ;;
        z) bbr_choice="z" ;;
        h|H)
            info "BBR Standalone Installer"
            info_2 "Usage: $0 [-x|-y|-z]"
            echo ""
            info_2 "  -x   Install BBRx"
            info_2 "  -y   Install BBRy"
            info_2 "  -z   Install BBRz"
            info_2 "  (no flag)  Interactive menu"
            exit 0
            ;;
        \?)
            fail "Unknown option. Use -h for help."
            exit 1
            ;;
    esac
done

## ── 交互式菜单（无参数时） ────────────────────────────────────
if [ -z "$bbr_choice" ]; then
    seperator
    info "BBR Variant Installer"
    info_2 "OS: $OS $VER  |  Arch: $(uname -m)"
    echo ""
    info_2 "Select BBR variant to install:"
    echo ""
    tput sgr0; tput setaf 6; tput bold
    echo "    1) BBRx"
    echo "    2) BBRy"
    echo "    3) BBRz"
    echo "    q) Quit"
    tput sgr0
    echo ""
    need_input "Enter your choice [1/2/3/q]:"
    read -r choice

    case "$choice" in
        1) bbr_choice="x" ;;
        2) bbr_choice="y" ;;
        3) bbr_choice="z" ;;
        q|Q)
            info "Aborted."
            exit 0
            ;;
        *)
            fail_exit "Invalid choice. Exiting."
            ;;
    esac
fi

## ── 安装 ─────────────────────────────────────────────────────
seperator
info "System: $OS $VER | Arch: $(uname -m)"
info "Starting BBR${bbr_choice^^} installation..."
echo ""

# 安装 wget（如果缺失）
if ! command -v wget >/dev/null 2>&1; then
    apt-get -qqy install wget
fi

do_install_ "$bbr_choice"

seperator
info "Done!"
info_2 "Reboot the server to activate BBR${bbr_choice^^}."
echo ""
exit 0
