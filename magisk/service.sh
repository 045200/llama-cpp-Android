#!/system/bin/sh
# Magisk 延迟自启脚本
# 在系统完全启动后执行

# 延迟 60 秒，等待系统 IO 和后台应用初始化完成
sleep 60

# 检查二进制是否存在
if [ ! -f "/data/llama/llama-server" ]; then
    echo "llama-server: 二进制不存在，跳过自启" > /dev/kmsg
    exit 1
fi

# 检查模型目录是否有模型（避免空转）
if [ -z "$(ls -A /data/llama/models/*.gguf 2>/dev/null)" ]; then
    echo "llama-server: /data/llama/models/ 下无 .gguf 模型，跳过自启" > /dev/kmsg
    exit 1
fi

# 设置 OOM 优先级（-1000 为最高优先级，尽可能防止被杀死）
# 注意：此处先启动进程再调优先级，脚本稍后处理
echo "llama-server: 延迟启动中..." > /dev/kmsg

# 启动 llama-server 守护进程
# - 模型路径：自动选取 /data/llama/models/ 下第一个 .gguf 文件
# - 上下文限制 2048（稳内存），线程数 4，监听所有 IP
MODEL_PATH=$(ls /data/llama/models/*.gguf | head -n 1)

nohup /data/llama/llama-server \
    -m "$MODEL_PATH" \
    -c 2048 \
    -t 4 \
    --host 0.0.0.0 \
    --port 8080 \
    > /data/llama/llama.log 2>&1 &

# 获取进程 PID 并调高优先级（防止被 LMK 误杀）
sleep 2
PID=$(pgrep -f "llama-server -m")
if [ -n "$PID" ]; then
    # oom_score_adj 范围 -1000 ~ 1000，-1000 表示几乎不会被杀死
    echo -1000 > /proc/$PID/oom_score_adj 2>/dev/null
    # 提升 nice 级别（-20 最高优先级，但可能影响 UI，此处用 -5 平衡）
    renice -5 -p $PID 2>/dev/null
    echo "llama-server: 启动成功，PID=$PID，OOM保护已启用" > /dev/kmsg
else
    echo "llama-server: 启动失败，请检查 /data/llama/llama.log" > /dev/kmsg
fi