#!/bin/bash
# ================================================================
#   X-UI PRO - All-in-One V2Ray Panel Installer
#   Version  : 4.0
#   OS       : Ubuntu 20.04 / 22.04 / 24.04
#   Features : BBR + X-UI + Auto Inbound + Auto Config
# ================================================================

# ── Colors ──────────────────────────────────────────────────────
R='\033[0;31m'
G='\033[0;32m'
Y='\033[1;33m'
B='\033[0;34m'
C='\033[0;36m'
W='\033[1;37m'
N='\033[0m'

# ── Config ───────────────────────────────────────────────────────
XUI_PORT=2053
XUI_USER="admin"
XUI_PASS="admin@1234"
XUI_PATH="/xui_secure_$(cat /proc/sys/kernel/random/uuid | tr -d '-' | head -c 8)"
LOG="/var/log/xui-install.log"
COOKIE="/tmp/xui_session.txt"

# ── Banner ───────────────────────────────────────────────────────
banner() {
    clear
    echo -e "${C}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║           X-UI PRO — High Speed VPN Panel                 ║"
    echo "║      VLESS • VMess • Trojan • Shadowsocks • Socks         ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${N}"
}

log() { echo "[$(date '+%H:%M:%S')] $1" >> "$LOG"; }

ok()   { echo -e "${G}  [✔] $1${N}"; log "OK: $1"; }
info() { echo -e "${B}  [•] $1${N}"; log "INFO: $1"; }
warn() { echo -e "${Y}  [!] $1${N}"; log "WARN: $1"; }
err()  { echo -e "${R}  [✘] $1${N}"; log "ERR: $1"; }
step() { echo -e "\n${W}═══ $1 ═══${N}"; }

# ── Root Check ───────────────────────────────────────────────────
check_root() {
    [[ $EUID -ne 0 ]] && err "Root হিসেবে চালান: sudo bash install.sh" && exit 1
    ok "Root access confirmed"
}

# ── OS Check ─────────────────────────────────────────────────────
check_os() {
    . /etc/os-release
    OS=$ID; VER=$VERSION_ID
    case $OS in
        ubuntu|debian) PKG="apt-get" ;;
        centos|rhel)   PKG="yum" ;;
        *) err "অসমর্থিত OS: $OS"; exit 1 ;;
    esac
    ok "OS: $OS $VER"
}

# ── Install Dependencies ─────────────────────────────────────────
install_deps() {
    step "প্রয়োজনীয় প্যাকেজ ইনস্টল"
    info "System আপডেট হচ্ছে..."
    $PKG update -y >> "$LOG" 2>&1
    $PKG install -y \
        curl wget unzip tar socat cron ufw \
        net-tools ca-certificates openssl \
        uuid-runtime jq python3 >> "$LOG" 2>&1
    ok "সব প্যাকেজ ইনস্টল সম্পন্ন"
}

# ── BBR + System Optimization ────────────────────────────────────
optimize() {
    step "High Speed অপটিমাইজেশন"

    # BBR Enable
    modprobe tcp_bbr 2>/dev/null
    echo "tcp_bbr" > /etc/modules-load.d/bbr.conf

    cat > /etc/sysctl.d/99-xui-speed.conf << 'EOF'
# BBR
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# Buffer
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.core.netdev_max_backlog = 250000
net.core.somaxconn = 65535
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864

# Performance
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_tw_reuse = 1
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1

# Connection
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_max_tw_buckets = 2000000
net.ipv4.tcp_fin_timeout = 10
EOF

    sysctl -p /etc/sysctl.d/99-xui-speed.conf >> "$LOG" 2>&1

    # File limits
    cat > /etc/security/limits.d/99-xui.conf << 'EOF'
* soft nofile 1000000
* hard nofile 1000000
root soft nofile 1000000
root hard nofile 1000000
EOF

    # Check BBR
    BBR=$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk '{print $3}')
    [[ "$BBR" == "bbr" ]] && ok "BBR TCP চালু — High Speed Mode Active" || warn "BBR রিবুটের পর চালু হবে"
    ok "System অপটিমাইজেশন সম্পন্ন"
}

# ── Install 3x-ui ─────────────────────────────────────────────────
install_xui() {
    step "3x-UI Panel ইনস্টল"
    info "3x-ui ডাউনলোড হচ্ছে..."

    # Install 3x-ui silently
    bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh) << 'ENDINPUT'

