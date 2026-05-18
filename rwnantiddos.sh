#!/bin/bash

# ==============================================================================
# Remnanode Interactive Protection & Tuning Script (Menu Edition v4)
# ==============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

LOG_FILE="/tmp/remnanode_install.log"

# ЖЕСТКАЯ ПРОВЕРКА НА ROOT / SUDO
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}ОШИБКА: Запустите скрипт через sudo! / Please run as root!${NC}"
  exit 1
fi

USER_IP=$(curl -s ifconfig.me)
USER_ASN=$(curl -s ipinfo.io/org)
if [ -z "$USER_ASN" ]; then USER_ASN="Unknown ASN"; fi

# Массивы стран
COUNTRY_CODES=("CN" "IN" "BR" "PK" "VN" "TW" "BD" "ID" "IR" "ZA" "MX" "EC")
COUNTRY_EN=("China" "India" "Brazil" "Pakistan" "Vietnam" "Taiwan" "Bangladesh" "Indonesia" "Iran" "South Africa" "Mexico" "Ecuador")
COUNTRY_RU=("Китай" "Индия" "Бразилия" "Пакистан" "Вьетнам" "Тайвань" "Бангладеш" "Индонезия" "Иран" "Южная Африка" "Мексика" "Эквадор")

# ==================== ВЫБОР ЯЗЫКА ====================
clear
echo -e "${BLUE}${BOLD}====================================================${NC}"
echo -e "1) English"
echo -e "2) Русский"
echo -n -e "${YELLOW}Select language / Выберите язык [1/2]: ${NC}"
read LANG_CHOICE

if [[ "$LANG_CHOICE" == "2" ]]; then
    M_TITLE="МЕНЮ НАСТРОЙКИ ЗАЩИТЫ REMNANODE"
    M_IP="Ваш IP:"
    M_ASN="Провайдер:"
    M_OPT_1="1. Настроить сетевой экран (UFW)"
    M_OPT_2="2. Установить защиту от сканеров (Traffic-Guard)"
    M_OPT_3="3. Установить CrowdSec (Защита от брутфорса)"
    M_OPT_4="4. Настроить Гео-блокировку DDoS"
    M_OPT_5="5. Оптимизация сети (Отключить IPv6, BBR+CAKE)"
    M_OPT_6="6. Запустить Speedtest"
    M_OPT_7="7. Проверить геобазы (IP Region)"
    M_OPT_0="0. Выход"
    M_CHOOSE="Выберите действие"
    
    P_SSH="Введите ваш текущий SSH порт (например, 22): "
    P_VPN="Введите порт вашего VPN/VLESS: "
    P_TG_SSH="ВАЖНО: Введите ваш SSH порт, чтобы Traffic-Guard не заблокировал вас: "
    P_GEO_INFO="Введите номера стран через пробел (например: 1 3 5) или 'all': "
    P_GEO_SKIP="Страны не выбраны, пропускаем."
    
    S_SPIN="Выполнение задачи"
    S_ERR="[ОШИБКА] Процесс завершился с кодом"
    S_LOG="Вывод последних 50 строк лога"
    S_OK="[УСПЕШНО] Операция выполнена!"
    S_ENTER="Нажмите Enter для продолжения..."
    S_SPEED="Результаты Speedtest"
    S_GEO_CHECK="Проверка по геобазам"
else
    M_TITLE="REMNANODE SECURITY SETUP MENU"
    M_IP="Your IP:"
    M_ASN="ASN:"
    M_OPT_1="1. Setup Firewall (UFW)"
    M_OPT_2="2. Install Anti-scanner (Traffic-Guard)"
    M_OPT_3="3. Install CrowdSec (Brute-force protection)"
    M_OPT_4="4. Setup Geo-blocking for DDoS"
    M_OPT_5="5. Network Tuning (Disable IPv6, BBR+CAKE)"
    M_OPT_6="6. Run Speedtest"
    M_OPT_7="7. Check Geo-databases (IP Region)"
    M_OPT_0="0. Exit"
    M_CHOOSE="Select an option"
    
    P_SSH="Enter your current SSH port (e.g., 22): "
    P_VPN="Enter your VPN/VLESS port: "
    P_TG_SSH="CRITICAL: Enter your SSH port so Traffic-Guard doesn't lock you out: "
    P_GEO_INFO="Enter country numbers separated by space (e.g., 1 3 5) or 'all': "
    P_GEO_SKIP="No countries selected, skipping."
    
    S_SPIN="Executing task"
    S_ERR="[ERROR] Process failed with exit code"
    S_LOG="Last 50 lines of the log"
    S_OK="[SUCCESS] Operation completed!"
    S_ENTER="Press Enter to continue..."
    S_SPEED="Speedtest Results"
    S_GEO_CHECK="Geo-database Check"
