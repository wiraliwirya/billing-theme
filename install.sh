#!/bin/bash

BOLD='\033[1m'
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

header() {
    clear
    echo -e "${CYAN}"
    echo -e " ╔════════════════════════════════════════════════════════════╗"
    echo -e " ║      🦅 PTERODACTYL INSTALLER BY LIWIRYA 🦅        ║"
    echo -e " ╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

info() { echo -e "${CYAN}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[DONE]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[FAIL]${NC} $1"; }
input_tag() { echo -ne "${WHITE}[INPUT]${NC} $1"; }

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "Woy! Jalanin pake ROOT (sudo). Lu mau ngedit system pake doa?"
        exit 1
    fi
}

setup_env() {
    header
    info "Ngecek alat perang (jq, zip, curl)..."
    sudo apt update -qq && sudo apt install -y jq zip unzip curl -qq
    
    if command -v jq &> /dev/null; then
        success "Tools lengkap. Aman."
    else
        error "Gagal install tools dasar. Internet lu idup gak sih?"
        exit 1
    fi
    sleep 1
}

verify_token() {
    header
    echo -e "${PURPLE}🔒 RESTRICTED ACCESS AREA${NC}"
    echo -e "Script ini diproteksi biar bocil gak asal pake.\n"
    
    input_tag "Masukin Token Lisensi: "
    read -r USER_TOKEN

    if [ "$USER_TOKEN" = "verlangdev" ]; then
        echo -e "${GREEN}>> ACCESS GRANTED. Welcome, Boss.${NC}"
        sleep 1
    else
        echo -e "${RED}>> ACCESS DENIED.${NC}"
        echo -e "${YELLOW}Token salah blok! Beli dulu sana sama ownernya.${NC}"
        echo -e "Telegram: @verlangid11"
        exit 1
    fi
}

feature_install_theme() {
    header
    echo -e "${YELLOW}--- [ INSTALL THEME ] ---${NC}"
    echo "Pilih baju baru buat panel lu:"
    echo -e "${CYAN}[1]${NC} Stellar Theme (Best Seller)"
    echo -e "${CYAN}[2]${NC} Billing Theme"
    echo -e "${CYAN}[3]${NC} Enigma Theme (Custom WA)"
    echo -e "${RED}[x]${NC} Batal / Back"
    
    input_tag "Pilih nomer: "
    read THEME_CHOICE

    case $THEME_CHOICE in
        1) THEME_NAME="stellar";;
        2) THEME_NAME="billing";;
        3) THEME_NAME="enigma";;
        x) return;;
        *) error "Mata lu siwer? Pilih 1, 2, atau 3!"; sleep 2; return;;
    esac

    cd /var/www/pterodactyl || { error "Panel Pterodactyl gak ketemu di /var/www/pterodactyl!"; return; }

    info "Lagi download theme $THEME_NAME..."
    wget -q -O "/root/${THEME_NAME}.zip" "https://github.com/Verlangid11/Installermenuverlang/raw/main/${THEME_NAME}.zip"

    if [ ! -f "/root/${THEME_NAME}.zip" ]; then
        error "Download gagal. Link mati atau internet lu bapuk."
        return
    fi

    info "Bongkar file zip..."
    unzip -oq "/root/${THEME_NAME}.zip" -d /root/pterodactyl

    if [ "$THEME_NAME" == "enigma" ]; then
        echo
        warn "Theme Enigma butuh config sosmed:"
        input_tag "Link WhatsApp: "; read WA
        input_tag "Link Grup: "; read GRUP
        input_tag "Link Channel: "; read CHNL
        
        SED_TARGET="/root/pterodactyl/resources/scripts/components/dashboard/DashboardContainer.tsx"
        sed -i "s|LINK_WA|$WA|g" "$SED_TARGET"
        sed -i "s|LINK_GROUP|$GRUP|g" "$SED_TARGET"
        sed -i "s|LINK_CHNL|$CHNL|g" "$SED_TARGET"
    fi

    info "Nerapin file ke panel..."
    sudo cp -rfT /root/pterodactyl /var/www/pterodactyl

    info "Build assets (Lama nih, sabar, jangan di-close)..."
    
    if ! command -v yarn &> /dev/null; then
        curl -sL https://deb.nodesource.com/setup_16.x | sudo -E bash - &>/dev/null
        sudo apt install -y nodejs &>/dev/null
        sudo npm install -g yarn &>/dev/null
    fi

    yarn add react-feather
    php artisan migrate
    yarn build:production
    php artisan view:clear

    rm -f "/root/${THEME_NAME}.zip"
    rm -rf /root/pterodactyl

    success "Theme $THEME_NAME kepasang! Ganteng dah panel lu."
    echo -e "${YELLOW}Note: Kalau tampilan masih aneh, clear cache browser lu.${NC}"
    read -p "Tekan Enter buat balik..."
}

