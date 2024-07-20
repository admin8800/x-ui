#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

#Add some basic function here
function LOGD() {
    echo -e "${yellow}[DEG] $* ${plain}"
}

function LOGE() {
    echo -e "${red}[ERR] $* ${plain}"
}

function LOGI() {
    echo -e "${green}[INF] $* ${plain}"
}
# check root
[[ $EUID -ne 0 ]] && LOGE "ERROR: 您必须是 root 才能运行此脚本！ \n" && exit 1

# Check OS and set release variable
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    release=$ID
elif [[ -f /usr/lib/os-release ]]; then
    source /usr/lib/os-release
    release=$ID
else
    echo "Failed to check the system OS, please contact the author!" >&2
    exit 1
fi

echo "The OS release is: $release"


os_version=""
os_version=$(grep -i version_id /etc/os-release | cut -d \" -f2 | cut -d . -f1)

if [[ "${release}" == "centos" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red} Please use CentOS 8 or higher ${plain}\n" && exit 1
    fi
elif [[ "${release}" ==  "ubuntu" ]]; then
    if [[ ${os_version} -lt 20 ]]; then
        echo -e "${red}please use Ubuntu 20 or higher version! ${plain}\n" && exit 1
    fi

elif [[ "${release}" == "fedora" ]]; then
    if [[ ${os_version} -lt 36 ]]; then
        echo -e "${red}please use Fedora 36 or higher version! ${plain}\n" && exit 1
    fi

elif [[ "${release}" == "debian" ]]; then
    if [[ ${os_version} -lt 10 ]]; then
        echo -e "${red} Please use Debian 10 or higher ${plain}\n" && exit 1
    fi
fi

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -p "$1 [Default$2]: " temp
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -p "$1 [y/n]: " temp
    fi
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

confirm_restart() {
    confirm "重启面板，注意：重启面板也会重启 xray" "y"
    if [[ $? == 0 ]]; then
        restart
    else
        show_menu
    fi
}

before_show_menu() {
    echo && echo -n -e "${yellow}按 Enter 返回主菜单: ${plain}" && read temp
    show_menu
}

install() {
    bash <(curl -Ls https://raw.githubusercontent.com/admin8800/x-ui/main/install.sh)
    if [[ $? == 0 ]]; then
        if [[ $# == 0 ]]; then
            start
        else
            start 0
        fi
    fi
}

update() {
    confirm "此功能将强制重新安装最新版本，数据不会丢失。是否继续？" "n"
    if [[ $? != 0 ]]; then
        LOGE "Cancelled"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 0
    fi
    bash <(curl -Ls https://raw.githubusercontent.com/admin8800/x-ui/main/install.sh)
    if [[ $? == 0 ]]; then
        LOGI "更新已完成，面板已自动重启 "
        exit 0
    fi
}

custom_version() {
    echo "Enter the panel version (like 1.6.0):"
    read panel_version

    if [ -z "$panel_version" ]; then
        echo "面板版本不能为空。退出。"
    exit 1
    fi

    download_link="https://raw.githubusercontent.com/admin8800/x-ui/main/install.sh"

    # Use the entered panel version in the download link
    install_command="bash <(curl -Ls $download_link) $panel_version"

    echo "下载并安装面板版本 $panel_version..."
    eval $install_command
}

# Function to handle the deletion of the script file
delete_script() {
    rm "$0"  # Remove the script file itself
    exit 1
}

uninstall() {
    confirm "您确定要卸载面板吗？xray也将被卸载！" " n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    systemctl stop x-ui
    systemctl disable x-ui
    rm /etc/systemd/system/x-ui.service -f
    systemctl daemon-reload
    systemctl reset-failed
    rm /etc/x-ui/ -rf
    rm /usr/local/x-ui/ -rf
    echo -e "\n卸载成功"
    echo ""
    echo -e "如果需要再次安装此面板，可以重新执行脚本"
    echo ""
    # Trap the SIGTERM signal
    trap delete_script SIGTERM
    delete_script
}

reset_user() {
    confirm "重置管理员用户名和密码？" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    /usr/local/x-ui/x-ui setting -username admin -password admin
    echo -e "用户名和密码已重置为 ${green}admin${plain}，请立即重启面板"
    confirm_restart
}

reset_config() {
    confirm "您确定要重置所有面板设置，账户数据不会丢失，用户名和密码不会改变" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    /usr/local/x-ui/x-ui setting -reset
    echo -e "所有面板设置已恢复默认，请立即重启面板，并使用默认设置 ${green}54321${plain} 访问网络面板的端口"
    confirm_restart
}

check_config() {
    info=$(/usr/local/x-ui/x-ui setting -show true)
    if [[ $? != 0 ]]; then
        LOGE "获取当前设置错误，请检查日志"
        show_menu
    fi
    LOGI "${info}"
}

set_port() {
    echo && echo -n -e "输入端口号[1-65535]: " && read port
    if [[ -z "${port}" ]]; then
        LOGD "取消"
        before_show_menu
    else
        /usr/local/x-ui/x-ui setting -port ${port}
        echo -e "端口已设置，请立即重启面板，并使用新的端口 ${green}${port}${plain} 访问网页面板"
        confirm_restart
    fi
}

start() {
    check_status
    if [[ $? == 0 ]]; then
        echo ""
        LOGI "面板正在运行，无需再次启动，如需重启请选择重启"
    else
        systemctl start x-ui
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            LOGI "x-ui 启动成功"
        else
            LOGE "panel启动失败，可能是因为启动时间超过两秒，请稍后查看日志信息"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

stop() {
    check_status
    if [[ $? == 1 ]]; then
        echo ""
        LOGI "面板已停止，无需再次停止！"
    else
        systemctl stop x-ui
        sleep 2
        check_status
        if [[ $? == 1 ]]; then
            LOGI "x-ui 和 xray 已成功停止"
        else
            LOGE "面板停止失败，可能是因为停止时间超过两秒，请稍后查看日志信息"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

restart() {
    systemctl restart x-ui
    sleep 2
    check_status
    if [[ $? == 0 ]]; then
        LOGI "x-ui 和 xray 重启成功"
    else
        LOGE "面板重启失败，可能是因为启动时间超过两秒，请稍后查看日志信息"
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

status() {
    systemctl status x-ui -l
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

enable() {
    systemctl enable x-ui
    if [[ $? == 0 ]]; then
        LOGI "x-ui 成功设置为开机自动启动"
    else
        LOGE "x-ui 无法设置自动启动"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

disable() {
    systemctl disable x-ui
    if [[ $? == 0 ]]; then
        LOGI "x-ui 自动启动已成功取消"
    else
        LOGE "x-ui 自动启动取消失败"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_log() {
    journalctl -u x-ui.service -e --no-pager -f
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

update_shell() {
    wget -O /usr/bin/x-ui -N --no-check-certificate https://github.com/admin8800/x-ui/raw/main/x-ui.sh
    if [[ $? != 0 ]]; then
        echo ""
        LOGE "下载脚本失败，请检查你的网络是否可以连接Github"
        before_show_menu
    else
        chmod +x /usr/bin/x-ui
        LOGI "升级脚本成功，请重新运行脚本" && exit 0
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/x-ui.service ]]; then
        return 2
    fi
    temp=$(systemctl status x-ui | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

check_enabled() {
    temp=$(systemctl is-enabled x-ui)
    if [[ x"${temp}" == x"enabled" ]]; then
        return 0
    else
        return 1
    fi
}

check_uninstall() {
    check_status
    if [[ $? != 2 ]]; then
        echo ""
        LOGE "面板安装完毕，请勿重新安装"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

check_install() {
    check_status
    if [[ $? == 2 ]]; then
        echo ""
        LOGE "请先安装面板"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

show_status() {
    check_status
    case $? in
    0)
        echo -e "面板状态: ${green}运行中${plain}"
        show_enable_status
        ;;
    1)
        echo -e "面板状态: ${yellow}未运行${plain}"
        show_enable_status
        ;;
    2)
        echo -e "面板状态: ${red}未安装${plain}"
        ;;
    esac
    show_xray_status
}

show_enable_status() {
    check_enabled
    if [[ $? == 0 ]]; then
        echo -e "开机自启: ${green}已启用${plain}"
    else
        echo -e "开机自启: ${red}未启用${plain}"
    fi
}

check_xray_status() {
    count=$(ps -ef | grep "xray-linux" | grep -v "grep" | wc -l)
    if [[ count -ne 0 ]]; then
        return 0
    else
        return 1
    fi
}

show_xray_status() {
    check_xray_status
    if [[ $? == 0 ]]; then
        echo -e "xray 状态: ${green}运行中${plain}"
    else
        echo -e "xray 状态: ${red}未运行${plain}"
    fi
}

install_acme() {
    cd ~
    LOGI "install acme..."
    curl https://get.acme.sh | sh
    if [ $? -ne 0 ]; then
        LOGE "安装 acme 失败"
        return 1
    else
        LOGI "安装 acme 成功"
    fi
    return 0
}

ssl_cert_issue_main() {
    echo -e "${green}\t1.${plain} 获取 SSL"
    echo -e "${green}\t2.${plain} 撤销"
    echo -e "${green}\t3.${plain} 强制更新"
    read -p "Choose an option: " choice
    case "$choice" in
        1) ssl_cert_issue ;;
        2) 
            local domain=""
            read -p "请输入您的域名以撤销证书: " domain
            ~/.acme.sh/acme.sh --revoke -d ${domain}
            LOGI "Certificate revoked"
            ;;
        3)
            local domain=""
            read -p "请输入您的域名以强制续订 SSL 证书: " domain
            ~/.acme.sh/acme.sh --renew -d ${domain} --force ;;
        *) echo "无效选择" ;;
    esac
}

ssl_cert_issue() {
    # check for acme.sh first
    if ! command -v ~/.acme.sh/acme.sh &>/dev/null; then
        echo "找不到 acme.sh。即将安装"
        install_acme
        if [ $? -ne 0 ]; then
            LOGE "安装 acme 失败，请检查日志"
            exit 1
        fi
    fi
    # install socat second
    case "${release}" in
        ubuntu|debian)
            apt update && apt install socat -y ;;
        centos)
            yum -y update && yum -y install socat ;;
        fedora)
            dnf -y update && dnf -y install socat ;;
        *)
            echo -e "${red}不支持的操作系统。请检查脚本并手动安装必要的软件包.${plain}\n"
            exit 1 ;;
    esac
    if [ $? -ne 0 ]; then
        LOGE "安装socat失败，请检查日志"
        exit 1
    else
        LOGI "安装socat成功..."
    fi

    # get the domain here,and we need verify it
    local domain=""
    read -p "输入你的域名:" domain
    LOGD "你的域名是：${domain}，核实..."
    # here we need to judge whether there exists cert already
    local currentCert=$(~/.acme.sh/acme.sh --list | tail -1 | awk '{print $1}')

    if [ ${currentCert} == ${domain} ]; then
        local certInfo=$(~/.acme.sh/acme.sh --list)
        LOGE "系统已有证书，无法再次颁发，当前证书详情："
        LOGI "$certInfo"
        LOGD "请检查/root/.acme.sh目录"
        exit 1
    else
        LOGI "您的域名已准备好颁发证书..."
    fi

    # create a directory for install cert
    certPath="/root/cert/${domain}"
    if [ ! -d "$certPath" ]; then
        mkdir -p "$certPath"
    else
        rm -rf "$certPath"
        mkdir -p "$certPath"
    fi

    # get needed port here
    local WebPort=80
    read -p "请选择要使用的端口号，默认端口号为80:" WebPort
    if [[ ${WebPort} -gt 65535 || ${WebPort} -lt 1 ]]; then
        LOGD "你输入的端口 ${WebPort} 无效，将使用默认端口"
    fi
    LOGI "将使用端口：${WebPort} 颁发证书，请确保此端口已开放..."
    # NOTE:This should be handled by user
    # open the port and kill the occupied progress
    ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
    ~/.acme.sh/acme.sh --issue -d ${domain} --standalone --httpport ${WebPort}
    if [ $? -ne 0 ]; then
        LOGE "颁发证书失败，请检查日志"
        rm -rf ~/.acme.sh/${domain}
        exit 1
    else
        LOGI "颁发证书成功，正在安装证书..."
    fi
    # install cert
    ~/.acme.sh/acme.sh --installcert -d ${domain} \
        --key-file /root/cert/${domain}/privkey.pem \
        --fullchain-file /root/cert/${domain}/fullchain.pem

    if [ $? -ne 0 ]; then
        LOGE "安装证书失败，退出"
        rm -rf ~/.acme.sh/${domain}
        exit 1
    else
        LOGI "安装证书成功，启用自动续签..."
    fi

    ~/.acme.sh/acme.sh --upgrade --auto-upgrade
    if [ $? -ne 0 ]; then
        LOGE "自动续签失败，证书详细信息:"
        ls -lah cert/*
        chmod 755 $certPath/*
        exit 1
    else
        LOGI "自动续签成功，证书详细信息:"
        ls -lah cert/*
        chmod 755 $certPath/*
    fi
}

ssl_cert_issue_CF() {
    echo -E ""
    LOGD "******使用说明******"
    LOGI "此 Acme 脚本需要以下数据:"
    LOGI "1.Cloudflare 注册邮箱"
    LOGI "2.Cloudflare 全区域 API 密钥"
    LOGI "3.Cloudflare 已经将 dns 解析到当前服务器的域名"
    LOGI "4.该脚本用于申请证书，默认安装路径为 /root/cert "
    confirm "确认?[y/n]" "y"
    if [ $? -eq 0 ]; then
        # check for acme.sh first
        if ! command -v ~/.acme.sh/acme.sh &>/dev/null; then
            echo "找不到 acme.sh。即将安装..."
            install_acme
            if [ $? -ne 0 ]; then
                LOGE "安装 acme 失败，请检查日志"
                exit 1
            fi
        fi
        CF_Domain=""
        CF_GlobalKey=""
        CF_AccountEmail=""
        certPath=/root/cert
        if [ ! -d "$certPath" ]; then
            mkdir $certPath
        else
            rm -rf $certPath
            mkdir $certPath
        fi
        LOGD "请设置域名:"
        read -p "Input your domain here:" CF_Domain
        LOGD "您的域名设置为:${CF_Domain}"
        LOGD "请设置 API 密钥:"
        read -p "Input your key here:" CF_GlobalKey
        LOGD "您的 API 密钥是:${CF_GlobalKey}"
        LOGD "请设置注册邮箱:"
        read -p "Input your email here:" CF_AccountEmail
        LOGD "您的注册电子邮件地址是:${CF_AccountEmail}"
        ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
        if [ $? -ne 0 ]; then
            LOGE "默认 CA、Lets'Encrypt 失败，脚本退出..."
            exit 1
        fi
        export CF_Key="${CF_GlobalKey}"
        export CF_Email=${CF_AccountEmail}
        ~/.acme.sh/acme.sh --issue --dns dns_cf -d ${CF_Domain} -d *.${CF_Domain} --log
        if [ $? -ne 0 ]; then
            LOGE "证书颁发失败，脚本退出..."
            exit 1
        else
            LOGI "证书颁发成功，正在安装..."
        fi
        ~/.acme.sh/acme.sh --installcert -d ${CF_Domain} -d *.${CF_Domain} --ca-file /root/cert/ca.cer \
        --cert-file /root/cert/${CF_Domain}.cer --key-file /root/cert/${CF_Domain}.key \
        --fullchain-file /root/cert/fullchain.cer
        if [ $? -ne 0 ]; then
            LOGE "证书安装失败，脚本退出..."
            exit 1
        else
            LOGI "证书安装成功，正在开启自动更新..."
        fi
        ~/.acme.sh/acme.sh --upgrade --auto-upgrade
        if [ $? -ne 0 ]; then
            LOGE "自动更新设置失败，脚本退出..."
            ls -lah cert
            chmod 755 $certPath
            exit 1
        else
            LOGI "证书安装完毕并开启自动续签，具体信息如下"
            ls -lah cert
            chmod 755 $certPath
        fi
    else
        show_menu
    fi
}

firewall_menu() {
    echo -e "${green}\t1.${plain} 安装防火墙并打开端口"
    echo -e "${green}\t2.${plain} 允许列表"
    echo -e "${green}\t3.${plain} 从列表中删除端口"
    echo -e "${green}\t4.${plain} 禁用防火墙"
    echo -e "${green}\t0.${plain} 返回主菜单"
    read -p "选择一个选项: " choice
    case "$choice" in
    0)
        show_menu
        ;;
    1)
        open_ports
        ;;
    2)
        sudo ufw status
        ;;
    3)
        delete_ports
        ;;
    4)
        sudo ufw disable
        ;;
    *) echo "无效选择" ;;
    esac
}

open_ports() {
    if ! command -v ufw &>/dev/null; then
        echo "ufw 防火墙未安装。正在安装..."
        apt-get update
        apt-get install -y ufw
    else
        echo "ufw 防火墙已安装"
    fi

    # Check if the firewall is inactive
    if ufw status | grep -q "Status: active"; then
        echo "防火墙已处于启用状态"
    else
        # Open the necessary ports
        ufw allow ssh
        ufw allow http
        ufw allow https
        ufw allow 54321/tcp

        # Enable the firewall
        ufw --force enable
    fi

    # Prompt the user to enter a list of ports
    read -p "输入要打开的端口 (e.g. 80,443,2053 or range 400-500): " ports

    # Check if the input is valid
    if ! [[ $ports =~ ^([0-9]+|[0-9]+-[0-9]+)(,([0-9]+|[0-9]+-[0-9]+))*$ ]]; then
        echo "Error: 输入无效。请输入逗号分隔的端口列表或端口范围 (e.g. 80,443,2053 or 400-500)." >&2
        exit 1
    fi

    # Open the specified ports using ufw
    IFS=',' read -ra PORT_LIST <<<"$ports"
    for port in "${PORT_LIST[@]}"; do
        if [[ $port == *-* ]]; then
            # Split the range into start and end ports
            start_port=$(echo $port | cut -d'-' -f1)
            end_port=$(echo $port | cut -d'-' -f2)
            # Loop through the range and open each port
            for ((i = start_port; i <= end_port; i++)); do
                ufw allow $i
            done
        else
            ufw allow "$port"
        fi
    done

    # Confirm that the ports are open
    ufw status | grep $ports
}

delete_ports() {
    # Prompt the user to enter the ports they want to delete
    read -p "输入要删除的端口 (e.g. 80,443,2053 or range 400-500): " ports

    # Check if the input is valid
    if ! [[ $ports =~ ^([0-9]+|[0-9]+-[0-9]+)(,([0-9]+|[0-9]+-[0-9]+))*$ ]]; then
        echo "Error: 输入无效。请输入逗号分隔的端口列表或端口范围 (e.g. 80,443,2053 or 400-500)." >&2
        exit 1
    fi

    # Delete the specified ports using ufw
    IFS=',' read -ra PORT_LIST <<<"$ports"
    for port in "${PORT_LIST[@]}"; do
        if [[ $port == *-* ]]; then
            # Split the range into start and end ports
            start_port=$(echo $port | cut -d'-' -f1)
            end_port=$(echo $port | cut -d'-' -f2)
            # Loop through the range and delete each port
            for ((i = start_port; i <= end_port; i++)); do
                ufw delete allow $i
            done
        else
            ufw delete allow "$port"
        fi
    done

    # Confirm that the ports are deleted
    echo "删除指定端口:"
    ufw status | grep $ports
}

bbr_menu() {
    echo -e "${green}\t1.${plain} 启用 BBR"
    echo -e "${green}\t2.${plain} 禁用 BBR"
    echo -e "${green}\t0.${plain} 返回主菜单"
    read -p "Choose an option: " choice
    case "$choice" in
    0)
        show_menu
        ;;
    1)
        enable_bbr
        ;;
    2)
        disable_bbr
        ;;
    *) echo "无效选择" ;;
    esac
}

disable_bbr() {

    if ! grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf || ! grep -q "net.ipv4.tcp_congestion_control=bbr" /etc/sysctl.conf; then
        echo -e "${yellow}BBR 目前尚未启用.${plain}"
        exit 0
    fi

    # Replace BBR with CUBIC configurations
    sed -i 's/net.core.default_qdisc=fq/net.core.default_qdisc=pfifo_fast/' /etc/sysctl.conf
    sed -i 's/net.ipv4.tcp_congestion_control=bbr/net.ipv4.tcp_congestion_control=cubic/' /etc/sysctl.conf

    # Apply changes
    sysctl -p

    # Verify that BBR is replaced with CUBIC
    if [[ $(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}') == "cubic" ]]; then
        echo -e "${green}BBR 已成功替换为 CUBIC.${plain}"
    else
        echo -e "${red}无法用 CUBIC 替换 BBR。请检查您的系统配置.${plain}"
    fi
}

enable_bbr() {
    if grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf && grep -q "net.ipv4.tcp_congestion_control=bbr" /etc/sysctl.conf; then
        echo -e "${green}BBR 已启用！${plain}"
        exit 0
    fi

    # Check the OS and install necessary packages
    case "${release}" in
    ubuntu | debian)
        apt-get update && apt-get install -yqq --no-install-recommends ca-certificates
        ;;
    centos | almalinux | rocky)
        yum -y update && yum -y install ca-certificates
        ;;
    fedora)
        dnf -y update && dnf -y install ca-certificates
        ;;
    *)
        echo -e "${red}不支持的操作系统。请检查脚本并手动安装必要的软件包.${plain}\n"
        exit 1
        ;;
    esac

    # Enable BBR
    echo "net.core.default_qdisc=fq" | tee -a /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" | tee -a /etc/sysctl.conf

    # Apply changes
    sysctl -p

    # Verify that BBR is enabled
    if [[ $(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}') == "bbr" ]]; then
        echo -e "${green}BBR 已成功启用.${plain}"
    else
        echo -e "${red}无法启用 BBR。请检查您的系统配置.${plain}"
    fi
}

update_geo() {
    cd /usr/local/x-ui/bin
    echo -e "${green}\t1.${plain} 更新地理文件 [推荐选择] "
    echo -e "${green}\t2.${plain} 可选择 jsDelivr CDN 下载 "
    echo -e "${green}\t0.${plain} 返回主菜单 "
    read -p "Select: " select

    case "$select" in
        0)
            show_menu
            ;;

        1)
            wget -N "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat" && echo -e "${green}Success${plain}\n" || echo -e "${red}Failure${plain}\n"
            wget -N "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat" && echo -e "${green}Success${plain}\n" || echo -e "${red}Failure${plain}\n"
            wget "https://github.com/chocolate4u/Iran-v2ray-rules/releases/latest/download/geoip.dat" -O /tmp/wget && mv /tmp/wget geoip_IR.dat && echo -e "${green}Success${plain}\n" || echo -e "${red}Failure${plain}\n"
            wget "https://github.com/chocolate4u/Iran-v2ray-rules/releases/latest/download/geosite.dat" -O /tmp/wget && mv /tmp/wget geosite_IR.dat && echo -e "${green}Success${plain}\n" || echo -e "${red}Failure${plain}\n"
            echo -e "${green}Files are updated.${plain}"
            confirm_restart
            ;;

        2)
            wget -N "https://cdn.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/geoip.dat" && echo -e "${green}Success${plain}\n" || echo -e "${red}Failure${plain}\n"
            wget -N "https://cdn.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/geosite.dat" && echo -e "${green}Success${plain}\n" || echo -e "${red}Failure${plain}\n"
            wget "https://cdn.jsdelivr.net/gh/chocolate4u/Iran-v2ray-rules@release/geoip.dat" -O /tmp/wget && mv /tmp/wget geoip_IR.dat && echo -e "${green}Success${plain}\n" || echo -e "${red}Failure${plain}\n"
            wget "https://cdn.jsdelivr.net/gh/chocolate4u/Iran-v2ray-rules@release/geosite.dat" -O /tmp/wget && mv /tmp/wget geosite_IR.dat && echo -e "${green}Success${plain}\n" || echo -e "${red}Failure${plain}\n"
            echo -e "${green}Files are updated.${plain}"
            confirm_restart
            ;;

        *)
            LOGE "请输入正确的数字 [0-2]\n"
            update_geo
            ;;
    esac
}

run_speedtest() {
    # Check if Speedtest is already installed
    if ! command -v speedtest &>/dev/null; then
        # If not installed, install it
        local pkg_manager=""
        local speedtest_install_script=""

        if command -v dnf &>/dev/null; then
            pkg_manager="dnf"
            speedtest_install_script="https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.rpm.sh"
        elif command -v yum &>/dev/null; then
            pkg_manager="yum"
            speedtest_install_script="https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.rpm.sh"
        elif command -v apt-get &>/dev/null; then
            pkg_manager="apt-get"
            speedtest_install_script="https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh"
        elif command -v apt &>/dev/null; then
            pkg_manager="apt"
            speedtest_install_script="https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh"
        fi

        if [[ -z $pkg_manager ]]; then
            echo "Error: 未找到软件包管理器。您可能需要手动安装 Speedtest."
            return 1
        else
            curl -s $speedtest_install_script | bash
            $pkg_manager install -y speedtest
        fi
    fi

    # Run Speedtest
    speedtest
}

show_usage() {
    echo "X-UI 控制菜单"
    echo "------------------------------------------"
    echo "命令:" 
    echo "x-ui              - 打开菜单"
    echo "x-ui start        - 启动"
    echo "x-ui stop         - 停止"
    echo "x-ui restart      - 重启"
    echo "x-ui status       - 查看当前状态"
    echo "x-ui enable       - 启用开机自启"
    echo "x-ui disable      - 禁用开机自启"
    echo "x-ui log          - 查看日志"
    echo "x-ui update       - 更新"
    echo "x-ui install      - 安装"
    echo "x-ui uninstall    - 卸载"
    echo "x-ui help         - 帮助"
    echo "------------------------------------------"
}

show_menu() {
    echo -e "
  ${green}X-UI 管理菜单 ${plain}
————————————————
  ${green}0.${plain} 退出 
————————————————
  ${green}1.${plain} 安装
  ${green}2.${plain} 更新
  ${green}3.${plain} 切换版本
  ${green}4.${plain} 卸载
————————————————
  ${green}5.${plain} 修改用户名和密码
  ${green}6.${plain} 重置面板设置
  ${green}7.${plain} 修改面板端口
  ${green}8.${plain} 查看面板设置
————————————————
  ${green}9.${plain}  启动
  ${green}10.${plain} 停止
  ${green}11.${plain} 重启
  ${green}12.${plain} 检查状态
  ${green}13.${plain} 检查日志
————————————————
  ${green}14.${plain} 启用开机自启
  ${green}15.${plain} 禁用开机自启
————————————————
  ${green}16.${plain} SSL 证书管理
  ${green}17.${plain} Cloudflare SSL 证书
  ${green}18.${plain} 防火墙管理
————————————————
  ${green}19.${plain} 启用或禁用 BBR
  ${green}20.${plain} 更新地理文件
  ${green}21.${plain} 网络速度测试
 "
    show_status
    echo && read -p "请输入您的选择 [0-21]: " num

    case "${num}" in
    0)
        exit 0
        ;;
    1)
        check_uninstall && install
        ;;
    2)
        check_install && update
        ;;
    3)
        check_install && custom_version
        ;;
    4)
        check_install && uninstall
        ;;
    5)
        check_install && reset_user
        ;;
    6)
        check_install && reset_config
        ;;
    7)
        check_install && set_port
        ;;
    8)
        check_install && check_config
        ;;
    9)
        check_install && start
        ;;
    10)
        check_install && stop
        ;;
    11)
        check_install && restart
        ;;
    12)
        check_install && status
        ;;
    13)
        check_install && show_log
        ;;
    14)
        check_install && enable
        ;;
    15)
        check_install && disable
        ;;
    16)
        ssl_cert_issue_main
        ;;
    17)
        ssl_cert_issue_CF
        ;;
    18)
        firewall_menu
        ;;
    19)
        bbr_menu
        ;;
    20)
        update_geo
        ;;
    21)
        run_speedtest
        ;;
    *)
        LOGE "请输入正确的数字 [0-21]"
        ;;
    esac
}

if [[ $# > 0 ]]; then
    case $1 in
    "start")
        check_install 0 && start 0
        ;;
    "stop")
        check_install 0 && stop 0
        ;;
    "restart")
        check_install 0 && restart 0
        ;;
    "status")
        check_install 0 && status 0
        ;;
    "enable")
        check_install 0 && enable 0
        ;;
    "disable")
        check_install 0 && disable 0
        ;;
    "log")
        check_install 0 && show_log 0
        ;;
    "update")
        check_install 0 && update 0
        ;;
    "install")
        check_uninstall 0 && install 0
        ;;
    "uninstall")
        check_install 0 && uninstall 0
        ;;
    *) show_usage ;;
    esac
else
    show_menu
fi