fi

# Предварительная установка
apt update -q >/dev/null 2>&1
apt install -yq ufw curl wget ipset iptables speedtest-cli >/dev/null 2>&1

# ==========================================
# Анимация Звезды
# ==========================================
spin_david_star() {
    local pid=$1
    local delay=0.15
    tput civis
    echo -e "\n\n\n\n\n\n\n"
    
    while kill -0 $pid 2>/dev/null; do
        tput cuu 7
        echo -e "${BLUE}       /\\       ${NC}"
        echo -e "${BLUE}    __/  \\__    ${NC}"
        echo -e "${BLUE}    \\  |   /    ${NC}"
        echo -e "${BLUE}    /_ |  _\\    ${NC}"
        echo -e "${BLUE}      \\  /      ${NC}"
        echo -e "${BLUE}       \\/       ${NC}"
        echo -e "${YELLOW} ${S_SPIN}...   ${NC}"
        sleep $delay
        
        tput cuu 7
        echo -e "${BLUE}       /\\       ${NC}"
        echo -e "${BLUE}    __/ / \\__   ${NC}"
        echo -e "${BLUE}    \\    / /    ${NC}"
        echo -e "${BLUE}    /_ /  _\\    ${NC}"
        echo -e "${BLUE}      \\  /      ${NC}"
        echo -e "${BLUE}       \\/       ${NC}"
        echo -e "${YELLOW} ${S_SPIN}..    ${NC}"
        sleep $delay
        
        tput cuu 7
        echo -e "${BLUE}       /\\       ${NC}"
        echo -e "${BLUE}    __/   \\__   ${NC}"
        echo -e "${BLUE}    \\ ---  /    ${NC}"
        echo -e "${BLUE}    /_   _\\     ${NC}"
        echo -e "${BLUE}      \\  /      ${NC}"
        echo -e "${BLUE}       \\/       ${NC}"
        echo -e "${YELLOW} ${S_SPIN}.     ${NC}"
        sleep $delay
        
        tput cuu 7
        echo -e "${BLUE}       /\\       ${NC}"
        echo -e "${BLUE}    __\\   \\__   ${NC}"
        echo -e "${BLUE}    \\  \\   /    ${NC}"
        echo -e "${BLUE}    /_  \\ _\\    ${NC}"
        echo -e "${BLUE}      \\  /      ${NC}"
        echo -e "${BLUE}       \\/       ${NC}"
        echo -e "${YELLOW} ${S_SPIN}      ${NC}"
        sleep $delay
    done
    tput cnorm
}

run_with_loader() {
    local cmd="$1"
    > "$LOG_FILE"
    
    eval "$cmd" > "$LOG_FILE" 2>&1 &
    local cmd_pid=$!
    
    spin_david_star $cmd_pid
    wait $cmd_pid
    local exit_status=$?
    
    if [ $exit_status -ne 0 ]; then
        echo -e "\n${RED}${S_ERR}: $exit_status${NC}"
        echo -e "${YELLOW}--- ${S_LOG} ---${NC}"
        tail -n 50 "$LOG_FILE"
        echo -e "${YELLOW}-------------------------------------${NC}"
        read -p "${S_ENTER}"
        return 1
    else
        echo -e "\n${GREEN}${S_OK}${NC}"
        sleep 1
        return 0
    fi
}

# ==========================================
# Рабочие функции
# ==========================================
setup_ufw() {
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow $1/tcp comment 'SSH'
    ufw allow 80/tcp comment 'HTTP'
    ufw allow 443/tcp comment 'HTTPS'
    ufw allow $2 comment 'VPN/Xray'
    ufw --force enable
}

setup_traffic_guard() {
    local ssh_port=$1
    iptables -I INPUT -p tcp --dport $ssh_port -j ACCEPT
    ufw allow $ssh_port/tcp comment 'TG Safe SSH' 2>/dev/null
    
    curl -fsSL https://raw.githubusercontent.com/dotX12/traffic-guard/master/install.sh | bash
    
    # Новая команда Traffic-Guard с двумя листами и логированием
    traffic-guard full \
      -u https://raw.githubusercontent.com/shadow-netlab/traffic-guard-lists/refs/heads/main/public/antiscanner.list \
      -u https://raw.githubusercontent.com/shadow-netlab/traffic-guard-lists/refs/heads/main/public/government_networks.list \
      --enable-logging
}

setup_crowdsec() {
    curl -s https://install.crowdsec.net | bash
    apt-get install -yq crowdsec crowdsec-firewall-bouncer-iptables
    systemctl enable crowdsec
    systemctl start crowdsec
}

