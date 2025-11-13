#!/bin/bash
#
# Setup skript pro Ubuntu VM - česká klávesnice + XFCE + XRDP + Firefox
# Spusťte na Ubuntu VM jako root nebo s sudo
#

set -e

echo "=== AIDA Ubuntu VM Setup ==="
echo ""

# Aktualizace systému
echo "1/7 Aktualizace systému..."
apt update
apt upgrade -y

# Instalace českého locale
echo "2/7 Instalace českého jazyka..."
apt install -y language-pack-cs language-pack-cs-base

# Instalace XFCE desktop + Firefox
echo "3/7 Instalace XFCE desktop a Firefox..."
apt install -y xfce4 xfce4-goodies firefox

# Instalace XRDP
echo "4/7 Instalace XRDP serveru..."
apt install -y xrdp
systemctl enable xrdp
systemctl start xrdp

# Nastavení českého layoutu systémově
echo "5/7 Nastavení české klávesnice..."
localectl set-x11-keymap cz pc105 '' qwertz

# Kontrola a konfigurace uživatele aida
echo "6/7 Kontrola uživatele aida..."
if ! id "aida" &>/dev/null; then
    echo "Vytvářím uživatele aida..."
    adduser --gecos "AIDA User" --disabled-password aida
    echo "aida:Poklop123..." | chpasswd
    usermod -aG ssl-cert aida
    echo "Uživatel aida vytvořen s heslem."
else
    echo "Uživatel aida již existuje - ponechávám stávající heslo."
    # Přidání do ssl-cert skupiny (pokud tam ještě není)
    usermod -aG ssl-cert aida 2>/dev/null || true
fi

# Vytvoření .xsession pro uživatele aida s českým layoutem
echo "Nastavuji .xsession pro českého layoutu..."
cat > /home/aida/.xsession << 'EOF'
#!/bin/bash
export LANG=cs_CZ.UTF-8
export LC_ALL=cs_CZ.UTF-8
setxkbmap cz
startxfce4
EOF

chmod +x /home/aida/.xsession
chown aida:aida /home/aida/.xsession

# Nastavení Firefoxu jako výchozího prohlížeče
echo "7/7 Nastavení Firefoxu jako výchozího prohlížeče..."
if [ -d /home/aida ]; then
    sudo -u aida xdg-settings set default-web-browser firefox.desktop 2>/dev/null || true
fi

# Povolení RDP portu ve firewallu (pokud je UFW aktivní)
if command -v ufw &> /dev/null; then
    echo "Povolit RDP port ve firewallu..."
    ufw allow 3389/tcp
fi

echo ""
echo "=== Setup dokončen! ==="
echo ""
echo "Informace:"
echo "  - XFCE desktop nainstalován"
echo "  - Firefox nainstalován jako výchozí prohlížeč"
echo "  - XRDP běží na portu 3389"
echo "  - Uživatel: aida"
echo "  - Heslo: Poklop123..."
echo "  - Česká klávesnice: cs-cz-qwertz"
echo ""
echo "Doporučuji restartovat VM:"
echo "  sudo reboot"
echo ""