ENDINPUT

    # Wait for service
    sleep 3
    systemctl enable x-ui >> "$LOG" 2>&1
    systemctl start x-ui >> "$LOG" 2>&1
    sleep 2

    if systemctl is-active --quiet x-ui; then
        ok "3x-UI Panel ইনস্টল ও চালু সম্পন্ন"
    else
        err "X-UI চালু হয়নি — লগ চেক করুন: journalctl -u x-ui -n 30"
        exit 1
    fi
}

# ── Configure Panel Settings ─────────────────────────────────────
configure_panel() {
    step "Panel কনফিগারেশন"
    info "Port, User, Password সেট হচ্ছে..."

    # Set via x-ui CLI
    x-ui setting -port "$XUI_PORT"        >> "$LOG" 2>&1
    x-ui setting -username "$XUI_USER"    >> "$LOG" 2>&1
    x-ui setting -password "$XUI_PASS"    >> "$LOG" 2>&1
    x-ui setting -webBasePath "$XUI_PATH" >> "$LOG" 2>&1

    systemctl restart x-ui
    sleep 3

    ok "Panel কনফিগার সম্পন্ন"
    ok "Port: $XUI_PORT | User: $XUI_USER | Pass: $XUI_PASS"
}

# ── Firewall Setup ───────────────────────────────────────────────
setup_firewall() {
    step "Firewall সেটআপ"

    ufw --force reset >> "$LOG" 2>&1
    ufw default deny incoming >> "$LOG" 2>&1
    ufw default allow outgoing >> "$LOG" 2>&1
    ufw allow ssh >> "$LOG" 2>&1
    ufw allow "$XUI_PORT"/tcp >> "$LOG" 2>&1
    ufw allow 80/tcp >> "$LOG" 2>&1
    ufw allow 443/tcp >> "$LOG" 2>&1
    # Inbound ports range
    ufw allow 10000:60000/tcp >> "$LOG" 2>&1
    ufw allow 10000:60000/udp >> "$LOG" 2>&1
    echo "y" | ufw enable >> "$LOG" 2>&1

    ok "Firewall কনফিগার সম্পন্ন"
}

# ── Panel Login ──────────────────────────────────────────────────
panel_login() {
    local BASE="http://127.0.0.1:${XUI_PORT}${XUI_PATH}"
    rm -f "$COOKIE"

    for i in 1 2 3; do
        RESP=$(curl -s -c "$COOKIE" \
            -X POST "${BASE}/login" \
            -H "Content-Type: application/x-www-form-urlencoded" \
            --connect-timeout 10 \
            -d "username=${XUI_USER}&password=${XUI_PASS}" 2>/dev/null)

        if echo "$RESP" | grep -q '"success":true'; then
            PANEL_BASE="$BASE"
            return 0
        fi
        sleep 2
    done

    # Fallback: try without path
    BASE="http://127.0.0.1:${XUI_PORT}"
    RESP=$(curl -s -c "$COOKIE" \
        -X POST "${BASE}/login" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        --connect-timeout 10 \
        -d "username=${XUI_USER}&password=${XUI_PASS}" 2>/dev/null)

    if echo "$RESP" | grep -q '"success":true'; then
        PANEL_BASE="$BASE"
        return 0
    fi

    return 1
}

# ── Add Inbound via API ──────────────────────────────────────────
add_inbound() {
    local REMARK="$1"
    local PAYLOAD="$2"
    local RESP

    RESP=$(curl -s -b "$COOKIE" \
        -X POST "${PANEL_BASE}/xui/inbound/add" \
        -H "Content-Type: application/json" \
        --connect-timeout 10 \
        -d "$PAYLOAD" 2>/dev/null)

    if echo "$RESP" | grep -q '"success":true'; then
        return 0
    else
        log "Inbound add failed: $RESP"
        return 1
    fi
}

