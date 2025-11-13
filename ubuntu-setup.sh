#!/bin/bash
#
# Setup skript pro Ubuntu VM - česká klávesnice + XFCE + XRDP
# Spusťte na Ubuntu VM jako root nebo s sudo
#

set -e

echo "=== AIDA Ubuntu VM Setup ==="
echo ""

# Aktualizace systému
echo "1/6 Aktualizace systému..."
apt update
apt upgrade -y

# Instalace českého locale
echo "2/6 Instalace českého jazyka..."
apt install -y language-pack-cs language-pack-cs-base

# Instalace XFCE desktop
echo "3/6 Instalace XFCE desktop..."
apt install -y xfce4 xfce4-goodies

# Instalace XRDP
echo "4/6 Instalace XRDP serveru..."
apt install -y xrdp
systemctl enable xrdp
systemctl start xrdp

# Nastavení českého layoutu systémově
echo "5/6 Nastavení české klávesnice..."
localectl set-x11-keymap cz pc105 '' qwertz

# Vytvoření uživatele aida (pokud neexistuje)
echo "6/6 Kontrola uživatele aida..."
if ! id "aida" &>/dev/null; then
    echo "Vytvářím uživatele aida..."
    adduser --gecos "AIDA User" --disabled-password aida
    echo "aida:Poklop123..." | chpasswd
    usermod -aG sudo aida
    echo "Uživatel aida vytvořen."
else
    echo "Uživatel aida již existuje."
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
echo "  - XRDP běží na portu 3389"
echo "  - Uživatel: aida"
echo "  - Heslo: Poklop123..."
echo "  - Česká klávesnice: cs-cz-qwertz"
echo ""
echo "Doporučuji restartovat VM:"
echo "  sudo reboot"
echo ""
