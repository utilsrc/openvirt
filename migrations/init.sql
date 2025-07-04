-- 云租用平台数据库设计 (PostgreSQL)
-- 基于 PVE + Rust + Vue + Stripe 技术栈
-- 专为中国市场优化版本

-- 启用必要的扩展
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 1. 用户表
COMMENT ON TABLE users IS '系统用户表，存储所有用户信息';
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(50) UNIQUE NOT NULL COMMENT '用户名，用于登录',
    email VARCHAR(255) UNIQUE NOT NULL COMMENT '电子邮箱',
    password_hash VARCHAR(255) NOT NULL COMMENT '密码哈希值',
    salt VARCHAR(255) NOT NULL COMMENT '密码盐值',
    phone VARCHAR(20) COMMENT '手机号码',
    full_name VARCHAR(100) COMMENT '用户真实姓名',
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'deleted')) COMMENT '用户状态',
    email_verified BOOLEAN DEFAULT FALSE COMMENT '邮箱是否验证',
    phone_verified BOOLEAN DEFAULT FALSE COMMENT '手机是否验证',
    balance DECIMAL(10,2) DEFAULT 0.00 COMMENT '账户余额(元)',
    credit_limit DECIMAL(10,2) DEFAULT 0.00 COMMENT '信用额度(元)',
    role VARCHAR(20) DEFAULT 'user' CHECK (role IN ('user', 'admin', 'support')) COMMENT '用户角色',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP COMMENT '更新时间',
    last_login TIMESTAMP WITH TIME ZONE COMMENT '最后登录时间',
    login_count INTEGER DEFAULT 0 COMMENT '登录次数',
    avatar_url VARCHAR(500) COMMENT '头像URL',
    two_factor_enabled BOOLEAN DEFAULT FALSE COMMENT '是否启用双因素认证',
    two_factor_secret VARCHAR(255) COMMENT '双因素认证密钥'
);

-- 2. 用户会话表
COMMENT ON TABLE user_sessions IS '用户会话表，存储登录会话信息';
CREATE TABLE user_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE COMMENT '关联用户ID',
    token_hash VARCHAR(255) NOT NULL COMMENT '会话令牌哈希',
    ip_address INET NOT NULL COMMENT '登录IP地址',
    user_agent TEXT COMMENT '用户代理信息',
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL COMMENT '过期时间',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    last_activity TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP COMMENT '最后活动时间'
);

-- 3. 验证码表（合并邮箱和手机验证）
COMMENT ON TABLE verifications IS '验证码表，用于邮箱/手机验证';
CREATE TABLE verifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE COMMENT '关联用户ID',
    target VARCHAR(255) NOT NULL COMMENT '验证目标（邮箱或手机号）',
    code VARCHAR(10) NOT NULL COMMENT '验证码',
    purpose VARCHAR(20) NOT NULL CHECK (purpose IN ('register', 'reset_password', 'change_email', 'change_phone')) COMMENT '验证目的',
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL COMMENT '过期时间',
    used BOOLEAN DEFAULT FALSE COMMENT '是否已使用',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间'
);

-- 4. PVE 节点表
COMMENT ON TABLE pve_nodes IS 'PVE节点表，存储物理服务器信息';
CREATE TABLE pve_nodes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL COMMENT '节点名称',
    hostname VARCHAR(255) NOT NULL COMMENT '主机名',
    ip_address INET NOT NULL COMMENT 'IP地址',
    port INTEGER DEFAULT 8006 COMMENT 'API端口',
    username VARCHAR(100) NOT NULL COMMENT 'PVE用户名',
    password_encrypted TEXT NOT NULL COMMENT '加密的PVE密码',
    api_token TEXT COMMENT 'API令牌',
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'maintenance', 'disabled')) COMMENT '节点状态',
    location VARCHAR(100) COMMENT '机房位置',
    max_cpu INTEGER NOT NULL COMMENT '总CPU核心数',
    max_memory_gb INTEGER NOT NULL COMMENT '总内存(GB)',
    max_storage_gb INTEGER NOT NULL COMMENT '总存储(GB)',
    used_cpu INTEGER DEFAULT 0 COMMENT '已用CPU核心数',
    used_memory_gb INTEGER DEFAULT 0 COMMENT '已用内存(GB)',
    used_storage_gb INTEGER DEFAULT 0 COMMENT '已用存储(GB)',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP COMMENT '更新时间',
    last_heartbeat TIMESTAMP WITH TIME ZONE COMMENT '最后心跳时间'
);

