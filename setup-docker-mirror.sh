#!/usr/bin/env bash

# Docker 国内镜像源一键安装配置脚本
# 支持 Linux, macOS, Windows (Git Bash/Cygwin)
# GitHub: https://github.com/yourusername/docker-mirror-setup

set -e

REGISTRY_MIRROR="https://docker.xuanyuan.me"
SCRIPT_VERSION="v1.0.0"
GITHUB_REPO="https://github.com/SolaTyolo/docker-mirror-setup"

# 颜色输出定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 检测操作系统和Docker状态
detect_environment() {
    log_info "检测运行环境..."
    
    # 检测操作系统
    case "$(uname -s)" in
        Linux*)     OS_TYPE="Linux" ;;
        Darwin*)    OS_TYPE="macOS" ;;
        CYGWIN*|MINGW*|MSYS*) OS_TYPE="Windows" ;;
        *)          OS_TYPE="UNKNOWN" ;;
    esac
    
    # 检测Linux发行版
    if [ "$OS_TYPE" = "Linux" ]; then
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            OS_DISTRO="$ID"
            OS_VERSION="$VERSION_ID"
        elif type lsb_release >/dev/null 2>&1; then
            OS_DISTRO=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
            OS_VERSION=$(lsb_release -sr)
        fi
    fi
    
    # 检测Docker
    if command -v docker &> /dev/null; then
        DOCKER_INSTALLED=true
        DOCKER_VERSION=$(docker --version | head -n1)
    else
        DOCKER_INSTALLED=false
    fi
    
    # 检测Docker Compose
    if command -v docker-compose &> /dev/null; then
        COMPOSE_INSTALLED=true
    else
        COMPOSE_INSTALLED=false
    fi
    
    # 显示检测结果
    echo "========================================"
    echo "操作系统:      $OS_TYPE"
    [ "$OS_DISTRO" ] && echo "Linux发行版:  $OS_DISTRO $OS_VERSION"
    echo "Docker状态:   $([ "$DOCKER_INSTALLED" = true ] && echo "已安装 ($DOCKER_VERSION)" || echo "未安装")"
    echo "镜像源地址:   $REGISTRY_MIRROR"
    echo "脚本版本:     $SCRIPT_VERSION"
    echo "========================================"
    echo ""
}

# 安装Linux Docker
install_docker_linux() {
    log_info "开始安装 Docker for Linux ($OS_DISTRO)..."
    
    # 卸载旧版本
    sudo apt-get remove -y docker docker-engine docker.io containerd runa 2>/dev/null || true
    sudo yum remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine 2>/dev/null || true
    
    # 安装依赖
    case "$OS_DISTRO" in
        ubuntu|debian)
            sudo apt-get update
            sudo apt-get install -y \
                apt-transport-https \
                ca-certificates \
                curl \
                gnupg \
                lsb-release
            ;;
        centos|rhel|fedora)
            sudo yum install -y yum-utils
            ;;
    esac
    
    # 添加Docker官方GPG密钥
    curl -fsSL https://download.docker.com/linux/$OS_DISTRO/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # 设置稳定版仓库
    case "$OS_DISTRO" in
        ubuntu)
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
            $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            sudo apt-get update
            sudo apt-get install -y docker-ce docker-ce-cli containerd.io
            ;;
        centos)
            sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            sudo yum install -y docker-ce docker-ce-cli containerd.io
            ;;
    esac
    
    # 启动Docker服务
    sudo systemctl start docker
    sudo systemctl enable docker
    
    # 添加当前用户到docker组（避免每次sudo）
    sudo usermod -aG docker $USER
    log_success "Docker 安装完成！请重新登录以使用docker命令（无需sudo）"
}

# 配置镜像源
configure_mirror() {
    log_info "配置 Docker 镜像源..."
    
    case "$OS_TYPE" in
        Linux)
            # 创建配置目录
            sudo mkdir -p /etc/docker
            
            # 检查是否已有配置
            if [ -f /etc/docker/daemon.json ]; then
                log_warn "检测到现有 daemon.json 配置，将备份并添加镜像源"
                sudo cp /etc/docker/daemon.json /etc/docker/daemon.json.bak
                
                # 使用jq添加镜像源（如果可用）
                if command -v jq >/dev/null 2>&1; then
                    sudo cat /etc/docker/daemon.json | jq '."registry-mirrors" |= (.[] | select(. != "'$REGISTRY_MIRROR'")) + ["'$REGISTRY_MIRROR'"]' | sudo tee /etc/docker/daemon.json.tmp > /dev/null
                    sudo mv /etc/docker/daemon.json.tmp /etc/docker/daemon.json
                else
                    # 如果没有jq，创建新配置
                    sudo tee /etc/docker/daemon.json << EOF
{
  "registry-mirrors": ["$REGISTRY_MIRROR"],
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF
                fi
            else
                # 创建新配置
                sudo tee /etc/docker/daemon.json << EOF
{
  "registry-mirrors": ["$REGISTRY_MIRROR"],
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF
            fi
            
            # 重启Docker服务
            sudo systemctl daemon-reload
            sudo systemctl restart docker
            log_success "Linux 镜像源配置完成"
            ;;
            
        macOS|Windows)
            log_warn "$OS_TYPE 需要手动配置 Docker Desktop"
            echo ""
            echo "请按以下步骤操作："
            echo "1. 打开 Docker Desktop"
            echo "2. 点击设置 (Settings/Preferences)"
            echo "3. 选择 'Docker Engine' 标签"
            echo "4. 在配置文件中添加以下内容："
            echo ""
            echo "   \"registry-mirrors\": [\"$REGISTRY_MIRROR\"]"
            echo ""
            echo "5. 点击 'Apply & Restart'"
            echo ""
            echo "或者，对于macOS，你也可以运行以下命令："
            echo "  cat > ~/.docker/daemon.json << EOF"
            echo "  {"
            echo "    \"registry-mirrors\": [\"$REGISTRY_MIRROR\"]"
            echo "  }"
            echo "  EOF"
            echo ""
            read -p "配置完成后按回车键继续..."
            ;;
    esac
}

