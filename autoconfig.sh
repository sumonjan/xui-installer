#!/bin/bash
# ============================================================
#   X-UI Auto V2Ray Config Setup - Fixed Version
#   Ubuntu 24.04 | 3x-ui Panel Compatible
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

COOKIE_FILE="/tmp/xui_cookie.txt"

show_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║      X-UI Auto V2Ray Config Generator v3.0          ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# ── Panel তথ্য নেওয়া ──────────────────────────────────────
get_panel_info() {
    echo -e "${YELLOW}Panel পোর্ট লিখুন (ডিফল্ট 54321):${NC}"
    read -r P
    PANEL_PORT=${P:-54321}

    echo -e "${YELLOW}Panel Username (ডিফল্ট admin):${NC}"
    read -r U
    PANEL_USER=${U:-admin}

    echo -e "${YELLOW}Panel Password:${NC}"
    read -rs PW
    echo ""
    PANEL_PASS=${PW:-admin}

    BASE_URL="http://127.0.0.1:${PANEL_PORT}"
}

# ── Panel চলছে কিনা চেক ──────────────────────────────────
check_panel_running() {
    echo -e "${BLUE}[INFO] Panel চেক করা হচ্ছে...${NC}"

    if ! systemctl is-active --quiet x-ui; then
        echo -e "${RED}[ERROR] X-UI Panel চলছে না!${NC}"
        echo -e "${YELLOW}চালু করুন: systemctl start x-ui${NC}"
        exit 1
    fi

    # পোর্ট খোলা আছে কিনা
    if ! ss -tlnp | grep -q ":${PANEL_PORT}"; then
        echo -e "${RED}[ERROR] Port ${PANEL_PORT} খোলা নেই!${NC}"
        echo -e "${YELLOW}চলমান পোর্ট দেখুন: ss -tlnp | grep x-ui${NC}"
        exit 1
    fi

    echo -e "${GREEN}[OK] Panel চলছে Port: ${PANEL_PORT}${NC}"
}

# ── Login ─────────────────────────────────────────────────
login_panel() {
    echo -e "${BLUE}[INFO] Login হচ্ছে...${NC}"
    rm -f "$COOKIE_FILE"

    HTTP_CODE=$(curl -s -o /tmp/login_resp.txt -w "%{http_code}" \
        -c "$COOKIE_FILE" \
        -X POST "${BASE_URL}/login" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        --connect-timeout 10 \
        -d "username=${PANEL_USER}&password=${PANEL_PASS}")

    RESP=$(cat /tmp/login_resp.txt)

    if echo "$RESP" | grep -q '"success":true'; then
        echo -e "${GREEN}[OK] Login সফল!${NC}"
    else
        echo -e "${RED}[ERROR] Login ব্যর্থ!${NC}"
        echo -e "${YELLOW}HTTP Code: $HTTP_CODE${NC}"
        echo -e "${YELLOW}Response: $RESP${NC}"
        echo ""
        echo -e "${YELLOW}সমাধান: Panel URL ব্রাউজারে খুলে username/password চেক করুন${NC}"
        echo -e "${YELLOW}URL: http://$(curl -s ifconfig.me):${PANEL_PORT}${NC}"
        exit 1
    fi
}

# ── UUID ও Port Generator ─────────────────────────────────
gen_uuid() {
    cat /proc/sys/kernel/random/uuid
}

gen_port() {
    local PORT
    while true; do
        PORT=$((RANDOM % 45000 + 10000))
        ! ss -tlnp | grep -q ":${PORT} " && echo $PORT && return
    done
}