-- 5. 产品套餐表
COMMENT ON TABLE product_plans IS '虚拟机套餐表';
CREATE TABLE product_plans (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL COMMENT '套餐名称',
    description TEXT COMMENT '套餐描述',
    cpu_cores INTEGER NOT NULL COMMENT 'CPU核心数',
    memory_gb INTEGER NOT NULL COMMENT '内存大小(GB)',
    storage_gb INTEGER NOT NULL COMMENT '存储空间(GB)',
    bandwidth_mbps INTEGER NOT NULL COMMENT '带宽(Mbps)',
    price_monthly DECIMAL(10,2) NOT NULL COMMENT '月费价格(元)',
    price_hourly DECIMAL(10,4) NOT NULL COMMENT '小时价格(元)',
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'disabled')) COMMENT '套餐状态',
    os_templates TEXT[] COMMENT '支持的操作系统模板',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP COMMENT '更新时间'
);

-- 6. 虚拟机实例表
COMMENT ON TABLE vm_instances IS '虚拟机实例表';
CREATE TABLE vm_instances (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE COMMENT '所属用户ID',
    plan_id UUID NOT NULL REFERENCES product_plans(id) COMMENT '套餐ID',
    pve_node_id UUID NOT NULL REFERENCES pve_nodes(id) COMMENT '所在节点ID',
    name VARCHAR(100) NOT NULL COMMENT '实例名称',
    pve_vmid INTEGER NOT NULL COMMENT 'PVE虚拟机ID',
    status VARCHAR(20) DEFAULT 'creating' CHECK (status IN ('creating', 'running', 'stopped', 'suspended', 'deleting', 'deleted')) COMMENT '实例状态',
    os_template VARCHAR(100) COMMENT '操作系统模板',
    cpu_cores INTEGER NOT NULL COMMENT 'CPU核心数',
    memory_gb INTEGER NOT NULL COMMENT '内存大小(GB)',
    storage_gb INTEGER NOT NULL COMMENT '存储空间(GB)',
    ip_address INET COMMENT 'IPv4地址',
    ipv6_address INET COMMENT 'IPv6地址',
    billing_type VARCHAR(20) DEFAULT 'monthly' CHECK (billing_type IN ('hourly', 'monthly')) COMMENT '计费类型',
    expires_at TIMESTAMP WITH TIME ZONE COMMENT '到期时间',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP COMMENT '更新时间',
    deleted_at TIMESTAMP WITH TIME ZONE COMMENT '删除时间'
);

-- 7. SSH 密钥表
COMMENT ON TABLE ssh_keys IS '用户SSH密钥表';
CREATE TABLE ssh_keys (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE COMMENT '所属用户ID',
    name VARCHAR(100) NOT NULL COMMENT '密钥名称',
    public_key TEXT NOT NULL COMMENT '公钥内容',
    fingerprint VARCHAR(255) NOT NULL COMMENT '密钥指纹',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间'
);

-- 8. 账单表（简化版）
COMMENT ON TABLE invoices IS '用户账单表';
CREATE TABLE invoices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE COMMENT '所属用户ID',
    invoice_number VARCHAR(50) UNIQUE NOT NULL COMMENT '账单编号',
    amount DECIMAL(10,2) NOT NULL COMMENT '账单金额(元)',
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'cancelled')) COMMENT '账单状态',
    due_date TIMESTAMP WITH TIME ZONE NOT NULL COMMENT '到期时间',
    paid_at TIMESTAMP WITH TIME ZONE COMMENT '支付时间',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    description TEXT COMMENT '账单描述'
);

-- 9. 支付记录表（适配中国支付方式）
COMMENT ON TABLE payments IS '支付记录表';
CREATE TABLE payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE COMMENT '所属用户ID',
    invoice_id UUID REFERENCES invoices(id) COMMENT '关联账单ID',
    amount DECIMAL(10,2) NOT NULL COMMENT '支付金额(元)',
    payment_method VARCHAR(50) NOT NULL COMMENT '支付方式',
    transaction_id VARCHAR(255) COMMENT '第三方交易ID',
    status VARCHAR(20) NOT NULL CHECK (status IN ('pending', 'completed', 'failed', 'refunded')) COMMENT '支付状态',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    completed_at TIMESTAMP WITH TIME ZONE COMMENT '完成时间'
);

-- 10. 余额变动记录表
COMMENT ON TABLE balance_transactions IS '用户余额变动记录表';
CREATE TABLE balance_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE COMMENT '所属用户ID',
    amount DECIMAL(10,2) NOT NULL COMMENT '变动金额(元)',
    balance DECIMAL(10,2) NOT NULL COMMENT '变动后余额(元)',
    transaction_type VARCHAR(30) NOT NULL CHECK (transaction_type IN ('recharge', 'payment', 'refund', 'adjustment')) COMMENT '交易类型',
    description TEXT NOT NULL COMMENT '交易描述',
    reference_id UUID COMMENT '关联ID',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间'
);

