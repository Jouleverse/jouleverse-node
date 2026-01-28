#!/bin/bash
# /j/scripts/clef_entrypoint.sh

set -euo pipefail

# 密码文件路径（可以在启动时通过环境变量覆盖）
PASSWORD_FILE="/data/${CLEF_PASSWORD_FILE}"

# 检查密码文件是否存在
if [ ! -f "$PASSWORD_FILE" ]; then
    echo "错误: 密码文件不存在: $PASSWORD_FILE" >&2
    exit 1
fi

# 读取密码
PWD=$(cat "$PASSWORD_FILE" 2>/dev/null || echo "")
if [ -z "$PWD" ]; then
    echo "错误: 密码文件为空或读取失败" >&2
    exit 1
fi

# 发送到clef
(sleep 0.5; printf '{"jsonrpc":"2.0","id":1,"result":{"text":"%s"}}\n' "$PWD") | \
exec /j/bin/clef \
  --configdir /data/clef \
  --keystore /data/mainnet/keystore \
  --chainid 3666 \
  --rules /j/config/clef-rules.js \
  --ipcpath /data/clef/ \
  --nousb \
  --lightkdf \
  --suppress-bootwarn \
  --stdio-ui

# 清理内存中的密码变量
unset PWD
