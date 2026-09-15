#!/bin/bash
# App 分发看板 一键启动脚本
# 用法：
#   ./start-dashboard.sh          前台运行（Ctrl+C 停止）
#   ./start-dashboard.sh bg       后台运行（关终端不停，日志 tmpdoc/web-8090.log）
#   ./start-dashboard.sh stop     停止看板
#   ./start-dashboard.sh status   查看运行状态

cd "$(dirname "$0")" || exit 1   # 切到项目根目录，config/ apps/ 相对路径才正确

PORT=8090
CREDENTIALS=config/credentials.json
CATALOG=apps/catalog.json
LOG=tmpdoc/web-8090.log

if [ ! -x .venv/bin/appstore ]; then
  echo "未找到 .venv（首次部署请先执行："
  echo "  python3 -m venv .venv && .venv/bin/pip install -e \".[google]\"）"
  exit 1
fi

running_pid() {
  lsof -nP -iTCP:$PORT -sTCP:LISTEN -t 2>/dev/null
}

case "$1" in
  stop)
    PID=$(running_pid)
    if [ -n "$PID" ]; then
      kill "$PID" && echo "已停止看板 (PID $PID)"
    else
      echo "看板未在运行"
    fi
    ;;
  status)
    PID=$(running_pid)
    if [ -n "$PID" ]; then
      echo "运行中 (PID $PID) → http://127.0.0.1:$PORT"
    else
      echo "未运行"
    fi
    ;;
  bg)
    if [ -n "$(running_pid)" ]; then
      echo "看板已在运行 (PID $(running_pid))，如需重启先执行 $0 stop"
      exit 1
    fi
    mkdir -p tmpdoc
    nohup .venv/bin/appstore web --port $PORT --credentials $CREDENTIALS --catalog $CATALOG >> "$LOG" 2>&1 &
    echo "已后台启动 (PID $!)，日志: $LOG"
    echo "看板地址: http://127.0.0.1:$PORT"
    ;;
  "")
    if [ -n "$(running_pid)" ]; then
      echo "看板已在运行 (PID $(running_pid))，如需重启先执行 $0 stop"
      exit 1
    fi
    exec .venv/bin/appstore web --port $PORT --credentials $CREDENTIALS --catalog $CATALOG
    ;;
  *)
    echo "用法: $0 [bg|stop|status]（不带参数 = 前台运行）"
    exit 1
    ;;
esac
