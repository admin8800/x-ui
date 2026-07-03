# X-UI
**高级 Web 管理面板 • 基于 Xray Core 构建**

![](https://img.shields.io/github/v/release/admin8800/x-ui.svg)
![](https://img.shields.io/docker/pulls/alireza7/x-ui.svg)
[![Go Report Card](https://goreportcard.com/badge/github.com/admin8800/x-ui)](https://goreportcard.com/report/github.com/admin8800/x-ui)
[![Downloads](https://img.shields.io/github/downloads/admin8800/x-ui/total.svg)](https://img.shields.io/github/downloads/admin8800/x-ui/total.svg)
[![License](https://img.shields.io/badge/license-GPL%20V3-blue.svg?longCache=true)](https://www.gnu.org/licenses/gpl-3.0.en.html)


## 功能概览
| 功能                                   |      是否支持       |
| -------------------------------------- | :----------------: |
| 多协议支持                             | :heavy_check_mark: |
| 多语言                                 | :heavy_check_mark: |
| 多客户端/入站                          | :heavy_check_mark: |
| 高级流量路由界面                       | :heavy_check_mark: |
| 客户端、流量与系统状态                 | :heavy_check_mark: |
| 基于首次使用的日期与流量限制           | :heavy_check_mark: |
| REST API                               | :heavy_check_mark: |
| TG 机器人（数据库备份 + 管理 + 客户端）| :heavy_check_mark: |
| 订阅服务（链接 + 信息）                | :heavy_check_mark: |
| 深度搜索                               | :heavy_check_mark: |
| 深色/浅色主题                          | :heavy_check_mark: |
| 每客户端 IP 限制（仅 Linux）           | :heavy_check_mark:* |
  
## 安装与升级到最新版本

```sh
bash <(curl -Ls https://raw.githubusercontent.com/admin8800/x-ui/master/install.sh)
```

## 手动安装与升级

<details>
  <summary>点击展开详情</summary>
  
### 使用方法

1. 确保已安装所需软件包（安装脚本会自动完成此步骤，手动安装时才需要执行）：

```sh
# Debian/Ubuntu
apt-get update && apt-get install -y wget curl tar tzdata cron ca-certificates nftables
# CentOS/Alma/Rocky/Fedora
# yum install -y wget curl tar tzdata cronie ca-certificates nftables
# Arch/Manjaro
# pacman -Syu --noconfirm wget curl tar tzdata cronie ca-certificates nftables
```

> `ca-certificates` 用于 HTTPS/TLS 连接，`nftables` 为每客户端 IP 限制功能所需。

2. 若要将最新版本的压缩包直接下载到服务器，运行以下命令：

```sh
ARCH=$(uname -m)
case "${ARCH}" in
  x86_64 | x64 | amd64) XUI_ARCH="amd64" ;;
  i*86 | x86) XUI_ARCH="386" ;;
  armv8* | armv8 | arm64 | aarch64) XUI_ARCH="arm64" ;;
  armv7* | armv7) XUI_ARCH="armv7" ;;
  *) XUI_ARCH="amd64" ;;
esac

wget https://github.com/admin8800/x-ui/releases/latest/download/x-ui-linux-${XUI_ARCH}.tar.gz
```

3. 压缩包下载完成后，执行以下命令安装或升级 x-ui：

```sh
ARCH=$(uname -m)
case "${ARCH}" in
  x86_64 | x64 | amd64) XUI_ARCH="amd64" ;;
  i*86 | x86) XUI_ARCH="386" ;;
  armv8* | armv8 | arm64 | aarch64) XUI_ARCH="arm64" ;;
  armv7* | armv7) XUI_ARCH="armv7" ;;
  *) XUI_ARCH="amd64" ;;
esac
cd /root/
rm x-ui/ /usr/local/x-ui/ /usr/bin/x-ui -rf
tar zxvf x-ui-linux-${XUI_ARCH}.tar.gz
chmod +x x-ui/x-ui x-ui/bin/xray-linux-* x-ui/x-ui.sh
cp x-ui/x-ui.sh /usr/bin/x-ui
cp -f x-ui/x-ui.service /etc/systemd/system/
mv x-ui/ /usr/local/
systemctl daemon-reload
systemctl enable x-ui
systemctl restart x-ui
```

</details>

## 使用 Docker 安装

<details>
   <summary>点击展开详情</summary>

### 使用方法

**步骤 1：** 安装 Docker

```shell
curl -fsSL https://get.docker.com | sh
```

**步骤 2：** 克隆项目仓库：

   ```sh
   git clone https://github.com/admin8800/x-ui.git
   cd x-ui
   ```

**步骤 3：** 启动服务

   ```sh
   docker compose up -d
   ```

   或者

```shell
mkdir x-ui && cd x-ui

docker run -itd \
    --network host \
    -e XRAY_VMESS_AEAD_FORCED=false \
    -v $PWD/db/:/etc/x-ui/ \
    -v $PWD/cert/:/root/cert/ \
    --name x-ui --restart=always \
    admin8800/x-ui
```

升级到最新版本

   ```sh
    cd x-ui
    docker compose down
    docker compose pull x-ui
    docker compose up -d
   ```

从 Docker 中移除 x-ui

   ```sh
    docker stop x-ui
    docker rm x-ui
    cd --
    rm -r x-ui
   ```

> 自行构建镜像

```shell
docker build -t x-ui .
```

</details>

## 支持语言

- 英语
- 中文
- 波斯语
- 俄语
- 越南语

## 功能特性

- 支持 VLESS、VMess、Trojan、Shadowsocks、Dokodemo-door、SOCKS、HTTP、Wireguard 等协议
- 支持 XTLS 协议，包括 Vision 和 REALITY
- 高级流量路由界面，支持 PROXY Protocol、Reverse、External、透明代理，以及多域名、SSL 证书和端口配置
- 支持通过 Wireguard 出站自动生成 Cloudflare WARP
- 交互式 JSON 界面用于 Xray 模板配置
- 高级入站和出站配置界面
- 基于首次使用的客户端流量限制和到期日期
- 每客户端 IP 限制，超出允许的并发 IP 数量时阻止连接（基于 nftables）
- 显示在线客户端、流量统计和系统状态监控
- 深度数据库搜索
- 显示流量耗尽或已到期的客户端
- 订阅服务（支持多链接）
- 数据库导入和导出
- 一键 SSL 证书申请与自动续期
- 为 Web 面板和订阅服务提供 HTTPS 访问（需自备域名 + SSL 证书）
- 深色/浅色主题

## 界面预览

![inbounds](./media/inbounds.png)
![Dark inbounds](./media/inbounds-dark.png)
![outbounds](./media/outbounds.png)
![rules](./media/rules.png)
![warp](./media/warp.png)


## API 路由

<details>
  <summary>点击展开详情</summary>

### 使用方法

- `/login` 使用 `POST` 提交用户数据：`{username: '', password: ''}` 进行登录
- `/xui/API/inbounds` 基础路径，支持以下操作：

| 方法 | 路径                               | 操作                                      |
| :----: | ---------------------------------  | ----------------------------------------- |
| `GET`  | `"/"`                              | 获取所有入站                                |
| `GET`  | `"/get/:id"`                       | 根据 inbound.id 获取入站                    |
| `POST` | `"/add"`                           | 添加入站                                    |
| `POST` | `"/del/:id"`                       | 删除入站                                    |
| `POST` | `"/update/:id"`                    | 更新入站                                    |
| `POST` | `"/addClient/"`                    | 向入站添加客户端                            |
| `POST` | `"/:id/delClient/:clientId"`       | 根据 clientId 删除客户端*                   |
| `POST` | `"/updateClient/:clientId"`        | 根据 clientId 更新客户端*                   |
| `GET`  | `"/getClientTraffics/:email"`      | 获取客户端流量                              |
| `GET`  | `"/getClientTrafficsById/:id"`     | 根据 ID 获取客户端流量                      |
| `POST` | `"/:id/resetClientTraffic/:email"` | 重置客户端流量                              |
| `POST` | `"/resetAllTraffics"`              | 重置所有入站流量                            |
| `POST` | `"/resetAllClientTraffics/:id"`    | 重置入站客户端流量（-1 表示全部）           |
| `POST` | `"/delDepletedClients/:id"`        | 删除入站已耗尽客户端（-1 表示全部）         |
| `POST` | `"/import"`                        | 从导出数据导入入站                          |
| `POST` | `"/onlines"`                       | 获取在线用户（邮箱列表）                    |


- `clientId` 字段应按以下方式填写：
  - VMess 和 VLESS 使用 `client.id`
  - Trojan 使用 `client.password`
  - Shadowsocks 使用 `client.email`


- `/xui/API/outbounds` 基础路径，支持以下操作：

| 方法 | 路径                               | 操作                                      |
| :----: | ---------------------------------  | ----------------------------------------- |
| `GET`  | `"/"`                              | 获取所有出站                                |
| `POST` | `"/add"`                           | 添加出站                                    |
| `POST` | `"/del/:id"`                       | 删除出站                                    |
| `POST` | `"/update/:id"`                    | 更新出站                                    |
| `POST` | `"/setFirst/:id"`                  | 将出站移至列表顶部                          |
| `POST` | `"/:id/resetTraffic"`              | 重置出站流量                                |
| `POST` | `"/resetAllTraffics"`             | 重置所有出站流量                            |
| `POST` | `"/onlines"`                       | 获取在线出站标签                            |
| `POST` | `"/test"`                          | 测试出站连通性                              |
| `POST` | `"/reverseTags"`                   | 获取客户端反向标签（可用作拨号器）          |


- `/xui/API/routing` 基础路径，支持以下操作：

| 方法 | 路径                               | 操作                                      |
| :----: | ---------------------------------  | ----------------------------------------- |
| `GET`  | `"/"`                              | 获取所有路由规则                            |
| `GET`  | `"/refs"`                          | 获取路由引用（标签和元数据）                |
| `POST` | `"/save"`                          | 保存路由规则                                |
| `POST` | `"/replaceBalancerTag"`            | 在路由规则中替换负载均衡标签                |


- `/xui/API/server` 基础路径，支持以下操作：

| 方法 | 路径                               | 操作                                      |
| :----: | ---------------------------------  | ----------------------------------------- |
| `GET`  | `"/status"`                        | 获取服务器状态                              |
| `GET`  | `"/getDb"`                         | 获取数据库备份                              |
| `GET`  | `"/createbackup"`                  | Telegram 机器人向管理员发送备份             |
| `GET`  | `"/getConfigJson"`                 | 获取 config.json                            |
| `GET`  | `"/getXrayVersion"`                | 获取最新 xray 版本                          |
| `GET`  | `"/getNewVlessEnc"`                | 获取新的 vless 加密                         |
| `GET`  | `"/getNewX25519Cert"`              | 获取新的 x25519 证书                        |
| `GET`  | `"/getNewmldsa65"`                 | 获取新的 mldsa65                            |
| `POST` | `"/getNewEchCert"`                 | 获取新的 ech 证书                           |
| `POST` | `"/getCertHash"`                   | 获取所提供证书的哈希                        |
| `POST` | `"/getTlsPing"`                    | 通过 TLS ping 获取哈希                      |
| `POST` | `"/importDB"`                      | 导入数据库到 x-ui                           |
| `POST` | `"/stopXrayService"`               | 停止 xray 服务                              |
| `POST` | `"/restartXrayService"`            | 重启 xray 服务                              |
| `POST` | `"/installXray/:version"`          | 安装指定版本的 xray                         |
| `POST` | `"/logs/:count"`                   | 获取面板/xray 日志                          |


</details>

## 环境变量

<details>
  <summary>点击展开详情</summary>

### 使用方法

| 变量           |                      类型                      | 默认值        |
| -------------- | :--------------------------------------------: | :------------ |
| XUI_LOG_LEVEL  | `"debug"` \| `"info"` \| `"warn"` \| `"error"` | `"info"`      |
| XUI_DEBUG      |                   `boolean`                    | `false`       |
| XUI_BIN_FOLDER |                    `string`                    | `"bin"`       |
| XUI_DB_FOLDER  |                    `string`                    | `"/etc/x-ui"` |

</details>

## SSL 证书

<details>
  <summary>点击展开详情</summary>

### Cloudflare

管理脚本内置了 Cloudflare SSL 证书申请功能。使用此脚本申请证书需要以下信息：

- Cloudflare 注册邮箱
- Cloudflare Global API Key
- 已通过 Cloudflare 解析 DNS 到当前服务器的域名

**步骤 1：** 在服务器终端运行 `x-ui` 命令，然后选择 `19`（Cloudflare SSL 证书）。按提示输入相关信息。


### Certbot

```bash
snap install core; snap refresh core
snap install --classic certbot
ln -s /snap/bin/certbot /usr/bin/certbot

certbot certonly --standalone --register-unsafely-without-email --non-interactive --agree-tos -d <您的域名>
```

</details>

## Telegram 机器人

<details>
  <summary>点击展开详情</summary>

### 使用方法

Web 面板支持通过 Telegram 机器人发送每日流量、面板登录、数据库备份、系统状态、客户端信息等通知和功能。使用机器人需要在面板中设置相关参数，包括：

- Telegram Token
- 管理员 Chat ID
- 通知时间（cron 语法）
- 数据库备份
- CPU 负载阈值通知

**Crontab 时间格式**

参考语法：

- `*/30 * * * *` - 每 30 分钟通知一次
- `30 * * * * *` - 每分钟的第 30 秒通知
- `0 */10 * * * *` - 每 10 分钟开始时通知
- `@hourly` - 每小时通知
- `@daily` - 每日通知（凌晨 00:00）
- `@every 8h` - 每 8 小时通知

更多关于 [Crontab](https://acquia.my.site.com/s/article/360004224494-Cron-time-string-format) 的信息

### 功能

- 定期报告
- 登录通知
- CPU 负载阈值通知
- 到期时间和流量的提前通知
- 客户端报告菜单（支持 Telegram ID 或配置中的用户名）
- 匿名流量报告，按 UUID（VLESS/VMess）或密码（Trojan/Shadowsocks）搜索
- 菜单式机器人
- 按邮箱搜索客户端（仅管理员）
- 入站检查
- 系统状态检查
- 已耗尽客户端检查
- 按需备份和定期报告中的备份
- 多语言支持
</details>

## 故障排查

<details>
  <summary>点击展开详情</summary>

### 启用流量统计

如果您从旧版本或其他分支升级，发现客户端流量统计可能默认不工作，请按以下步骤启用：

**步骤 1：定位配置部分**

在配置文件中找到以下部分：

```json
  "policy": {
    "system": {
      // 其他 policy 配置
    }
  },
```
**步骤 2：添加所需配置**

在 `"policy": {` 之后添加以下部分：

```json
"levels": {
  "0": {
    "statsUserUplink": true,
    "statsUserDownlink": true
  }
},
```
**步骤 3：最终配置**

最终配置应如下所示：

```json
"policy": {
  "levels": {
    "0": {
      "statsUserUplink": true,
      "statsUserDownlink": true
    }
  },
  "system": {
    "statsInboundDownlink": true,
    "statsInboundUplink": true
  }
},
"routing": {
  // 其他 routing 配置
},
```
**步骤 4：保存并重启**

保存更改并重启 Xray 服务
</details>

## 特别感谢

https://github.com/alireza0/x-ui
