#!/bin/bash
# Dashboard PM2 Manager
# Usage: ./server.sh [start|stop|restart|status|logs]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="claude-dashboard"
ECOSYSTEM="$SCRIPT_DIR/dashboard/ecosystem.config.js"
URL="http://localhost:31415"

case "$1" in
  start)
    echo "Starting $APP_NAME..."
    pm2 start "$ECOSYSTEM"
    pm2 save
    echo ""
    echo "Dashboard running at: $URL"
    ;;
  stop)
    echo "Stopping $APP_NAME..."
    pm2 stop "$APP_NAME"
    ;;
  restart)
    echo "Restarting $APP_NAME..."
    pm2 restart "$APP_NAME"
    echo ""
    echo "Dashboard running at: $URL"
    ;;
  status)
    pm2 status "$APP_NAME"
    ;;
  logs)
    pm2 logs "$APP_NAME" --lines 50
    ;;
  *)
    echo "Usage: $0 {start|stop|restart|status|logs}"
    exit 1
    ;;
esac
