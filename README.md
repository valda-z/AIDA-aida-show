# AIDA Show - Remote Linux Desktop přes HTTPS

Tento projekt poskytuje zabezpečený vzdálený přístup k Linux desktopu přes HTTPS s autentizací pomocí Azure AD.

## Architektura

```
Internet (HTTPS)
    ↓
Traefik (reverse proxy + TLS)
    ↓
OAuth2-Proxy (Azure AD autentizace)
    ↓
Apache Guacamole (HTML5 remote desktop)
    ↓
Ubuntu VM (RDP/SSH server)
```

### Komponenty

- **Traefik**: Reverse proxy s automatickými Let's Encrypt certifikáty
- **OAuth2-Proxy**: Autentizace uživatelů přes Azure Active Directory
- **Apache Guacamole**: HTML5 klient pro vzdálené připojení (RDP, VNC, SSH)
- **Guacd**: Backend daemon pro Guacamole (zpracování RDP/VNC/SSH protokolů)
- **Ubuntu VM**: Cílový systém s X Window + XRDP serverem

## Prerekvizity

### 1. Docker Host

- Docker Engine 20.10+
- Docker Compose v2+
- Doména s DNS A záznamy směřující na server

### 2. Ubuntu VM (cílový systém)

Na Ubuntu VM (fyzický nebo KVM virtuální stroj) nainstalujte:

```bash
# Aktualizace systému
sudo apt update && sudo apt upgrade -y

# Instalace XFCE desktop environment
sudo apt install -y xfce4 xfce4-goodies

# Instalace XRDP serveru
sudo apt install -y xrdp
sudo systemctl enable xrdp
sudo systemctl start xrdp

# Konfigurace XFCE jako výchozí session
echo "startxfce4" > ~/.xsession
chmod +x ~/.xsession

# Povolení RDP portu ve firewallu (pokud je UFW aktivní)
sudo ufw allow 3389/tcp

# Vytvoření uživatele pro vzdálený přístup (volitelné)
sudo adduser remotuser
sudo usermod -aG sudo remotuser
```

**DŮLEŽITÉ**: Port 3389 (RDP) by měl být přístupný pouze z Docker sítě nebo interní VLAN, ne z internetu!

### 3. Azure AD Application

V Azure Portal již máte nakonfigurovanou aplikaci:
- **Client ID**: `c5bb91d7-8bc7-4c7c-8167-5b4b9762399f`
- **Tenant ID**: `269a1b55-b8e0-4721-9d49-ae9f28544118`
- **Redirect URL**: `https://aida-show.aida.cloudfield.dev/oauth2/callback`

Pokud potřebujete změnit doménu, upravte:
1. Redirect URL v Azure AD aplikaci
2. Všechny výskyty domény v `compose.yaml` (REDIRECT_URL, COOKIE_DOMAIN, WHITELIST_DOMAIN)

## Konfigurace

### 1. Secrets (.env)

Vytvořte `.env` soubor v root adresáři projektu s citlivými údaji:

```bash
# Zkopírujte šablonu
cp .env.example .env

# Upravte secrets
nano .env
```

Soubor `.env` obsahuje pouze **2 secrets**:
```bash
# Citlivé údaje - SECRETS
OAUTH2_PROXY_CLIENT_SECRET=your-client-secret-here
OAUTH2_PROXY_COOKIE_SECRET=your-cookie-secret-here
```

**Kde získat hodnoty**:
- `OAUTH2_PROXY_CLIENT_SECRET`: Z Azure AD App Registration
- `OAUTH2_PROXY_COOKIE_SECRET`: Vygenerujte pomocí:
  ```bash
  python -c 'import os,base64; print(base64.urlsafe_b64encode(os.urandom(32)).decode())'
  ```

**DŮLEŽITÉ**:
- Soubor `.env` je v `.gitignore` a nikdy se necommituje
- Všechny ostatní hodnoty (Client ID, Tenant ID, Domain) jsou přímo v `compose.yaml`

