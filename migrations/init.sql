-- 云租用平台数据库设计 (PostgreSQL)
-- 基于 PVE + Rust + Vue + Stripe 技术栈

-- 启用必要的扩展
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 1. 用户表
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    salt VARCHAR(255) NOT NULL,
    phone VARCHAR(20),
    full_name VARCHAR(100),
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'deleted')),
    email_verified BOOLEAN DEFAULT FALSE,
    phone_verified BOOLEAN DEFAULT FALSE,
    balance DECIMAL(10,2) DEFAULT 0.00,
    credit_limit DECIMAL(10,2) DEFAULT 0.00,
    role VARCHAR(20) DEFAULT 'user' CHECK (role IN ('user', 'admin', 'support')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP WITH TIME ZONE,
    login_count INTEGER DEFAULT 0,
    avatar_url VARCHAR(500),
    timezone VARCHAR(50) DEFAULT 'UTC',
    language VARCHAR(10) DEFAULT 'zh-CN',
    two_factor_enabled BOOLEAN DEFAULT FALSE,
    two_factor_secret VARCHAR(255)
);

-- 2. 用户会话表
CREATE TABLE user_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash VARCHAR(255) NOT NULL,
    ip_address INET NOT NULL,
    user_agent TEXT,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_activity TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 3. 邮箱验证码表
CREATE TABLE email_verifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    email VARCHAR(255) NOT NULL,
    code VARCHAR(10) NOT NULL,
    purpose VARCHAR(20) NOT NULL CHECK (purpose IN ('register', 'reset_password', 'change_email')),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    used BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 4. PVE 节点表
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
    location VARCHAR(100),
    datacenter VARCHAR(100),
    max_cpu INTEGER NOT NULL,
    max_memory_gb INTEGER NOT NULL,
    max_storage_gb INTEGER NOT NULL,
    used_cpu INTEGER DEFAULT 0,
    used_memory_gb INTEGER DEFAULT 0,
    used_storage_gb INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_heartbeat TIMESTAMP WITH TIME ZONE
);

-- 5. 产品套餐表
CREATE TABLE product_plans (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    cpu_cores INTEGER NOT NULL,
    memory_gb INTEGER NOT NULL,
    storage_gb INTEGER NOT NULL,
    bandwidth_mbps INTEGER NOT NULL,
    price_monthly DECIMAL(10,2) NOT NULL,
    price_hourly DECIMAL(10,4) NOT NULL,
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'disabled')),
    category VARCHAR(50) DEFAULT 'vps',
    os_templates TEXT[], -- 支持的操作系统模板
    features JSONB, -- 额外特性配置
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 6. 虚拟机实例表
CREATE TABLE vm_instances (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    plan_id UUID NOT NULL REFERENCES product_plans(id),
    pve_node_id UUID NOT NULL REFERENCES pve_nodes(id),
    name VARCHAR(100) NOT NULL,
    hostname VARCHAR(255),
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
    auto_backup BOOLEAN DEFAULT FALSE,
    billing_type VARCHAR(20) DEFAULT 'monthly' CHECK (billing_type IN ('hourly', 'monthly')),
    expires_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE,
    pve_config JSONB -- PVE 配置快照
);

-- 7. SSH 密钥表
CREATE TABLE ssh_keys (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    public_key TEXT NOT NULL,
    fingerprint VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 8. 账单表（主账单）
CREATE TABLE invoices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    invoice_number VARCHAR(50) UNIQUE NOT NULL, -- 账单编号，如 INV-2025-001
    billing_period_start TIMESTAMP WITH TIME ZONE NOT NULL,
    billing_period_end TIMESTAMP WITH TIME ZONE NOT NULL,
    subtotal DECIMAL(10,2) NOT NULL DEFAULT 0.00, -- 小计
    tax_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00, -- 税费
    total_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00, -- 总计
    status VARCHAR(20) DEFAULT 'draft' CHECK (status IN ('draft', 'pending', 'paid', 'overdue', 'cancelled')),
    due_date TIMESTAMP WITH TIME ZONE NOT NULL,
    paid_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    notes TEXT
);