# ── Auto Create All Inbounds ─────────────────────────────────────
create_inbounds() {
    step "Multi-Protocol Inbound তৈরি"

    SERVER_IP=$(curl -s --connect-timeout 5 ifconfig.me 2>/dev/null || \
                curl -s --connect-timeout 5 icanhazip.com 2>/dev/null)

    info "Panel Login হচ্ছে..."
    if ! panel_login; then
        warn "Auto inbound তৈরি করা যায়নি — Panel খুলে ম্যানুয়ালি করুন"
        return
    fi
    ok "Login সফল"

    # ── 1. VLESS TCP ───────────────────────────────────────────
    UUID1=$(cat /proc/sys/kernel/random/uuid)
    PORT1=443

    PAYLOAD=$(cat <<EOF
{
  "remark": "VLESS-TCP-443",
  "enable": true,
  "listen": "",
  "port": ${PORT1},
  "protocol": "vless",
  "expiryTime": 0,
  "settings": {
    "clients": [{"id":"${UUID1}","flow":"","email":"vless@server","limitIp":0,"totalGB":0,"expiryTime":0,"enable":true,"tgId":"","subId":""}],
    "decryption": "none",
    "fallbacks": []
  },
  "streamSettings": {
    "network": "tcp",
    "security": "none",
    "tcpSettings": {"acceptProxyProtocol":false,"header":{"type":"none"}}
  },
  "sniffing": {"enabled":true,"destOverride":["http","tls"]}
}
EOF
)
    if add_inbound "VLESS-TCP" "$PAYLOAD"; then
        ok "VLESS TCP (Port 443) তৈরি সফল"
        VLESS_LINK="vless://${UUID1}@${SERVER_IP}:${PORT1}?type=tcp&security=none#VLESS-TCP"
    else
        warn "VLESS TCP তৈরি ব্যর্থ"
    fi

    # ── 2. VMess WebSocket ─────────────────────────────────────
    UUID2=$(cat /proc/sys/kernel/random/uuid)
    PORT2=8080
    WS_PATH="/$(cat /proc/sys/kernel/random/uuid | tr -d '-' | head -c 10)"

    PAYLOAD=$(cat <<EOF
{
  "remark": "VMess-WS-8080",
  "enable": true,
  "listen": "",
  "port": ${PORT2},
  "protocol": "vmess",
  "expiryTime": 0,
  "settings": {
    "clients": [{"id":"${UUID2}","alterId":0,"email":"vmess@server","limitIp":0,"totalGB":0,"expiryTime":0,"enable":true,"tgId":"","subId":""}],
    "disableInsecureEncryption": false
  },
  "streamSettings": {
    "network": "ws",
    "security": "none",
    "wsSettings": {"acceptProxyProtocol":false,"path":"${WS_PATH}","headers":{}}
  },
  "sniffing": {"enabled":true,"destOverride":["http","tls"]}
}
EOF
)
    if add_inbound "VMess-WS" "$PAYLOAD"; then
        ok "VMess WebSocket (Port 8080) তৈরি সফল"
        VMESS_JSON="{\"v\":\"2\",\"ps\":\"VMess-WS\",\"add\":\"${SERVER_IP}\",\"port\":\"${PORT2}\",\"id\":\"${UUID2}\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"\",\"path\":\"${WS_PATH}\",\"tls\":\"\"}"
        VMESS_LINK="vmess://$(echo -n "$VMESS_JSON" | base64 -w 0)"
    else
        warn "VMess WS তৈরি ব্যর্থ"
    fi

    # ── 3. Trojan TCP ──────────────────────────────────────────
    TROJAN_PASS=$(cat /proc/sys/kernel/random/uuid | tr -d '-' | head -c 20)
    PORT3=2083

    PAYLOAD=$(cat <<EOF
{
  "remark": "Trojan-TCP-2083",
  "enable": true,
  "listen": "",
  "port": ${PORT3},
  "protocol": "trojan",
  "expiryTime": 0,
  "settings": {
    "clients": [{"password":"${TROJAN_PASS}","email":"trojan@server","limitIp":0,"totalGB":0,"expiryTime":0,"enable":true,"tgId":"","subId":""}],
    "fallbacks": []
  },
  "streamSettings": {
    "network": "tcp",
    "security": "none",
    "tcpSettings": {"acceptProxyProtocol":false,"header":{"type":"none"}}
  },
  "sniffing": {"enabled":true,"destOverride":["http","tls"]}
}
EOF
)
    if add_inbound "Trojan-TCP" "$PAYLOAD"; then
        ok "Trojan TCP (Port 2083) তৈরি সফল"
        TROJAN_LINK="trojan://${TROJAN_PASS}@${SERVER_IP}:${PORT3}?security=none&type=tcp#Trojan-TCP"
    else
        warn "Trojan TCP তৈরি ব্যর্থ"
    fi

    # ── 4. Shadowsocks ─────────────────────────────────────────
    SS_PASS=$(cat /proc/sys/kernel/random/uuid | tr -d '-' | head -c 16)
    PORT4=8388

    PAYLOAD=$(cat <<EOF
{
  "remark": "Shadowsocks-8388",
  "enable": true,
  "listen": "",
  "port": ${PORT4},
  "protocol": "shadowsocks",
  "expiryTime": 0,
  "settings": {
    "method": "chacha20-ietf-poly1305",
    "password": "${SS_PASS}",
    "network": "tcp,udp",
    "clients": []
  },
  "streamSettings": {
    "network": "tcp",
    "security": "none"
  },
  "sniffing": {"enabled":true,"destOverride":["http","tls"]}
}
EOF
)
    if add_inbound "Shadowsocks" "$PAYLOAD"; then
        ok "Shadowsocks (Port 8388) তৈরি সফল"
        SS_B64=$(echo -n "chacha20-ietf-poly1305:${SS_PASS}" | base64 -w 0)
        SS_LINK="ss://${SS_B64}@${SERVER_IP}:${PORT4}#Shadowsocks"
    else
        warn "Shadowsocks তৈরি ব্যর্থ"
    fi

    # Save configs
    cat > /root/vpn-configs.txt << EOF
════════════════════════════════════════
  X-UI PRO — VPN Config Links
  Generated: $(date)
  Server IP: ${SERVER_IP}
════════════════════════════════════════

[1] VLESS TCP (Port 443)
UUID: ${UUID1}
${VLESS_LINK:-N/A}

[2] VMess WebSocket (Port 8080)
UUID: ${UUID2}
WS Path: ${WS_PATH}
${VMESS_LINK:-N/A}

[3] Trojan TCP (Port 2083)
Password: ${TROJAN_PASS}
${TROJAN_LINK:-N/A}

[4] Shadowsocks (Port 8388)
Method: chacha20-ietf-poly1305
Password: ${SS_PASS}
${SS_LINK:-N/A}

════════════════════════════════════════
Panel URL  : http://${SERVER_IP}:${XUI_PORT}${XUI_PATH}
Username   : ${XUI_USER}
Password   : ${XUI_PASS}
════════════════════════════════════════
EOF

    ok "সব Config /root/vpn-configs.txt এ সেভ হয়েছে"
}

