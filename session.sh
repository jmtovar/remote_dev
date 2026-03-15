#!/usr/bin/env bash
# =============================================================================
# session.sh — Daily workflow helper (run this on your LOCAL machine)
# =============================================================================
# Usage:
#   ./session.sh up       — provision instance, wait for it, SSH in
#   ./session.sh ip       — print the current instance IP
#   ./session.sh down     — destroy everything cleanly
# =============================================================================
set -euo pipefail

TERRAFORM_DIR="$(cd "$(dirname "$0")/terraform" && pwd)"
YOUR_IP="$(curl -s ifconfig.me)/32"

case "${1:-help}" in

  up)
    echo "🚀 Bringing up ephemeral dev instance..."
    cd "$TERRAFORM_DIR"

    terraform init -input=false -upgrade > /dev/null

    terraform apply \
      -auto-approve \
      -var="your_ip=$YOUR_IP"

    IP=$(terraform output -raw public_ip)
    echo ""
    echo "✅ Instance is up at: $IP"
    echo "⏳ Waiting 30s for SSH to become available..."
    sleep 30

    echo "🔌 Connecting via SSH..."
    ssh -o StrictHostKeyChecking=no \
        -o ConnectTimeout=15 \
        ubuntu@"$IP"
    ;;

  ip)
    cd "$TERRAFORM_DIR"
    terraform output -raw public_ip
    ;;

  ssh)
    cd "$TERRAFORM_DIR"
    IP=$(terraform output -raw public_ip)
    ssh -o StrictHostKeyChecking=no ubuntu@"$IP"
    ;;

  down)
    echo "🔥 Destroying instance..."
    cd "$TERRAFORM_DIR"
    terraform destroy -auto-approve
    echo "✅ Instance destroyed. Goodbye!"
    ;;

  help|*)
    echo "Usage: $0 [up|ip|ssh|down]"
    echo ""
    echo "  up    Provision instance + SSH in automatically"
    echo "  ip    Print current instance IP"
    echo "  ssh   SSH into a running instance"
    echo "  down  Destroy instance and all resources"
    ;;
esac
