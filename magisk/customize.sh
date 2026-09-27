#!/system/bin/sh

ui_print "****************************************"
ui_print "    llama-server 安装器 (手动执行版)"
ui_print "    版本: $(grep version $MODPATH/module.prop | cut -d= -f2)"
ui_print "****************************************"

TARGET_DIR="/data/llama"

ui_print "-> 创建目录: $TARGET_DIR"
mkdir -p "$TARGET_DIR"
mkdir -p "$TARGET_DIR/models"

ui_print "-> 安装 llama-server"
cp -f "$MODPATH/llama-server" "$TARGET_DIR/"
chmod 755 "$TARGET_DIR/llama-server"

# 创建 system/bin 软链脚本，方便直接输入 llama-server 调用
mkdir -p "$MODPATH/system/bin"
cat > "$MODPATH/system/bin/llama-server" << 'EOF'
#!/system/bin/sh
exec /data/llama/llama-server "$@"
EOF
chmod 755 "$MODPATH/system/bin/llama-server"

ui_print "-> 安装完成!"
ui_print "   二进制: /data/llama/llama-server"
ui_print "   模型存放: /data/llama/models/"
ui_print "   手动执行: su -c /data/llama/llama-server 或 su -c llama-server"
ui_print "****************************************"