-- 9. 账单明细表
CREATE TABLE invoice_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    invoice_id UUID NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
    vm_instance_id UUID REFERENCES vm_instances(id),
    item_type VARCHAR(50) NOT NULL, -- 'vm_usage', 'bandwidth', 'storage', 'backup', 'addon'
    description TEXT NOT NULL,
    quantity DECIMAL(10,4) NOT NULL DEFAULT 1, -- 数量（如小时数）
    unit_price DECIMAL(10,4) NOT NULL, -- 单价
    total_price DECIMAL(10,2) NOT NULL, -- 总价
    billing_period_start TIMESTAMP WITH TIME ZONE,
    billing_period_end TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    metadata JSONB -- 额外信息，如资源配置快照
);

-- 10. 支付记录表
CREATE TABLE payment_records (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    invoice_id UUID REFERENCES invoices(id), -- 关联账单（充值时为空）
    payment_type VARCHAR(20) NOT NULL CHECK (payment_type IN ('recharge', 'invoice_payment')),
    amount DECIMAL(10,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'USD',
    payment_method VARCHAR(50) NOT NULL, -- 'stripe_card', 'stripe_paypal', 'manual'
    stripe_payment_intent_id VARCHAR(255) UNIQUE,
    stripe_customer_id VARCHAR(255),
    status VARCHAR(20) NOT NULL CHECK (status IN ('pending', 'processing', 'succeeded', 'failed', 'canceled', 'refunded')),
    failure_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP WITH TIME ZONE,
    metadata JSONB
);

-- 11. 余额变动记录表（详细的资金流水）
CREATE TABLE balance_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    transaction_type VARCHAR(30) NOT NULL CHECK (transaction_type IN (
        'recharge', 'payment', 'refund', 'admin_adjustment', 'penalty', 'bonus'
    )),
    amount DECIMAL(10,2) NOT NULL, -- 正数表示收入，负数表示支出
    balance_before DECIMAL(10,2) NOT NULL,
    balance_after DECIMAL(10,2) NOT NULL,
    description TEXT NOT NULL,
    reference_id UUID, -- 关联的支付记录ID、账单ID等
    reference_type VARCHAR(20), -- 'payment', 'invoice', 'adjustment'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    metadata JSONB
);

-- 10. 系统配置表
CREATE TABLE system_configs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    key VARCHAR(100) UNIQUE NOT NULL,
    value JSONB NOT NULL,
    description TEXT,
    category VARCHAR(50) DEFAULT 'general',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 11. 操作日志表
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id),
    action VARCHAR(100) NOT NULL,
    resource_type VARCHAR(50) NOT NULL,
    resource_id UUID,
    ip_address INET,
    user_agent TEXT,
    details JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 12. 监控数据表
CREATE TABLE monitoring_data (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    vm_instance_id UUID NOT NULL REFERENCES vm_instances(id) ON DELETE CASCADE,
    metric_type VARCHAR(50) NOT NULL, -- cpu, memory, disk, network
    value DECIMAL(10,4) NOT NULL,
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 13. 备份记录表
CREATE TABLE backup_records (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    vm_instance_id UUID NOT NULL REFERENCES vm_instances(id) ON DELETE CASCADE,
    backup_name VARCHAR(255) NOT NULL,
    backup_type VARCHAR(20) DEFAULT 'manual' CHECK (backup_type IN ('manual', 'auto', 'snapshot')),
    size_gb DECIMAL(10,2),
    status VARCHAR(20) DEFAULT 'creating' CHECK (status IN ('creating', 'completed', 'failed', 'deleted')),
    pve_backup_id VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP WITH TIME ZONE,
    expires_at TIMESTAMP WITH TIME ZONE
);

-- 14. 工单系统表
CREATE TABLE support_tickets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    subject VARCHAR(255) NOT NULL,
    category VARCHAR(50) NOT NULL,
    priority VARCHAR(20) DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
    status VARCHAR(20) DEFAULT 'open' CHECK (status IN ('open', 'pending', 'resolved', 'closed')),
    assigned_to UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP WITH TIME ZONE
);

