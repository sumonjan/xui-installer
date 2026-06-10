#!/bin/bash
# ============================================================
#   X-UI Auto V2Ray Config Setup (Fixed Version)
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

PANEL_PORT=54321
PANEL_USER="admin"
PANEL_PASS="admin"
BASE_URL="http://127.0.0.1:$PANEL_PORT"
COOKIE_FILE="/tmp/xui_cookie.txt"

show_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║      X-UI Auto V2Ray Config Generator v2.0          ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

gen_uuid() {
    cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen
}

gen_port() {
    local PORT
    while true; do
        PORT=$((RANDOM % 45535 + 10000))
        ss -tlnp | grep -q ":$PORT " || break
    done
    echo $PORT
}

login_panel() {
    echo -e "${BLUE}[INFO] Panel লগইন হচ্ছে...${NC}"
    rm -f $COOKIE_FILE

    RESPONSE=$(curl -s -c $COOKIE_FILE \
        -X POST "$BASE_URL/login" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "username=$PANEL_USER&password=$PANEL_PASS")

    if echo "$RESPONSE" | grep -q '"success":true'; then
        echo -e "${GREEN}[OK] লগইন সফল${NC}"
    else
        echo -e "${RED}[ERROR] লগইন ব্যর্থ!${NC}"
        echo "Response: $RESPONSE"
        exit 1
    fi
}

add_vless_tcp() {
    local UUID=$(gen_uuid)
    local PORT=$(gen_port)
    local REMARK="VLESS-TCP-$(date +%H%M)"

    echo -e "${BLUE}[INFO] VLESS TCP তৈরি হচ্ছে (Port: $PORT)...${NC}"

    # settings ও streamSettings সরাসরি JSON object — string নয়
    curl -s -b $COOKIE_FILE \
        -X POST "$BASE_URL/xui/inbound/add" \
        -H "Content-Type: application/json" \
        -d "{
  \"remark\": \"$REMARK\",
  \"enable\": true,
  \"listen\": \"\",
  \"port\": $PORT,
  \"protocol\": \"vless\",
  \"expiryTime\": 0,
  \"settings\": {
    \"clients\": [
      {
        \"id\": \"$UUID\",
        \"flow\": \"\",
        \"email\": \"user1\",
        \"limitIp\": 0,
        \"totalGB\": 0,
        \"expiryTime\": 0,
        \"enable\": true,
        \"tgId\": \"\",
        \"subId\": \"\"
      }
    ],
    \"decryption\": \"none\",
    \"fallbacks\": []
  },
  \"streamSettings\": {
    \"network\": \"tcp\",
    \"security\": \"none\",
    \"tcpSettings\": {
      \"acceptProxyProtocol\": false,
      \"header\": { \"type\": \"none\" }
    }
  },
  \"sniffing\": {
    \"enabled\": true,
    \"destOverride\": [\"http\", \"tls\"]
  }
}" > /tmp/vless_result.json

    if grep -q '"success":true' /tmp/vless_result.json; then
        SERVER_IP=$(curl -s ifconfig.me)
        echo -e "${GREEN}[OK] VLESS TCP তৈরি হয়েছে!${NC}"
        echo -e "${CYAN}  Port   : $PORT${NC}"
        echo -e "${CYAN}  UUID   : $UUID${NC}"
        echo -e "${CYAN}  Link   : vless://$UUID@$SERVER_IP:$PORT?type=tcp&security=none#$REMARK${NC}"
    else
        echo -e "${RED}[ERROR] VLESS TCP ব্যর্থ:${NC}"
        cat /tmp/vless_result.json
    fi
}

add_vmess_ws() {
    local UUID=$(gen_uuid)
    local PORT=$(gen_port)
    local WS_PATH="/$(cat /proc/sys/kernel/random/uuid | tr -d '-' | head -c 8)"
    local REMARK="VMess-WS-$(date +%H%M)"

    echo -e "${BLUE}[INFO] VMess WebSocket তৈরি হচ্ছে (Port: $PORT)...${NC}"

    curl -s -b $COOKIE_FILE \
        -X POST "$BASE_URL/xui/inbound/add" \
        -H "Content-Type: application/json" \
        -d "{
  \"remark\": \"$REMARK\",
  \"enable\": true,
  \"listen\": \"\",
  \"port\": $PORT,
  \"protocol\": \"vmess\",
  \"expiryTime\": 0,
  \"settings\": {
    \"clients\": [
      {
        \"id\": \"$UUID\",
        \"alterId\": 0,
        \"email\": \"user1\",
        \"limitIp\": 0,
        \"totalGB\": 0,
        \"expiryTime\": 0,
        \"enable\": true,
        \"tgId\": \"\",
        \"subId\": \"\"
      }
    ],
    \"disableInsecureEncryption\": false
  },
  \"streamSettings\": {
    \"network\": \"ws\",
    \"security\": \"none\",
    \"wsSettings\": {
      \"acceptProxyProtocol\": false,
      \"path\": \"$WS_PATH\",
      \"headers\": {}
    }
  },
  \"sniffing\": {
    \"enabled\": true,
    \"destOverride\": [\"http\", \"tls\"]
  }
}" > /tmp/vmess_result.json

    if grep -q '"success":true' /tmp/vmess_result.json; then
        SERVER_IP=$(curl -s ifconfig.me)
        VMESS_JSON="{\"v\":\"2\",\"ps\":\"$REMARK\",\"add\":\"$SERVER_IP\",\"port\":\"$PORT\",\"id\":\"$UUID\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"\",\"path\":\"$WS_PATH\",\"tls\":\"\"}"
        VMESS_B64=$(echo -n "$VMESS_JSON" | base64 -w 0)
        echo -e "${GREEN}[OK] VMess WebSocket তৈরি হয়েছে!${NC}"
        echo -e "${CYAN}  Port   : $PORT${NC}"
        echo -e "${CYAN}  Path   : $WS_PATH${NC}"
        echo -e "${CYAN}  UUID   : $UUID${NC}"
        echo -e "${CYAN}  Link   : vmess://$VMESS_B64${NC}"
    else
        echo -e "${RED}[ERROR] VMess WS ব্যর্থ:${NC}"
        cat /tmp/vmess_result.json
    fi
}

