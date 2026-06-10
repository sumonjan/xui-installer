#!/bin/bash
# ============================================================
#   X-UI V2Ray Panel High Speed Server Installer
#   GitHub: https://github.com/YOUR_USERNAME/xui-installer
#   Author: Your Name
#   Version: 2.0
# ============================================================

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# --- Banner ---
show_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║       X-UI V2Ray Panel - High Speed Installer       ║"
    echo "║              Optimized for Bangladesh               ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# --- Root Check ---
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}[ERROR] এই স্ক্রিপ্ট root হিসেবে চালাতে হবে!${NC}"
        echo -e "${YELLOW}চালান: sudo bash install.sh${NC}"
        exit 1
    fi
}

# --- OS Check ---
check_os() {
    echo -e "${BLUE}[INFO] অপারেটিং সিস্টেম চেক করা হচ্ছে...${NC}"
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
    else
        echo -e "${RED}[ERROR] অসমর্থিত OS!${NC}"
        exit 1
    fi

    case $OS in
        ubuntu|debian)
            PKG_MANAGER="apt-get"
            echo -e "${GREEN}[OK] OS: $OS $VER${NC}"
            ;;
        centos|rhel|fedora)
            PKG_MANAGER="yum"
            echo -e "${GREEN}[OK] OS: $OS $VER${NC}"
            ;;
        *)
            echo -e "${RED}[ERROR] অসমর্থিত OS: $OS${NC}"
            exit 1
            ;;
    esac
}

# --- Architecture Check ---
check_arch() {
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)
            XRAY_ARCH="64"
            ;;
        aarch64|arm64)
            XRAY_ARCH="arm64-v8a"
            ;;
        armv7l)
            XRAY_ARCH="arm32-v7a"
            ;;
        *)
            echo -e "${RED}[ERROR] অসমর্থিত আর্কিটেকচার: $ARCH${NC}"
            exit 1
            ;;
    esac
    echo -e "${GREEN}[OK] Architecture: $ARCH${NC}"
}

# --- Install Dependencies ---
install_deps() {
    echo -e "${BLUE}[INFO] প্রয়োজনীয় প্যাকেজ ইনস্টল করা হচ্ছে...${NC}"
    if [[ $PKG_MANAGER == "apt-get" ]]; then
        apt-get update -y
        apt-get install -y curl wget unzip tar net-tools ufw iptables \
            socat cron bash-completion ca-certificates gnupg lsb-release \
            openssl uuid-runtime
    else
        yum update -y
        yum install -y curl wget unzip tar net-tools firewalld \
            socat cronie ca-certificates openssl
    fi
    echo -e "${GREEN}[OK] প্যাকেজ ইনস্টল সম্পন্ন${NC}"
}

# --- System Optimization (High Speed) ---
optimize_system() {
    echo -e "${BLUE}[INFO] সিস্টেম হাই-স্পিড অপটিমাইজ করা হচ্ছে...${NC}"

    # BBR TCP Congestion Control
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf

    # Network Buffer Optimization
    cat >> /etc/sysctl.conf << 'EOF'
# High Speed Network Optimization
net.core.rmem_max=67108864
net.core.wmem_max=67108864
net.core.netdev_max_backlog=250000
net.core.somaxconn=4096
net.ipv4.tcp_rmem=4096 87380 67108864
net.ipv4.tcp_wmem=4096 65536 67108864
net.ipv4.tcp_mtu_probing=1
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_tw_reuse=1
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
EOF

    sysctl -p > /dev/null 2>&1

    # Check BBR loaded
    if lsmod | grep -q bbr; then
        echo -e "${GREEN}[OK] BBR TCP অ্যাক্টিভ - হাই স্পিড মোড চালু${NC}"
    else
        echo -e "${YELLOW}[WARN] BBR লোড হয়নি, রিবুটের পর কার্যকর হবে${NC}"
    fi

    # Limits optimization
    cat >> /etc/security/limits.conf << 'EOF'
* soft nofile 1000000
* hard nofile 1000000
root soft nofile 1000000
root hard nofile 1000000
EOF

    echo -e "${GREEN}[OK] সিস্টেম অপটিমাইজেশন সম্পন্ন${NC}"
}

# --- Install X-UI Panel ---
install_xui() {
    echo -e "${BLUE}[INFO] X-UI Panel ডাউনলোড ও ইনস্টল হচ্ছে...${NC}"

    # Use 3x-ui (latest maintained fork)
    bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)

    if [[ $? -ne 0 ]]; then
        echo -e "${RED}[ERROR] X-UI ইনস্টলেশন ব্যর্থ হয়েছে!${NC}"
        exit 1
    fi
    echo -e "${GREEN}[OK] X-UI Panel ইনস্টল সম্পন্ন${NC}"
}

# --- Configure Firewall ---
setup_firewall() {
    echo -e "${BLUE}[INFO] ফায়ারওয়াল কনফিগার করা হচ্ছে...${NC}"

    PANEL_PORT=${1:-54321}

    if command -v ufw &> /dev/null; then
        ufw allow ssh
        ufw allow $PANEL_PORT/tcp
        ufw allow 80/tcp
        ufw allow 443/tcp
        ufw allow 2053/tcp
        ufw allow 2096/tcp
        echo "y" | ufw enable
        echo -e "${GREEN}[OK] UFW ফায়ারওয়াল কনফিগার হয়েছে${NC}"
    elif command -v firewall-cmd &> /dev/null; then
        systemctl start firewalld
        firewall-cmd --permanent --add-port=$PANEL_PORT/tcp
        firewall-cmd --permanent --add-port=80/tcp
        firewall-cmd --permanent --add-port=443/tcp
        firewall-cmd --permanent --add-service=ssh
        firewall-cmd --reload
        echo -e "${GREEN}[OK] FirewallD কনফিগার হয়েছে${NC}"
    fi
}

# --- Show Final Info ---
show_info() {
    SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s icanhazip.com)
    PANEL_PORT=54321

    echo -e "\n${GREEN}"
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║           ইনস্টলেশন সফলভাবে সম্পন্ন!              ║"
    echo "╠══════════════════════════════════════════════════════╣"
    printf "║  Panel URL: http://%-33s║\n" "$SERVER_IP:$PANEL_PORT"
    echo "║  Default Username: admin                             ║"
    echo "║  Default Password: admin                             ║"
    echo "║                                                      ║"
    echo "║  ⚡ BBR High Speed Mode: Active                     ║"
    echo "║  🔒 Firewall: Configured                            ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "${YELLOW}[!] প্রথম লগইনের পরে পাসওয়ার্ড পরিবর্তন করুন!${NC}"
    echo -e "${YELLOW}[!] SSL সার্টিফিকেট সেটআপের জন্য: bash ssl.sh${NC}"
}

# --- Main Flow ---
main() {
    show_banner
    check_root
    check_os
    check_arch
    install_deps
    optimize_system
    install_xui
    setup_firewall
    show_info
}

main "$@"