# 安装Docker Compose
install_docker_compose() {
    if [ "$COMPOSE_INSTALLED" = false ]; then
        log_info "安装 Docker Compose..."
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
            -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        
        # 创建软链接（如果需要）
        if [ ! -f /usr/bin/docker-compose ]; then
            sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
        fi
        
        log_success "Docker Compose 安装完成"
    fi
}

# 验证安装
verify_installation() {
    log_info "验证 Docker 安装和配置..."
    
    if command -v docker &> /dev/null; then
        log_success "Docker 命令可用"
        
        # 测试镜像源
        echo ""
        echo "当前 Docker 镜像源配置："
        docker info 2>/dev/null | grep -A 5 "Registry Mirrors" || \
            echo "  (如果输出为空，可能需要重启终端或Docker服务)"
        
        echo ""
        log_info "正在测试镜像下载速度..."
        
        # 测试拉取一个小镜像
        start_time=$(date +%s)
        if docker pull hello-world:latest > /tmp/docker_test.log 2>&1; then
            end_time=$(date +%s)
            elapsed=$((end_time - start_time))
            log_success "镜像拉取成功！耗时 ${elapsed} 秒"
            
            # 运行测试容器
            if docker run --rm hello-world > /tmp/hello-world.log 2>&1; then
                log_success "Docker 运行正常！"
                echo ""
                echo "🎉 所有配置已完成！"
                echo ""
                echo "接下来你可以："
                echo "1. 运行 'docker images' 查看已下载的镜像"
                echo "2. 运行 'docker run -it ubuntu bash' 测试Ubuntu容器"
                echo "3. 访问 $GITHUB_REPO 获取更多帮助"
            fi
        else
            log_error "镜像拉取失败，请检查网络或配置"
            echo "错误日志："
            tail -n 10 /tmp/docker_test.log
        fi
    else
        log_error "Docker 安装可能有问题，请检查以上步骤"
    fi
}

# 显示帮助信息
show_help() {
    echo "使用说明:"
    echo "  $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help     显示此帮助信息"
    echo "  -v, --version  显示版本信息"
    echo "  -m, --mirror URL  使用指定的镜像源"
    echo ""
    echo "示例:"
    echo "  $0                     # 使用默认镜像源"
    echo "  $0 --mirror https://mirror.aliyuncs.com  # 使用阿里云镜像"
    echo ""
    echo "支持的镜像源示例:"
    echo "  https://docker.xuanyuan.me       # 轩辕镜像"
    echo "  https://registry.docker-cn.com   # Docker中国官方"
    echo "  https://mirror.aliyuncs.com      # 阿里云"
    echo "  https://mirror.ccs.tencentyun.com # 腾讯云"
}

# 主函数
main() {
    echo ""
    echo "========================================"
    echo "  Docker 一键安装与国内镜像源配置脚本  "
    echo "========================================"
    
    # 处理参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                echo "版本: $SCRIPT_VERSION"
                exit 0
                ;;
            -m|--mirror)
                REGISTRY_MIRROR="$2"
                shift 2
                ;;
            *)
                log_error "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 检测环境
    detect_environment
    
    # 检查是否已安装
    if [ "$DOCKER_INSTALLED" = false ]; then
        case "$OS_TYPE" in
            Linux)
                read -p "是否安装 Docker？(y/N): " choice
                if [ "$choice" = "y" ] || [ "$choice" = "Y" ]; then
                    install_docker_linux
                    install_docker_compose
                else
                    log_info "跳过 Docker 安装"
                fi
                ;;
            macOS|Windows)
                log_warn "$OS_TYPE 系统需要手动安装 Docker Desktop"
                echo ""
                echo "请先下载安装 Docker Desktop："
                echo "  - macOS: https://docs.docker.com/desktop/mac/install/"
                echo "  - Windows: https://docs.docker.com/desktop/windows/install/"
                echo ""
                read -p "安装完成后按回车键继续..."
                ;;
            *)
                log_error "不支持的操作系统: $OS_TYPE"
                exit 1
                ;;
        esac
    else
        log_success "Docker 已安装"
    fi
    
    # 配置镜像源
    read -p "是否配置国内镜像源？(Y/n): " choice
    if [ "$choice" != "n" ] && [ "$choice" != "N" ]; then
        configure_mirror
    fi
    
    # 验证安装
    verify_installation
    
    # 清理临时文件
    rm -f /tmp/docker_test.log /tmp/hello-world.log 2>/dev/null || true
}

# 运行主函数
main "$@"