add_trojan_tcp() {
    local PASSWORD=$(cat /proc/sys/kernel/random/uuid | tr -d '-' | head -c 16)
    local PORT=$(gen_port)
    local REMARK="Trojan-TCP-$(date +%H%M)"

    echo -e "${BLUE}[INFO] Trojan TCP তৈরি হচ্ছে (Port: $PORT)...${NC}"

    curl -s -b $COOKIE_FILE \
        -X POST "$BASE_URL/xui/inbound/add" \
        -H "Content-Type: application/json" \
        -d "{
  \"remark\": \"$REMARK\",
  \"enable\": true,
  \"listen\": \"\",
  \"port\": $PORT,
  \"protocol\": \"trojan\",
  \"expiryTime\": 0,
  \"settings\": {
    \"clients\": [
      {
        \"password\": \"$PASSWORD\",
        \"email\": \"user1\",
        \"limitIp\": 0,
        \"totalGB\": 0,
        \"expiryTime\": 0,
        \"enable\": true,
        \"tgId\": \"\",
        \"subId\": \"\"
      }
    ],
    \"fallbacks\": []
  },
  \"streamSettings\": {
    \"network\": \"tcp\",
    \"security\": \"none\",
    \"tcpSettings\": {
      \"acceptProxyProtocol\": false,
      \"header\": { \"type\": \"none\" }
    }
  },
  \"sniffing\": {
    \"enabled\": true,
    \"destOverride\": [\"http\", \"tls\"]
  }
}" > /tmp/trojan_result.json

    if grep -q '"success":true' /tmp/trojan_result.json; then
        SERVER_IP=$(curl -s ifconfig.me)
        echo -e "${GREEN}[OK] Trojan TCP তৈরি হয়েছে!${NC}"
        echo -e "${CYAN}  Port     : $PORT${NC}"
        echo -e "${CYAN}  Password : $PASSWORD${NC}"
        echo -e "${CYAN}  Link     : trojan://$PASSWORD@$SERVER_IP:$PORT?security=none&type=tcp#$REMARK${NC}"
    else
        echo -e "${RED}[ERROR] Trojan TCP ব্যর্থ:${NC}"
        cat /tmp/trojan_result.json
    fi
}

list_inbounds() {
    echo -e "${BLUE}=== বর্তমান সকল Inbound ===${NC}"
    curl -s -b $COOKIE_FILE "$BASE_URL/xui/inbound/list" | \
    python3 -c "
import json,sys
data=json.load(sys.stdin)
items=data.get('obj',[])
if not items:
    print('  কোনো Inbound নেই')
for i,o in enumerate(items):
    status='✅' if o.get('enable') else '❌'
    print(f\"  {status} [{i+1}] {o.get('remark','?')} | {o.get('protocol','?')} | Port: {o.get('port','?')}\")
" 2>/dev/null
}

update_credentials() {
    echo -e "${YELLOW}Panel পোর্ট (ডিফল্ট 54321):${NC}"
    read -r P; PANEL_PORT=${P:-54321}
    echo -e "${YELLOW}Username (ডিফল্ট admin):${NC}"
    read -r U; PANEL_USER=${U:-admin}
    echo -e "${YELLOW}Password:${NC}"
    read -rs PW; echo ""; PANEL_PASS=${PW:-admin}
    BASE_URL="http://127.0.0.1:$PANEL_PORT"
}

main() {
    show_banner

    echo -e "${YELLOW}Panel লগইন তথ্য কাস্টম করবেন? (y/n):${NC}"
    read -r C; [[ $C == "y" ]] && update_credentials

    login_panel

    echo -e "\n${WHITE}কোনটা তৈরি করবেন?${NC}"
    echo "  [1] VLESS TCP"
    echo "  [2] VMess WebSocket"
    echo "  [3] Trojan TCP"
    echo "  [4] সবগুলো একসাথে ✅ (Recommended)"
    echo "  [5] Inbound লিস্ট দেখুন"
    echo "  [0] বাহির"
    echo -e "${YELLOW}পছন্দ:${NC}"
    read -r CH

    echo ""
    case $CH in
        1) add_vless_tcp ;;
        2) add_vmess_ws ;;
        3) add_trojan_tcp ;;
        4) add_vless_tcp; echo ""; add_vmess_ws; echo ""; add_trojan_tcp ;;
        5) list_inbounds ;;
        0) exit 0 ;;
        *) echo -e "${RED}অবৈধ পছন্দ${NC}" ;;
    esac

    echo -e "\n${GREEN}✅ সম্পন্ন! Link গুলো V2RayNG/Nekoray তে import করুন।${NC}"
}

main "$@"
