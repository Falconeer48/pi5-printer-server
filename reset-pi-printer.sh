# ~/Scripts/reset-pi-printer.sh
#!/bin/bash
# Reset a printer queue on the Raspberry Pi from macOS
# Usage: ~/Scripts/reset-pi-printer.sh [QUEUE]
set -euo pipefail

# --- CONFIG: edit these to match your Pi ---
PI_USER="ian"                   # Pi username
PI_HOST="192.168.50.243"        # Pi IP or hostname (e.g. mypi5.local)
QUEUE_DEFAULT="G4470"           # CUPS queue name on the Pi
# ------------------------------------------

QUEUE="${1:-$QUEUE_DEFAULT}"

echo "== Resetting queue '$QUEUE' on $PI_USER@$PI_HOST =="

ssh -o BatchMode=no -o StrictHostKeyChecking=accept-new "$PI_USER@$PI_HOST" bash -s -- "$QUEUE" <<'EOS'
set -euo pipefail
Q="${1:-}"
if [ -z "$Q" ]; then
  echo "[Pi] No queue name provided"; exit 1
fi

echo "[Pi] Stopping queue: $Q"
sudo cupsdisable "$Q" || true

echo "[Pi] Cancelling jobs"
if lpq -P "$Q" >/dev/null 2>&1; then
  cancel -a "$Q" || true
else
  cancel -a || true
fi

echo "[Pi] Forcing copies=1"
lpoptions -p "$Q" -o copies=1 || true

echo "[Pi] Restarting CUPS"
sudo systemctl restart cups

echo "[Pi] Re-enabling queue"
sudo cupsenable "$Q"

echo "[Pi] Queue state:"
lpstat -p "$Q" || true
EOS