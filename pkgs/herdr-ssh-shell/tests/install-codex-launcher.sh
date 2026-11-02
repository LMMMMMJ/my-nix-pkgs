# Copyright 2026 HerdrChat contributors
# SPDX-License-Identifier: Apache-2.0; see LICENSE.herdrchat
# Source: cobanov/herdrchat 73512ca5231c124e37576e3964196d48b0b0a3cc
# Exact output of installCodexLauncher + withPath; includes the embedded launcher.
export PATH="$HOME/.local/bin:$HOME/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"; codex_launcher_dir="$HOME/.local/bin"; for codex_launcher_name in herdrchat-codex codex; do codex_launcher_target="$codex_launcher_dir/$codex_launcher_name"; if [ -e "$codex_launcher_target" ] || [ -L "$codex_launcher_target" ]; then grep -Fqx "# herdrchat-managed-codex-launcher-v1" "$codex_launcher_target" || exit 47; fi; done; mkdir -p "$codex_launcher_dir" || exit $?; for codex_launcher_name in herdrchat-codex codex; do codex_launcher_target="$codex_launcher_dir/$codex_launcher_name"; codex_launcher_tmp=$(mktemp "$codex_launcher_dir/.herdrchat-codex.XXXXXX") || exit $?; trap 'rm -f "$codex_launcher_tmp"' EXIT HUP INT TERM; printf %s '#!/usr/bin/env bash
# herdrchat-managed-codex-launcher-v1
# Start Codex with this Herdr pane'\''s context, including with a shared app server.
# Installed as codex and herdrchat-codex. Never changes Codex config or hook trust.
set -euo pipefail

# Resolve the real executable on every launch so package-manager updates work.
# Skip both managed entry points, including duplicate PATH entries and symlinks.
codex_binary='\'''\''
while IFS= read -r candidate; do
  [[ "$candidate" -ef "$0" ]] && continue
  if head -n 2 "$candidate" | grep -Fqx '\''# herdrchat-managed-codex-launcher-v1'\''; then
    continue
  fi
  codex_binary="$candidate"
  break
done < <(type -aP codex)
[[ -n "$codex_binary" ]] || { echo '\''The original Codex executable is not on PATH.'\'' >&2; exit 1; }

if [[ "${HERDR_ENV:-}" != 1 || -z "${HERDR_PANE_ID:-}" || -z "${HERDR_SOCKET_PATH:-}" ]]; then
  if [[ "${0##*/}" == herdrchat-codex ]]; then
    echo '\''Run herdrchat-codex inside the Herdr pane that should own this chat.'\'' >&2
    exit 1
  fi
  exec "$codex_binary" "$@"
fi

command -v python3 >/dev/null || { echo '\''python3 is required by the Herdr integration.'\'' >&2; exit 1; }

# JSON strings are valid TOML strings. Quote paths as values, never as shell code.
quote_env() {
  python3 -c '\''import json, os, sys; print(json.dumps(os.environ[sys.argv[1]]))'\'' "$1"
}

exec "$codex_binary" \
  -c '\''features.hooks=true'\'' \
  -c '\''shell_environment_policy.set.HERDR_ENV="1"'\'' \
  -c "shell_environment_policy.set.HERDR_PANE_ID=$(quote_env HERDR_PANE_ID)" \
  -c "shell_environment_policy.set.HERDR_SOCKET_PATH=$(quote_env HERDR_SOCKET_PATH)" \
  "$@"
' > "$codex_launcher_tmp" && chmod 700 "$codex_launcher_tmp" && mv -f "$codex_launcher_tmp" "$codex_launcher_target" || exit $?; done
