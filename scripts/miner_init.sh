#!/bin/bash
# miner_init.sh - Geth和Clef初始化脚本
# 放置在 /j/scripts/miner_init.sh

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 路径定义
DATA_DIR="/data"
KEYSTORE_FILE="/data/mainnet.keystore"
GETH_BIN="/j/bin/geth"
CLEF_BIN="/j/bin/clef"
GENESIS_FILE="/j/init/genesis-mainnet.json"
RULES_FILE="/j/config/clef-rules.js"
EXPECTED_HASH="66f7354d369835a51b0a41343433c1b5670819dcc6ede20f92904e81244829af"

# 函数：打印带颜色的消息
info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 函数：从keystore文件中提取地址（不使用jq）
extract_address_from_keystore() {
	local keystore_file="$1"

	if [ ! -f "$keystore_file" ]; then
		error "Keystore文件不存在: $keystore_file"
		return 1
	fi

	# 方法1: 使用grep提取（适用于标准keystore格式）
	local address=$(grep -o '"address":"[^"]*"' "$keystore_file" | head -1 | cut -d'"' -f4 2>/dev/null)

	# 方法2: 如果grep失败，尝试使用sed
	if [ -z "$address" ]; then
		address=$(sed -n 's/.*"address":"\([^"]*\)".*/\1/p' "$keystore_file" 2>/dev/null | head -1)
	fi

	# 方法3: 如果前两种方法都失败，尝试使用awk
	if [ -z "$address" ]; then
		address=$(awk -F'"' '/"address":/ {print $4; exit}' "$keystore_file" 2>/dev/null)
	fi

	if [ -n "$address" ]; then
		echo "$address"
		return 0
	else
		error "无法从keystore文件中提取地址"
		return 1
	fi
}

