#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}致命错误：${plain} 请使用 root 权限运行此脚本 \n " && exit 1

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

arch() {
    case "$(uname -m)" in
    x86_64 | x64 | amd64) echo 'amd64' ;;
    i*86 | x86) echo '386' ;;
    armv8* | armv8 | arm64 | aarch64) echo 'arm64' ;;
    armv7* | armv7 | arm) echo 'armv7' ;;
    armv6* | armv6) echo 'armv6' ;;
    armv5* | armv5) echo 'armv5' ;;
    s390x) echo 's390x' ;;
    *) echo -e "${green}不支持的 CPU 架构！${plain}" && rm -f install.sh && exit 1 ;;
    esac
}

echo "架构: $(arch)"

install_dependencies() {
    case "${release}" in
    ubuntu | debian | armbian)
        apt-get update && apt-get install -y -q wget curl tar tzdata cron ca-certificates nftables
        ;;
    centos | almalinux | rocky | ol)
        yum -y update && yum install -y -q wget curl tar tzdata cronie ca-certificates nftables
        ;;
    fedora | amzn)
        dnf -y update && dnf install -y -q wget curl tar tzdata cronie ca-certificates nftables
        ;;
    arch | manjaro | parch)
        pacman -Syu && pacman -Syu --noconfirm wget curl tar tzdata cronie ca-certificates nftables
        ;;
    opensuse-tumbleweed)
        zypper refresh && zypper -q install -y wget curl tar timezone cron ca-certificates nftables
        ;;
    *)
        apt-get update && apt install -y -q wget curl tar tzdata cron ca-certificates nftables
        ;;
    esac
}

gen_random_string() {
    local length="$1"
    local random_string=$(LC_ALL=C tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w "$length" | head -n 1)
    echo "$random_string"
}

