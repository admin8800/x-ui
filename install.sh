#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Fatal error: ${plain} Please run this script with root privilege \n " && exit 1

# Check OS and set release variable
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    release=$ID
elif [[ -f /usr/lib/os-release ]]; then
    source /usr/lib/os-release
    release=$ID
else
    echo "检查系统失败" >&2
    exit 1
fi
echo "操作系统版本是: $release"

arch() {
    case "$(uname -m)" in
    x86_64 | x64 | amd64) echo 'amd64' ;;
    i*86 | x86) echo '386' ;;
    armv8* | armv8 | arm64 | aarch64) echo 'arm64' ;;
    armv7* | armv7 | arm) echo 'armv7' ;;
    *) echo -e "${green}不支持的 CPU 架构！ ${plain}" && rm -f install.sh && exit 1 ;;
    esac
}
echo "arch: $(arch)"

os_version=""
os_version=$(grep -i version_id /etc/os-release | cut -d \" -f2 | cut -d . -f1)

if [[ "${release}" == "centos" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red} 请使用 CentOS 8 或更高版本! ${plain}\n" && exit 1
    fi
elif [[ "${release}" == "ubuntu" ]]; then
    if [[ ${os_version} -lt 20 ]]; then
        echo -e "${red}请使用Ubuntu 20或更高版本！ ${plain}\n" && exit 1
    fi

elif [[ "${release}" == "fedora" ]]; then
    if [[ ${os_version} -lt 36 ]]; then
        echo -e "${red}请使用Fedora 36或更高版本！ ${plain}\n" && exit 1
    fi

elif [[ "${release}" == "debian" ]]; then
    if [[ ${os_version} -lt 10 ]]; then
        echo -e "${red} 请使用 Debian 10 或更高版本 ${plain}\n" && exit 1
    fi
else
    echo -e "${red}无法检查操作系统版本!${plain}" && exit 1
fi

install_dependencies() {
    case "${release}" in
    centos)
        yum -y update && yum install -y -q wget curl tar tzdata
        ;;
    fedora)
        dnf -y update && dnf install -y -q wget curl tar tzdata
        ;;
    *)
        apt-get update && apt install -y -q wget curl tar tzdata
        ;;
    esac
}

#This function will be called when user installed x-ui out of security
config_after_install() {
    echo -e "${yellow}安装/更新已完成！为了安全起见，建议修改面板设置 ${plain}"
    read -p "是否要继续修改 [y/n]? ": config_confirm
    if [[ "${config_confirm}" == "y" || "${config_confirm}" == "Y" ]]; then
        read -p "请设置您的用户名:" config_account
        echo -e "${yellow}您的用户名是:${config_account}${plain}"
        read -p "请设置您的密码:" config_password
        echo -e "${yellow}您的密码是:${config_password}${plain}"
        read -p "请设置面板端口:" config_port
        echo -e "${yellow}您的面板端口是:${config_port}${plain}"
        echo -e "${yellow}正在初始化，请等待...${plain}"
        /usr/local/x-ui/x-ui setting -username ${config_account} -password ${config_password}
        echo -e "${yellow}账户名及密码设置成功!${plain}"
        /usr/local/x-ui/x-ui setting -port ${config_port}
        echo -e "${yellow}面板端口设置成功!${plain}"
    else
        echo -e "${red}cancel...${plain}"
        if [[ ! -f "/etc/x-ui/x-ui.db" ]]; then
            local usernameTemp=$(head -c 6 /dev/urandom | base64)
            local passwordTemp=$(head -c 6 /dev/urandom | base64)
            /usr/local/x-ui/x-ui setting -username ${usernameTemp} -password ${passwordTemp}
            echo -e "这是全新安装，出于安全考虑将生成随机登录信息:"
            echo -e "###############################################"
            echo -e "${green}用户名:${usernameTemp}${plain}"
            echo -e "${green}密码:${passwordTemp}${plain}"
            echo -e "${green}面板端口：54321${plain}"
            echo -e "###############################################"
            echo -e "${red}如果你忘记了登录信息，你可以在安装后输入 x-ui 然后输入 8 进行检查${plain}"
        else
            echo -e "${red} 这是你的升级，将保留旧设置，如果你忘记了登录信息，你可以输入 x-ui 然后输入 8 进行检查${plain}"
        fi
    fi
    /usr/local/x-ui/x-ui migrate
}

install_x-ui() {
    # checks if the installation backup dir exist. if existed then ask user if they want to restore it else continue installation.
    if [[ -e /usr/local/x-ui-backup/ ]]; then
        read -p "检测到安装失败。是否要恢复之前安装的版本? [y/n]? ": restore_confirm
        if [[ "${restore_confirm}" == "y" || "${restore_confirm}" == "Y" ]]; then
            systemctl stop x-ui
            mv /usr/local/x-ui-backup/x-ui.db /etc/x-ui/ -f
            mv /usr/local/x-ui-backup/ /usr/local/x-ui/ -f
            systemctl start x-ui
            echo -e "${green}之前安装的 x-ui 恢复成功${plain}, 它现已启动并运行..."
            exit 0
        else
            echo -e "继续安装 x-ui ..."
        fi
    fi

    cd /usr/local/

    if [ $# == 0 ]; then
        last_version=$(curl -Ls "https://api.github.com/repos/admin8800/x-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}Failed to fetch x-ui version, it maybe due to Github API restrictions, please try it later${plain}"
            exit 1
        fi
        echo -e "获得 x-ui 最新版本: ${last_version}, 开始安装..."
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-$(arch).tar.gz https://github.com/admin8800/x-ui/releases/download/${last_version}/x-ui-linux-$(arch).tar.gz
        if [[ $? -ne 0 ]]; then
            echo -e "${red}下载x-ui失败，请确保你的服务器可以访问Github ${plain}"
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/admin8800/x-ui/releases/download/${last_version}/x-ui-linux-$(arch).tar.gz"
        echo -e "开始安装x-ui v$1"
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-$(arch).tar.gz ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}download x-ui v$1 失败${plain}"
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
    #echo -e "If it is a new installation, the default web port is ${green}54321${plain}, The username and password are ${green}admin${plain} by default"
    #echo -e "Please make sure that this port is not occupied by other procedures,${yellow} And make sure that port 54321 has been released${plain}"
    #    echo -e "If you want to modify the 54321 to other ports and enter the x-ui command to modify it, you must also ensure that the port you modify is also released"
    #echo -e ""
    #echo -e "If it is updated panel, access the panel in your previous way"
    #echo -e ""
    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui
    echo -e "${green}x-ui ${last_version}${plain} 安装完成，现在可以运行了..."
    echo -e ""
    echo "X-UI 控制菜单"
    echo "------------------------------------------"
    echo "命令:"
    echo "x-ui              - 打开菜单"
    echo "x-ui start        - 启动"
    echo "x-ui stop         - 停止"
    echo "x-ui restart      - 重启"
    echo "x-ui status       - 当前状态"
    echo "x-ui enable       - 启用开机自启"
    echo "x-ui disable      - 禁用开机自启"
    echo "x-ui log          - 检查日志"
    echo "x-ui update       - 更新"
    echo "x-ui install      - 安装"
    echo "x-ui uninstall    - 卸载"
    echo "x-ui help         - 帮助"
    echo "------------------------------------------"
}

echo -e "${green}运行中...${plain}"
install_dependencies
install_x-ui $1