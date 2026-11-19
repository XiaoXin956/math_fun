# 数学乐园 🧮

一款面向小学生的算术计算小游戏。

- **前端**：Flutter 项目 `math_fun_app`，包名 `com.xiaoxin.math_fun_app`，状态管理使用 **BLoC**
- **后端**：Dart 服务 `math_fun_service` + MySQL（数据库驱动使用 `mysql_client` 包）

## 功能

- **四种玩法**
  - 🎯 自由练习：自选年级与运算（加/减/乘/除/混合），每次 10 题
  - 🏆 闯关挑战：每个年级 5 关，正确率 ≥ 70% 通关，按表现获得 ⭐
  - ⏰ 限时挑战：60 秒倒计时，答得越多分越高，记录最佳成绩
  - ✍️ 手写练习：出带书写区的算术题，孩子手写答案后提交给家长批改
- **积分奖励系统**
  - 闯关完成自动结算积分：成功率 **≥ 95% +3 分**；成功率在 **80%~95% 不加不减**；成功率 **不足 80%（含 60%）-3 分**
  - 闯关**中途退出 -5 分**，退出前弹窗提醒
  - **同一关卡 7 天内重复挑战不再加分**
  - 手写题由家长批改：判断正确自动加分，错误扣分，**分值由家长决定（0~10 分）**
- **积分明细**：App 内「积分明细」页面可查看当前总分及每条记录的
  **积分来源**（闯关结算 / 中途退出 / 手写批改）与**加减分理由**、时间
- **按年级自动适配难度**：一年级（20 以内加减）到六年级（大数四则混合运算）
- **家长-孩子账号绑定**：家长登录后创建孩子账号，自动建立绑定关系；家长可查看孩子成绩、批改手写答案
- 题目由**服务端生成**，答案不下发到客户端，判分在服务端完成

## 目录结构

```
math_fun/
├── docker-compose.yml           # 一键启动后端服务（直连远程 MySQL）
├── math_fun_service/            # Dart 服务端 math_fun_service
│   ├── Dockerfile
│   ├── pubspec.yaml
│   ├── db/
│   │   ├── schema.sql           # 完整建库建表 SQL
│   │   └── seed.sql             # 演示账号
│   └── lib/
│       ├── main.dart            # 入口与路由注册
│       ├── http_router.dart     # 轻量 HTTP 路由（dart:io）
│       ├── config.dart          # 环境变量配置
│       ├── db.dart              # MySQL 连接池 + 自动建表
│       ├── auth.dart            # 密码哈希 / token
│       ├── question_generator.dart # 按年级出题
│       └── handlers.dart        # 业务接口
└── math_fun_app/                # Flutter 应用 math_fun_app（BLoC 状态管理）
    ├── pubspec.yaml
    └── lib/
        ├── main.dart            # 应用入口、BlocProvider 根布局
        ├── bloc/                # BLoC：AuthCubit（认证/会话）、PointsCubit（积分）
        ├── api/                 # API 客户端与地址配置
        ├── models/              # 数据模型
        ├── services/session.dart # 登录会话持久化
        ├── widgets/             # 公共组件、答题组件、手写画板
        └── pages/               # 登录、首页、练习、闯关、限时、
                                 # 手写、批改、积分、成绩
```

## MySQL SQL 文件

- `math_fun_service/db/schema.sql`：完整建库建表语句（用户、会话、题目、记录、闯关进度、限时成绩、积分记录、手写提交）
- `math_fun_service/db/seed.sql`：演示账号（家长 + 孩子，自动绑定）

手动导入（如需在本地独立建库时）：

```bash
mysql -uroot -p < math_fun_service/db/schema.sql
mysql -uroot -p < math_fun_service/db/seed.sql
```

> 默认部署使用**远程 MySQL**（配置在 `math_fun_service/.env`），docker-compose 不再启动本地 MySQL 容器，也不会自动导入这两个文件。
> 后端首次启动会自动执行幂等建表（`CREATE TABLE IF NOT EXISTS`），无需手动导入 `schema.sql`；演示账号需按需手动导入 `seed.sql`。

## 快速开始（Docker 一键部署：Web 客户端 + 后端）

前提：本机已安装 Docker 与 Docker Compose，且 `.env` 中已配置好可连接的远程 MySQL。

```bash
docker compose up -d --build
```

启动后：

- **Web 客户端**：http://localhost:8083（nginx 托管 Flutter Web，`/api/*` 同源反代到后端容器）
- **后端 API**：http://localhost:8082（数据库为 `.env` 中配置的远程 MySQL，供手机 App 直连）

演示账号（密码均为 `123456`，需先在远程库中导入 `db/seed.sql`，生产环境请修改）：

| 账号 | 角色 | 说明 |
| --- | --- | --- |
| `parent` | 家长 | 登录后可添加孩子、批改手写答案、查看成绩 |
| `xiaoming` | 孩子 | 二年级，已绑定 `parent`，可直接开始游戏 |

### 手动启动后端（不用 Docker）

