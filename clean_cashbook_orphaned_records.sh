#!/bin/bash

# 数据库连接信息
# 数据库主机IP
DB_HOST="xxx.xxx.xxx.xxx"
# 数据库端口
DB_PORT="xxxxx"
# 数据库名称
DB_NAME="********"
# 数据库用户名
DB_USER="********"
# 数据库密码
DB_PASS="********"


# 设置密码环境变量
export PGPASSWORD="$DB_PASS"

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# 检查并安装PostgreSQL客户端
install_postgresql_client() {
    if command -v psql &> /dev/null; then
        log "PostgreSQL客户端已安装"
        return 0
    fi
    
    log "PostgreSQL客户端未安装，正在尝试安装..."
    
    # 检查包管理器类型
    if command -v apt-get &> /dev/null; then
        log "检测到APT包管理器"
        apt-get update && apt-get install -y postgresql-client
    elif command -v dnf &> /dev/null; then
        log "检测到DNF包管理器"
        dnf install -y postgresql
    elif command -v yum &> /dev/null; then
        log "检测到YUM包管理器"
        yum install -y postgresql
    else
        log "错误: 无法识别包管理器，无法自动安装PostgreSQL客户端"
        return 1
    fi
    
    # 检查安装是否成功
    if command -v psql &> /dev/null; then
        log "PostgreSQL客户端安装成功"
        return 0
    else
        log "错误: PostgreSQL客户端安装失败"
        return 1
    fi
}

# 备份数据库表数据
backup_database() {
    local backup_dir="/tmp/********_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # 设置备份目录权限
    chmod 700 "$backup_dir"
    
    if [ $? -eq 0 ]; then
        log "创建备份目录: $backup_dir"
    else
        log "错误: 无法创建备份目录"
        return 1
    fi
    
    # 备份各个表的数据
    local tables=("Book" "Budget" "FixedFlow" "Flow" "Receivable" "TypeRelation")
    
    for table in "${tables[@]}"; do
        log "正在备份表: $table"
        psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT * FROM \"$table\";" > "$backup_dir/${table}.txt"
        
        # 设置备份文件权限
        chmod 600 "$backup_dir/${table}.txt"
        
        if [ $? -eq 0 ]; then
            log "表 $table 备份成功"
        else
            log "警告: 表 $table 备份失败"
        fi
    done
    
    log "数据库备份完成，备份位置: $backup_dir"
    echo "$backup_dir"
}

