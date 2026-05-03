#!/bin/bash
# =============================================================
# HAProxy Traffic Control Script
# Uses HAProxy Runtime API (no restart needed!)
#
# Usage:
#   ./switch.sh blue-green switch-to-green
#   ./switch.sh blue-green switch-to-blue
#   ./switch.sh canary set 30
#   ./switch.sh canary rollback
# =============================================================

HAPROXY_SOCKET="/tmp/admin.sock"

# If running outside Docker, use TCP instead:
# HAPROXY_SOCKET="tcp://localhost:9999"

send_cmd() {
    echo "$1" | socat stdio "$HAPROXY_SOCKET"
}

show_weights() {
    echo ""
    echo "📊 Current backend weights:"
    send_cmd "show servers state" | grep -E "app-blue|app-green|app-canary" | awk '{print "  "$2" → weight: "$18}'
    echo ""
}

case "$1" in

    # -----------------------------------------------------------
    # BLUE-GREEN: Switch to Green (V1.1)
    # -----------------------------------------------------------
    blue-green)
        case "$2" in
            switch-to-green)
                echo "🟢 Switching traffic: Blue → Green"
                send_cmd "set weight blue_green_backend/app-blue 0"
                send_cmd "set weight blue_green_backend/app-green 100"
                echo "✅ Done! 100% traffic now on Green V1.1"
                show_weights
                ;;
            switch-to-blue)
                echo "🔵 Switching traffic: Green → Blue"
                send_cmd "set weight blue_green_backend/app-green 0"
                send_cmd "set weight blue_green_backend/app-blue 100"
                echo "✅ Done! 100% traffic now on Blue V1.0"
                show_weights
                ;;
            *)
                echo "Usage: $0 blue-green [switch-to-green|switch-to-blue]"
                ;;
        esac
        ;;

    # -----------------------------------------------------------
    # CANARY: Gradual traffic shift
    # -----------------------------------------------------------
    canary)
        case "$2" in
            set)
                WEIGHT=${3:-5}
                echo "🐤 Setting canary traffic to ${WEIGHT}%"
                send_cmd "set weight canary_backend/app-canary $WEIGHT"
                echo "✅ Done! Canary is now at ${WEIGHT}%"
                show_weights
                ;;
            rollback)
                echo "⏪ Rolling back canary to 0%"
                send_cmd "set weight canary_backend/app-canary 0"
                echo "✅ Canary rolled back!"
                show_weights
                ;;
            gradual)
                echo "🚀 Gradually shifting canary: 5% → 30% → 60% → 100%"
                for weight in 5 30 60 100; do
                    echo "  → Setting canary to ${weight}%..."
                    send_cmd "set weight canary_backend/app-canary $weight"
                    sleep 30  # wait 30s between each shift — monitor errors!
                done
                echo "✅ Canary promoted to 100%!"
                show_weights
                ;;
            *)
                echo "Usage: $0 canary [set <weight>|rollback|gradual]"
                ;;
        esac
        ;;

    # -----------------------------------------------------------
    # STATUS: Show current state
    # -----------------------------------------------------------
    status)
        show_weights
        ;;

    *)
        echo ""
        echo "HAProxy Traffic Control Script"
        echo "================================"
        echo "  $0 blue-green switch-to-green   → Switch all traffic to Green V1.1"
        echo "  $0 blue-green switch-to-blue    → Rollback to Blue V1.0"
        echo "  $0 canary set <weight>          → Set canary % (e.g. set 30)"
        echo "  $0 canary rollback              → Stop canary (0%)"
        echo "  $0 canary gradual               → Auto-shift 5→30→60→100%"
        echo "  $0 status                       → Show current weights"
        echo ""
        ;;
esac