需要本机安装 Dart SDK（3.3+），并有一个可连接的 MySQL（本地或远程均可）。

在 `math_fun_service/.env` 中配置数据库连接（该文件已被 .gitignore 忽略，不会提交到仓库）：

```env
DB_HOST=127.0.0.1
DB_PORT=3306
DB_USER=root
DB_PASSWORD=123456
DB_NAME=math_fun
DB_SECURE=false
PORT=8082
```

> 配置优先级：**系统环境变量 > .env 文件 > 代码默认值**。
> 若你的 MySQL 使用 `caching_sha2_password` 认证（MySQL 8 默认）或连接远程库，需设置 `DB_SECURE=true` 启用 TLS，否则会报
> `Auth plugin caching_sha2_password is supported only with secure connections`。

首次运行会自动建表，无需手动导入 `db/schema.sql`。

```bash
cd math_fun_service
dart pub get
dart run lib/main.dart
```

服务启动后会打印 `[db] MySQL 连接成功: host:port/db` 与监听地址。

## 运行前端（Flutter）

需要本机安装 Flutter SDK（3.3+）。首次需要生成平台工程并指定包名：

```bash
cd math_fun_app
# 生成 android/ios 等平台目录，包名 com.xiaoxin.math_fun_app
flutter create --org com.xiaoxin --project-name math_fun_app .
flutter pub get
flutter run
```

> **重要**：默认后端地址是 `http://10.0.2.2:8082`（Android 模拟器访问宿主机）。
> 真机调试请修改 `math_fun_app/lib/api/config.dart` 中的 `apiBaseUrl` 为后端所在机器的 IP，例如
> `http://192.168.1.10:8082`。

## 状态管理（BLoC）

前端全局状态由 BLoC 管理，页面局部交互状态使用 setState：

- **AuthCubit**：登录、注册、登出、本地会话恢复、刷新用户（含积分）。
  登录状态变化时，根布局自动在「登录页 / 首页」间切换，无需手动导航
- **PointsCubit**：积分总分与明细的加载、刷新，供「积分明细」页消费
- 积分发生变动（闯关结算、中途退出、手写批改）后，相关页面会触发
  `AuthCubit.refresh()`，首页积分实时同步

## 积分规则说明

闯关完成时自动结算（服务端计算）：

| 成功率 | 积分 |
| --- | --- |
| ≥ 95% | +3 |
| 80% ~ 95% | 0（不加不减） |
| < 80%（含 60%） | -3 |

其他规则：

- **中途退出**：闯关未答完就退出，扣 **5 分**，退出前有弹窗提醒
- **7 天限制**：同一关卡（同年级同关卡号）7 天内重复完成，不再加分
- **手写批改**：家长判断正确 → 加家长所选分值；判断错误 → 扣家长所选分值；分值 0~10，默认 5

积分明细可在 App 内「积分明细」页面查看，每条记录包含**积分来源**（闯关结算 / 中途退出 / 手写批改）、**加减分理由**、关卡信息与时间。

## 主要 API

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| POST | `/api/auth/register` | 注册（角色 parent/child） |
| POST | `/api/auth/login` | 登录，返回 token |
| GET | `/api/auth/me` | 当前用户与孩子列表 |
| GET | `/api/grades` | 年级配置 |
| POST | `/api/questions` | 生成题目（`type` 为 `math` 或 `handwriting`，答案仅存服务端） |
| POST | `/api/results` | 提交答案判分并记录 |
| POST | `/api/handwriting/submit` | 提交手写答案图片（base64 PNG） |
| GET | `/api/handwriting/pending` | 家长查看待批改列表 |
| POST | `/api/handwriting/review` | 家长批改（correct + points 0-10） |
| GET | `/api/history` | 本人答题记录 |
| GET | `/api/stats` | 统计 |
| GET/POST | `/api/progress/challenge` | 闯关进度查询 / 上报（自动结算积分） |
| POST | `/api/progress/challenge/quit` | 闯关中途退出（扣 5 分） |
| GET/POST | `/api/progress/timed` | 限时最佳成绩查询 / 上报 |
| GET | `/api/points` | 积分明细与总分 |
| POST/GET | `/api/children` | 家长添加 / 查看孩子（自动绑定） |
| GET | `/api/children/:id/history` | 查看某孩子的成绩 |

除注册、登录外，所有接口都需要请求头 `Authorization: Bearer <token>`。

## 难度设计

| 年级 | 范围 | 运算 | 步数 |
| --- | --- | --- | --- |
| 一年级 | 20 以内 | 加减 | 1 步 |
| 二年级 | 100 以内 | 加减乘除（表内乘除） | 1 步 |
| 三年级 | 200 以内 | 四则 | 最多 2 步 |
| 四年级 | 500 以内 | 四则 | 最多 3 步 |
| 五年级 | 1000 以内 | 四则 | 最多 3 步 |
| 六年级 | 2000 以内 | 四则 | 最多 3 步 |

所有题目结果与中间过程均为非负整数，除法保证整除；多步运算以括号呈现，保证书写顺序与答案一致。
