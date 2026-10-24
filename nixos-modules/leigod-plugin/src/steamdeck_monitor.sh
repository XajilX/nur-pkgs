#!/bin/sh

# 通用进程守护脚本
# 监控两个进程：acc-gw.router 和 acc_upgrade_monitor

run_env=$1

# 日志目录配置
LOG_DIR="/tmp/acc/log"
LOG_FILE="$LOG_DIR/steamdeck_acc_monitor.log"

UPGRADE_FLAG="/tmp/acc/upgrade_flag"

# 创建日志目录（如果不存在）
mkdir -p "$LOG_DIR"

# 日志函数
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# 初始化日志
echo "=========================================" >> "$LOG_FILE"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting process monitor daemon" >> "$LOG_FILE"
echo "=========================================" >> "$LOG_FILE"

# 获取架构
arch=$(uname -m)
if [ ${arch} = "x86_64" ]; then
    log_message "match x86_64 -> amd64"
    arch="amd64"
elif [ ${arch} = "aarch64" ]; then
    log_message "match aarch64 -> arm64"
    arch="arm64"
elif [ ${arch} = "mips" ]; then
    log_message "match mips -> mipsel"
    arch="mipsel"
elif [ ${arch} = "armv7l" ]; then
    log_message "match armv7l -> arm"
    arch="arm"
else
    log_message "current arch not support, arch: ${arch}"
    exit 1
fi

# 获取 Steam Deck 安装目录
get_steamdeck_party() {
    local user_dir="/home/deck"
    if [ -d ${user_dir} ] ; then
        BASE_PATH="$user_dir/leigod"
    else
        BASE_PATH="/home/leigod"
    fi
    log_message "steamdeck plugin install directory is $BASE_PATH"
}

# 调用函数获取安装目录
get_steamdeck_party

# 单例锁文件路径（防止重复运行）
LOCK_FILE="/var/run/acc_daemon.lock"

# 守护的进程列表
# 格式：进程名:匹配参数:启动命令
if [ ${run_env} == "test" ]; then
    PROCESS_DATA="
    acc-gw.router.${arch}:-d debug -r daemon:${BASE_PATH}/acc-gw.router.${arch} -d debug -r daemon -m tun -p 5588
    acc_upgrade_monitor:-d debug -r upgrade:${BASE_PATH}/acc_upgrade_monitor -d debug -r upgrade"
else
    PROCESS_DATA="
    acc-gw.router.${arch}:-r daemon:${BASE_PATH}/acc-gw.router.${arch} -r daemon -m tun -p 5588
    acc_upgrade_monitor:-r upgrade:${BASE_PATH}/acc_upgrade_monitor -r upgrade"
fi

# 检查是否已有实例在运行
if [ -f "$LOCK_FILE" ]; then
    if kill -0 "$(cat "$LOCK_FILE")" 2>/dev/null; then
        log_message "[Monitor] Daemon is already running (PID: $(cat "$LOCK_FILE")). Exiting."
        exit 1
    else
        # 锁文件存在但进程已死，清理锁文件
        log_message "[Monitor] Removing stale lock file"
        rm -f "$LOCK_FILE"
    fi
fi

# 创建锁文件（写入当前PID）
echo $$ > "$LOCK_FILE"
#trap "rm -f '$LOCK_FILE'; log_message '[Monitor] Daemon stopped'; exit" INT TERM EXIT

# 检查进程是否存在（精确匹配参数）
is_process_running() {
    local process_name="$1"
    local pattern="$2"
    
    # 使用 pidof 获取进程PID
    pids=$(pidof "$process_name" 2>/dev/null)
    if [ -z "$pids" ]; then
        return 1
    fi
    
    # 遍历所有PID，检查命令行参数是否匹配
    for pid in $pids; do
        if [ -f "/proc/$pid/cmdline" ]; then
            # 读取进程命令行，将 \0 替换为空格
            cmdline=$(cat "/proc/$pid/cmdline" | tr '\0' ' ')
            # 检查是否包含指定的模式
            echo "$cmdline" | grep -qF -- "$pattern"
            if [ $? -eq 0 ]; then
                return 0  # 进程存在且匹配
            fi
        fi
    done
    return 1  # 进程不存在或不匹配
}

log_message "Monitor daemon started (PID: $$)"
log_message "Monitoring processes:"

# 主循环
while true; do
    # 判断是否正在升级，如果在升级则直接返回
    if [ -f ${UPGRADE_FLAG} ]; then
        echo "it's upgrading..."
        return
    fi

    # 使用临时文件存储进程状态，避免子shell问题
    echo "$PROCESS_DATA" | while IFS=":" read -r process_name pattern start_cmd; do
        # 跳过空行
        [ -z "$process_name" ] && continue
        
        # 去除可能的空格
        process_name=$(echo "$process_name" | xargs)
        pattern=$(echo "$pattern" | xargs)
        start_cmd=$(echo "$start_cmd" | xargs)
        
        # 检查进程是否存在
        if ! is_process_running "$process_name" "$pattern"; then
            log_message "Process not running: $process_name, starting..."
            log_message "Start command: $start_cmd"
            
            # 启动进程（后台运行）
            eval "$start_cmd >/dev/null 2>&1 </dev/null &"
            
            # 短暂等待，让进程启动
            sleep 1
            
            # 验证进程是否成功启动
            if is_process_running "$process_name" "$pattern"; then
                log_message "Successfully started: $process_name"
            else
                log_message "Failed to start: $process_name"
            fi
        fi
    done
    
    # 每5秒检查一次
    sleep 5
done
