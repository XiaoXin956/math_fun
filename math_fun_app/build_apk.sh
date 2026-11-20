#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

ENV_FILE=".env.apk"

if [ ! -f "$ENV_FILE" ]; then
  echo "[build_apk] 未找到 $ENV_FILE，已从模板生成，请确认地址后重新运行。"
  cp ".env.apk.example" "$ENV_FILE"
  exit 1
fi

API_URL="$(grep '^API_BASE_URL=' "$ENV_FILE" | head -n 1 | cut -d= -f2-)"
echo "[build_apk] API_BASE_URL = $API_URL"
echo "[build_apk] 提示：换后端只改 $ENV_FILE 一行，无需改任何 Dart 代码。"

# 每次构建前清理旧产物，避免 APK 混淆版本混杂
flutter clean >/dev/null 2>&1 || true
flutter pub get

COMMON_FLAGS=(
  --release
  --dart-define-from-file="$ENV_FILE"
  --obfuscate
  --split-debug-info=build/symbols
)

if [ -n "${SINGLE_ABI:-}" ]; then
  echo "[build_apk] 单 ABI 模式：$SINGLE_ABI"
  flutter build apk "${COMMON_FLAGS[@]}" --target-platform "android-$SINGLE_ABI"
else
  echo "[build_apk] 多 ABI 分包模式（arm64-v8a / armeabi-v7a / x86_64）"
  flutter build apk "${COMMON_FLAGS[@]}" --split-per-abi
fi

echo ""
echo "[build_apk] 构建完成，产物："
ls -lh build/app/outputs/flutter-apk/*.apk
echo ""
echo "[build_apk] 混淆符号表：build/symbols（排查线上崩溃时需保留）"