# ── VLESS TCP ─────────────────────────────────────────────
add_vless_tcp() {
    local UUID PORT REMARK SERVER_IP
    UUID=$(gen_uuid)
    PORT=$(gen_port)
    REMARK="VLESS-TCP-${PORT}"
    SERVER_IP=$(curl -s --connect-timeout 5 ifconfig.me)

    echo -e "${BLUE}[INFO] VLESS TCP তৈরি হচ্ছে... Port: ${PORT}${NC}"

    curl -s -b "$COOKIE_FILE" \
        -X POST "${BASE_URL}/xui/inbound/add" \
        -H "Content-Type: application/json" \
        --connect-timeout 10 \
        -d @- << EOF > /tmp/vless_resp.txt
{
  "remark": "${REMARK}",
  "enable": true,
  "listen": "",
  "port": ${PORT},
  "protocol": "vless",
  "expiryTime": 0,
  "settings": {
    "clients": [
      {
        "id": "${UUID}",
        "flow": "",
        "email": "vless_user",
        "limitIp": 0,
        "totalGB": 0,
        "expiryTime": 0,
        "enable": true,
        "tgId": "",
        "subId": ""
      }
    ],
    "decryption": "none",
    "fallbacks": []
  },
  "streamSettings": {
    "network": "tcp",
    "security": "none",
    "tcpSettings": {
      "acceptProxyProtocol": false,
      "header": {
        "type": "none"
      }
    }
  },
  "sniffing": {
    "enabled": true,
    "destOverride": ["http", "tls"]
  }
}
EOF

    if grep -q '"success":true' /tmp/vless_resp.txt; then
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}✅ VLESS TCP তৈরি সফল!${NC}"
        echo -e "${CYAN}   Port    : ${PORT}${NC}"
        echo -e "${CYAN}   UUID    : ${UUID}${NC}"
        echo -e "${CYAN}   Link    : vless://${UUID}@${SERVER_IP}:${PORT}?type=tcp&security=none#${REMARK}${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    else
        echo -e "${RED}[ERROR] VLESS TCP ব্যর্থ:${NC}"
        cat /tmp/vless_resp.txt
    fi
}

# ── VMess WebSocket ───────────────────────────────────────
add_vmess_ws() {
    local UUID PORT WS_PATH REMARK SERVER_IP VMESS_JSON VMESS_B64
    UUID=$(gen_uuid)
    PORT=$(gen_port)
    WS_PATH="/$(cat /proc/sys/kernel/random/uuid | tr -d '-' | head -c 8)"
    REMARK="VMess-WS-${PORT}"
    SERVER_IP=$(curl -s --connect-timeout 5 ifconfig.me)

    echo -e "${BLUE}[INFO] VMess WebSocket তৈরি হচ্ছে... Port: ${PORT}${NC}"

    curl -s -b "$COOKIE_FILE" \
        -X POST "${BASE_URL}/xui/inbound/add" \
        -H "Content-Type: application/json" \
        --connect-timeout 10 \
        -d @- << EOF > /tmp/vmess_resp.txt
{
  "remark": "${REMARK}",
  "enable": true,
  "listen": "",
  "port": ${PORT},
  "protocol": "vmess",
  "expiryTime": 0,
  "settings": {
    "clients": [
      {
        "id": "${UUID}",
        "alterId": 0,
        "email": "vmess_user",
        "limitIp": 0,
        "totalGB": 0,
        "expiryTime": 0,
        "enable": true,
        "tgId": "",
        "subId": ""
      }
    ],
    "disableInsecureEncryption": false
  },
  "streamSettings": {
    "network": "ws",
    "security": "none",
    "wsSettings": {
      "acceptProxyProtocol": false,
      "path": "${WS_PATH}",
      "headers": {}
    }
  },
  "sniffing": {
    "enabled": true,
    "destOverride": ["http", "tls"]
  }
}
EOF

    if grep -q '"success":true' /tmp/vmess_resp.txt; then
        VMESS_JSON="{\"v\":\"2\",\"ps\":\"${REMARK}\",\"add\":\"${SERVER_IP}\",\"port\":\"${PORT}\",\"id\":\"${UUID}\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"\",\"path\":\"${WS_PATH}\",\"tls\":\"\"}"
        VMESS_B64=$(echo -n "$VMESS_JSON" | base64 -w 0)
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}✅ VMess WebSocket তৈরি সফল!${NC}"
        echo -e "${CYAN}   Port    : ${PORT}${NC}"
        echo -e "${CYAN}   Path    : ${WS_PATH}${NC}"
        echo -e "${CYAN}   UUID    : ${UUID}${NC}"
        echo -e "${CYAN}   Link    : vmess://${VMESS_B64}${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    else
        echo -e "${RED}[ERROR] VMess WS ব্যর্থ:${NC}"
        cat /tmp/vmess_resp.txt
    fi
}