# ── Final Summary ─────────────────────────────────────────────────
show_summary() {
    SERVER_IP=$(curl -s --connect-timeout 5 ifconfig.me 2>/dev/null)

    echo ""
    echo -e "${G}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║            ✅ ইনস্টলেশন সফলভাবে সম্পন্ন!                ║"
    echo "╠════════════════════════════════════════════════════════════╣"
    printf "║  🌐 Panel  : http://%-40s║\n" "${SERVER_IP}:${XUI_PORT}${XUI_PATH}"
    printf "║  👤 User   : %-45s║\n" "${XUI_USER}"
    printf "║  🔑 Pass   : %-45s║\n" "${XUI_PASS}"
    echo "╠════════════════════════════════════════════════════════════╣"
    echo "║  ⚡ BBR High Speed    : Active                            ║"
    echo "║  🔒 Firewall         : Active                            ║"
    echo "║  📡 VLESS TCP        : Port 443                          ║"
    echo "║  📡 VMess WebSocket  : Port 8080                         ║"
    echo "║  📡 Trojan TCP       : Port 2083                         ║"
    echo "║  📡 Shadowsocks      : Port 8388                         ║"
    echo "╠════════════════════════════════════════════════════════════╣"
    echo "║  📄 Config file: /root/vpn-configs.txt                   ║"
    echo "║  📋 Manage    : bash manage.sh                           ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${N}"
    echo -e "${Y}  [!] প্রথম লগইনে পাসওয়ার্ড পরিবর্তন করুন!${N}"
    echo -e "${Y}  [!] SSL এর জন্য: bash ssl.sh${N}"
    echo ""
    echo -e "${C}  Config links দেখুন: cat /root/vpn-configs.txt${N}"
    echo ""
}

# ── Main ─────────────────────────────────────────────────────────
main() {
    banner
    > "$LOG"

    echo -e "${W}ইনস্টলেশন শুরু হচ্ছে... লগ: $LOG${N}"
    echo ""

    check_root
    check_os
    install_deps
    optimize
    install_xui
    configure_panel
    setup_firewall
    create_inbounds
    show_summary
}

main "$@"