# 恢复TypeRelation表数据
restore_typerelation_table() {
    local backup_dir="$1"
    
    # 检查参数
    if [ -z "$backup_dir" ]; then
        log "错误: 请提供备份目录路径"
        return 1
    fi
    
    # 检查备份目录是否存在
    if [ ! -d "$backup_dir" ]; then
        log "错误: 备份目录不存在: $backup_dir"
        return 1
    fi
    
    log "开始从 $backup_dir 恢复TypeRelation表数据"
    
    # 检查TypeRelation表的备份文件是否存在
    local backup_file="$backup_dir/TypeRelation.txt"
    if [ ! -f "$backup_file" ]; then
        log "错误: TypeRelation表的备份文件不存在: $backup_file"
        return 1
    fi
    
    log "正在恢复TypeRelation表"
    
    # 创建临时SQL文件用于导入数据
    local temp_sql_file="/tmp/TypeRelation_restore.sql"
    echo "BEGIN;" > "$temp_sql_file"
    echo "DELETE FROM \"TypeRelation\";" >> "$temp_sql_file"
    
    # 跳过前2行（表头）并逐行处理数据
    local line_num=0
    while IFS= read -r line; do
        line_num=$((line_num + 1))
        
        # 跳过前2行表头和最后1行记录数统计
        if [ $line_num -le 2 ] || [[ "$line" =~ "行记录)" ]] || [[ "$line" =~ "-----" ]]; then
            continue
        fi
        
        # 跳过空行
        if [ -z "$(echo "$line" | tr -d ' ')" ]; then
            continue
        fi
        
        # 分割行数据，使用'|'作为分隔符
        IFS='|' read -ra FIELDS <<< "$line"
        
        # 确保有足够的字段
        if [ ${#FIELDS[@]} -ge 5 ]; then
            # 提取并清理字段值
            local id=$(echo "${FIELDS[0]}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            local userId=$(echo "${FIELDS[1]}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            local bookId=$(echo "${FIELDS[2]}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed "s/'/''/g")
            local source=$(echo "${FIELDS[3]}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed "s/'/''/g")
            local target=$(echo "${FIELDS[4]}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed "s/'/''/g")
            
            # 生成INSERT语句
            echo "INSERT INTO \"TypeRelation\" (\"id\", \"userId\", \"bookId\", \"source\", \"target\") VALUES ($id, $userId, '$bookId', '$source', '$target');" >> "$temp_sql_file"
        fi
    done < "$backup_file"
    
    echo "COMMIT;" >> "$temp_sql_file"
    
    # 统计将要导入的记录数
    local insert_count=$(grep -c "INSERT INTO" "$temp_sql_file")
    log "准备导入 $insert_count 条记录到TypeRelation表"
    
    # 执行数据导入
    log "正在导入数据..."
    psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$temp_sql_file" > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        log "TypeRelation表数据恢复成功"
    else
        log "错误: TypeRelation表数据恢复失败"
        rm -f "$temp_sql_file"
        return 1
    fi
    
    # 清理临时文件
    rm -f "$temp_sql_file"
    
    log "TypeRelation表数据恢复操作完成"
}

# 清理指向不存在账本的记录（只清理TypeRelation表）
clean_orphaned_records() {
    log "开始清理TypeRelation表中指向不存在账本的记录..."
    
    # 显示清理前TypeRelation表记录数
    log "清理前TypeRelation表记录数统计:"
    psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 'TypeRelation' as table_name, COUNT(*) as count FROM \"TypeRelation\";" 
    
    # 只删除TypeRelation表中指向不存在账本的记录
    log "正在删除TypeRelation表中的无效记录..."
    psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "DELETE FROM \"TypeRelation\" WHERE \"bookId\" NOT IN (SELECT \"bookId\" FROM \"Book\");"
    
    if [ $? -eq 0 ]; then
        log "TypeRelation表中的无效记录删除成功"
    else
        log "错误: 删除操作失败"
        return 1
    fi
    
    # 显示清理后TypeRelation表记录数
    log "清理后TypeRelation表记录数统计:"
    psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 'TypeRelation' as table_name, COUNT(*) as count FROM \"TypeRelation\";"
    
    log "TypeRelation表清理操作完成"
}

# 显示帮助信息
show_help() {
    echo "用法: $0 [选项]"
    echo "选项:"
    echo "  clean        清理TypeRelation表中指向不存在账本的记录（默认操作）"
    echo "  backup       备份数据库表数据"
    echo "  restore <目录> 从指定备份目录恢复TypeRelation表数据"
    echo "  help         显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0              # 执行TypeRelation表清理操作"
    echo "  $0 clean        # 执行TypeRelation表清理操作"
    echo "  $0 backup       # 备份所有表数据"
    echo "  $0 restore /tmp/********_backup_20251201_120000  # 恢复TypeRelation表数据"
}

# 主函数
main() {
    local action="${1:-clean}"
    
    case "$action" in
        clean)
            log "开始执行********数据库TypeRelation表清理任务"
            
            # 安装PostgreSQL客户端（如果需要）
            install_postgresql_client
            if [ $? -ne 0 ]; then
                log "无法安装PostgreSQL客户端，脚本退出"
                exit 1
            fi
            
            # 备份数据库
            local backup_dir=$(backup_database)
            if [ $? -ne 0 ]; then
                log "数据库备份失败，脚本退出"
                exit 1
            fi
            
            # 清理TypeRelation表中的无效记录
            clean_orphaned_records
            if [ $? -ne 0 ]; then
                log "清理操作失败，脚本退出"
                exit 1
            fi
            
            log "所有任务完成"
            ;;
            
        backup)
            log "开始执行数据库备份任务"
            
            # 安装PostgreSQL客户端（如果需要）
            install_postgresql_client
            if [ $? -ne 0 ]; then
                log "无法安装PostgreSQL客户端，脚本退出"
                exit 1
            fi
            
            # 备份数据库
            backup_database
            if [ $? -ne 0 ]; then
                log "数据库备份失败"
                exit 1
            fi
            
            log "备份任务完成"
            ;;
            
        restore)
            local backup_dir="$2"
            log "开始执行TypeRelation表数据恢复任务"
            restore_typerelation_table "$backup_dir"
            log "TypeRelation表数据恢复任务完成"
            ;;
            
        help|--help|-h)
            show_help
            ;;
            
        *)
            log "错误: 未知操作 '$action'"
            show_help
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"