config_after_install() {
    local existing_username=$(/usr/local/x-ui/x-ui setting -show true | grep -Eo 'username: .+' | awk '{print $2}')
    local existing_password=$(/usr/local/x-ui/x-ui setting -show true | grep -Eo 'password: .+' | awk '{print $2}')
    local existing_webBasePath=$(/usr/local/x-ui/x-ui setting -show true | grep -Eo 'webBasePath: .+' | awk '{print $2}')

    if [[ ${#existing_webBasePath} -lt 4 ]]; then
        if [[ "$existing_username" == "admin" && "$existing_password" == "admin" ]]; then
            local config_webBasePath=$(gen_random_string 15)
            local config_username=$(gen_random_string 10)
            local config_password=$(gen_random_string 10)

            read -p "是否自定义面板端口设置？（若不自定义，将使用随机端口）[y/n]: " config_confirm
            if [[ "${config_confirm}" == "y" || "${config_confirm}" == "Y" ]]; then
                read -p "请设置面板端口: " config_port
                echo -e "${yellow}您的面板端口为: ${config_port}${plain}"
            else
                local config_port=$(shuf -i 1024-62000 -n 1)
                echo -e "${yellow}已生成随机端口: ${config_port}${plain}"
            fi

            /usr/local/x-ui/x-ui setting -username "${config_username}" -password "${config_password}" -port "${config_port}" -webBasePath "${config_webBasePath}"
            echo -e "这是全新安装，出于安全考虑已生成随机登录信息:"
            echo -e "###############################################"
            echo -e "${green}用户名: ${config_username}${plain}"
            echo -e "${green}密码: ${config_password}${plain}"
            echo -e "${green}端口: ${config_port}${plain}"
            echo -e "${green}Web 基础路径: ${config_webBasePath}${plain}"
            echo -e "###############################################"
            echo -e "${yellow}若忘记登录信息，可输入 'x-ui settings' 查看${plain}"
        else
            local config_webBasePath=$(gen_random_string 15)
            echo -e "${yellow}Web 基础路径缺失或过短，正在生成新的路径...${plain}"
            /usr/local/x-ui/x-ui setting -webBasePath "${config_webBasePath}"
            echo -e "${green}新的 Web 基础路径: ${config_webBasePath}${plain}"
        fi
    else
        if [[ "$existing_username" == "admin" && "$existing_password" == "admin" ]]; then
            local config_username=$(gen_random_string 10)
            local config_password=$(gen_random_string 10)

            echo -e "${yellow}检测到默认凭据，需要进行安全更新...${plain}"
            /usr/local/x-ui/x-ui setting -username "${config_username}" -password "${config_password}"
            echo -e "已生成新的随机登录凭据:"
            echo -e "###############################################"
            echo -e "${green}用户名: ${config_username}${plain}"
            echo -e "${green}密码: ${config_password}${plain}"
            echo -e "###############################################"
            echo -e "${yellow}若忘记登录信息，可输入 'x-ui settings' 查看${plain}"
        else
            echo -e "${green}用户名、密码和 Web 基础路径已正确设置，跳过配置...${plain}"
        fi
    fi

    /usr/local/x-ui/x-ui migrate
}

install_x-ui() {
    # checks if the installation backup dir exist. if existed then ask user if they want to restore it else continue installation.
    if [[ -e /usr/local/x-ui-backup/ ]]; then
        read -p "检测到安装失败，是否恢复之前安装的版本？[y/n]? ": restore_confirm
        if [[ "${restore_confirm}" == "y" || "${restore_confirm}" == "Y" ]]; then
            systemctl stop x-ui
            mv /usr/local/x-ui-backup/x-ui.db /etc/x-ui/ -f
            mv /usr/local/x-ui-backup/ /usr/local/x-ui/ -f
            systemctl start x-ui
            echo -e "${green}已成功恢复之前安装的 x-ui${plain}，服务现已运行..."
            exit 0
        else
            echo -e "继续安装 x-ui ..."
        fi
    fi

    cd /usr/local/

    if [ $# == 0 ]; then
        last_version=$(curl -Ls "https://api.github.com/repos/admin8800/x-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}获取 x-ui 版本失败，可能是 GitHub API 限制导致，请稍后再试${plain}"
            exit 1
        fi
        echo -e "已获取 x-ui 最新版本: ${last_version}，开始安装..."
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-$(arch).tar.gz https://github.com/admin8800/x-ui/releases/download/${last_version}/x-ui-linux-$(arch).tar.gz
        if [[ $? -ne 0 ]]; then
            echo -e "${red}下载 x-ui 失败，请确保服务器可以访问 GitHub${plain}"
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/admin8800/x-ui/releases/download/${last_version}/x-ui-linux-$(arch).tar.gz"
        echo -e "开始安装 x-ui $1"
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-$(arch).tar.gz ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}下载 x-ui $1 失败，请检查该版本是否存在${plain}"
            exit 1
        fi
    fi

    if [[ -e /usr/local/x-ui/ ]]; then
        systemctl stop x-ui
        mv /usr/local/x-ui/ /usr/local/x-ui-backup/ -f
        cp /etc/x-ui/x-ui.db /usr/local/x-ui-backup/ -f
    fi

    tar zxvf x-ui-linux-$(arch).tar.gz
    rm x-ui-linux-$(arch).tar.gz -f
    cd x-ui
    chmod +x x-ui

    # Check the system's architecture and rename the file accordingly
    if [[ $(arch) == "armv7" ]]; then
        mv bin/xray-linux-$(arch) bin/xray-linux-arm
        chmod +x bin/xray-linux-arm
    fi
    chmod +x x-ui bin/xray-linux-$(arch)
    cp -f x-ui.service /etc/systemd/system/
    wget --no-check-certificate -O /usr/bin/x-ui https://raw.githubusercontent.com/admin8800/x-ui/main/x-ui.sh
    chmod +x /usr/local/x-ui/x-ui.sh
    chmod +x /usr/bin/x-ui
    config_after_install
    rm /usr/local/x-ui-backup/ -rf
    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui
    echo -e "${green}x-ui ${last_version}${plain} 安装完成，服务现已运行..."
    echo -e ""
    echo -e "您可以通过以下 URL 访问面板:${yellow}"
    /usr/local/x-ui/x-ui uri
    echo -e "${plain}"
    echo "X-UI 控制菜单用法"
    echo "------------------------------------------"
    echo "子命令:"
    echo "x-ui              - 管理脚本"
    echo "x-ui start        - 启动"
    echo "x-ui stop         - 停止"
    echo "x-ui restart      - 重启"
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

echo -e "${green}正在运行...${plain}"
install_dependencies
install_x-ui $1