### 2. Guacamole user-mapping.xml

Upravte soubor `guacamole/user-mapping.xml`:

```xml
<authorize username="linux" password="ZMENIT_HESLO_PRO_GUACAMOLE">
    <connection name="Ubuntu-Desktop-RDP">
        <protocol>rdp</protocol>
        <!-- ZMĚŇTE na IP vaší Ubuntu VM -->
        <param name="hostname">192.168.1.100</param>
        <param name="port">3389</param>

        <!-- ZMĚŇTE na přihlašovací údaje Ubuntu -->
        <param name="username">remotuser</param>
        <param name="password">ubuntu_password</param>
        ...
    </connection>
</authorize>
```

**Poznámka**: Pro produkční použití doporučujeme:
- Databázový backend (MySQL/PostgreSQL) místo XML
- LDAP/AD integraci pro správu uživatelů
- Vícefaktorovou autentizaci

**BEZPEČNOST**: Soubor `user-mapping.xml` je přidán do `.gitignore` po jeho úpravě (obsahuje hesla). Uchovávejte šablonu v gitu, ale upravený soubor s reálnými hesly nikdy necommitujte.

### 3. DNS konfigurace

Ověřte DNS A záznam:
```
aida-show.aida.cloudfield.dev → IP vašeho serveru
```

### 4. Síťová dostupnost

Ujistěte se, že:
- Port **443** je otevřený směrem z internetu
- Port **3389** (RDP) je přístupný z Docker sítě na Ubuntu VM
- Port **22** (SSH) je přístupný z Docker sítě (volitelné)

## Spuštění

### 1. Příprava environment

```bash
# Vytvoření potřebných adresářů
mkdir -p letsencrypt traefik/dynamic guacamole
chmod 700 letsencrypt

# Zkopírování a úprava .env souboru
cp .env.example .env
nano .env  # nebo vim/code .env

# Úprava Guacamole konfigurace
nano guacamole/user-mapping.xml  # upravte IP, username, password
```

### 2. Kontrola konfigurace

```bash
# Zkontrolujte .env soubor
cat .env

# Ověřte, že compose.yaml načte proměnné
docker compose config

# Zkontrolujte Traefik routing
cat traefik/dynamic/dynamic.yml

# Zkontrolujte Guacamole připojení
cat guacamole/user-mapping.xml
```

### 3. Spuštění stacku

```bash
# Spuštění všech služeb
docker compose up -d

# Sledování logů
docker compose logs -f

# Kontrola stavu služeb
docker compose ps
```

### 4. Ověření funkčnosti

1. **Traefik Dashboard**: http://localhost:8080 (pouze z localhost)
2. **HTTPS přístup**: https://aida-show.aida.cloudfield.dev

Očekávaný flow:
1. Přístup na URL → redirect na Azure AD login
2. Po přihlášení → redirect zpět na aplikaci
3. Guacamole login stránka → zadáte credentials z user-mapping.xml
4. Po přihlášení → zobrazí se Ubuntu desktop v prohlížeči

## Řešení problémů

### Nelze se připojit k Ubuntu VM

```bash
# Na Docker hostu - test RDP připojení
docker run --rm -it --network aida-network alpine:latest sh
apk add --no-cache nmap
nmap -p 3389 IP_UBUNTU_VM

# Kontrola XRDP služby na Ubuntu
sudo systemctl status xrdp
sudo journalctl -u xrdp -f
```

### OAuth2 Proxy nefunguje

```bash
# Kontrola logů OAuth2 Proxy
docker compose logs oauth2-aida-show

# Časté problémy:
# - Nesprávný Redirect URL v Azure AD
# - Nesprávný Client Secret
# - Cookie domain nesouhlasí s doménou
```

### Guacamole connection error

```bash
# Kontrola guacd logů
docker compose logs guacd

# Kontrola Guacamole logů
docker compose logs guacamole

# Časté problémy:
# - Špatná IP adresa Ubuntu VM v user-mapping.xml
# - Špatné přihlašovací údaje
# - RDP server není dostupný z Docker sítě
```

