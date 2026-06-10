# ⚡ X-UI PRO — High Speed VPN Panel Installer

সম্পূর্ণ অটোমেটিক V2Ray/Xray Panel ইনস্টলার।  
এক কমান্ডে সব হয়ে যায় — BBR, Panel, Multi-Protocol, Auto Config।

---

## 🚀 এক কমান্ডে ইনস্টল

```bash
bash <(curl -Ls https://raw.githubusercontent.com/sumonjan/xui-pro/main/install.sh)
```

---

## 📁 ফাইল তালিকা

| ফাইল | কাজ |
|------|-----|
| `install.sh` | মূল ইনস্টলার — সব অটো করে |
| `ssl.sh` | SSL সার্টিফিকেট সেটআপ |
| `manage.sh` | ম্যানেজমেন্ট মেনু + User তৈরি |

---

## ✅ স্বয়ংক্রিয়ভাবে যা হয়

- BBR High Speed Mode চালু
- 3x-UI Panel ইনস্টল ও কনফিগার
- ৪টি Protocol অটো Inbound তৈরি:
  - VLESS TCP (Port 443)
  - VMess WebSocket (Port 8080)
  - Trojan TCP (Port 2083)
  - Shadowsocks (Port 8388)
- Firewall সেটআপ
- সব Config `/root/vpn-configs.txt` এ সেভ

---

## 👤 নতুন User তৈরি (Auto Config)

```bash
bash manage.sh
# তারপর [6] চাপুন
```

User তৈরি করলে সাথে সাথে V2RayNG/Nekoray Link পাওয়া যাবে।

---

## 🔒 SSL সেটআপ

```bash
bash ssl.sh
```

---

## ⚙️ ম্যানেজমেন্ট

```bash
bash manage.sh
```
