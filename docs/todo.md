# Rust 后端 API 模块设计

## 🏗️ 技术栈建议
- **Web框架**: Actix-web (高性能、生态丰富、文档完善)
- **数据库**: SQLx (异步、类型安全)
- **认证**: JWT + Argon2 (密码哈希)
- **序列化**: Serde
- **日志**: Env_logger / Log
- **配置**: Config crate
- **任务调度**: Actix-cron (可选)
- **中间件**: Actix-web-middleware (CORS、限流等)

## 📁 项目结构
```
src/
├── main.rs                 # 程序入口
├── config/                 # 配置模块
│   ├── mod.rs
│   └── database.rs
├── middleware/             # 中间件
│   ├── mod.rs
│   ├── auth.rs
│   └── rate_limit.rs
├── models/                 # 数据模型
│   ├── mod.rs
│   ├── user.rs
│   ├── vm.rs
│   └── billing.rs
├── handlers/               # 请求处理器
│   ├── mod.rs
│   ├── auth.rs
│   ├── user.rs
│   ├── vm.rs
│   └── billing.rs
├── services/               # 业务逻辑
│   ├── mod.rs
│   ├── user_service.rs
│   ├── vm_service.rs
│   └── billing_service.rs
├── database/               # 数据库操作
│   ├── mod.rs
│   └── connection.rs
├── utils/                  # 工具函数
│   ├── mod.rs
│   ├── crypto.rs
│   └── email.rs
└── errors/                 # 错误处理
    ├── mod.rs
    └── api_error.rs
```

---

## 🔐 1. 认证授权模块 (Auth)

### 接口列表
- **POST** `/api/auth/register` - 用户注册
- **POST** `/api/auth/login` - 用户登录
- **POST** `/api/auth/logout` - 用户登出
- **POST** `/api/auth/refresh` - 刷新Token
- **POST** `/api/auth/forgot-password` - 忘记密码
- **POST** `/api/auth/reset-password` - 重置密码
- **POST** `/api/auth/verify-email` - 验证邮箱
- **POST** `/api/auth/resend-verification` - 重发验证邮件
- **GET** `/api/auth/me` - 获取当前用户信息

### 核心功能
- JWT Token 生成和验证
- 密码安全哈希 (Argon2)
- 邮箱验证流程
- 登录频率限制
- 会话管理

---

## 👤 2. 用户管理模块 (Users)

### 用户接口
- **GET** `/api/users/profile` - 获取用户资料
- **PUT** `/api/users/profile` - 更新用户资料
- **POST** `/api/users/change-password` - 修改密码
- **GET** `/api/users/balance` - 获取账户余额
- **GET** `/api/users/transactions` - 获取余额变动记录
- **POST** `/api/users/upload-avatar` - 上传头像

### 管理员接口
- **GET** `/api/admin/users` - 用户列表（分页、搜索）
- **GET** `/api/admin/users/{id}` - 获取用户详情
- **PUT** `/api/admin/users/{id}` - 更新用户信息
- **PUT** `/api/admin/users/{id}/status` - 修改用户状态
- **POST** `/api/admin/users/{id}/adjust-balance` - 调整用户余额
- **GET** `/api/admin/users/{id}/audit-logs` - 用户操作日志

---

## 🖥️ 3. 虚拟机管理模块 (VMs)

### 用户接口
- **GET** `/api/vms` - 获取我的虚拟机列表
- **POST** `/api/vms` - 创建虚拟机
- **GET** `/api/vms/{id}` - 获取虚拟机详情
- **PUT** `/api/vms/{id}` - 更新虚拟机配置
- **DELETE** `/api/vms/{id}` - 删除虚拟机
- **POST** `/api/vms/{id}/start` - 启动虚拟机
- **POST** `/api/vms/{id}/stop` - 关闭虚拟机
- **POST** `/api/vms/{id}/restart` - 重启虚拟机
- **POST** `/api/vms/{id}/reset-password` - 重置root密码
- **GET** `/api/vms/{id}/console` - 获取控制台链接
- **GET** `/api/vms/{id}/monitoring` - 获取监控数据