-- 11. 系统配置表
COMMENT ON TABLE system_configs IS '系统配置表';
CREATE TABLE system_configs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    key VARCHAR(100) UNIQUE NOT NULL COMMENT '配置键',
    value TEXT NOT NULL COMMENT '配置值',
    description TEXT COMMENT '配置描述',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP COMMENT '更新时间'
);

-- 12. 操作日志表
COMMENT ON TABLE audit_logs IS '系统操作日志表';
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) COMMENT '操作用户ID',
    action VARCHAR(100) NOT NULL COMMENT '操作类型',
    resource_type VARCHAR(50) NOT NULL COMMENT '资源类型',
    resource_id UUID COMMENT '资源ID',
    ip_address INET COMMENT '操作IP',
    details TEXT COMMENT '操作详情',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间'
);

-- 13. 监控数据表
COMMENT ON TABLE monitoring_data IS '虚拟机监控数据表';
CREATE TABLE monitoring_data (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    vm_instance_id UUID NOT NULL REFERENCES vm_instances(id) ON DELETE CASCADE COMMENT '虚拟机实例ID',
    metric_type VARCHAR(50) NOT NULL COMMENT '指标类型(cpu/memory/disk/network)',
    value DECIMAL(10,4) NOT NULL COMMENT '指标值',
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL COMMENT '记录时间',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间'
);

-- 14. 工单系统表
COMMENT ON TABLE support_tickets IS '用户工单表';
CREATE TABLE support_tickets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE COMMENT '提交用户ID',
    subject VARCHAR(255) NOT NULL COMMENT '工单主题',
    status VARCHAR(20) DEFAULT 'open' CHECK (status IN ('open', 'pending', 'resolved', 'closed')) COMMENT '工单状态',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP COMMENT '更新时间'
);

-- 15. 工单消息表
COMMENT ON TABLE ticket_messages IS '工单消息表';
CREATE TABLE ticket_messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ticket_id UUID NOT NULL REFERENCES support_tickets(id) ON DELETE CASCADE COMMENT '关联工单ID',
    sender_id UUID NOT NULL REFERENCES users(id) COMMENT '发送者ID',
    content TEXT NOT NULL COMMENT '消息内容',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间'
);

-- 创建索引
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_phone ON users(phone);
CREATE INDEX idx_vm_instances_user_id ON vm_instances(user_id);
CREATE INDEX idx_vm_instances_status ON vm_instances(status);
CREATE INDEX idx_invoices_user_id ON invoices(user_id);
CREATE INDEX idx_invoices_status ON invoices(status);
CREATE INDEX idx_payments_user_id ON payments(user_id);
CREATE INDEX idx_monitoring_data_vm_instance_id ON monitoring_data(vm_instance_id);
CREATE INDEX idx_monitoring_data_timestamp ON monitoring_data(timestamp);

-- 更新时间触发器函数
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 为表创建更新时间触发器
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_pve_nodes_updated_at BEFORE UPDATE ON pve_nodes FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_product_plans_updated_at BEFORE UPDATE ON product_plans FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_vm_instances_updated_at BEFORE UPDATE ON vm_instances FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_system_configs_updated_at BEFORE UPDATE ON system_configs FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_support_tickets_updated_at BEFORE UPDATE ON support_tickets FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 插入初始系统配置
INSERT INTO system_configs (key, value, description) VALUES
('site_name', '云主机租用平台', '网站名称'),
('min_recharge_amount', '10', '最小充值金额(元)'),
('max_recharge_amount', '10000', '最大充值金额(元)'),
('auto_suspend_days', '7', '欠费自动暂停天数'),
('max_instances_per_user', '10', '每用户最大实例数'),
('enable_phone_verification', 'true', '是否启用手机验证'),
('default_os_template', 'centos-8', '默认操作系统模板');

-- 创建视图：用户资源使用统计
CREATE VIEW user_resource_usage AS
SELECT 
    u.id as user_id,
    u.username,
    COUNT(vm.id) as total_instances,
    COUNT(CASE WHEN vm.status = 'running' THEN 1 END) as running_instances,
    COALESCE(SUM(vm.cpu_cores), 0) as total_cpu_cores,
    COALESCE(SUM(vm.memory_gb), 0) as total_memory_gb,
    COALESCE(SUM(vm.storage_gb), 0) as total_storage_gb,
    u.balance
FROM users u
LEFT JOIN vm_instances vm ON u.id = vm.user_id AND vm.status != 'deleted'
GROUP BY u.id, u.username, u.balance;