# ── Trojan TCP ────────────────────────────────────────────
add_trojan_tcp() {
    local PASS PORT REMARK SERVER_IP
    PASS=$(cat /proc/sys/kernel/random/uuid | tr -d '-' | head -c 16)
    PORT=$(gen_port)
    REMARK="Trojan-TCP-${PORT}"
    SERVER_IP=$(curl -s --connect-timeout 5 ifconfig.me)

    echo -e "${BLUE}[INFO] Trojan TCP তৈরি হচ্ছে... Port: ${PORT}${NC}"

    curl -s -b "$COOKIE_FILE" \
        -X POST "${BASE_URL}/xui/inbound/add" \
        -H "Content-Type: application/json" \
        --connect-timeout 10 \
        -d @- << EOF > /tmp/trojan_resp.txt
{
  "remark": "${REMARK}",
  "enable": true,
  "listen": "",
  "port": ${PORT},
  "protocol": "trojan",
  "expiryTime": 0,
  "settings": {
    "clients": [
      {
        "password": "${PASS}",
        "email": "trojan_user",
        "limitIp": 0,
        "totalGB": 0,
        "expiryTime": 0,
        "enable": true,
        "tgId": "",
        "subId": ""
      }
    ],
    "fallbacks": []
  },
  "streamSettings": {
    "network": "tcp",
    "security": "none",
    "tcpSettings": {
      "acceptProxyProtocol": false,
      "header": {
        "type": "none"
      }
    }
  },
  "sniffing": {
    "enabled": true,
    "destOverride": ["http", "tls"]
  }
}
EOF

    if grep -q '"success":true' /tmp/trojan_resp.txt; then
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}✅ Trojan TCP তৈরি সফল!${NC}"
        echo -e "${CYAN}   Port     : ${PORT}${NC}"
        echo -e "${CYAN}   Password : ${PASS}${NC}"
        echo -e "${CYAN}   Link     : trojan://${PASS}@${SERVER_IP}:${PORT}?security=none&type=tcp#${REMARK}${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    else
        echo -e "${RED}[ERROR] Trojan TCP ব্যর্থ:${NC}"
        cat /tmp/trojan_resp.txt
    fi
}

# ── Inbound List ──────────────────────────────────────────
list_inbounds() {
    echo -e "${BLUE}=== বর্তমান Inbound লিস্ট ===${NC}"
    curl -s -b "$COOKIE_FILE" "${BASE_URL}/xui/inbound/list" | \
    python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    items = data.get('obj', [])
    if not items:
        print('  কোনো Inbound নেই')
    else:
        for i, o in enumerate(items, 1):
            st = '✅' if o.get('enable') else '❌'
            print(f\"  {st} [{i}] {o.get('remark','?')} | {o.get('protocol','?').upper()} | Port: {o.get('port','?')}\")
except:
    print('  Parse error - raw response দেখুন')
"
}

# ── Main ──────────────────────────────────────────────────
main() {
    show_banner
    get_panel_info
    check_panel_running
    login_panel

    echo ""
    echo -e "${WHITE}কী করতে চান?${NC}"
    echo "  [1] VLESS TCP"
    echo "  [2] VMess WebSocket"
    echo "  [3] Trojan TCP"
    echo "  [4] সবগুলো একসাথে ✅ (Recommended)"
    echo "  [5] Inbound লিস্ট দেখুন"
    echo "  [0] বাহির"
    echo ""
    echo -e "${YELLOW}পছন্দ লিখুন:${NC}"
    read -r CH

    echo ""
    case $CH in
        1) add_vless_tcp ;;
        2) add_vmess_ws ;;
        3) add_trojan_tcp ;;
        4)
            add_vless_tcp
            echo ""
            add_vmess_ws
            echo ""
            add_trojan_tcp
            ;;
        5) list_inbounds ;;
        0) echo -e "${GREEN}ধন্যবাদ!${NC}"; exit 0 ;;
        *) echo -e "${RED}অবৈধ পছন্দ!${NC}" ;;
    esac

    echo ""
    echo -e "${GREEN}✅ সম্পন্ন! Link গুলো V2RayNG / Nekoray / Clash তে import করুন।${NC}"
}

main "$@"
