# Rust 后端 API 模块设计

## 一、技术栈建议
- **Web框架**: Actix-web (高性能、生态丰富、文档完善)
- **数据库**: SQLx (异步、类型安全)
- **认证**: JWT + Argon2 (密码哈希)
- **序列化**: Serde
- **日志**: Env_logger / Log
- **配置**: Config crate
- **任务调度**: Actix-cron (可选)
- **中间件**: Actix-web-middleware (CORS、限流等)

## 二、项目结构
```
├── src/
│   ├── main.rs                          # 应用入口
│   ├── config.rs                        # 配置管理
│   ├── lib.rs                           # 库入口
│   ├── app.rs                           # 应用状态和配置
│   │
│   ├── models/                          # 数据模型
│   │   ├── mod.rs
│   │   ├── user.rs                      # 用户模型
│   │   ├── vm_instance.rs               # 虚拟机实例
│   │   ├── payment.rs                   # 支付相关
│   │   ├── ticket.rs                    # 工单模型
│   │   ├── pve_node.rs                  # PVE节点
│   │   └── system_config.rs             # 系统配置
│   │
│   ├── handlers/                        # 路由处理器 (Actix-web handlers)
│   │   ├── mod.rs
│   │   ├── auth.rs                      # 认证处理
│   │   ├── user.rs                      # 用户管理
│   │   ├── vm.rs                        # 虚拟机管理
│   │   ├── payment.rs                   # 支付处理
│   │   ├── ticket.rs                    # 工单处理
│   │   ├── admin.rs                     # 管理员功能
│   │   └── report.rs                    # 统计报表
│   │
│   ├── routes/                          # 路由配置
│   │   ├── mod.rs
│   │   ├── auth.rs                      # 认证路由
│   │   ├── user.rs                      # 用户路由
│   │   ├── vm.rs                        # 虚拟机路由
│   │   ├── payment.rs                   # 支付路由
│   │   ├── ticket.rs                    # 工单路由
│   │   └── admin.rs                     # 管理员路由
│   │
│   ├── services/                        # 业务逻辑层
│   │   ├── mod.rs
│   │   ├── auth_service.rs              # 认证服务
│   │   ├── user_service.rs              # 用户服务
│   │   ├── vm_service.rs                # 虚拟机服务
│   │   ├── pve_service.rs               # PVE API服务
│   │   ├── payment_service.rs           # 支付服务
│   │   ├── ticket_service.rs            # 工单服务
│   │   ├── email_service.rs             # 邮件服务
│   │   └── report_service.rs            # 报表服务
│   │
│   ├── middleware/                      # Actix-web中间件
│   │   ├── mod.rs
│   │   ├── auth.rs                      # JWT验证中间件
│   │   ├── admin.rs                     # 管理员权限中间件
│   │   ├── cors.rs                      # CORS处理
│   │   ├── rate_limit.rs                # 限流中间件
│   │   └── logging.rs                   # 日志记录中间件
│   │
│   ├── utils/                           # 工具函数
│   │   ├── mod.rs
│   │   ├── crypto.rs                    # 加密工具
│   │   ├── email.rs                     # 邮件工具
│   │   ├── jwt.rs                       # JWT工具
│   │   ├── validation.rs                # 验证工具
│   │   └── error.rs                     # 错误处理
│   │
│   ├── database/                        # 数据库相关
│   │   ├── mod.rs
│   │   ├── connection.rs                # 数据库连接
│   │   └── migrations.rs                # 迁移管理
│   │
│   └── types/                           # 类型定义
│       ├── mod.rs
│       ├── requests.rs                  # 请求类型
│       ├── responses.rs                 # 响应类型
│       └── enums.rs                     # 枚举类型
│
├── migrations/                          # 数据库迁移文件
│   ├── 001_initial_schema.sql
│   ├── 002_add_tickets.sql
│   └── ...
│
├── tests/                               # 测试文件
│   ├── integration/
│   │   ├── auth_tests.rs
│   │   ├── vm_tests.rs
│   │   └── payment_tests.rs
│   └── unit/
│       ├── services/
│       └── utils/
│
├── docs/                                # 文档
│   ├── api.md                          # API文档
│   ├── deployment.md                   # 部署文档
│   └── development.md                  # 开发文档
│
├── Cargo.toml                          # 依赖配置
├── .env.example                        # 环境变量示例
├── docker-compose.yml                  # Docker编排
└── Dockerfile                          # Docker镜像
```