-- 15. 工单消息表
CREATE TABLE support_messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ticket_id UUID NOT NULL REFERENCES support_tickets(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES users(id),
    content TEXT NOT NULL,
    is_internal BOOLEAN DEFAULT FALSE,
    attachments JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 16. 系统通知表
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL,
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    read BOOLEAN DEFAULT FALSE,
    action_url VARCHAR(500),
    expires_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 创建索引
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_status ON users(status);
CREATE INDEX idx_user_sessions_user_id ON user_sessions(user_id);
CREATE INDEX idx_user_sessions_token_hash ON user_sessions(token_hash);
CREATE INDEX idx_user_sessions_expires_at ON user_sessions(expires_at);
CREATE INDEX idx_vm_instances_user_id ON vm_instances(user_id);
CREATE INDEX idx_vm_instances_status ON vm_instances(status);
CREATE INDEX idx_vm_instances_pve_node_id ON vm_instances(pve_node_id);
CREATE INDEX idx_invoices_user_id ON invoices(user_id);
CREATE INDEX idx_invoices_status ON invoices(status);
CREATE INDEX idx_invoices_due_date ON invoices(due_date);
CREATE INDEX idx_invoices_invoice_number ON invoices(invoice_number);
CREATE INDEX idx_invoice_items_invoice_id ON invoice_items(invoice_id);
CREATE INDEX idx_invoice_items_vm_instance_id ON invoice_items(vm_instance_id);
CREATE INDEX idx_payment_records_user_id ON payment_records(user_id);
CREATE INDEX idx_payment_records_invoice_id ON payment_records(invoice_id);
CREATE INDEX idx_payment_records_stripe_payment_intent_id ON payment_records(stripe_payment_intent_id);
CREATE INDEX idx_balance_transactions_user_id ON balance_transactions(user_id);
CREATE INDEX idx_balance_transactions_created_at ON balance_transactions(created_at);
CREATE INDEX idx_balance_transactions_reference ON balance_transactions(reference_type, reference_id);
CREATE INDEX idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_created_at ON audit_logs(created_at);
CREATE INDEX idx_monitoring_data_vm_instance_id ON monitoring_data(vm_instance_id);
CREATE INDEX idx_monitoring_data_timestamp ON monitoring_data(timestamp);
CREATE INDEX idx_support_tickets_user_id ON support_tickets(user_id);
CREATE INDEX idx_support_tickets_status ON support_tickets(status);
CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_read ON notifications(read);

-- 创建更新时间触发器函数
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 为需要的表创建更新时间触发器
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_pve_nodes_updated_at BEFORE UPDATE ON pve_nodes FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_product_plans_updated_at BEFORE UPDATE ON product_plans FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_vm_instances_updated_at BEFORE UPDATE ON vm_instances FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_system_configs_updated_at BEFORE UPDATE ON system_configs FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_invoices_updated_at BEFORE UPDATE ON invoices FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 插入初始系统配置
INSERT INTO system_configs (key, value, description, category) VALUES
('site_name', '"云主机租用平台"', '网站名称', 'general'),
('site_description', '"专业的云主机租用服务"', '网站描述', 'general'),
('currency', '"USD"', '默认货币', 'billing'),
('min_recharge_amount', '10.00', '最小充值金额', 'billing'),
('max_recharge_amount', '10000.00', '最大充值金额', 'billing'),
('auto_suspend_days', '7', '欠费自动暂停天数', 'billing'),
('auto_delete_days', '30', '暂停后自动删除天数', 'billing'),
('backup_retention_days', '30', '备份保留天数', 'backup'),
('max_instances_per_user', '10', '每用户最大实例数', 'limits'),
('session_timeout_hours', '24', '会话超时时间（小时）', 'security'),
('password_min_length', '8', '密码最小长度', 'security'),
('enable_registration', 'true', '是否允许注册', 'security'),
('enable_email_verification', 'true', '是否启用邮箱验证', 'security'),
('stripe_webhook_secret', '""', 'Stripe Webhook 密钥', 'payment'),
('smtp_host', '""', 'SMTP 服务器', 'email'),
('smtp_port', '587', 'SMTP 端口', 'email'),
('smtp_username', '""', 'SMTP 用户名', 'email'),
('smtp_password', '""', 'SMTP 密码', 'email'),
('from_email', '""', '发件人邮箱', 'email');

-- 插入默认管理员用户（密码需要在应用中设置）
INSERT INTO users (id, username, email, password_hash, salt, role, email_verified)
VALUES (
    uuid_generate_v4(),
    'admin',
    'admin@example.com',
    '', -- 需要在应用中设置
    '', -- 需要在应用中设置
    'admin',
    true
);

-- 创建视图：用户资源使用统计
CREATE VIEW user_resource_usage AS
SELECT 
    u.id as user_id,
    u.username,
    u.email,
    COUNT(vm.id) as total_instances,
    COUNT(CASE WHEN vm.status = 'running' THEN 1 END) as running_instances,
    COALESCE(SUM(CASE WHEN vm.status = 'running' THEN vm.cpu_cores ELSE 0 END), 0) as total_cpu_cores,
    COALESCE(SUM(CASE WHEN vm.status = 'running' THEN vm.memory_gb ELSE 0 END), 0) as total_memory_gb,
    COALESCE(SUM(CASE WHEN vm.status = 'running' THEN vm.storage_gb ELSE 0 END), 0) as total_storage_gb,
    u.balance
FROM users u
LEFT JOIN vm_instances vm ON u.id = vm.user_id AND vm.status != 'deleted'
WHERE u.status = 'active'
GROUP BY u.id, u.username, u.email, u.balance;

-- 创建视图：节点资源使用统计
CREATE VIEW node_resource_usage AS
SELECT 
    n.id as node_id,
    n.name,
    n.hostname,
    n.location,
    n.max_cpu,
    n.max_memory_gb,
    n.max_storage_gb,
    COUNT(vm.id) as total_instances,
    COUNT(CASE WHEN vm.status = 'running' THEN 1 END) as running_instances,
    COALESCE(SUM(CASE WHEN vm.status = 'running' THEN vm.cpu_cores ELSE 0 END), 0) as used_cpu,
    COALESCE(SUM(CASE WHEN vm.status = 'running' THEN vm.memory_gb ELSE 0 END), 0) as used_memory_gb,
    COALESCE(SUM(CASE WHEN vm.status = 'running' THEN vm.storage_gb ELSE 0 END), 0) as used_storage_gb,
    n.status
FROM pve_nodes n
LEFT JOIN vm_instances vm ON n.id = vm.pve_node_id AND vm.status != 'deleted'
GROUP BY n.id, n.name, n.hostname, n.location, n.max_cpu, n.max_memory_gb, n.max_storage_gb, n.status;

-- 创建分区表（可选，用于大数据量的监控数据）
-- CREATE TABLE monitoring_data_y2025m01 PARTITION OF monitoring_data
-- FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');

-- 数据库权限设置（根据实际需要调整）
-- CREATE ROLE app_user WITH LOGIN PASSWORD 'your_secure_password';
-- GRANT CONNECT ON DATABASE your_database TO app_user;
-- GRANT USAGE ON SCHEMA public TO app_user;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app_user;
-- GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO app_user;
