# save as ~/check-pi-printer.sh, then: chmod +x ~/check-pi-printer.sh && ~/check-pi-printer.sh
#!/bin/bash
set -e

# Config
QUEUE="${QUEUE:-G4470}"
SUBNET="${SUBNET:-192.168.50.0/24}"

ok() { printf "\033[32mOK\033[0m  %s\n" "$1"; }
fail() { printf "\033[31mFAIL\033[0m %s\n" "$1"; }

echo "== Pi Print Server Health Check =="

# 1) CUPS running
if systemctl is-active --quiet cups; then
  ok "CUPS service is running"
else
  fail "CUPS not running. Starting..."
  sudo systemctl restart cups || true
  sleep 1
  systemctl is-active --quiet cups && ok "CUPS started" || fail "CUPS failed to start"
fi

# 2) Avahi running
if systemctl is-active --quiet avahi-daemon; then
  ok "Avahi service is running"
else
  fail "Avahi not running. Starting..."
  sudo systemctl enable --now avahi-daemon || true
  systemctl is-active --quiet avahi-daemon && ok "Avahi started" || fail "Avahi failed to start"
fi

# 3) CUPS listening on 0.0.0.0:631
if ss -ltnp | grep -q '0.0.0.0:631'; then
  ok "CUPS is listening on 0.0.0.0:631"
else
  fail "CUPS not listening on LAN. Checking cupsd.conf..."
  grep -E 'Listen|Allow' /etc/cups/cupsd.conf || true
fi

# 4) Queue exists and is enabled
if lpstat -p "$QUEUE" >/dev/null 2>&1; then
  state=$(lpstat -p "$QUEUE" | sed -n 's/^printer '"$QUEUE"' is //p')
  ok "Queue $QUEUE present: $state"
else
  fail "Queue $QUEUE not found"
fi

# 5) Firewall rules for 631
UFW_OK_TCP=$(sudo ufw status | grep -qE '631/tcp.*ALLOW' && echo yes || echo no)
UFW_OK_UDP=$(sudo ufw status | grep -qE '631/udp.*ALLOW' && echo yes || echo no)
if [ "$UFW_OK_TCP" = "yes" ] && [ "$UFW_OK_UDP" = "yes" ]; then
  ok "UFW allows 631 TCP and UDP"
else
  fail "UFW missing 631 rules. Applying LAN rules for $SUBNET..."
  sudo ufw allow from "$SUBNET" to any port 631 proto tcp || true
  sudo ufw allow from "$SUBNET" to any port 631 proto udp || true
  sudo ufw reload || true
  sudo ufw status | grep 631 || true
fi

# 6) Quick HTTP probe of CUPS locally
if curl -sI http://localhost:631 | head -n1 | grep -q 'HTTP/1.1 200\|HTTP/1.1 401'; then
  ok "CUPS web UI responds on localhost:631"
else
  fail "CUPS web UI did not respond on localhost:631"
fi

# 7) Optional test print if queue exists
if lpstat -p "$QUEUE" >/dev/null 2>&1; then
  TESTFILE="/usr/share/cups/data/testprint"
  if [ -f "$TESTFILE" ]; then
    echo "Sending optional test page to $QUEUE..."
    lp -d "$QUEUE" "$TESTFILE" >/dev/null 2>&1 && ok "Test page queued" || fail "Could not queue test page"
  else
    echo "Test page file not found, skipping"
  fi
fi

PI_IP=$(hostname -I | awk '{print $1}')
echo "Done. From a Mac you should reach: http://$PI_IP:631"