feature_repair_panel() {
    header
    warn "Fitur ini bakal ngereset tampilan panel ke DEFAULT."
    warn "Semua modifikasi theme bakal ilang. Yakin?"
    input_tag "Ketik 'gas' kalau yakin: "
    read KONFIRM
    
    if [ "$KONFIRM" == "gas" ]; then
        info "Jalanin script repair..."
        bash <(curl https://raw.githubusercontent.com/Verlangid11/installer-theme/main/repair.sh)
        success "Panel udah bersih (default)."
    else
        info "Dibatalkan."
    fi
    sleep 2
}

feature_config_wings() {
    header
    echo -e "${YELLOW}--- [ CONFIGURE WINGS ] ---${NC}"
    echo "Fungsi ini buat nge-link node ke panel secara otomatis."
    echo "Copas command konfigurasi dari panel lu (yang depannya 'cd /etc/pterodactyl...')"
    
    echo
    input_tag "Paste command di sini: "
    read WINGS_CMD

    if [[ "$WINGS_CMD" == *"cd /etc/pterodactyl"* ]]; then
        info "Eksekusi command..."
        eval "$WINGS_CMD"
        sudo systemctl start wings
        success "Wings dikonfigurasi & dinyalain."
    else
        error "Command apaan tuh? Harus ada 'cd /etc/pterodactyl' nya."
    fi
    sleep 2
}

feature_create_node() {
    header
    echo -e "${YELLOW}--- [ AUTO CREATE NODE ] ---${NC}"
    
    # Input Data
    input_tag "Nama Lokasi (ex: Indo): "; read LOC_NAME
    input_tag "Nama Node (ex: Node-01): "; read NODE_NAME
    input_tag "Domain (ex: panel.ku.com): "; read DOMAIN
    input_tag "RAM (MB): "; read RAM
    input_tag "Disk (MB): "; read DISK
    
    cd /var/www/pterodactyl || return

    info "Membuat lokasi..."
    php artisan p:location:make <<EOF
$LOC_NAME
Lokasi dibuat oleh installer Liwirya
EOF

    LOC_ID=$(php artisan p:location:list | grep "$LOC_NAME" | awk '{print $2}' | tail -n 1 | tr -d '|')

    if [ -z "$LOC_ID" ]; then
        warn "Gagal detect ID lokasi otomatis. Masukin manual aja."
        input_tag "ID Lokasi: "; read LOC_ID
    fi

    info "Membuat node..."
    php artisan p:node:make <<EOF
$NODE_NAME
Auto Created Node
$LOC_ID
https
$DOMAIN
yes
no
no
$RAM
$RAM
$DISK
$DISK
100
8080
2022
/var/lib/pterodactyl/volumes
EOF

    success "Node & Lokasi berhasil dibuat!"
    read -p "Tekan Enter buat balik..."
}

feature_nuke_panel() {
    header
    echo -e "${RED}${BOLD}⚠️  DANGER ZONE: HAPUS PANEL ⚠️${NC}"
    echo "Ini bakal ngehapus Pterodactyl SAMPE KE AKARNYA."
    echo "Data ilang gak bisa balik. Jangan nangis."
    
    input_tag "Ketik 'HANCURKAN' kalau lu beneran nekat: "
    read CONFIRM
    
    if [ "$CONFIRM" == "HANCURKAN" ]; then
        info "Oke, lu yang minta..."
        bash <(curl -s https://pterodactyl-installer.se) <<EOF
y
y
y
y
EOF
        success "Panel musnah. Server lu kosong sekarang."
    else
        info "Batal. Aman."
    fi
    sleep 2
}

feature_force_admin() {
    header
    echo -e "${PURPLE}--- [ FORCE ADMIN CREATION ] ---${NC}"
    echo "Lupa password? Atau mau ambil alih panel? Sini gua bantuin."
    
    input_tag "Email Baru: "; read EMAIL
    input_tag "Username Baru: "; read USER
    input_tag "Password Baru: "; read PASS
    
    cd /var/www/pterodactyl || return
    
    php artisan p:user:make <<EOF
yes
$EMAIL
$USER
$USER
$USER
$PASS
EOF
    success "Admin baru berhasil dibuat. Login gih."
    sleep 2
}

feature_chpasswd() {
    header
    echo -e "${YELLOW}--- [ GANTI PASSWORD VPS/ROOT ] ---${NC}"
    echo "Masukkan password baru buat user root."
    passwd
    success "Password VPS diganti."
    sleep 2
}

check_root
setup_env
verify_token

while true; do
    header
    echo -e "${WHITE}Selamat datang di tools ini. Gunakan dengan bijak, jangan tolol.${NC}"
    echo -e "${DIM}Support: @mynameisliwirya ${NC}"
    echo -e ""
    echo -e "${CYAN}[1]${NC} Install Theme (Stellar/Billing/Enigma)"
    echo -e "${CYAN}[2]${NC} Uninstall Theme / Repair Panel"
    echo -e "${CYAN}[3]${NC} Configure Wings (Auto-Link)"
    echo -e "${CYAN}[4]${NC} Create Node & Location"
    echo -e "${CYAN}[5]${NC} ${RED}Uninstall Panel (Delete All)${NC}"
    echo -e "${CYAN}[6]${NC} Force Create Admin (Hack Back)"
    echo -e "${CYAN}[7]${NC} Ubah Password VPS"
    echo -e "${CYAN}[x]${NC} Exit / Keluar"
    echo -e ""
    input_tag "Pilih menu (1-7): "
    read MENU

    case $MENU in
        1) feature_install_theme ;;
        2) feature_repair_panel ;;
        3) feature_config_wings ;;
        4) feature_create_node ;;
        5) feature_nuke_panel ;;
        6) feature_force_admin ;;
        7) feature_chpasswd ;;
        x) 
           echo -e "${GREEN}Cabut dulu bro. Jangan lupa ngopi.${NC}"
           exit 0 
           ;;
        *) 
           error "Pilihan lu gak ada di menu, kocak."
           sleep 1 
           ;;
    esac
done
