-- 云租用平台数据库设计 (PostgreSQL) - 中国优化版
-- 基于 PVE + Rust + Vue + 国内支付 技术栈

-- 启用必要的扩展
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 1. 用户表（优化国内字段）
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE,
    phone VARCHAR(20) UNIQUE,  -- 国内更常用手机号
    password_hash VARCHAR(255) NOT NULL,
    salt VARCHAR(255) NOT NULL,
    real_name VARCHAR(100),  -- 实名认证用
    id_card VARCHAR(18),  -- 身份证号（加密存储）
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'deleted')),
    phone_verified BOOLEAN DEFAULT FALSE,  -- 重点验证手机
    email_verified BOOLEAN DEFAULT FALSE,
    balance DECIMAL(10,2) DEFAULT 0.00,  -- 人民币余额
    credit_limit DECIMAL(10,2) DEFAULT 0.00,
    role VARCHAR(20) DEFAULT 'user' CHECK (role IN ('user', 'admin', 'support')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP WITH TIME ZONE,
    login_count INTEGER DEFAULT 0,
    avatar_url VARCHAR(500),
    province VARCHAR(50),  -- 省份
    city VARCHAR(50),  -- 城市
    two_factor_enabled BOOLEAN DEFAULT FALSE,
    last_login_ip INET
);

-- 2. 用户会话表（保留核心安全）
CREATE TABLE user_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash VARCHAR(255) NOT NULL,
    ip_address INET NOT NULL,
    user_agent TEXT,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 3. 邮件验证码表
CREATE TABLE email_verifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) NOT NULL,
    code VARCHAR(6) NOT NULL,
    purpose VARCHAR(20) NOT NULL CHECK (purpose IN ('login', 'register', 'reset_password')),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    used BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 4. PVE 节点表（保持不变）
CREATE TABLE pve_nodes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    hostname VARCHAR(255) NOT NULL,
    ip_address INET NOT NULL,
    port INTEGER DEFAULT 8006,
    username VARCHAR(100) NOT NULL,
    password_encrypted TEXT NOT NULL,
    api_token TEXT,
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'maintenance', 'disabled')),
    location VARCHAR(100),  -- 国内地理位置，如"北京", "上海"
    max_cpu INTEGER NOT NULL,
    max_memory_gb INTEGER NOT NULL,
    max_storage_gb INTEGER NOT NULL,
    used_cpu INTEGER DEFAULT 0,
    used_memory_gb INTEGER DEFAULT 0,
    used_storage_gb INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_heartbeat TIMESTAMP WITH TIME ZONE
);

-- 5. 产品套餐表（人民币计价）
CREATE TABLE product_plans (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    cpu_cores INTEGER NOT NULL,
    memory_gb INTEGER NOT NULL,
    storage_gb INTEGER NOT NULL,
    bandwidth_mbps INTEGER NOT NULL,
    price_monthly DECIMAL(10,2) NOT NULL,  -- 月费(CNY)
    price_hourly DECIMAL(10,4) NOT NULL,   -- 小时费用(CNY)
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'disabled')),
    os_templates TEXT[],  -- 支持的操作系统模板
    features JSONB,  -- 额外特性配置
    show_order INTEGER DEFAULT 0  -- 前端展示顺序
);

-- 6. 虚拟机实例表（优化计费周期）
CREATE TABLE vm_instances (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    plan_id UUID NOT NULL REFERENCES product_plans(id),
    pve_node_id UUID NOT NULL REFERENCES pve_nodes(id),
    name VARCHAR(100) NOT NULL,
    pve_vmid INTEGER NOT NULL,
    status VARCHAR(20) DEFAULT 'creating' CHECK (status IN ('creating', 'running', 'stopped', 'suspended', 'deleting', 'deleted')),
    os_template VARCHAR(100),
    cpu_cores INTEGER NOT NULL,
    memory_gb INTEGER NOT NULL,
    storage_gb INTEGER NOT NULL,
    ip_address INET,
    ipv6_address INET,
    root_password VARCHAR(255),
    ssh_key_id UUID,
    billing_type VARCHAR(20) DEFAULT 'monthly' CHECK (billing_type IN ('hourly', 'monthly', 'yearly')),  -- 增加年付选项
    expires_at TIMESTAMP WITH TIME ZONE,  -- 到期时间
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    auto_renew BOOLEAN DEFAULT TRUE  -- 是否自动续费
);

-- 7. 账单表（人民币专用）
CREATE TABLE invoices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    invoice_number VARCHAR(50) UNIQUE NOT NULL,  -- 账单编号，如 INV-2025-001
    amount DECIMAL(10,2) NOT NULL,  -- 金额(CNY)
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'cancelled', 'refunded')),
    payment_method VARCHAR(50),  -- 'alipay', 'wechat', 'bank_transfer'
    transaction_id VARCHAR(100),  -- 第三方支付交易号
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    paid_at TIMESTAMP WITH TIME ZONE,
    due_date TIMESTAMP WITH TIME ZONE  -- 支付截止时间
);

-- 8. 支付记录表（国内支付方式）
CREATE TABLE payment_records (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    invoice_id UUID REFERENCES invoices(id),
    amount DECIMAL(10,2) NOT NULL,
    payment_method VARCHAR(50) NOT NULL CHECK (payment_method IN ('alipay', 'wechat', 'bank_transfer')),
    transaction_id VARCHAR(100),  -- 第三方交易号
    status VARCHAR(20) NOT NULL CHECK (status IN ('pending', 'paid', 'failed', 'refunded')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP WITH TIME ZONE,
    payment_account VARCHAR(100)  -- 付款账号（如支付宝账号）
);

-- 9. 监控数据表（核心监控）
CREATE TABLE monitoring_data (
    vm_instance_id UUID NOT NULL REFERENCES vm_instances(id) ON DELETE CASCADE,
    metric_type VARCHAR(50) NOT NULL,  -- cpu, memory, disk, network
    value DECIMAL(10,4) NOT NULL,
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    PRIMARY KEY (vm_instance_id, metric_type, timestamp)
) PARTITION BY RANGE (timestamp);

-- 10. 系统配置表（国内优化）
CREATE TABLE system_configs (
    key VARCHAR(100) PRIMARY KEY,
    value JSONB NOT NULL,
    description TEXT
);

-- 11.工单表
CREATE TABLE tickets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    subject VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    status VARCHAR(20) DEFAULT 'open' CHECK (status IN ('open', 'in_progress', 'closed')),
    priority VARCHAR(20) DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
    assigned_to UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 12.工单回复表
CREATE TABLE ticket_messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ticket_id UUID NOT NULL REFERENCES tickets(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    is_staff BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 初始化系统配置（国内专用）
INSERT INTO system_configs (key, value, description) VALUES
('site_name', '"云主机租用平台"', '平台名称'),
('currency', '"CNY"', '人民币结算'),
('min_recharge', '100.00', '最小充值金额(元)'),
('sms_provider', '"aliyun"', '短信服务商'),
('id_verify_required', 'true', '是否需要实名认证'),
('default_os_images', '["CentOS 7", "Ubuntu 20.04", "Debian 12"]', '默认系统镜像');

-- 创建常用索引
CREATE INDEX idx_users_phone ON users(phone);
CREATE INDEX idx_vm_instances_user_id ON vm_instances(user_id);
CREATE INDEX idx_vm_instances_status ON vm_instances(status);
CREATE INDEX idx_invoices_user_id ON invoices(user_id);
CREATE INDEX idx_invoices_status ON invoices(status);
