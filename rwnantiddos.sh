#!/bin/bash

# ==============================================================================
# Remnanode Interactive Protection & Tuning Script (Menu Edition v10 - Final)
# Supports: Debian 11/12/13, Ubuntu 22.04/24.04
# ==============================================================================

# ПРИНУДИТЕЛЬНЫЙ ЗАХВАТ ТЕРМИНАЛА (Защита от бага при curl | bash)
if [ ! -t 0 ]; then
    exec < /dev/tty
fi

# ПРОТИВОАВАРИЙНАЯ ПРОВЕРКА ОБОЛОЧКИ
if [ -z "$BASH_VERSION" ]; then
    echo "ОШИБКА: Скрипт необходимо запускать через bash, а не sh!"
    echo "Используйте: bash script.sh (или ./script.sh)"
    exit 1
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

LOG_FILE="/tmp/remnanode_install.log"

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

if ! read LANG_CHOICE; then
    echo -e "\n${RED}Ошибка ввода. Выход...${NC}"
    exit 1
fi

if [[ "$LANG_CHOICE" == "2" ]]; then
    M_TITLE="МЕНЮ НАСТРОЙКИ ЗАЩИТЫ REMNANODE"
    M_IP="Ваш IP:"
    M_ASN="Провайдер:"
    
    M_OPT_1="1. [ШАГ 1] Продвинутый тюнинг (Ядро XanMod, BBRv3, Nftables) [⚠️ РЕБУТ]"
    M_OPT_2="2. [ШАГ 1.АЛЬТЕРНАТИВА] Базовый тюнинг сети (Без смены ядра: IPv6 OFF, BBR+CAKE)"
    M_OPT_3="3. [ШАГ 2] Настроить сетевой экран (UFW + Авто-Домен + Блок 25)"
    M_OPT_4="4. [ШАГ 3] Установить защиту от сканеров (Traffic-Guard)"
    M_OPT_5="5. [ШАГ 4] Настроить Гео-блокировку DDoS (ipset)"
    M_OPT_6="6. [ШАГ 5] Установить Fail2Ban (Защита SSH через UFW)"
    M_OPT_7="7. [ШАГ 6] Установить CrowdSec (Сетевой IPS)"
    M_OPT_8="8. [ДИАГНОСТИКА] Запустить Speedtest"
    M_OPT_9="9. [ДИАГНОСТИКА] Проверить геобазы (IP Region)"
    M_OPT_0="0. Выход"
    M_CHOOSE="Выберите действие"
    
    P_SSH="Введите ваш текущий SSH порт (например, 22): "
    P_VPN="Введите порт вашего VPN/VLESS: "
    P_PANEL="Введите IP или ДОМЕН вашей панели (или Enter для пропуска): "
    P_TG_SSH="ВАЖНО: Введите ваш SSH порт, чтобы Traffic-Guard не заблокировал вас: "
    P_GEO_INFO="Введите номера стран через пробел (например: 1 3 5) или 'all': "
    P_GEO_SKIP="Страны не выбраны, пропускаем."
    
    W_XAN_TITLE="⚠️ ВНИМАНИЕ / WARNING ⚠️"
    W_XAN_TEXT="Эта operation заменит стандартное ядро Linux на кастомное ядро XanMod (с поддержкой BBRv3), перенастроит sysctl и развернет правила nftables (MSS Clamping).\nВАЖНО: Выполнение этого шага сбросит (flush) текущие правила файрвола, поэтому его делают ПЕРВЫМ.\n\nВы уверены, что хотите продолжить? [y/n]: "
    W_XAN_REBOOT="⚠️ Скрипт отработал. Для активации нового ядра XanMod и BBRv3 ОБЯЗАТЕЛЬНО перезагрузите сервер командой: sudo reboot"
    
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
    
    M_OPT_1="1. [STEP 1] Advanced Tuning (XanMod Kernel, BBRv3, Nftables) [⚠️ REBOOT]"
    M_OPT_2="2. [STEP 1.ALT] Basic Network Tuning (No kernel change: IPv6 OFF, BBR+CAKE)"
    M_OPT_3="3. [STEP 2] Setup Firewall (UFW + Auto-Domain + Block 25)"
    M_OPT_4="4. [STEP 3] Install Anti-scanner (Traffic-Guard)"
    M_OPT_5="5. [STEP 4] Setup Geo-blocking for DDoS (ipset)"
    M_OPT_6="6. [STEP 5] Install Fail2Ban (SSH Protection via UFW)"
    M_OPT_7="7. [STEP 6] Install CrowdSec (Network IPS)"
    M_OPT_8="8. [DIAGNOSTICS] Run Speedtest"
    M_OPT_9="9. [DIAGNOSTICS] Check Geo-databases (IP Region)"
    M_OPT_0="0. Exit"
    M_CHOOSE="Select an option"
    
    P_SSH="Enter your current SSH port (e.g., 22): "
    P_VPN="Enter your VPN/VLESS port: "
    P_PANEL="Enter your Panel IP or DOMAIN (or press Enter to skip): "
    P_TG_SSH="CRITICAL: Enter your SSH port so Traffic-Guard doesn't lock you out: "
    P_GEO_INFO="Enter country numbers separated by space (e.g., 1 3 5) or 'all': "
    P_GEO_SKIP="No countries selected, skipping."
    
    W_XAN_TITLE="⚠️ WARNING / ВНИМАНИЕ ⚠️"
    W_XAN_TEXT="This operation will replace your stock Linux kernel with custom XanMod kernel (enabling BBRv3), tune sysctl, and deploy nftables (MSS Clamping).\nCRITICAL: Running this step will FLUSH current firewall rules, which is why it must be executed FIRST.\n\nAre you sure you want to proceed? [y/n]: "
    W_XAN_REBOOT="⚠️ Task finished. To activate the new XanMod kernel and BBRv3, you MUST reboot the server using: sudo reboot"
    
    S_SPIN="Executing task"
    S_ERR="[ERROR] Process failed with exit code"
    S_LOG="Last 50 lines of the log"
    S_OK="[SUCCESS] Operation completed!"
    S_ENTER="Press Enter to continue..."
    S_SPEED="Speedtest Results"
    S_GEO_CHECK="Geo-database Check"
