#!/bin/bash
# Delegate the cpuset controller to user managers so user scopes can use AllowedCPUs= (requires sudo).
# Takes effect on next login; restarting user@1000 in place would kill the session.
sudo install -Dm644 /dev/stdin /etc/systemd/system/user@.service.d/delegate-cpuset.conf <<'CONF'
[Service]
Delegate=pids memory cpu cpuset
CONF
sudo systemctl daemon-reload
echo "cpuset delegated to user@.service (active after re-login)"
