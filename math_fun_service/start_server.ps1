# 本地启动 math_fun_service：从 .env 加载环境变量后运行。
# Docker 部署不需要此脚本（compose 的 env_file 会注入环境变量）。
#
# 用法（在 math_fun_service 目录下）：
#   .\start_server.ps1
#
# 若想临时连别的数据库，可先在本窗口设置环境变量再运行，例如：
#   $env:DB_HOST='127.0.0.1'; $env:DB_PORT='3306'; .\start_server.ps1
#   注意：脚本会以 .env 的值为准加载；如需完全自定义，直接 export 变量后 dart run lib/main.dart

# 读取 .env 到当前进程环境变量（已存在的系统/会话环境变量优先，不被覆盖）
$envFile = Join-Path $PSScriptRoot '.env'
if (Test-Path $envFile) {
  Get-Content $envFile | ForEach-Object {
    if ($_ -match '^\s*([^#=\s]+)\s*=\s*(.*?)\s*$') {
      $key = $Matches[1]
      if (-not [Environment]::GetEnvironmentVariable($key)) {
        Set-Item -Path "env:$key" -Value $Matches[2]
      }
    }
  }
}

Write-Host "连接目标: $($env:DB_HOST):$($env:DB_PORT)/$($env:DB_NAME) 端口: $($env:PORT)"
dart run lib/main.dart