fi

# Предварительная установка базовых утилит
apt update -q >/dev/null 2>&1
apt install -yq ufw curl wget ipset iptables speedtest-cli cron >/dev/null 2>&1

# ==========================================
# Анимация Звезды Давида
# ==========================================
spin_david_star() {
    local pid=$1
    local delay=0.15
    tput civis
    echo -e "\n\n\n\n\n\n\n"
    
    while kill -0 $pid 2>/dev/null; do
        tput cuu 7
        echo -e "${BLUE}        /\\        ${NC}"
        echo -e "${BLUE}     __/  \\__     ${NC}"
        echo -e "${BLUE}     \\  |   /     ${NC}"
        echo -e "${BLUE}     /_ |  _\\     ${NC}"
        echo -e "${BLUE}       \\  /       ${NC}"
        echo -e "${BLUE}        \\/        ${NC}"
        echo -e "${YELLOW} ${S_SPIN}...   ${NC}"
        sleep $delay
        
        tput cuu 7
        echo -e "${BLUE}        /\\        ${NC}"
        echo -e "${BLUE}     __/ / \\__    ${NC}"
        echo -e "${BLUE}     \\    / /     ${NC}"
        echo -e "${BLUE}     /_ /  _\\     ${NC}"
        echo -e "${BLUE}       \\  /       ${NC}"
        echo -e "${BLUE}        \\/        ${NC}"
        echo -e "${YELLOW} ${S_SPIN}..    ${NC}"
        sleep $delay
        
        tput cuu 7
        echo -e "${BLUE}        /\\        ${NC}"
        echo -e "${BLUE}     __/   \\__    ${NC}"
        echo -e "${BLUE}     \\ ---  /     ${NC}"
        echo -e "${BLUE}     /_   _\\      ${NC}"
        echo -e "${BLUE}       \\  /       ${NC}"
        echo -e "${BLUE}        \\/        ${NC}"
        echo -e "${YELLOW} ${S_SPIN}.     ${NC}"
        sleep $delay
        
        tput cuu 7
        echo -e "${BLUE}        /\\        ${NC}"
        echo -e "${BLUE}     __\\   \\__    ${NC}"
        echo -e "${BLUE}     \\  \\   /     ${NC}"
        echo -e "${BLUE}     /_  \\ _\\     ${NC}"
        echo -e "${BLUE}       \\  /       ${NC}"
        echo -e "${BLUE}        \\/        ${NC}"
        echo -e "${YELLOW} ${S_SPIN}       ${NC}"
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
# Рабочие функции (Бизнес-логика)
# ==========================================
setup_xanmod_bbr3() {
    export DEBIAN_FRONTEND=noninteractive
    apt-get update && apt-get install -y wget gpg ca-certificates lsb-release
    
    mkdir -p /etc/apt/sources.list.d
    rm -f /etc/apt/sources.list.distrib.d/xanmod.list 2>/dev/null
    
    wget -qO - https://dl.xanmod.org/archive.key | gpg --dearmor -o /usr/share/keyrings/xanmod-archive-keyring.gpg --yes
    echo 'deb [signed-by=/usr/share/keyrings/xanmod-archive-keyring.gpg] http://dl.xanmod.org/repository debian main' | tee /etc/apt/sources.list.d/xanmod.list
    apt-get update
    apt-get install -yq linux-image-xanmod-edge linux-headers-xanmod-edge

    local sysctl_conf="/etc/sysctl.d/99-network-optimization.conf"
    cat << 'EOF' > $sysctl_conf
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_fastopen = 3
net.netfilter.nf_conntrack_max = 2000000
net.netfilter.nf_conntrack_tcp_timeout_established = 7200
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 60
net.netfilter.nf_conntrack_tcp_timeout_close_wait = 30
net.netfilter.nf_conntrack_tcp_timeout_fin_wait = 30
EOF
    modprobe nf_conntrack 2>/dev/null
    sysctl --system

    apt-get install -y nftables
    systemctl enable nftables

    local interface=$(ip route | grep default | awk '{print $5}' | head -n1)
    if [ -z "$interface" ]; then
        interface=$(ip -o link show | awk -F': ' '{print $2}' | grep -v lo | head -n1)
    fi
    if [ -z "$interface" ]; then interface="eth0"; fi

    local nft_conf="/etc/nftables.conf"
    cat << EOF > $nft_conf
#!/usr/sbin/nft -f

flush ruleset

table inet filter {
    counter tier_high { comment "VIP Traffic" }
    counter tier_normal { comment "Standard Traffic" }

    chain input {
        type filter hook input priority filter; policy accept;
        tcp dport { 22, 80, 443 } ct state established ct timeout set 14400 counter name tier_high
        counter name tier_normal
    }

    chain forward {
        type filter hook forward priority filter; policy accept;
        oifname "$interface" tcp flags syn tcp option maxseg size set rt mtu
    }

    chain output {
        type filter hook output priority filter; policy accept;
    }
}
EOF
    systemctl restart nftables
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

setup_ufw() {
    local ssh_port=$1
    local vpn_port=$2
    local panel_input=$3

    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing

    ufw allow $ssh_port/tcp comment 'SSH'
    ufw allow 80/tcp comment 'HTTP'
    ufw allow 443/tcp comment 'HTTPS'
    ufw allow $vpn_port comment 'VPN/Xray'

    if [ -n "$panel_input" ]; then
        if [[ $panel_input =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            ufw allow from "$panel_input" to any port $vpn_port proto tcp comment 'Panel_IP'
        else
            apt-get install -yq dnsutils >/dev/null 2>&1
            local panel_ip=$(dig +short A "$panel_input" | grep -E '^[0-9.]+$' | head -n 1)
            if [ -z "$panel_ip" ]; then
                panel_ip=$(nslookup "$panel_input" 2>/dev/null | awk '/^Address: / { print $2 }' | head -n 1)
            fi
            
            if [ -n "$panel_ip" ]; then
                ufw allow from "$panel_ip" to any port $vpn_port proto tcp comment 'Panel_IP'
                
                cat > /usr/local/bin/remnanode_ufw_updater.sh <<EOF
#!/bash
DOMAIN="$panel_input"
PORT="$vpn_port"
OLD_IP_FILE="/var/run/remnanode_panel_ip.txt"
OLD_IP=\$(cat \$OLD_IP_FILE 2>/dev/null)
NEW_IP=\$(dig +short A "\$DOMAIN" | grep -E '^[0-9.]+$' | head -n 1)
if [ -z "\$NEW_IP" ]; then
    NEW_IP=\$(nslookup "\$DOMAIN" 2>/dev/null | awk '/^Address: / { print \$2 }' | head -n 1)
fi
if [ -n "\$NEW_IP" ] && [ "\$NEW_IP" != "\$OLD_IP" ]; then
    if [ -n "\$OLD_IP" ]; then
        ufw delete allow from \$OLD_IP to any port \$PORT proto tcp 2>/dev/null
    fi
    ufw allow from \$NEW_IP to any port \$PORT proto tcp comment 'Panel_IP'
    echo \$NEW_IP > \$OLD_IP_FILE
    ufw reload
fi
EOF
                chmod +x /usr/local/bin/remnanode_ufw_updater.sh
                echo "$panel_ip" > /var/run/remnanode_panel_ip.txt
                
                crontab -l 2>/dev/null | grep -v "/usr/local/bin/remnanode_ufw_updater.sh" > /tmp/cron_temp
                echo "0 */6 * * * /usr/local/bin/remnanode_ufw_updater.sh >/dev/null 2>&1" >> /tmp/cron_temp
                crontab /tmp/cron_temp
                rm /tmp/cron_temp
                systemctl restart cron 2>/dev/null || systemctl restart crond 2>/dev/null
            fi
        fi
    fi

    for port in 25 465 587 2525 24 387; do
        ufw deny out to any port $port proto tcp comment 'Block_Spam'
    done
    ufw deny out to any port 5060 proto udp comment 'Block_SIP'

    local bad_ips=("34.209.195.255" "3.229.117.57" "52.16.171.153" "3.238.30.69" "34.16.47.102" "44.244.22.128" "3.250.92.156" "3.222.192.211")
    for ip in "${bad_ips[@]}"; do
        ufw deny out from any to $ip comment 'Block_Malicious_IP'
    done

    ufw --force enable
}

setup_traffic_guard() {
    local ssh_port=$1
    iptables -I INPUT -p tcp --dport $ssh_port -j ACCEPT
    ufw allow $ssh_port/tcp comment 'TG Safe SSH' 2>/dev/null
    
    curl -fsSL https://raw.githubusercontent.com/dotX12/traffic-guard/master/install.sh | bash
    traffic-guard full \
      -u https://raw.githubusercontent.com/shadow-netlab/traffic-guard-lists/refs/heads/main/public/antiscanner.list \
      -u https://raw.githubusercontent.com/shadow-netlab/traffic-guard-lists/refs/heads/main/public/government_networks.list \
      --enable-logging
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

setup_fail2ban() {
    local ssh_port=$1
    apt-get install fail2ban -y
    cat > /etc/fail2ban/jail.local <<EOL
[sshd]
enabled   = true
port      = $ssh_port
maxretry  = 5
findtime  = 1h
bantime   = 1d
ignoreip  = 127.0.0.1/8
banaction = ufw
EOL
    systemctl restart fail2ban
    systemctl enable fail2ban
}

setup_crowdsec() {
    curl -s https://install.crowdsec.net | bash
    apt-get install -yq crowdsec crowdsec-firewall-bouncer-iptables
    systemctl enable crowdsec
    systemctl start crowdsec
}

# ==========================================
# Главное меню Цикл
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
    echo "$M_OPT_8"
    echo "$M_OPT_9"
    echo "$M_OPT_0"
    echo -e "${BLUE}${BOLD}====================================================${NC}"
    
    if ! read -p "${M_CHOOSE} [0-9]: " choice; then
        echo -e "\n${RED}Ошибка ввода или обрыв соединения. Выход...${NC}"
        exit 1
    fi
    
    case $choice in
        1)
            clear
            echo -e "${RED}${BOLD}${W_XAN_TITLE}${NC}"
            echo -e "${YELLOW}${W_XAN_TEXT}${NC}"
            read -p "> " XAN_CONFIRM
            if [[ "$XAN_CONFIRM" == "y" || "$XAN_CONFIRM" == "Y" || "$XAN_CONFIRM" == "н" || "$XAN_CONFIRM" == "Н" ]]; then
                run_with_loader "setup_xanmod_bbr3"
                if [ $? -eq 0 ]; then
                    echo -e "\n${RED}${BOLD}${W_XAN_REBOOT}${NC}"
                    read -p "${S_ENTER}"
                fi
            fi
            ;;
        2)
            run_with_loader "setup_network"
            ;;
        3)
            echo -n -e "${YELLOW}${P_SSH}${NC}"
            read SSH_PORT
            if [ -z "$SSH_PORT" ]; then SSH_PORT=22; fi
            echo -n -e "${YELLOW}${P_VPN}${NC}"
            read VPN_PORT
            echo -n -e "${YELLOW}${P_PANEL}${NC}"
            read PANEL_IP
            run_with_loader "setup_ufw $SSH_PORT $VPN_PORT '$PANEL_IP'"
            ;;
        4)
            echo -n -e "${RED}${BOLD}${P_TG_SSH}${NC}"
            read TG_SSH_PORT
            if [ -z "$TG_SSH_PORT" ]; then TG_SSH_PORT=22; fi
            run_with_loader "setup_traffic_guard $TG_SSH_PORT"
            ;;
        5)
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
        6)
            echo -n -e "${YELLOW}${P_SSH}${NC}"
            read F2B_SSH_PORT
            if [ -z "$F2B_SSH_PORT" ]; then F2B_SSH_PORT=22; fi
            run_with_loader "setup_fail2ban $F2B_SSH_PORT"
            ;;
        7)
            run_with_loader "setup_crowdsec"
            ;;
        8)
            run_with_loader "speedtest-cli --simple"
            if [ $? -eq 0 ]; then
                echo -e "\n${BLUE}--- ${S_SPEED} ---${NC}"
                cat "$LOG_FILE"
                echo -e "${BLUE}----------------------------${NC}"
                read -p "${S_ENTER}"
            fi
            ;;
        9)
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
