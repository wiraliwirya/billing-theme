#!/bin/bash

BOLD='\033[1m'
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

header() {
    clear
    echo -e "${CYAN}"
    echo -e " ╔════════════════════════════════════════════════════════════╗"
    echo -e " ║       🦅 PTERODACTYL REPAIR TOOL BY LIWIRYA 🦅           ║"
    echo -e " ╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

info() { echo -e "${CYAN}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[DONE]${NC} $1"; }
error() { echo -e "${RED}[FAIL]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

if [[ $EUID -ne 0 ]]; then
    error "Pake user ROOT (sudo) woy! Lu mau benerin server apa main kelereng?"
    exit 1
fi

repair_panel() {
    header
    echo -e "${YELLOW}Proses ini bakal ngehapus SEMUA perubahan UI/Theme.${NC}"
    echo -e "${YELLOW}Panel bakal balik ke tampilan original (bawaan pabrik).${NC}"
    echo
    
    if [ -d "/var/www/pterodactyl" ]; then
        cd /var/www/pterodactyl
        info "Masuk direktori panel..."
    else
        error "Folder panel gak ketemu. Lu install di planet mana?"
        exit 1
    fi

    info "Matiin panel bentar (Maintenance Mode)..."
    php artisan down

    info "Download file original Pterodactyl..."
    curl -L https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz -o panel.tar.gz

    if [ ! -f "panel.tar.gz" ]; then
        error "Download gagal! Internet lu bapuk atau GitHub lagi down."
        echo "Batal repair biar panel lu gak makin ancur."
        php artisan up
        exit 1
    fi

    info "Hapus theme sampah lu & timpa file asli..."
    rm -rf resources
    tar -xzvf panel.tar.gz --overwrite > /dev/null 2>&1
    
    info "Setel permission folder..."
    chmod -R 755 storage/* bootstrap/cache

    info "Install ulang dependencies (Sabar, ini lama kayak nunggu dia peka)..."
    composer install --no-dev --optimize-autoloader --no-interaction

    info "Bersihin cache & update database..."
    php artisan view:clear
    php artisan config:clear
    php artisan migrate --seed --force

    info "Balikin kepemilikan file ke www-data..."
    chown -R www-data:www-data /var/www/pterodactyl/*

    info "Restart worker queue..."
    php artisan queue:restart

    info "Nyalahin panel lagi..."
    php artisan up
    
    rm -f panel.tar.gz

    echo
    success "Panel udah bersih! Balik ke default."
    echo -e "${CYAN}Credits: Liwirya (Yang nyelamatin pantat lu).${NC}"
    exit 0
}

header
echo -e "${RED}${BOLD}⚠️  PERINGATAN KERAS ⚠️${NC}"
echo "Script ini bakal ngehapus Theme lu dan balikin ke Default."
echo "Kalau lu salah pencet, jangan nangis."
echo

while true; do
    echo -ne "${WHITE}[INPUT]${NC} Yakin mau uninstall theme/repair panel? (y/n): "
    read yn
    case $yn in
        [Yy]* ) 
            repair_panel
            break
            ;;
        [Nn]* ) 
            echo -e "${GREEN}Batal. Panel lu aman (masih jelek, tapi aman).${NC}"
            exit 0
            ;;
        * ) 
            echo -e "${RED}Jawab 'y' atau 'n' doang susah amat.${NC}"
            ;;
    esac
done