setup_geoblock() {
    local user_ip=$1
    shift
    local countries=("$@")

    ipset create geo_block hash:net maxelem 500000 -exist
    ipset flush geo_block
    iptables -I INPUT -s $user_ip -j ACCEPT

    for code in "${countries[@]}"; do
        curl -s "https://www.ipdeny.com/ipblocks/data/countries/$(echo $code | tr '[:upper:]' '[:lower:]').zone" | while read ip; do
            ipset add geo_block $ip -exist
        done
    done

    iptables -D INPUT -m set --match-set geo_block src -j DROP 2>/dev/null
    iptables -I INPUT -m set --match-set geo_block src -j DROP
}

setup_network() {
    sed -i '/disable_ipv6/d' /etc/sysctl.conf
    sed -i '/default_qdisc/d' /etc/sysctl.conf
    sed -i '/tcp_congestion_control/d' /etc/sysctl.conf

    cat >> /etc/sysctl.conf << EOF
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
net.core.default_qdisc = cake
net.ipv4.tcp_congestion_control = bbr
EOF
    sysctl -p
}

# ==========================================
# Главное меню
# ==========================================
while true; do
    clear
    echo -e "${BLUE}${BOLD}====================================================${NC}"
    echo -e "${BLUE}${BOLD}   ${M_TITLE}                                 ${NC}"
    echo -e "${BLUE}${BOLD}   ${M_IP} ${USER_IP}                               ${NC}"
    echo -e "${BLUE}${BOLD}   ${M_ASN} ${USER_ASN}                              ${NC}"
    echo -e "${BLUE}${BOLD}====================================================${NC}"
    echo "$M_OPT_1"
    echo "$M_OPT_2"
    echo "$M_OPT_3"
    echo "$M_OPT_4"
    echo "$M_OPT_5"
    echo "$M_OPT_6"
    echo "$M_OPT_7"
    echo "$M_OPT_0"
    echo -e "${BLUE}${BOLD}====================================================${NC}"
    read -p "${M_CHOOSE} [0-7]: " choice
    
    case $choice in
        1)
            echo -n -e "${YELLOW}${P_SSH}${NC}"
            read SSH_PORT
            echo -n -e "${YELLOW}${P_VPN}${NC}"
            read VPN_PORT
            run_with_loader "setup_ufw $SSH_PORT $VPN_PORT"
            ;;
        2)
            echo -n -e "${RED}${BOLD}${P_TG_SSH}${NC}"
            read TG_SSH_PORT
            if [ -z "$TG_SSH_PORT" ]; then TG_SSH_PORT=22; fi
            run_with_loader "setup_traffic_guard $TG_SSH_PORT"
            ;;
        3)
            run_with_loader "setup_crowdsec"
            ;;
        4)
            echo -e "\n${BOLD}Available countries / Доступные страны:${NC}"
            for i in "${!COUNTRY_CODES[@]}"; do
                num=$((i+1))
                if [[ "$LANG_CHOICE" == "2" ]]; then
                    echo -e "  ${BOLD}${num})${NC} ${COUNTRY_CODES[$i]} - ${COUNTRY_RU[$i]}"
                else
                    echo -e "  ${BOLD}${num})${NC} ${COUNTRY_CODES[$i]} - ${COUNTRY_EN[$i]}"
                fi
            done
            
            echo -e "${YELLOW}${P_GEO_INFO}${NC}"
            read GEO_CHOICE

            SELECTED_CODES=()
            if [[ "$GEO_CHOICE" == "all" || "$GEO_CHOICE" == "ALL" ]]; then
                SELECTED_CODES=("${COUNTRY_CODES[@]}")
            else
                for num in $GEO_CHOICE; do
                    index=$((num-1))
                    if [[ $index -ge 0 && $index -lt ${#COUNTRY_CODES[@]} ]]; then
                        SELECTED_CODES+=("${COUNTRY_CODES[$index]}")
                    fi
                done
            fi

            if [ ${#SELECTED_CODES[@]} -gt 0 ]; then
                run_with_loader "setup_geoblock $USER_IP ${SELECTED_CODES[*]}"
            else
                echo -e "${RED}${P_GEO_SKIP}${NC}"
                sleep 1
            fi
            ;;
        5)
            run_with_loader "setup_network"
            ;;
        6)
            run_with_loader "speedtest-cli --simple"
            if [ $? -eq 0 ]; then
                echo -e "\n${BLUE}--- ${S_SPEED} ---${NC}"
                cat "$LOG_FILE"
                echo -e "${BLUE}----------------------------${NC}"
                read -p "${S_ENTER}"
            fi
            ;;
        7)
            echo -e "\n${BLUE}--- ${S_GEO_CHECK} ---${NC}"
            bash <(wget -qO- https://ipregion.vrnt.xyz)
            echo -e "${BLUE}----------------------------${NC}"
            read -p "${S_ENTER}"
            ;;
        0)
            exit 0
            ;;
        *)
            sleep 1
            ;;
    esac
done
