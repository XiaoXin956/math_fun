# 数学乐园 🧮

一款面向小学生的算术计算小游戏。前端 Flutter，后端 Dart + MySQL。

## 功能

- **三种玩法**
  - 🎯 自由练习：自选年级与运算（加/减/乘/除/混合），每次 10 题
  - 🏆 闯关挑战：每个年级 5 关，正确率 ≥ 70% 通关，按表现获得 ⭐
  - ⏰ 限时挑战：60 秒倒计时，答得越多分越高，记录最佳成绩
- **按年级自动适配难度**：一年级（20 以内加减）到六年级（大数四则混合运算）
- **完整账号体系**：家长/孩子角色注册登录；家长可添加孩子账号并查看孩子成绩
- 题目由**服务端生成**，答案不下发到客户端，判分在服务端完成

## 目录结构

```
math_fun/
├── docker-compose.yml      # 一键启动 MySQL + 后端
├── backend/                # Dart 后端
│   ├── Dockerfile
│   ├── pubspec.yaml
│   ├── db/                 # 数据库初始化 SQL（建表 + 演示账号）
│   └── lib/
│       ├── main.dart            # 入口与路由注册
│       ├── http_router.dart     # 轻量 HTTP 路由（dart:io）
│       ├── config.dart          # 环境变量配置
│       ├── db.dart              # MySQL 连接池 + 自动建表
│       ├── auth.dart            # 密码哈希 / token
│       ├── question_generator.dart # 按年级出题
│       └── handlers.dart        # 业务接口
└── frontend/               # Flutter 前端
    ├── pubspec.yaml
    └── lib/
        ├── main.dart            # 应用入口与主题
        ├── api/                 # API 客户端与地址配置
        ├── models/              # 数据模型
        ├── services/session.dart # 登录会话持久化
        ├── widgets/             # 公共组件、答题组件
        └── pages/               # 登录、首页、练习、闯关、限时、成绩
```

## 快速开始（Docker 一键部署后端）

前提：本机已安装 Docker 与 Docker Compose。

```bash
docker compose up -d --build
```

启动后：

- 后端 API：http://localhost:8080
- MySQL：容器内 `math_fun_db`，数据库 `math_fun`
- 初始化 SQL（建表 + 演示账号）在首次启动数据库时自动执行

演示账号（密码均为 `123456`，生产环境请修改）：

| 账号 | 角色 | 说明 |
| --- | --- | --- |
| `parent` | 家长 | 登录后可添加孩子、查看成绩 |
| `xiaoming` | 孩子 | 二年级，可直接开始游戏 |

### 手动启动后端（不用 Docker）

需要本机安装 Dart SDK（3.3+）与 MySQL 8。

```bash
cd backend
dart pub get
# 创建数据库（表结构会在启动时自动创建）
mysql -uroot -p < db/schema.sql
dart run lib/main.dart \
  -DB_HOST=127.0.0.1 -DB_USER=root -DB_PASSWORD=123456 -DB_NAME=math_fun
```

## 运行前端（Flutter）

需要本机安装 Flutter SDK（3.3+）。

```bash
cd frontend
flutter pub get
flutter run
```

> **重要**：默认后端地址是 `http://10.0.2.2:8080`（Android 模拟器访问宿主机）。
> 真机调试请修改 `frontend/lib/api/config.dart` 中的 `apiBaseUrl` 为后端所在机器的 IP，例如
> `http://192.168.1.10:8080`。

iOS / Web 同理，改好地址后运行对应平台的 `flutter run` 即可。

## 主要 API

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| POST | `/api/auth/register` | 注册（角色 parent/child） |
| POST | `/api/auth/login` | 登录，返回 token |
| GET | `/api/auth/me` | 当前用户与孩子列表 |
| GET | `/api/grades` | 年级配置 |
| POST | `/api/questions` | 生成题目（答案仅存服务端） |
| POST | `/api/results` | 提交答案判分并记录 |
| GET | `/api/history` | 本人答题记录 |
| GET | `/api/stats` | 统计 |
| GET/POST | `/api/progress/challenge` | 闯关进度查询 / 上报 |
| GET/POST | `/api/progress/timed` | 限时最佳成绩查询 / 上报 |
| POST/GET | `/api/children` | 家长添加 / 查看孩子 |
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
