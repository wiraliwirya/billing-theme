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
    echo -e " ║       🦅 PTERODACTYL CREATE NODE BY LIWIRYA 🦅             ║"
    echo -e " ╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

info() { echo -e "${CYAN}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[DONE]${NC} $1"; }
error() { echo -e "${RED}[FAIL]${NC} $1"; }
input_tag() { echo -ne "${WHITE}[INPUT]${NC} $1"; }

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "Woy! Jalanin pake ROOT (sudo). Lu mau bikin node pake doa?"
        exit 1
    fi
}

check_dir() {
    if [ -d "/var/www/pterodactyl" ]; then
        cd /var/www/pterodactyl
        info "Direktori Pterodactyl ketemu. Lanjut..."
    else
        error "Folder /var/www/pterodactyl GAK ADA! Lu salah server apa gimana?"
        exit 1
    fi
}

setup_location() {
    header
    echo -e "${YELLOW}--- [ STEP 1: LOKASI SERVER ] ---${NC}"
    echo "Lu mau bikin lokasi baru atau udah ada ID Lokasi-nya?"
    echo "1) Bikin Lokasi Baru"
    echo "2) Skip (Gua udah punya ID Lokasi)"
    
    while true; do
        input_tag "Pilih (1/2): "
        read LOC_CHOICE
        case $LOC_CHOICE in
            1)
                echo
                input_tag "Kode Lokasi (Short Code, ex: US, ID, SG): "
                read LOC_SHORT
                input_tag "Deskripsi Lokasi (ex: Server Jakarta): "
                read LOC_DESC
                
                info "Membuat lokasi baru..."
                php artisan p:location:make <<EOF
$LOC_SHORT
$LOC_DESC
EOF
                success "Lokasi dibuat. CEK OUTPUT DI ATAS, CARI 'ID' LOKASINYA!"
                echo -e "${YELLOW}CATET ID LOKASI YANG BARUSAN MUNCUL! JANGAN PIKUN!${NC}"
                echo
                break
                ;;
            2)
                info "Oke, skip pembuatan lokasi."
                break
                ;;
            *)
                error "Pilih 1 atau 2 anjir. Susah amat."
                ;;
        esac
    done
}

get_node_data() {
    echo -e "${YELLOW}--- [ STEP 2: CONFIG NODE ] ---${NC}"
    echo -e "Isi data node dengan teliti. Salah input = Node Gagal.\n"

    while true; do
        input_tag "Masukkan ID LOKASI (Angka): "
        read LOC_ID
        if [[ "$LOC_ID" =~ ^[0-9]+$ ]]; then
            break
        else
            error "ID Lokasi harus angka woy!"
        fi
    done

    input_tag "Nama Node (ex: Node-01): "
    read NODE_NAME
    [ -z "$NODE_NAME" ] && NODE_NAME="Node-Liwirya"

    while true; do
        input_tag "Domain / FQDN (ex: node.domain.com): "
        read DOMAIN
        if [[ "$DOMAIN" =~ \. ]]; then
            break
        else
            error "Domain gak valid. Harus ada titiknya (ex: panel.x.com)."
        fi
    done

    while true; do
        input_tag "RAM (MB) (ex: 16000): "
        read RAM
        if [[ "$RAM" =~ ^[0-9]+$ ]]; then
            break
        else
            error "RAM harus angka (Megabyte)!"
        fi
    done

    while true; do
        input_tag "Disk Space (MB) (ex: 50000): "
        read DISK
        if [[ "$DISK" =~ ^[0-9]+$ ]]; then
            break
        else
            error "Disk harus angka (Megabyte)!"
        fi
    done

    echo -e "${YELLOW}--- [ STEP 3: PORT SETUP ] ---${NC}"
    input_tag "Daemon Port (Default: 8080): "
    read DAEMON_PORT
    [ -z "$DAEMON_PORT" ] && DAEMON_PORT=8080

    input_tag "SFTP Port (Default: 2022): "
    read SFTP_PORT
    [ -z "$SFTP_PORT" ] && SFTP_PORT=2022
}

create_node() {
    header
    echo -e "${YELLOW}--- [ REVIEW DATA ] ---${NC}"
    echo -e "Nama Node : $NODE_NAME"
    echo -e "Domain    : $DOMAIN"
    echo -e "RAM       : $RAM MB"
    echo -e "Disk      : $DISK MB"
    echo -e "Loc ID    : $LOC_ID"
    echo -e "Ports     : $DAEMON_PORT (Daemon) / $SFTP_PORT (SFTP)"
    echo
    input_tag "Yakin mau hajar? (y/n): "
    read CONFIRM
    if [[ "$CONFIRM" != "y" ]]; then
        error "Dibatalkan. Dasar plin-plan."
        exit 1
    fi

    info "Sedang membuat node... Tunggu bentar."

    php artisan p:node:make <<EOF
$NODE_NAME
Node Created by Liwirya Script
$LOC_ID
$DOMAIN
yes
no
no
$RAM
0
$DISK
0
100
$DAEMON_PORT
$SFTP_PORT
/var/lib/pterodactyl/volumes
EOF

    if [ $? -eq 0 ]; then
        success "Node berhasil dibuat!"
        echo -e "${YELLOW}NOTE:${NC} Jangan lupa konfigurasi Wings di server node lu pake token yang ada di panel."
    else
        error "Gagal membuat node. Cek error log di atas."
    fi
}

check_root
check_dir
setup_location
get_node_data
create_node

echo
echo -e "${CYAN}Credits: Code dibuat sama Liwirya. Jangan lupa ngopi. 🦅${NC}"