### 管理员接口
- **GET** `/api/admin/vms` - 所有虚拟机列表
- **GET** `/api/admin/vms/{id}` - 虚拟机详情
- **PUT** `/api/admin/vms/{id}/status` - 强制修改状态
- **POST** `/api/admin/vms/{id}/migrate` - 迁移虚拟机
- **GET** `/api/admin/vms/statistics` - 虚拟机统计信息

---

## 💳 4. 计费支付模块 (Billing)

### 用户接口
- **POST** `/api/billing/recharge` - 创建充值订单
- **GET** `/api/billing/invoices` - 获取账单列表
- **GET** `/api/billing/invoices/{id}` - 获取账单详情
- **POST** `/api/billing/invoices/{id}/pay` - 支付账单
- **GET** `/api/billing/payments` - 支付记录
- **GET** `/api/billing/usage` - 资源使用统计

### Stripe 回调接口
- **POST** `/api/billing/stripe/webhook` - Stripe 支付回调

### 管理员接口
- **GET** `/api/admin/billing/invoices` - 所有账单
- **POST** `/api/admin/billing/invoices/{id}/cancel` - 取消账单
- **GET** `/api/admin/billing/payments` - 所有支付记录
- **POST** `/api/admin/billing/refund` - 退款处理
- **GET** `/api/admin/billing/statistics` - 财务统计

---

## 📦 5. 产品套餐模块 (Plans)

### 用户接口
- **GET** `/api/plans` - 获取可用套餐列表
- **GET** `/api/plans/{id}` - 获取套餐详情

### 管理员接口
- **GET** `/api/admin/plans` - 所有套餐列表
- **POST** `/api/admin/plans` - 创建套餐
- **PUT** `/api/admin/plans/{id}` - 更新套餐
- **DELETE** `/api/admin/plans/{id}` - 删除套餐
- **PUT** `/api/admin/plans/{id}/status` - 修改套餐状态

---

## 🗝️ 6. SSH密钥管理模块 (SSH Keys)

### 用户接口
- **GET** `/api/ssh-keys` - 获取SSH密钥列表
- **POST** `/api/ssh-keys` - 添加SSH密钥
- **GET** `/api/ssh-keys/{id}` - 获取SSH密钥详情
- **PUT** `/api/ssh-keys/{id}` - 更新SSH密钥
- **DELETE** `/api/ssh-keys/{id}` - 删除SSH密钥

---

## 🔧 7. 系统管理模块 (System)

### 节点管理接口
- **GET** `/api/admin/nodes` - PVE节点列表
- **POST** `/api/admin/nodes` - 添加PVE节点
- **GET** `/api/admin/nodes/{id}` - 节点详情
- **PUT** `/api/admin/nodes/{id}` - 更新节点配置
- **DELETE** `/api/admin/nodes/{id}` - 删除节点
- **GET** `/api/admin/nodes/{id}/resources` - 节点资源使用情况

### 系统配置接口
- **GET** `/api/admin/configs` - 系统配置列表
- **PUT** `/api/admin/configs/{key}` - 更新配置项
- **GET** `/api/admin/system/info` - 系统信息
- **GET** `/api/admin/system/logs` - 系统日志

---

## 🎫 8. 工单支持模块 (Support)

### 用户接口
- **GET** `/api/support/tickets` - 我的工单列表
- **POST** `/api/support/tickets` - 创建工单
- **GET** `/api/support/tickets/{id}` - 工单详情
- **POST** `/api/support/tickets/{id}/messages` - 发送消息
- **PUT** `/api/support/tickets/{id}/close` - 关闭工单

### 管理员接口
- **GET** `/api/admin/support/tickets` - 所有工单
- **PUT** `/api/admin/support/tickets/{id}/assign` - 分配工单
- **PUT** `/api/admin/support/tickets/{id}/status` - 修改工单状态
- **POST** `/api/admin/support/tickets/{id}/messages` - 回复工单

