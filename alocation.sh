#!/bin/bash

# --- [ CONFIG & COLORS ] ---
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
    echo -e " ║     🦅 PTERODACTYL ALLOCATION MANAGER BY LIWIRYA 🦅      ║"
    echo -e " ╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

info() { echo -e "${CYAN}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[DONE]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[FAIL]${NC} $1"; }
input_tag() { echo -ne "${WHITE}[INPUT]${NC} $1"; }

show_spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "Woy! Jalanin pake ROOT (sudo). Lu mau ngedit system file pake user curut?"
        exit 1
    fi
}

check_deps() {
    header
    info "Ngecek barang bawaan..."
    local deps=(curl jq php)
    for cmd in "${deps[@]}"; do
        if ! command -v $cmd &> /dev/null; then
            error "Tools '$cmd' gak ada. Install dulu lah tolol."
            exit 1
        fi
    done
    success "Aman. Semua tools lengkap."
    sleep 1
}

get_input() {
    header
    echo -e "${WHITE}Isi data yang bener. Jangan typo, jari jempol semua lo?${NC}\n"

    while true; do
        input_tag "URL Panel (ex: https://panel.domain.com): "
        read PANEL_URL
        # Validasi regex simpel buat URL
        if [[ $PANEL_URL =~ ^https?:// ]]; then
            # Hapus slash di akhir kalo user iseng nambahin
            PANEL_URL=${PANEL_URL%/}
            break
        else
            error "Format URL salah blok! Harus pake http:// atau https://"
        fi
    done

    while true; do
        input_tag "ID Node (Angka doang): "
        read NODE_ID
        if [[ "$NODE_ID" =~ ^[0-9]+$ ]]; then
            break
        else
            error "ID Node itu angka, bukan huruf! Baca docs gak sih?"
        fi
    done

    while true; do
        input_tag "IP Address (ex: 192.168.1.1): "
        read IP_ADDR
        if [[ $IP_ADDR =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            break
        else
            error "Itu bukan IP Address, itu nomor togel! Masukin IP yang bener."
        fi
    done

    while true; do
        input_tag "List Port (Pisahin pake spasi, ex: 8080 25565): "
        read -a PORTS
        if [[ ${#PORTS[@]} -gt 0 ]]; then
            break
        else
            error "Isi minimal satu port lah, pelit amat."
        fi
    done
}

enter_panel_dir() {
    echo
    info "Masuk ke direktori Pterodactyl..."
    if [ -d "/var/www/pterodactyl" ]; then
        cd /var/www/pterodactyl
    else
        error "Folder /var/www/pterodactyl GAK ADA! Lu install panel dimana woy?"
        exit 1
    fi
}

setup_api() {
    info "Bikin API Key Admin (Temporary)..."
    
    (php artisan p:admin:generate-token --name "Liwirya_Auto_Alloc" > /tmp/liwirya_token.txt) &
    show_spinner $!

    API_KEY=$(grep "Your API Key" /tmp/liwirya_token.txt | awk '{print $4}' | tr -d '[:space:]')
    rm -f /tmp/liwirya_token.txt

    if [[ -z "$API_KEY" || ${#API_KEY} -lt 20 ]]; then
        error "Gagal bikin API Key. Cek error log php artisan lu."
        exit 1
    fi
    
    success "API Key Created: ${API_KEY:0:10}*******************"
}

process_allocations() {
    echo
    info "Mulai nembak API buat nambahin port..."
    
    local success_count=0
    local fail_count=0

    for PORT in "${PORTS[@]}"; do
        if ! [[ "$PORT" =~ ^[0-9]+$ ]]; then
            warn "Skip '$PORT' -> Bukan angka. Mabok lu?"
            ((fail_count++))
            continue
        fi

        RESPONSE=$(curl -s -X POST "$PANEL_URL/api/application/nodes/$NODE_ID/allocations" \
            -H "Authorization: Bearer $API_KEY" \
            -H "Content-Type: application/json" \
            -H "Accept: application/json" \
            -d "{\"ip\": \"$IP_ADDR\", \"ports\": [\"$PORT\"]}")

        if echo "$RESPONSE" | grep -q "\"object\":\"allocation\""; then
            success "Port $PORT -> SUKSES masuk database."
            ((success_count++))
        else
            ERR_MSG=$(echo "$RESPONSE" | jq -r '.errors[0].detail // "Unknown Error"')
            error "Port $PORT -> GAGAL! ($ERR_MSG)"
            ((fail_count++))
        fi
        sleep 0.2
    done

    echo
    info "Rekap: $success_count Sukses, $fail_count Gagal."
}

get_wings() {
    echo
    info "Ngambil Token Wings buat Node $NODE_ID..."
    
    RESPONSE=$(curl -s -X POST "$PANEL_URL/api/application/nodes/$NODE_ID/configuration" \
        -H "Authorization: Bearer $API_KEY" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json")

    TOKEN=$(echo "$RESPONSE" | jq -r '.token // empty')

    if [[ -n "$TOKEN" ]]; then
        echo -e "${YELLOW}╔════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║ WINGS TOKEN (Copas ke config.yml node lu):                 ║${NC}"
        echo -e "${WHITE}$TOKEN${NC}"
        echo -e "${YELLOW}╚════════════════════════════════════════════════════════════╝${NC}"
    else
        error "Gagal ambil token wings. Response API busuk."
        echo "Debug: $RESPONSE"
    fi
}

check_root
check_deps
get_input
enter_panel_dir
setup_api
process_allocations
get_wings

echo
success "Kelarrr bos! Script selesai."
echo -e "${CYAN}Credits: Script dibuat sama Liwirya biar idup lu tenang.${NC}"
exit 0