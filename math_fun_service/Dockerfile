# 使用最新稳定版 Dart SDK（需支持 dart build cli）
FROM dart:stable AS build

# 先拷贝依赖清单，利用 Docker 层缓存
WORKDIR /app
COPY pubspec.* ./
RUN dart pub get

# 拷贝源码（.dockerignore 中排除 .env / 构建产物等）
# 再编译为 AOT bundle，产物位于 /app/output/bundle/
COPY . .
RUN dart build cli --target lib/main.dart -o output

# 使用 scratch 最小镜像：仅包含 AOT 运行时与编译产物
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/output/bundle/ /app/

# DB_* / PORT 等环境变量由 docker-compose 注入（HOST 默认 0.0.0.0）
EXPOSE 8082

# 启动服务（入口为 lib/main.dart，对应 bundle/bin/main）
CMD ["/app/bin/main"]