# 检查必要文件是否存在
check_prerequisites() {
	info "检查必要文件..."

	local missing_files=()

	if [ ! -f "$GETH_BIN" ]; then
		missing_files+=("$GETH_BIN")
	fi

	if [ ! -f "$CLEF_BIN" ]; then
		missing_files+=("$CLEF_BIN")
	fi

	if [ ! -f "$GENESIS_FILE" ]; then
		missing_files+=("$GENESIS_FILE")
	fi

	if [ ! -f "$KEYSTORE_FILE" ]; then
		missing_files+=("$KEYSTORE_FILE")
	fi

	if [ ! -f "$RULES_FILE" ]; then
		missing_files+=("$RULES_FILE")
	fi

	if [ ${#missing_files[@]} -gt 0 ]; then
		error "缺少必要文件:"
		for file in "${missing_files[@]}"; do
			echo "  - $file"
		done
		exit 1
	fi

	info "所有必要文件都存在 ✓"
}

# 步骤1: 初始化geth数据目录（包含数据目录检查）
init_geth() {
	info "步骤2: 初始化geth数据目录"

	local geth_data_dir="$DATA_DIR/mainnet"

	# 检查数据目录是否存在
	if [ -e "$geth_data_dir" ]; then
		warn "警告: Geth 数据目录 $geth_data_dir 已存在！"
		warn "重新初始化将会破坏现有数据。"

		echo -n "是否继续强制重新初始化Geth数据目录？(y/N): "
		read -r confirm

		if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
			info "跳过Geth初始化"
			return 1
		fi

		# 可选：备份现有数据
		warn "正在备份现有数据目录..."
		local backup_dir="${geth_data_dir}_backup_$(date +%Y%m%d_%H%M%S)"
		if cp -r "$geth_data_dir" "$backup_dir" 2>/dev/null; then
			info "数据已备份到: $backup_dir"
		else
			warn "备份失败，继续执行..."
		fi

		# 清理现有目录
		warn "清理现有数据目录..."
		rm -rf "$geth_data_dir"
	fi

	# 创建数据目录
	mkdir -p "$geth_data_dir"

	info "步骤2.1: 初始化区块链"
	warn "正在执行: $GETH_BIN init --datadir $geth_data_dir $GENESIS_FILE"

	if $GETH_BIN init --datadir "$geth_data_dir" "$GENESIS_FILE"; then
		info "Geth初始化成功 ✓"
	else
		error "Geth初始化失败"
		exit 1
	fi

	return 0
}

# 步骤2: 复制keystore文件
copy_keystore() {
	info "步骤2.2: 复制keystore文件"

	local keystore_dir="$DATA_DIR/mainnet/keystore"

	# 创建keystore目录
	mkdir -p "$keystore_dir"

	# 检查目标文件是否已存在
	local target_file="$keystore_dir/mainnet.keystore"
	if [ -f "$target_file" ]; then
		warn "目标文件已存在: $target_file"
		echo -n "是否覆盖？(y/N): "
		read -r confirm

		if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
			info "跳过keystore文件复制"
			return 0
		fi
	fi

	if cp "$KEYSTORE_FILE" "$target_file"; then
		info "Keystore文件复制成功 ✓"

		# 提取并显示keystore地址
		local address=$(extract_address_from_keystore "$KEYSTORE_FILE")
		if [ $? -eq 0 ] && [ -n "$address" ]; then
			# 确保地址是完整的（可能缺少0x前缀）
			if [[ ! "$address" =~ ^0x ]]; then
				address="0x$address"
			fi
			info "账户地址: $address"
		else
			warn "无法提取keystore地址，后续步骤需要手动输入"
		fi
	else
		error "Keystore文件复制失败"
		exit 1
	fi
}

# 步骤3: 初始化clef签名机
init_clef() {
	info "步骤1: 初始化clef签名机"

	# 检查clef是否已经初始化
	local clef_dir="$DATA_DIR/clef"
	if [ -d "$clef_dir" ]; then
		warn "警告: Clef目录 $clef_dir 已存在！"
		echo -n "是否重新初始化Clef签名机？(y/N): "
		read -r confirm

		if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
			info "跳过Clef初始化"
			return 1
		fi

		# 备份现有clef目录
		warn "正在备份现有Clef目录..."
		local backup_dir="${clef_dir}_backup_$(date +%Y%m%d_%H%M%S)"
		if cp -r "$clef_dir" "$backup_dir" 2>/dev/null; then
			info "Clef数据已备份到: $backup_dir"
		fi

		# 清理现有目录
		rm -rf "$clef_dir"
	fi

	info "步骤1.1: 初始化Clef加密存储区"
	warn "正在执行: $CLEF_BIN init"
	echo "请按照提示操作:"
	echo "1. 输入并确认clef加密密码（两次）"

	mkdir -p $DATA_DIR/clef
	if ! $CLEF_BIN --configdir $DATA_DIR/clef --suppress-bootwarn init; then
		error "Clef初始化失败"
		exit 1
	fi

	return 0
}

# 步骤4: 设置账户密码
set_account_password() {
	info "步骤1.2: 设置账户密码"

	local address=""

	# 尝试从keystore文件读取地址
	if [ -f "$KEYSTORE_FILE" ]; then
		address=$(extract_address_from_keystore "$KEYSTORE_FILE")
		if [ $? -eq 0 ] && [ -n "$address" ]; then
			# 确保地址是完整的（可能缺少0x前缀）
			if [[ ! "$address" =~ ^0x ]]; then
				address="0x$address"
			fi
			info "使用自动提取的地址: $address"
		else
			warn "无法提取keystore地址，后续步骤需要手动输入"
		fi
	fi

	# 如果无法获取地址，提示用户输入
	if [ -z "$address" ]; then
		warn "无法自动获取keystore地址，需要手动输入"
		while true; do
			echo -n "请输入keystore地址（16进制，带或不带0x前缀）: "
			read -r input_address

			# 移除可能的空格
			input_address=$(echo "$input_address" | tr -d '[:space:]')

			# 检查地址格式（基本验证）
			if [[ "$input_address" =~ ^(0x)?[0-9a-fA-F]{40}$ ]]; then
				# 确保有0x前缀
				if [[ ! "$input_address" =~ ^0x ]]; then
					input_address="0x$input_address"
				fi
				address="$input_address"
				break
			else
				error "地址格式不正确，应为40个十六进制字符（可选0x前缀）"
			fi
		done
	fi

	warn "正在执行: $CLEF_BIN setpw $address"
	echo "请按照提示操作:"
	echo "1. 输入keystore解锁密码（两次）"
	echo "2. 输入clef加密密码"

	if ! $CLEF_BIN --configdir $DATA_DIR/clef --suppress-bootwarn setpw "$address"; then
		error "设置账户密码失败"
		exit 1
	fi

	return 0
}

# 步骤5: 验证规则脚本
verify_and_attest_rules() {
	info "步骤1.3: 验证规则脚本"

	if [ ! -f "$RULES_FILE" ]; then
		error "规则脚本文件不存在: $RULES_FILE"
		exit 1
	fi

	warn "正在计算规则脚本哈希值..."

	# 检查sha256sum命令是否可用
	if ! command -v sha256sum &> /dev/null; then
		error "sha256sum命令不可用，无法验证规则脚本"
		echo -n "是否跳过验证？(y/N): "
		read -r skip_verify

		if [[ "$skip_verify" != "y" && "$skip_verify" != "Y" ]]; then
			exit 1
		fi

		warn "跳过哈希验证，直接进行认证..."
		local actual_hash="$EXPECTED_HASH"
	else
		local actual_hash=$(sha256sum "$RULES_FILE" | awk '{print $1}')

		info "计算得到的哈希值: $actual_hash"
		info "期望的哈希值:	 $EXPECTED_HASH"

		if [ "$actual_hash" = "$EXPECTED_HASH" ]; then
			info "规则脚本哈希验证成功 ✓"
		else
			warn "警告: 规则脚本哈希值不匹配!"
			echo -n "是否继续？(y/N): "
			read -r continue_anyway

			if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
				error "用户取消操作"
				exit 1
			fi

			# 使用实际计算的哈希进行认证
			EXPECTED_HASH="$actual_hash"
		fi
	fi

	# 认证规则脚本
	info "正在认证规则脚本..."
	warn "正在执行: $CLEF_BIN attest $EXPECTED_HASH"
	echo "请按照提示操作:"
	echo "1. 输入clef加密密码"

	if ! $CLEF_BIN --configdir $DATA_DIR/clef --suppress-bootwarn attest "$EXPECTED_HASH"; then
		error "规则脚本认证失败"
		exit 1
	fi

	return 0
}

# 清理临时文件
cleanup() {
	echo 🧹
}

# 主函数
main() {
	echo "=========================================="
	echo "	Geth & Clef 初始化脚本"
	echo "=========================================="

	# 检查前置条件
	check_prerequisites

	# 执行初始化步骤
	if init_clef ; then
		set_account_password
		verify_and_attest_rules
	fi
	if init_geth ; then
		copy_keystore
	fi

	# 清理
	cleanup

	echo "=========================================="
	info "所有初始化步骤已完成！"
	echo "=========================================="
}

# 设置退出时清理
trap cleanup EXIT

# 运行主函数
main "$@"
