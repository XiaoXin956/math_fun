# ---------- 构建阶段 ----------
FROM dart:3.4.4-bookworm AS builder

WORKDIR /app

# 先拷贝依赖清单，利用 Docker 层缓存
COPY pubspec.yaml ./
RUN dart pub get

# 再拷贝源码并编译为可执行文件
COPY lib ./lib
RUN dart compile -o server

# ---------- 运行阶段 ----------
FROM debian:bookworm-slim

WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/server /app/server

ENV HOST=0.0.0.0 \
    PORT=8080 \
    DB_HOST=db \
    DB_PORT=3306 \
    DB_USER=root \
    DB_PASSWORD=math_fun_root \
    DB_NAME=math_fun

EXPOSE 8080

CMD ["/app/server"]
