#!/system/bin/sh
# Magisk Action 按钮脚本 — llama-server 启停控制
# 适用机型: Redmi Note 12 Turbo (骁龙 7+ Gen 2)
# 用法: Magisk 中点模块「运行」按钮 → 按音量键操作

# ============ 配置区 ============
BIN="/data/llama/llama-server"
MODEL_DIR="/data/llama/models"
LOG="/data/llama/llama.log"
LOG_MAX_SIZE=10485760         # 日志轮转阈值: 10MB（只打错误后基本不会触发）
PORT=8080
CTX=2048
DEFAULT_THREADS=4
LOG_VERBOSITY=0               # 0=仅错误 1=警告 2=信息(默认) 3=调试
# ================================

# ---------- 工具函数 ----------
is_running() {
    pgrep -f "[l]lama-server -m" >/dev/null 2>&1
}

get_pid() {
    pgrep -f "[l]lama-server -m" | tr '\n' ' '
}

calc_threads() {
    n=$(nproc 2>/dev/null || echo 4)
    if [ "$n" -gt 6 ]; then
        echo "$DEFAULT_THREADS"
    else
        echo "$n"
    fi
}

rotate_log() {
    [ -f "$LOG" ] || return 0
    size=$(stat -c %s "$LOG" 2>/dev/null || echo 0)
    if [ "$size" -gt "$LOG_MAX_SIZE" ]; then
        rm -f "$LOG.old"
        mv "$LOG" "$LOG.old" 2>/dev/null
        echo "日志已轮转 → $LOG.old"
    fi
}

# ---------- 启动 ----------
do_start() {
    if [ ! -f "$BIN" ]; then
        echo "✗ 二进制不存在: $BIN"
        return 1
    fi

    MODEL_PATH=$(ls "$MODEL_DIR"/*.gguf 2>/dev/null | head -n 1)
    if [ -z "$MODEL_PATH" ]; then
        echo "✗ $MODEL_DIR 下无 .gguf 模型"
        return 1
    fi

    THREADS=$(calc_threads)
    rotate_log

    echo "正在启动 llama-server ..."
    echo "模型: $(basename "$MODEL_PATH")"
    echo "线程: $THREADS  |  上下文: $CTX  |  端口: $PORT"
    echo "日志级别: $LOG_VERBOSITY (0=仅错误)"

    nohup "$BIN" \
        -m "$MODEL_PATH" \
        -c "$CTX" \
        -t "$THREADS" \
        --no-mmap \
        --host 0.0.0.0 \
        --port "$PORT" \
        --log-verbosity "$LOG_VERBOSITY" \
        > "$LOG" 2>&1 &

    sleep 2

    if is_running; then
        for p in $(get_pid); do
            echo -1000 > /proc/$p/oom_score_adj 2>/dev/null
            renice -5 -p "$p" >/dev/null 2>&1
        done
        echo "✓ 启动成功  PID: $(get_pid)"
        echo "✓ OOM 保护已启用 (oom_score_adj=-1000)"
    else
        echo "✗ 启动失败，日志尾部:"
        tail -n 20 "$LOG" 2>/dev/null
        echo ""
        echo "提示: 若日志为空, 尝试把 LOG_VERBOSITY 临时改为 2 再启动"
        return 1
    fi
}

# ---------- 停止 ----------
do_stop() {
    if ! is_running; then
        echo "没有运行中的进程"
        return 0
    fi

    echo "正在停止 llama-server (PID: $(get_pid)) ..."
    for p in $(get_pid); do
        kill "$p" 2>/dev/null
    done
    sleep 1
    if is_running; then
        for p in $(get_pid); do
            kill -9 "$p" 2>/dev/null
        done
    fi
    echo "✓ 已停止"
}

# ---------- 主流程 ----------
echo "================================"
echo "  llama-server 控制面板"
echo "  Redmi Note 12 Turbo / 7+ Gen 2"
echo "================================"
if is_running; then
    echo "状态: ● 运行中 (PID: $(get_pid))"
    echo "  [音量上] → 停止服务"
else
    echo "状态: ○ 未运行"
    echo "  [音量上] → 启动服务"
fi
echo "  [音量下] → 退出脚本"
echo "================================"
echo "等待按键 (最长 30 秒)..."
echo ""

KEY=""
i=0
while [ $i -lt 30 ]; do
    ev=$(timeout 1 getevent -lqc 1 2>/dev/null)
    case "$ev" in
        *KEY_VOLUMEUP*DOWN*)
            KEY="UP"
            break
            ;;
        *KEY_VOLUMEDOWN*DOWN*)
            KEY="DOWN"
            break
            ;;
    esac
    i=$((i + 1))
done

echo ""
case "$KEY" in
    UP)
        if is_running; then
            do_stop
        else
            do_start
        fi
        ;;
    DOWN)
        echo "已取消，未做任何操作"
        ;;
    *)
        echo "超时未检测到音量键，退出"
        ;;
esac