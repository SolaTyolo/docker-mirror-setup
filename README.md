# Docker 一键安装与国内镜像源配置脚本

![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20macOS%20%7C%20Windows-blue)
![Shell](https://img.shields.io/badge/Shell-Bash-green)
![License](https://img.shields.io/badge/License-MIT-yellow)

一个跨平台的 Docker 安装配置脚本，自动配置国内镜像源加速下载。

## 🚀 一键安装执行

打开终端，执行以下命令：

```bash
# 方法1：直接下载执行
bash <(curl -sL https://raw.githubusercontent.com/SolaTyolo/docker-mirror-setup/main/setup_docker_mirror.sh)

# 方法2：先下载后执行
curl -O https://raw.githubusercontent.com/SolaTyolo/docker-mirror-setup/main/setup_docker_mirror.sh
chmod +x setup_docker_mirror.sh
./setup_docker_mirror.sh

# 方法3：使用wget
bash <(wget -qO- https://raw.githubusercontent.com/SolaTyolo/docker-mirror-setup/main/setup_docker_mirror.sh)