---

## 🔔 9. 通知模块 (Notifications)

### 用户接口
- **GET** `/api/notifications` - 获取通知列表
- **PUT** `/api/notifications/{id}/read` - 标记已读
- **PUT** `/api/notifications/read-all` - 全部标记已读
- **DELETE** `/api/notifications/{id}` - 删除通知

### 管理员接口
- **POST** `/api/admin/notifications/broadcast` - 广播通知
- **GET** `/api/admin/notifications/statistics` - 通知统计

---

## 💾 10. 备份管理模块 (Backups)

### 用户接口
- **GET** `/api/backups` - 获取备份列表
- **POST** `/api/backups` - 创建备份
- **GET** `/api/backups/{id}` - 备份详情
- **POST** `/api/backups/{id}/restore` - 恢复备份
- **DELETE** `/api/backups/{id}` - 删除备份

### 管理员接口
- **GET** `/api/admin/backups` - 所有备份列表
- **POST** `/api/admin/backups/cleanup` - 清理过期备份

---

## 🌐 11. PVE集成模块 (PVE Integration)

### 内部接口（不直接暴露）
- `sync_vm_status()` - 同步虚拟机状态
- `create_vm()` - 在PVE上创建虚拟机
- `control_vm()` - 控制虚拟机（启动/停止/重启）
- `get_vm_monitoring()` - 获取虚拟机监控数据
- `create_backup()` - 创建备份
- `get_node_resources()` - 获取节点资源

---

## 📊 12. 统计报表模块 (Analytics)

### 管理员接口
- **GET** `/api/admin/analytics/dashboard` - 仪表板数据
- **GET** `/api/admin/analytics/users` - 用户统计
- **GET** `/api/admin/analytics/revenue` - 收入统计
- **GET** `/api/admin/analytics/resources` - 资源使用统计
- **GET** `/api/admin/analytics/performance` - 性能统计

---

## 🔒 权限设计

### 角色定义
- **user**: 普通用户，只能管理自己的资源
- **admin**: 管理员，可以管理所有资源
- **support**: 客服，可以查看工单和用户信息

### 权限中间件
```rust
// 示例权限检查 (Actix-web 风格)
pub async fn require_auth() -> Result<HttpResponse, ApiError>
pub async fn require_admin() -> Result<HttpResponse, ApiError>
pub async fn require_resource_owner(resource_id: Uuid) -> Result<HttpResponse, ApiError>

// Actix-web 中间件示例
use actix_web::{dev::ServiceRequest, Error, HttpMessage};
use actix_web_httpauth::extractors::bearer::BearerAuth;

pub async fn jwt_middleware(
    req: ServiceRequest,
    credentials: BearerAuth,
) -> Result<ServiceRequest, Error> {
    // JWT 验证逻辑
}
```

---

## 🚀 实现建议

### 1. 核心优先级
1. **认证授权** - 系统基础
2. **用户管理** - 用户体验
3. **虚拟机管理** - 核心功能
4. **计费支付** - 商业模式
5. **PVE集成** - 底层对接

### 2. 轻量化策略
- 使用 Actix-web 框架，性能优异且文档完善
- 数据库操作使用 SQLx，避免重型ORM
- 最小化依赖，只引入必要的crate
- 利用 Actix-web 的中间件系统简化开发

### 3. Actix-web 特有优势
- **高性能**：基于 Actor 模型，并发性能优异
- **中间件丰富**：认证、CORS、限流等中间件齐全
- **文档完善**：学习资料丰富，社区活跃
- **生态成熟**：与各种数据库、缓存集成良好

### 3. 可维护性
- 清晰的模块划分
- 统一的错误处理
- 完善的日志记录
- 简单的配置管理

### 4. 扩展性
- 预留接口扩展点
- 模块化设计便于功能增减
- 支持多节点扩展

