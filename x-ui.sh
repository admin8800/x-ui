#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

#Add some basic function here
function LOGD() {
    echo -e "${yellow}[调试] $* ${plain}"
}

function LOGE() {
    echo -e "${red}[错误] $* ${plain}"
}

function LOGI() {
    echo -e "${green}[信息] $* ${plain}"
}
# check root
[[ $EUID -ne 0 ]] && LOGE "错误：必须使用 root 权限运行此脚本！ \n" && exit 1

# Check OS and set release variable
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    release=$ID
elif [[ -f /usr/lib/os-release ]]; then
    source /usr/lib/os-release
    release=$ID
else
    echo "无法检测系统操作系统，请联系作者！" >&2
    exit 1
fi

echo "操作系统发行版: $release"

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -p "$1 [默认 $2]: " temp
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
    confirm "重启面板，注意：重启面板也会同时重启 xray" "y"
    if [[ $? == 0 ]]; then
        restart
    else
        show_menu
    fi
}

before_show_menu() {
    echo && echo -n -e "${yellow}按回车键返回主菜单: ${plain}" && read temp
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
        LOGE "已取消"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 0
    fi
    bash <(curl -Ls https://raw.githubusercontent.com/admin8800/x-ui/main/install.sh)
    if [[ $? == 0 ]]; then
        LOGI "更新完成，面板已自动重启"
        exit 0
    fi
}

legacy_version() {
    echo "请输入面板版本号（例如 1.6.0）:"
    read panel_version

    if [ -z "$panel_version" ]; then
        echo "面板版本号不能为空，退出。"
        exit 1
    fi

    download_link="https://raw.githubusercontent.com/admin8800/x-ui/master/install.sh"

    # Use the entered panel version in the download link
    install_command="bash <(curl -Ls $download_link) $panel_version"

    echo "正在下载并安装面板版本 $panel_version..."
    eval $install_command
}

# Function to handle the deletion of the script file
delete_script() {
    rm "$0" # Remove the script file itself
    exit 1
}

uninstall() {
    confirm "确定要卸载面板吗？xray 也将一并卸载！" " n"
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
    echo -e "\n卸载成功。"
    echo ""
    echo -e "如需重新安装此面板，可使用以下命令:"
    echo -e "${green}bash <(curl -Ls https://raw.githubusercontent.com/admin8800/x-ui/master/install.sh)${plain}"
    echo ""
    # Trap the SIGTERM signal
    trap delete_script SIGTERM
    delete_script
}

reset_user() {
    confirm "确定要重置面板的用户名和密码吗？" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi

    read -rp "请设置登录用户名 [默认为随机用户名]: " config_account
    [[ -z $config_account ]] && config_account=$(gen_random_string 10)
    read -rp "请设置登录密码 [默认为随机密码]: " config_password
    [[ -z $config_password ]] && config_password=$(gen_random_string 18)
    /usr/local/x-ui/x-ui setting -username "${config_account}" -password "${config_password}"
    
    echo -e "面板登录用户名已重置为: ${green} ${config_account} ${plain}"
    echo -e "面板登录密码已重置为: ${green} ${config_password} ${plain}"
    echo -e "${green}请使用新的用户名和密码访问 X-UI 面板，并妥善保存！${plain}"

    confirm_restart
}

gen_random_string() {
    local length="$1"
    local random_string=$(LC_ALL=C tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w "$length" | head -n 1)
    echo "$random_string"
}

reset_webbasepath() {
    echo -e "${yellow}重置 Web 基础路径${plain}"

    read -rp "确定要重置 Web 基础路径吗？(y/n): " confirm
    if [[ $confirm != "y" && $confirm != "Y" ]]; then
        echo -e "${yellow}操作已取消。${plain}"
        return
    fi

    config_webBasePath=$(gen_random_string 10)

    # Apply the new web base path setting
    /usr/local/x-ui/x-ui setting -webBasePath "${config_webBasePath}" >/dev/null 2>&1

    echo -e "Web 基础路径已重置为: ${green}${config_webBasePath}${plain}"
    echo -e "${green}请使用新的 Web 基础路径访问面板。${plain}"
    restart
}

reset_config() {
    confirm "确定要重置所有面板设置吗？账户数据不会丢失，用户名和密码不会改变" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    /usr/local/x-ui/x-ui setting -reset
    echo -e "所有面板设置已恢复默认。请立即重启面板，并使用默认端口 ${green}54321${plain} 访问 Web 面板"
    confirm_restart
}

check_config() {
    info=$(/usr/local/x-ui/x-ui setting -show true)
    if [[ $? != 0 ]]; then
        LOGE "获取当前设置失败，请检查日志"
        show_menu
    fi
    LOGI "${info}"
}

get_uri() {
    info=$(/usr/local/x-ui/x-ui uri)
    if [[ $? != 0 ]]; then
        LOGE "获取当前访问地址失败"
        show_menu
    fi
    LOGI "您可以通过以下 URL 访问面板:"
    echo -e "${yellow}${info}${plain}"
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

set_port() {
    echo && echo -n -e "请输入端口号[1-65535]: " && read port
    if [[ -z "${port}" ]]; then
        LOGD "已取消"
        before_show_menu
    else
        /usr/local/x-ui/x-ui setting -port ${port}
        echo -e "端口已设置，请立即重启面板，并使用新端口 ${green}${port}${plain} 访问 Web 面板"
        confirm_restart
    fi
}

start() {
    check_status
    if [[ $? == 0 ]]; then
        echo ""
        LOGI "面板已在运行，无需再次启动。如需重启，请选择重启选项"
    else
        systemctl start x-ui
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            LOGI "x-ui 启动成功"
        else
            LOGE "面板启动失败，可能是启动时间超过两秒，请稍后检查日志信息"
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
            LOGE "面板停止失败，可能是停止时间超过两秒，请稍后检查日志信息"
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
        LOGE "面板重启失败，可能是启动时间超过两秒，请稍后检查日志信息"
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

restart_xray() {
    systemctl reload x-ui
    LOGI "xray-core 重启信号已发送，请检查日志确认 xray 是否重启成功"
    sleep 2
    show_xray_status
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
        LOGI "x-ui 开机自启设置成功"
    else
        LOGE "x-ui 设置开机自启失败"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

disable() {
    systemctl disable x-ui
    if [[ $? == 0 ]]; then
        LOGI "x-ui 已取消开机自启"
    else
        LOGE "x-ui 取消开机自启失败"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_log() {
    echo -e "${green}\t1.${plain} 调试日志"
    echo -e "${green}\t2.${plain} 清除所有日志"
    echo -e "${green}\t0.${plain} 返回主菜单"
    read -p "请选择: " choice

    case "$choice" in
    0)
        return
        ;;
    1)
        journalctl -u x-ui -e --no-pager -f -p debug
        if [[ $# == 0 ]]; then
        before_show_menu
        fi
        ;;
    2)
        sudo journalctl --rotate
        sudo journalctl --vacuum-time=1s
        echo "所有日志已清除。"
        restart
        ;;
    *)
        echo "无效选项"
        ;;
    esac
}

update_shell() {
    wget -O /usr/bin/x-ui -N --no-check-certificate https://github.com/admin8800/x-ui/raw/main/x-ui.sh
    if [[ $? != 0 ]]; then
        echo ""
        LOGE "下载脚本失败，请检查服务器是否可以连接 GitHub"
        before_show_menu
    else
        chmod +x /usr/bin/x-ui
        LOGI "脚本升级成功，请重新运行脚本" && exit 0
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
        LOGE "面板已安装，请勿重复安装"
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
        echo -e "开机自启: ${green}是${plain}"
    else
        echo -e "开机自启: ${red}否${plain}"
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
    # Check if acme.sh is already installed
    if command -v ~/.acme.sh/acme.sh &>/dev/null; then
        LOGI "acme.sh 已安装。"
        return 0
    fi

    LOGI "正在安装 acme.sh..."
    cd ~ || return 1 # Ensure you can change to the home directory

    curl -s https://get.acme.sh | sh
    if [ $? -ne 0 ]; then
        LOGE "acme.sh 安装失败。"
        return 1
    else
        LOGI "acme.sh 安装成功。"
    fi

    return 0
}

ssl_cert_issue_main() {
    echo -e "${green}\t1.${plain} 申请 SSL 证书"
    echo -e "${green}\t2.${plain} 吊销证书"
    echo -e "${green}\t3.${plain} 强制续期"
    echo -e "${green}\t4.${plain} 查看已有域名"
    echo -e "${green}\t5.${plain} 为面板设置证书路径"
    echo -e "${green}\t0.${plain} 返回主菜单"

    read -p "请选择: " choice
    case "$choice" in
    0)
        show_menu
        ;;
    1)
        ssl_cert_issue
        ;;
    2)
        local domains=$(find /root/cert/ -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)
        if [ -z "$domains" ]; then
            echo "未找到可吊销的证书。"
        else
            echo "已有域名:"
            echo "$domains"
            read -p "请从列表中输入要吊销证书的域名: " domain
            if echo "$domains" | grep -qw "$domain"; then
                ~/.acme.sh/acme.sh --revoke -d ${domain}
                LOGI "已吊销域名 $domain 的证书"
            else
                echo "输入的域名无效。"
            fi
        fi
        ;;
    3)
        local domains=$(find /root/cert/ -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)
        if [ -z "$domains" ]; then
            echo "未找到可续期的证书。"
        else
            echo "已有域名:"
            echo "$domains"
            read -p "请从列表中输入要续期 SSL 证书的域名: " domain
            if echo "$domains" | grep -qw "$domain"; then
                ~/.acme.sh/acme.sh --renew -d ${domain} --force
                LOGI "已强制续期域名 $domain 的证书"
            else
                echo "输入的域名无效。"
            fi
        fi
        ;;
    4)
        local domains=$(find /root/cert/ -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)
        if [ -z "$domains" ]; then
            echo "未找到证书。"
        else
            echo "已有域名及其路径:"
            for domain in $domains; do
                local cert_path="/root/cert/${domain}/fullchain.pem"
                local key_path="/root/cert/${domain}/privkey.pem"
                if [[ -f "${cert_path}" && -f "${key_path}" ]]; then
                    echo -e "域名: ${domain}"
                    echo -e "\t证书路径: ${cert_path}"
                    echo -e "\t私钥路径: ${key_path}"
                else
                    echo -e "域名: ${domain} - 证书或私钥缺失。"
                fi
            done
        fi
        ;;
    5)
        local domains=$(find /root/cert/ -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)
        if [ -z "$domains" ]; then
            echo "未找到证书。"
        else
            echo "可用域名:"
            echo "$domains"
            read -p "请选择要设置面板路径的域名: " domain

            if echo "$domains" | grep -qw "$domain"; then
                local webCertFile="/root/cert/${domain}/fullchain.pem"
                local webKeyFile="/root/cert/${domain}/privkey.pem"

                if [[ -f "${webCertFile}" && -f "${webKeyFile}" ]]; then
                    /usr/local/x-ui/x-ui cert -webCert "$webCertFile" -webCertKey "$webKeyFile"
                    echo "已为域名 $domain 设置面板路径"
                    echo "  - 证书文件: $webCertFile"
                    echo "  - 私钥文件: $webKeyFile"
                    restart
                else
                    echo "未找到域名 $domain 的证书或私钥。"
                fi
            else
                echo "输入的域名无效。"
            fi
        fi
        ;;

    *)
        echo "无效选项"
        ;;
    esac
}

