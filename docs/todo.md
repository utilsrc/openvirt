# Rust 后端 API 模块设计

## 技术栈建议
- **Web框架**: Actix-web (高性能、生态丰富、文档完善)
- **数据库**: SQLx (异步、类型安全)
- **认证**: JWT + Argon2 (密码哈希)
- **序列化**: Serde
- **日志**: Env_logger / Log
- **配置**: Config crate
- **任务调度**: Actix-cron (可选)
- **中间件**: Actix-web-middleware (CORS、限流等)

## 项目结构
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

## 模块与接口设计

设计一个轻量但功能完善的 Rust 后端 API 方案，适合单人维护的小型系统。

### 1. 认证授权模块 (Auth)

#### 用户接口
- `POST /auth/register` - 用户注册（邮箱/手机验证）
- `POST /auth/login` - 用户登录（JWT 返回）
- `POST /auth/logout` - 用户登出
- `POST /auth/refresh` - 刷新令牌
- `POST /auth/verify` - 验证验证码（邮箱/手机）
- `POST /auth/reset-password` - 重置密码

#### 管理员接口
- `POST /auth/admin/login` - 管理员登录
- `GET /auth/admin/users` - 查看用户列表

### 2. 用户模块 (User)

#### 用户接口
- `GET /user/profile` - 获取个人信息
- `PUT /user/profile` - 更新个人信息
- `PUT /user/password` - 修改密码
- `GET /user/balance` - 获取余额
- `POST /user/balance/recharge` - 余额充值

#### 管理员接口
- `PUT /admin/users/{id}/balance` - 调整用户余额
- `PUT /admin/users/{id}/status` - 修改用户状态

### 3. 虚拟机管理模块 (VM)

#### 用户接口
- `GET /vm/instances` - 获取我的虚拟机列表
- `POST /vm/instances` - 创建新虚拟机
- `GET /vm/instances/{id}` - 获取虚拟机详情
- `POST /vm/instances/{id}/start` - 启动虚拟机
- `POST /vm/instances/{id}/stop` - 停止虚拟机
- `POST /vm/instances/{id}/restart` - 重启虚拟机
- `DELETE /vm/instances/{id}` - 删除虚拟机
- `GET /vm/instances/{id}/stats` - 获取虚拟机监控数据
- `GET /vm/plans` - 获取可用套餐列表

#### 管理员接口
- `GET /admin/vm/instances` - 获取所有虚拟机
- `POST /admin/vm/instances/{id}/migrate` - 迁移虚拟机
- `POST /admin/vm/templates` - 添加操作系统模板

### 4. 支付模块 (Payment)

#### 用户接口
- `POST /payment/recharge` - 创建充值订单
- `GET /payment/recharge/{id}` - 获取充值订单状态
- `GET /payment/history` - 获取支付记录

#### 管理员接口
- `GET /admin/payment/transactions` - 获取所有交易记录
- `POST /admin/payment/refund` - 执行退款

### 5. 工单模块 (Ticket)

#### 用户接口
- `GET /tickets` - 获取我的工单列表
- `POST /tickets` - 创建新工单
- `GET /tickets/{id}` - 获取工单详情
- `POST /tickets/{id}/messages` - 添加工单回复

#### 管理员接口
- `GET /admin/tickets` - 获取所有工单
- `PUT /admin/tickets/{id}/status` - 更新工单状态

### 6. 统计报表模块 (Report) - 仅管理员

- `GET /admin/report/daily-income` - 每日收入统计
- `GET /admin/report/user-growth` - 用户增长统计
- `GET /admin/report/resource-usage` - 资源使用统计
- `GET /admin/report/node-status` - 节点状态统计

### 7. 系统管理模块 (System) - 仅管理员

- `GET /admin/system/config` - 获取系统配置
- `PUT /admin/system/config` - 更新系统配置
- `GET /admin/system/logs` - 查看系统日志

## 优先级规划

### 开发优先级 (Todo List)

#### 第一阶段: 核心功能 (1-2周)
1. [ ] 项目初始化 + 基础配置
2. [ ] 用户认证模块 (注册/登录/JWT)
3. [ ] 用户管理基础API
4. [ ] PVE API 封装层
5. [ ] 虚拟机生命周期管理 (创建/启动/停止/删除)
6. [ ] 基础支付接口 (充值/扣费)

#### 第二阶段: 必要功能 (1周)
1. [ ] 套餐管理
2. [ ] 余额系统
3. [ ] 工单系统基础
4. [ ] 管理员用户管理
5. [ ] 基础监控数据收集

#### 第三阶段: 增强功能 (1周)
1. [ ] 统计报表功能
2. [ ] 系统配置管理
3. [ ] 操作日志记录
4. [ ] 自动化任务 (到期检测等)

#### 第四阶段: 优化与安全 (持续)
1. [ ] 输入验证增强
2. [ ] 安全审计
3. [ ] 性能优化
4. [ ] 文档完善

### 维护建议

1. **监控**: 实现简单的健康检查接口 `GET /health`
2. **备份**: 设置每日数据库自动备份
3. **日志**: 确保关键操作都有日志记录
4. **文档**: 使用 Swagger UI 或 Redoc 维护API文档
5. **部署**: 使用 systemd 管理服务进程

### 轻量化实现技巧

1. 合并相似功能接口 (如验证码发送)
2. 简化错误处理，使用统一的错误响应格式
3. 避免过度抽象，保持代码直接可读
4. 使用简单的内存缓存而不是Redis
5. 对于小型系统，可以暂时省略消息队列

### 安全注意事项

1. 所有用户输入必须验证
2. 敏感操作需要二次确认
3. 密码必须加盐哈希存储
4. JWT 设置合理过期时间
5. 管理员接口需要严格权限控制
6. 定期更新依赖库

这个设计保持了轻量化的同时覆盖了核心业务需求，适合单人开发和维护。您可以根据实际需求进一步调整接口细节。
