#!/bin/bash
# SessionStart hook (.claude/settings.json) for Claude Code cloud sessions: what the setup script (cloud-setup.sh)
# cannot do before the checkout exists, or may not leave running. Does nothing outside the cloud. Slow steps run in the
# background (log: /tmp/isim-session.log) so the session starts at once.
[ "$CLAUDE_CODE_REMOTE" = true ] || exit 0
cd "$(dirname "$0")/../.." || exit 0
command -v docker >/dev/null || exit 0
{
  docker info >/dev/null 2>&1 || { nohup dockerd > /tmp/dockerd.log 2>&1 & }
  for i in $(seq 30); do docker info >/dev/null 2>&1 && break; sleep 1; done
  docker image inspect swift:6.2 >/dev/null 2>&1 \
    || { docker pull -q mirror.gcr.io/library/swift:6.2 && docker tag mirror.gcr.io/library/swift:6.2 swift:6.2; }
  python3 isim/build.py fetch >/dev/null
  echo "isim session ready"
} > /tmp/isim-session.log 2>&1 &
exit 0
