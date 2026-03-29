#!/bin/bash

# Helper script to view installation logs
# Usage: ./view-install-logs.sh [latest|all|NUMBER]

LOG_DIR="$HOME/.dotfiles-install-logs"

if [ ! -d "$LOG_DIR" ]; then
    echo "No installation logs found at $LOG_DIR"
    exit 1
fi

case "${1:-latest}" in
    latest)
        LATEST_LOG=$(ls -t "$LOG_DIR"/install-*.log 2>/dev/null | head -1)
        if [ -n "$LATEST_LOG" ]; then
            echo "Viewing latest log: $LATEST_LOG"
            echo "========================================"
            less "$LATEST_LOG"
        else
            echo "No logs found"
        fi
        ;;
    all)
        echo "All installation logs:"
        echo "========================================"
        ls -lh "$LOG_DIR"/install-*.log 2>/dev/null | awk '{print $9, "(" $5 ")"}'
        echo ""
        echo "Use: view-install-logs.sh NUMBER to view a specific log"
        ;;
    [0-9]*)
        LOGS=($(ls -t "$LOG_DIR"/install-*.log 2>/dev/null))
        INDEX=$((${1} - 1))
        if [ $INDEX -ge 0 ] && [ $INDEX -lt ${#LOGS[@]} ]; then
            echo "Viewing log #${1}: ${LOGS[$INDEX]}"
            echo "========================================"
            less "${LOGS[$INDEX]}"
        else
            echo "Invalid log number. Available: 1-${#LOGS[@]}"
            ls -t "$LOG_DIR"/install-*.log 2>/dev/null | nl
        fi
        ;;
    *)
        echo "Usage: $0 [latest|all|NUMBER]"
        echo ""
        echo "  latest  - View the most recent log (default)"
        echo "  all     - List all logs"
        echo "  NUMBER  - View log by number (1 = newest)"
        exit 1
        ;;
esac
