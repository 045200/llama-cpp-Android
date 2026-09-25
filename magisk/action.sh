#!/system/bin/sh
# Magisk Action 按钮脚本 — llama-server 启停控制
# 用法：Magisk 中点模块「运行」按钮 → 按音量键操作

BIN="/data/llama/llama-server"
MODEL_DIR="/data/llama/models"
LOG="/data/llama/llama.log"
PORT=8080
CTX=2048
THREADS=4

# ---------- 工具函数 ----------
is_running() {
    pgrep -f "[l]lama-server -m" >/dev/null 2>&1
}

get_pid() {
    pgrep -f "[l]lama-server -m" | tr '\n' ' '
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

    echo "正在启动 llama-server ..."
    echo "模型: $(basename "$MODEL_PATH")"

    nohup "$BIN" \
        -m "$MODEL_PATH" \
        -c "$CTX" \
        -t "$THREADS" \
        --host 0.0.0.0 \
        --port "$PORT" \
        > "$LOG" 2>&1 &

    sleep 2

    if is_running; then
        for p in $(get_pid); do
            echo -1000 > /proc/$p/oom_score_adj 2>/dev/null
            renice -5 -p "$p" >/dev/null 2>&1
        done
        echo "✓ 启动成功  PID: $(get_pid)"
        echo "✓ OOM 保护已启用"
    else
        echo "✗ 启动失败，日志尾部:"
        tail -n 10 "$LOG" 2>/dev/null
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
    # 兜底强杀
    if is_running; then
        for p in $(get_pid); do
            kill -9 "$p" 2>/dev/null
        done
    fi
    echo "✓ 已停止"
}

# ---------- 主流程 ----------
echo "================================"
echo "     llama-server 控制面板"
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
    # -l 标签化输出, -q 静默, -c 1 读完 1 个事件就退出
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