ssl_cert_issue() {
    # check for acme.sh first
    if ! command -v ~/.acme.sh/acme.sh &>/dev/null; then
        echo "未找到 acme.sh，即将安装"
        install_acme
        if [ $? -ne 0 ]; then
            LOGE "安装 acme 失败，请检查日志"
            exit 1
        fi
    fi

    # install socat second
    case "${release}" in
    ubuntu | debian | armbian)
        apt update && apt install socat -y
        ;;
    centos | almalinux | rocky | ol)
        yum -y update && yum -y install socat
        ;;
    fedora | amzn)
        dnf -y update && dnf -y install socat
        ;;
    arch | manjaro | parch)
        pacman -Sy --noconfirm socat
        ;;
    *)
        echo -e "${red}不支持的操作系统。请检查脚本并手动安装所需软件包。${plain}\n"
        exit 1
        ;;
    esac
    if [ $? -ne 0 ]; then
        LOGE "安装 socat 失败，请检查日志"
        exit 1
    else
        LOGI "安装 socat 成功..."
    fi

    # get the domain here, and we need to verify it
    local domain=""
    read -p "请输入您的域名: " domain
    LOGD "您的域名为: ${domain}，正在验证..."

    # check if there already exists a certificate
    local currentCert=$(~/.acme.sh/acme.sh --list | tail -1 | awk '{print $1}')
    if [ "${currentCert}" == "${domain}" ]; then
        local certInfo=$(~/.acme.sh/acme.sh --list)
        LOGE "系统已有该域名的证书，无法重复申请。当前证书详情:"
        LOGI "$certInfo"
        exit 1
    else
        LOGI "您的域名已准备好申请证书..."
    fi

    # create a directory for the certificate
    certPath="/root/cert/${domain}"
    if [ ! -d "$certPath" ]; then
        mkdir -p "$certPath"
    else
        rm -rf "$certPath"
        mkdir -p "$certPath"
    fi

    # get the port number for the standalone server
    local WebPort=80
    read -p "请选择使用的端口（默认为 80）: " WebPort
    if [[ ${WebPort} -gt 65535 || ${WebPort} -lt 1 ]]; then
        LOGE "您输入的端口 ${WebPort} 无效，将使用默认端口 80。"
        WebPort=80
    fi
    LOGI "将使用端口 ${WebPort} 申请证书，请确保该端口已开放。"

    # issue the certificate
    ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
    ~/.acme.sh/acme.sh --issue -d ${domain} --listen-v6 --standalone --httpport ${WebPort}
    if [ $? -ne 0 ]; then
        LOGE "申请证书失败，请检查日志。"
        rm -rf ~/.acme.sh/${domain}
        exit 1
    else
        LOGE "申请证书成功，正在安装证书..."
    fi

    # install the certificate
    ~/.acme.sh/acme.sh --installcert -d ${domain} \
        --key-file /root/cert/${domain}/privkey.pem \
        --fullchain-file /root/cert/${domain}/fullchain.pem

    if [ $? -ne 0 ]; then
        LOGE "安装证书失败，退出。"
        rm -rf ~/.acme.sh/${domain}
        exit 1
    else
        LOGI "安装证书成功，正在启用自动续期..."
    fi

    # enable auto-renew
    ~/.acme.sh/acme.sh --upgrade --auto-upgrade
    if [ $? -ne 0 ]; then
        LOGE "自动续期失败，证书详情:"
        ls -lah cert/*
        chmod 755 $certPath/*
        exit 1
    else
        LOGI "自动续期成功，证书详情:"
        ls -lah cert/*
        chmod 755 $certPath/*
    fi

    # Prompt user to set panel paths after successful certificate installation
    read -p "是否将此证书设置为面板证书？(y/n): " setPanel
    if [[ "$setPanel" == "y" || "$setPanel" == "Y" ]]; then
        local webCertFile="/root/cert/${domain}/fullchain.pem"
        local webKeyFile="/root/cert/${domain}/privkey.pem"

        if [[ -f "$webCertFile" && -f "$webKeyFile" ]]; then
            /usr/local/x-ui/x-ui cert -webCert "$webCertFile" -webCertKey "$webKeyFile"
            LOGI "已为域名 $domain 设置面板路径"
            LOGI "  - 证书文件: $webCertFile"
            LOGI "  - 私钥文件: $webKeyFile"
            restart
        else
            LOGE "错误：未找到域名 $domain 的证书或私钥文件。"
        fi
    else
        LOGI "跳过面板路径设置。"
    fi
}

ssl_cert_issue_CF() {
    echo -E ""
    LOGD "******使用说明******"
    LOGI "此 Acme 脚本需要以下信息:"
    LOGI "1. Cloudflare 注册邮箱"
    LOGI "2. Cloudflare Global API Key"
    LOGI "3. 已通过 Cloudflare 解析 DNS 到当前服务器的域名"
    LOGI "4. 脚本申请证书，默认安装路径为 /root/cert"
    confirm "已确认？[y/n]" "y"
    if [ $? -eq 0 ]; then
        # check for acme.sh first
        if ! command -v ~/.acme.sh/acme.sh &>/dev/null; then
            echo "未找到 acme.sh，即将安装"
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
        read -p "在此输入您的域名:" CF_Domain
        LOGD "您的域名已设置为:${CF_Domain}"
        LOGD "请设置 API Key:"
        read -p "在此输入您的 Key:" CF_GlobalKey
        LOGD "您的 API Key 为:${CF_GlobalKey}"
        LOGD "请设置注册邮箱:"
        read -p "在此输入您的邮箱:" CF_AccountEmail
        LOGD "您的注册邮箱为:${CF_AccountEmail}"
        ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
        if [ $? -ne 0 ]; then
            LOGE "默认 CA LetsEncrypt 设置失败，脚本退出..."
            exit 1
        fi
        export CF_Key="${CF_GlobalKey}"
        export CF_Email=${CF_AccountEmail}
        ~/.acme.sh/acme.sh --issue --dns dns_cf -d ${CF_Domain} -d *.${CF_Domain} --log
        if [ $? -ne 0 ]; then
            LOGE "证书申请失败，脚本退出..."
            exit 1
        else
            LOGI "证书申请成功，正在安装..."
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
            LOGI "证书已安装并开启自动续期，详细信息如下"
            ls -lah cert
            chmod 755 $certPath
        fi
    else
        show_menu
    fi
}

firewall_menu() {
    echo -e "${green}\t1.${plain} 安装防火墙并开放端口"
    echo -e "${green}\t2.${plain} 允许列表"
    echo -e "${green}\t3.${plain} 从列表中删除端口"
    echo -e "${green}\t4.${plain} 禁用防火墙"
    echo -e "${green}\t0.${plain} 返回主菜单"
    read -p "请选择: " choice
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
    *) echo "无效选项" ;;
    esac
}

open_ports() {
    if ! command -v ufw &>/dev/null; then
        echo "ufw 防火墙未安装，正在安装..."
        apt-get update
        apt-get install -y ufw
    else
        echo "ufw 防火墙已安装"
    fi

    # Check if the firewall is inactive
    if ufw status | grep -q "Status: active"; then
        echo "防火墙已处于激活状态"
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
    read -p "请输入要开放的端口（例如 80,443,2053 或范围 400-500）: " ports

    # Check if the input is valid
    if ! [[ $ports =~ ^([0-9]+|[0-9]+-[0-9]+)(,([0-9]+|[0-9]+-[0-9]+))*$ ]]; then
        echo "错误：输入无效。请输入逗号分隔的端口列表或端口范围（例如 80,443,2053 或 400-500）。" >&2
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
    read -p "请输入要删除的端口（例如 80,443,2053 或范围 400-500）: " ports

    # Check if the input is valid
    if ! [[ $ports =~ ^([0-9]+|[0-9]+-[0-9]+)(,([0-9]+|[0-9]+-[0-9]+))*$ ]]; then
        echo "错误：输入无效。请输入逗号分隔的端口列表或端口范围（例如 80,443,2053 或 400-500）。" >&2
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
    echo "已删除指定端口:"
    ufw status | grep $ports
}

bbr_menu() {
    echo -e "${green}\t1.${plain} 启用 BBR"
    echo -e "${green}\t2.${plain} 禁用 BBR"
    echo -e "${green}\t0.${plain} 返回主菜单"
    read -p "请选择: " choice
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
    *) echo "无效选项" ;;
    esac
}

disable_bbr() {

    if ! grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf || ! grep -q "net.ipv4.tcp_congestion_control=bbr" /etc/sysctl.conf; then
        echo -e "${yellow}BBR 当前未启用。${plain}"
        exit 0
    fi

    # Replace BBR with CUBIC configurations
    sed -i 's/net.core.default_qdisc=fq/net.core.default_qdisc=pfifo_fast/' /etc/sysctl.conf
    sed -i 's/net.ipv4.tcp_congestion_control=bbr/net.ipv4.tcp_congestion_control=cubic/' /etc/sysctl.conf

    # Apply changes
    sysctl -p

    # Verify that BBR is replaced with CUBIC
    if [[ $(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}') == "cubic" ]]; then
        echo -e "${green}BBR 已成功替换为 CUBIC。${plain}"
    else
        echo -e "${red}BBR 替换为 CUBIC 失败，请检查系统配置。${plain}"
    fi
}

enable_bbr() {
    if grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf && grep -q "net.ipv4.tcp_congestion_control=bbr" /etc/sysctl.conf; then
        echo -e "${green}BBR 已启用！${plain}"
        exit 0
    fi

    # Check the OS and install necessary packages
    case "${release}" in
    ubuntu | debian | armbian)
        apt-get update && apt-get install -yqq --no-install-recommends ca-certificates
        ;;
    centos | almalinux | rocky | ol)
        yum -y update && yum -y install ca-certificates
        ;;
    fedora | amzn)
        dnf -y update && dnf -y install ca-certificates
        ;;
    arch | manjaro | parch)
        pacman -Sy --noconfirm ca-certificates
        ;;
    *)
        echo -e "${red}不支持的操作系统。请检查脚本并手动安装所需软件包。${plain}\n"
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
        echo -e "${green}BBR 启用成功。${plain}"
    else
        echo -e "${red}BBR 启用失败，请检查系统配置。${plain}"
    fi
}

update_geo() {
    cd /usr/local/x-ui/bin
    echo -e "${green}\t1.${plain} 更新 Geo 文件 [推荐] "
    echo -e "${green}\t2.${plain} 从 jsDelivr CDN 下载 "
    echo -e "${green}\t0.${plain} 返回主菜单 "
    read -p "请选择: " select

    case "$select" in
    0)
        show_menu
        ;;

    1)
        wget -N "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat" && echo -e "${green}成功${plain}\n" || echo -e "${red}失败${plain}\n"
        wget -N "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat" && echo -e "${green}成功${plain}\n" || echo -e "${red}失败${plain}\n"
        wget "https://github.com/chocolate4u/Iran-v2ray-rules/releases/latest/download/geoip.dat" -O /tmp/wget && mv /tmp/wget geoip_IR.dat && echo -e "${green}成功${plain}\n" || echo -e "${red}失败${plain}\n"
        wget "https://github.com/chocolate4u/Iran-v2ray-rules/releases/latest/download/geosite.dat" -O /tmp/wget && mv /tmp/wget geosite_IR.dat && echo -e "${green}成功${plain}\n" || echo -e "${red}失败${plain}\n"
        echo -e "${green}文件已更新。${plain}"
        confirm_restart
        ;;

    2)
        wget -N "https://cdn.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/geoip.dat" && echo -e "${green}成功${plain}\n" || echo -e "${red}失败${plain}\n"
        wget -N "https://cdn.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/geosite.dat" && echo -e "${green}成功${plain}\n" || echo -e "${red}失败${plain}\n"
        wget "https://cdn.jsdelivr.net/gh/chocolate4u/Iran-v2ray-rules@release/geoip.dat" -O /tmp/wget && mv /tmp/wget geoip_IR.dat && echo -e "${green}成功${plain}\n" || echo -e "${red}失败${plain}\n"
        wget "https://cdn.jsdelivr.net/gh/chocolate4u/Iran-v2ray-rules@release/geosite.dat" -O /tmp/wget && mv /tmp/wget geosite_IR.dat && echo -e "${green}成功${plain}\n" || echo -e "${red}失败${plain}\n"
        echo -e "${green}文件已更新。${plain}"
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
            echo "错误：未找到包管理器，可能需要手动安装 Speedtest。"
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
    echo "X-UI 控制菜单用法"
    echo "------------------------------------------"
    echo "子命令:"
    echo "x-ui              - 管理脚本"
    echo "x-ui start        - 启动"
    echo "x-ui stop         - 停止"
    echo "x-ui restart      - 重启"
    echo "x-ui restart-xray - 重启 xray-core"
    echo "x-ui status       - 当前状态"
    echo "x-ui settings     - 当前设置"
    echo "x-ui enable       - 设置开机自启"
    echo "x-ui disable      - 取消开机自启"
    echo "x-ui log          - 查看日志"
    echo "x-ui update       - 更新"
    echo "x-ui install      - 安装"
    echo "x-ui uninstall    - 卸载"
    echo "x-ui help         - 控制菜单用法"
    echo "------------------------------------------"
}

show_menu() {
    echo -e "
  ${green}X-UI 管理脚本 ${plain}
————————————————
  ${green}0.${plain} 退出 
————————————————
  ${green}1.${plain} 安装
  ${green}2.${plain} 更新
  ${green}3.${plain} 旧版安装
  ${green}4.${plain} 卸载
————————————————
  ${green}5.${plain} 重置用户名和密码
  ${green}6.${plain} 重置 Web 基础路径
  ${green}7.${plain} 重置面板设置
  ${green}8.${plain} 设置面板端口
  ${green}9.${plain} 查看面板设置
————————————————
  ${green}10.${plain} 启动
  ${green}11.${plain} 停止
  ${green}12.${plain} 重启
  ${green}13.${plain} 重启 Xray
  ${green}14.${plain} 查看状态
  ${green}15.${plain} 查看日志
————————————————
  ${green}16.${plain} 启用开机自启
  ${green}17.${plain} 禁用开机自启
————————————————
  ${green}18.${plain} SSL 证书管理
  ${green}19.${plain} Cloudflare SSL 证书
  ${green}20.${plain} 防火墙管理
————————————————
  ${green}21.${plain} 启用或禁用 BBR
  ${green}22.${plain} 更新 Geo 文件
  ${green}23.${plain} Ookla 网速测试
 "
    show_status
    echo && read -p "请输入您的选择 [0-23]: " num

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
        check_install && legacy_version
        ;;
    4)
        check_install && uninstall
        ;;
    5)
        check_install && reset_user
        ;;
    6)
        check_install && reset_webbasepath
        ;;
    7)
        check_install && reset_config
        ;;
    8)
        check_install && set_port
        ;;
    9)
        check_install && check_config && get_uri
        ;;
    10)
        check_install && start
        ;;
    11)
        check_install && stop
        ;;
    12)
        check_install && restart
        ;;
    13)
        check_install && restart_xray
        ;;
    14)
        check_install && status
        ;;
    15)
        check_install && show_log
        ;;
    16)
        check_install && enable
        ;;
    17)
        check_install && disable
        ;;
    18)
        ssl_cert_issue_main
        ;;
    19)
        ssl_cert_issue_CF
        ;;
    20)
        firewall_menu
        ;;
    21)
        bbr_menu
        ;;
    22)
        update_geo
        ;;
    23)
        run_speedtest
        ;;
    *)
        LOGE "请输入正确的数字 [0-23]"
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
    "restart-xray")
        check_install 0 && restart_xray 0
        ;;
    "status")
        check_install 0 && status 0
        ;;
    "settings")
        check_install 0 && check_config 0 && get_uri 0
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
