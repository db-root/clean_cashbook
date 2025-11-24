i# Cashbook 数据库清理工具

该工具用于清理 ******** 数据库中指向已删除账本的无效记录，避免在界面中显示"未知账本DB ID: N/A"的问题。

## 功能说明

1. **备份功能** - 备份所有相关表的数据
2. **清理功能** - 只清理 TypeRelation 表中指向不存在账本的记录
3. **恢复功能** - 从备份中恢复 TypeRelation 表的数据

## 使用方法

### 前置条件

确保系统中已安装 PostgreSQL 客户端。如果未安装，脚本会自动尝试安装：
- CentOS/RHEL/Fedora: 使用 `dnf` 或 `yum`
- Ubuntu/Debian: 使用 `apt-get`

### 配置数据库连接信息

编辑脚本头部的数据库连接信息：

```bash
# 数据库连接信息
DB_HOST="xxx.xxx.xxx.xxx"    # 数据库主机IP
DB_PORT="xxxxx"            # 数据库端口
DB_NAME="********"         # 数据库名称
DB_USER="********"            # 数据库用户名
DB_PASS="********"     # 数据库密码
```

### 运行脚本

```bash
# 进入脚本目录
cd /opt/code/bash/clean_********

# 添加执行权限
chmod +x clean_********_orphaned_records.sh

# 执行清理操作（默认）
./clean_********_orphaned_records.sh

# 或明确指定执行清理操作
./clean_********_orphaned_records.sh clean

# 执行备份操作（备份所有表）
./clean_********_orphaned_records.sh backup

# 从指定备份目录恢复TypeRelation表数据
./clean_********_orphaned_records.sh restore /tmp/********_backup_20251124_153915

# 显示帮助信息
./clean_********_orphaned_records.sh help
```

## 操作说明

### 清理操作 (clean)

- 只清理 TypeRelation 表中 bookId 不存在于 Book 表的记录
- 操作前会自动进行完整备份
- 操作前后会显示 TypeRelation 表的记录数统计

### 备份操作 (backup)

- 备份所有相关表的数据：Book、Budget、FixedFlow、Flow、Receivable、TypeRelation
- 备份文件存储在 `/tmp/********_backup_YYYYMMDD_HHMMSS/` 目录中
- 每个表单独备份到对应的 .txt 文件中

### 恢复操作 (restore)

- 仅恢复 TypeRelation 表的数据
- 从指定备份目录中读取 TypeRelation.txt 文件
- 清空当前 TypeRelation 表数据后导入备份数据

## 安全措施

1. **自动备份** - 每次清理操作前都会自动进行完整备份
2. **精确操作** - 清理和恢复操作仅针对 TypeRelation 表，不影响其他表
3. **权限控制** - 备份文件创建后会设置严格的访问权限
4. **日志记录** - 所有操作都有详细的时间戳日志记录

## 注意事项

1. 请确保数据库连接信息配置正确
2. 脚本会自动安装 PostgreSQL 客户端（如未安装）
3. 恢复操作会清空 TypeRelation 表的当前数据，请谨慎使用
4. 备份文件存储在 /tmp 目录下，系统重启后可能会丢失
5. 如果需要长期保存备份，请将备份文件复制到持久化存储中

## 故障排除

### psql 命令未找到

脚本会自动检测并安装 PostgreSQL 客户端。如果自动安装失败，请手动安装：
```bash
# CentOS/RHEL/Fedora
sudo dnf install -y postgresql

# Ubuntu/Debian
sudo apt-get update && sudo apt-get install -y postgresql-client
```

### 恢复操作失败

如果恢复操作失败，请检查：
1. 备份目录路径是否正确
2. TypeRelation.txt 文件是否存在
3. 数据库连接信息是否正确
4. 用户是否具有相应的数据库权限