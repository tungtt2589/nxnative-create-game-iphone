#!/usr/bin/env bash
# Scaleway Apple Silicon instance management
# Usage:
#   bash scaleway_manage.sh status
#   bash scaleway_manage.sh delete

set -euo pipefail

export SCW_ACCESS_KEY="${SCW_ACCESS_KEY:-SCWAG4XSJ9Q26HJKDDZE}"
export SCW_SECRET_KEY="${SCW_SECRET_KEY:-f019d4e0-1be1-4c6b-8f79-b68d73589f3f}"
export SCW_DEFAULT_ORGANIZATION_ID="${SCW_DEFAULT_ORGANIZATION_ID:-e80a64ac-e120-4941-a0e6-1cce5ce8bac7}"
export SCW_DEFAULT_PROJECT_ID="${SCW_DEFAULT_PROJECT_ID:-e80a64ac-e120-4941-a0e6-1cce5ce8bac7}"

SERVER_ID="a66aa052-802d-4c99-9ca6-d78365e693d8"
ZONE="fr-par-1"
SERVER_IP="62.210.194.185"
SSH_KEY="$HOME/.ssh/scaleway_nxnative"

CMD="${1:-status}"

case "$CMD" in
  status)
    scw apple-silicon server get "$SERVER_ID" zone="$ZONE" 2>&1 | grep -E "Status|IP|DeletableAt|Delivered"
    ;;
  ssh)
    echo "SSHing into $SERVER_IP..."
    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=10 m1@"$SERVER_IP" "${@:2}"
    ;;
  delete)
    echo "Checking if server is deletable..."
    DELETABLE=$(scw apple-silicon server get "$SERVER_ID" zone="$ZONE" 2>&1 | grep "DeletionScheduled")
    echo "$DELETABLE"
    echo "Deleting server $SERVER_ID..."
    scw apple-silicon server delete "$SERVER_ID" zone="$ZONE" 2>&1
    echo "Server deleted."
    ;;
  wait)
    echo "Waiting for server to be ready..."
    for i in $(seq 1 60); do
      sleep 30
      STATUS=$(scw apple-silicon server get "$SERVER_ID" zone="$ZONE" 2>&1 | grep "^Status")
      echo "[$i] $(date +%H:%M:%S) $STATUS"
      if echo "$STATUS" | grep -q "ready"; then
        echo "SERVER READY at $SERVER_IP"
        break
      fi
    done
    ;;
  *)
    echo "Usage: $0 [status|ssh|delete|wait]"
    ;;
esac
