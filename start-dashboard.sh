#!/bin/bash
# App 分发看板 一键启动脚本
# 用法：
#   ./start-dashboard.sh          前台运行（Ctrl+C 停止，仅本机 127.0.0.1）
#   ./start-dashboard.sh bg       后台运行（关终端不停，日志 tmpdoc/web-8090.log）
#   ./start-dashboard.sh lan      局域网模式前台运行（绑 0.0.0.0，须已配置登录账号）
#   ./start-dashboard.sh lanbg    局域网模式后台运行
#   ./start-dashboard.sh stop     停止看板
#   ./start-dashboard.sh status   查看运行状态

cd "$(dirname "$0")" || exit 1   # 切到项目根目录，config/ apps/ 相对路径才正确

PORT=8090
CREDENTIALS=config/credentials.json
CATALOG=apps/catalog.json
BOARD=config/board.json
LOG=tmpdoc/web-8090.log

if [ ! -x .venv/bin/appstore ]; then
  echo "未找到 .venv（首次部署请先执行："
  echo "  python3 -m venv .venv && .venv/bin/pip install -e \".[google]\"）"
  exit 1
fi

running_pid() {
  lsof -nP -iTCP:$PORT -sTCP:LISTEN -t 2>/dev/null
}

lan_ip() {
  ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo ""
}

# 局域网模式安全闸：没有登录账号就拒绝启动（看板能执行真实发布，不能裸奔在网内）
check_lan_auth() {
  if ! .venv/bin/python -c "import json,sys;cfg=json.load(open('$BOARD'));users=cfg.get('users') or [];sys.exit(0 if any(isinstance(u,dict) and u.get('username') and (u.get('password') or u.get('password_sha256')) for u in users) else 1)" 2>/dev/null; then
    echo "✘ 局域网模式需要先配置登录账号："
    echo "  1. cp config/example.board.json config/board.json"
    echo "  2. 编辑 users（admin=可发布 / viewer=只读），说明见 docs/WEB_GUIDE.md"
    exit 1
  fi
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
    nohup .venv/bin/appstore web --port $PORT --credentials $CREDENTIALS --catalog $CATALOG --board-config $BOARD >> "$LOG" 2>&1 &
    echo "已后台启动 (PID $!)，日志: $LOG"
    echo "看板地址: http://127.0.0.1:$PORT"
    ;;
  lan|lanbg)
    check_lan_auth
    if [ -n "$(running_pid)" ]; then
      echo "看板已在运行 (PID $(running_pid))，如需重启先执行 $0 stop"
      exit 1
    fi
    IP=$(lan_ip)
    if [ "$1" = "lanbg" ]; then
      mkdir -p tmpdoc
      nohup .venv/bin/appstore web --host 0.0.0.0 --port $PORT --credentials $CREDENTIALS --catalog $CATALOG --board-config $BOARD >> "$LOG" 2>&1 &
      echo "已后台启动局域网模式 (PID $!)，日志: $LOG"
    else
      .venv/bin/appstore web --host 0.0.0.0 --port $PORT --credentials $CREDENTIALS --catalog $CATALOG --board-config $BOARD
      exit $?
    fi
    echo "本机访问: http://127.0.0.1:$PORT"
    if [ -n "$IP" ]; then
      echo "局域网访问: http://$IP:$PORT （同网段设备；首次启动 macOS 防火墙弹窗请点「允许」）"
    else
      echo "局域网访问: http://<本机IP>:$PORT （未能自动探测 IP，可在 系统设置→Wi-Fi 查看）"
    fi
    ;;
  "")
    if [ -n "$(running_pid)" ]; then
      echo "看板已在运行 (PID $(running_pid))，如需重启先执行 $0 stop"
      exit 1
    fi
    exec .venv/bin/appstore web --port $PORT --credentials $CREDENTIALS --catalog $CATALOG --board-config $BOARD
    ;;
  *)
    echo "用法: $0 [bg|lan|lanbg|stop|status]（不带参数 = 前台运行）"
    exit 1
    ;;
esac