### Let's Encrypt certifikát se nevygeneruje

```bash
# Kontrola Traefik logů
docker compose logs traefik

# Časté problémy:
# - DNS nezobrazuje na správnou IP
# - Port 443 není přístupný z internetu
# - Rate limit Let's Encrypt (použijte staging nejdříve)
```

Pro testování můžete dočasně povolit staging certifikáty:
```yaml
# V compose.yaml Traefik command
- "--certificatesresolvers.myresolver.acme.caserver=https://acme-staging-v02.api.letsencrypt.org/directory"
```

## Bezpečnostní doporučení

### ⚠️ DŮLEŽITÉ - Před produkčním nasazením

1. **Změňte všechna hesla**:
   - Client Secret v Azure AD
   - Cookie Secret pro OAuth2 Proxy
   - Heslo v user-mapping.xml
   - Hesla uživatelů na Ubuntu VM

2. **Zabezpečte Traefik Dashboard**:
   ```yaml
   # V compose.yaml vypněte nebo zabezpečte:
   - "--api.insecure=false"  # ZMĚNIT na false
   ```

3. **Použijte databázový backend pro Guacamole**:
   - MySQL nebo PostgreSQL
   - Lepší správa uživatelů a připojení
   - Audit logging

4. **Síťová izolace**:
   - Ubuntu VM pouze v privátní síti
   - Žádný direct RDP přístup z internetu
   - Použijte firewall pravidla

5. **Monitoring a logging**:
   - Centralizované logy (ELK, Loki, atd.)
   - Monitoring dostupnosti služeb
   - Alerting při podezřelých aktivitách

6. **Rate limiting**:
   - Traefik rate limit middleware
   - Fail2ban pro SSH na Ubuntu VM

## Údržba

### Aktualizace služeb

```bash
# Pull nových images
docker compose pull

# Restart s novými images
docker compose up -d

# Cleanup starých images
docker image prune
```

### Backup

Zálohujte tyto soubory a adresáře:
- `.env` - Environment proměnné (CITLIVÉ!)
- `letsencrypt/` - TLS certifikáty
- `guacamole/user-mapping.xml` - Konfigurace připojení (CITLIVÉ!)
- `traefik/dynamic/` - Routing konfigurace

**POZOR**: Backup obsahuje citlivá data! Šifrujte a ukládejte bezpečně.

### Rotace přihlašovacích údajů

1. Vygenerujte nový Client Secret v Azure AD
2. Vygenerujte nový Cookie Secret:
   ```bash
   python -c 'import os,base64; print(base64.urlsafe_b64encode(os.urandom(32)).decode())'
   ```
3. Aktualizujte hodnoty v `.env` souboru
4. Restart služeb: `docker compose up -d`

## Rozšíření

### Připojení více Ubuntu VM

V `user-mapping.xml` přidejte další connections:

```xml
<connection name="Ubuntu-Server-2">
    <protocol>rdp</protocol>
    <param name="hostname">192.168.1.101</param>
    ...
</connection>
```

### Použití VNC místo RDP

```xml
<connection name="Ubuntu-VNC">
    <protocol>vnc</protocol>
    <param name="hostname">192.168.1.100</param>
    <param name="port">5901</param>
    <param name="password">vnc_password</param>
</connection>
```

Na Ubuntu VM:
```bash
sudo apt install -y tigervnc-standalone-server
vncserver :1
```

## Reference

- [Apache Guacamole Documentation](https://guacamole.apache.org/doc/gug/)
- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [OAuth2 Proxy Documentation](https://oauth2-proxy.github.io/oauth2-proxy/)
- [XRDP Documentation](http://www.xrdp.org/)

## Podpora

Pro problémy nebo dotazy kontaktujte: valda@cloudfield.cz

---

**Verze**: 1.0
**Datum**: 2025-01-13
**Autor**: AIDA Team