## 三、详细的开发优先级规划

### 第一阶段：基础架构
**优先级：P0**
- 项目初始化和环境搭建
- 数据库设计和迁移
- 基础中间件（CORS、日志、错误处理）
- JWT认证机制

并且实现以下两个接口，不需要鉴权

```
POST /health                  # 健康检测
POST /pve_version             # PVE调用示例
```

### 第二阶段：核心认证系统
**优先级：P0**
```
POST /auth/register           # 用户注册
POST /auth/login              # 用户登录  
POST /auth/logout             # 用户登出
POST /auth/refresh            # 刷新令牌
POST /auth/verify             # 验证验证码
POST /auth/reset-password     # 重置密码
```

### 第三阶段：用户基础功能
**优先级：P0**
```
GET  /user/profile           # 获取个人信息
PUT  /user/profile           # 更新个人信息
GET  /user/balance           # 获取余额
POST /user/balance/recharge  # 余额充值
```

### 第四阶段：虚拟机核心功能
**优先级：P0**
```
GET  /vm/plans               # 获取可用套餐
GET  /vm/instances           # 获取虚拟机列表
POST /vm/instances           # 创建虚拟机
GET  /vm/instances/{id}      # 获取虚拟机详情
POST /vm/instances/{id}/start    # 启动虚拟机
POST /vm/instances/{id}/stop     # 停止虚拟机
POST /vm/instances/{id}/restart  # 重启虚拟机
DELETE /vm/instances/{id}        # 删除虚拟机
```

### 第五阶段：支付系统
**优先级：P1**
```
POST /payment/recharge           # 创建充值订单
GET  /payment/recharge/{id}      # 获取充值订单状态
GET  /payment/history            # 获取支付记录
```

### 第六阶段：工单系统
**优先级：P1**
```
GET  /tickets                    # 获取工单列表
POST /tickets                    # 创建工单
GET  /tickets/{id}               # 获取工单详情
POST /tickets/{id}/messages      # 添加工单回复
```

### 第七阶段：监控与高级功能
**优先级：P2**
```
GET  /vm/instances/{id}/stats    # 获取监控数据
POST /vm/instances/{id}/migrate  # 迁移虚拟机
POST /vm/templates               # 添加系统模板
```

### 第八阶段：管理员功能
**优先级：P2**
```
# 管理员认证
POST /auth/admin/login           # 管理员登录
GET  /auth/admin/users           # 查看用户列表

# 用户管理
PUT  /admin/users/{id}/balance   # 调整用户余额
PUT  /admin/users/{id}/status    # 修改用户状态

# 虚拟机管理
GET  /admin/vm/instances         # 获取所有虚拟机

# 支付管理
GET  /admin/payment/transactions # 获取所有交易记录
POST /admin/payment/refund       # 执行退款

# 工单管理
GET  /admin/tickets              # 获取所有工单
PUT  /admin/tickets/{id}/status  # 更新工单状态
```

### 第九阶段：报表系统
**优先级：P3**
```
GET  /admin/report/daily-income    # 每日收入统计
GET  /admin/report/user-growth     # 用户增长统计
GET  /admin/report/resource-usage  # 资源使用统计
GET  /admin/report/node-status     # 节点状态统计
```

### 第十阶段：系统管理
**优先级：P3**
```
GET  /admin/system/config        # 获取系统配置
PUT  /admin/system/config        # 更新系统配置
GET  /admin/system/logs          # 查看系统日志
```
