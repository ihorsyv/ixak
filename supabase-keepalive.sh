#!/bin/bash
# Пингует Supabase-проекты, чтобы Supabase не ставил их на авто-паузу за неактивность.
# Нужны anon-ключи проектов (Dashboard -> Project Settings -> API -> anon public).
# Задать их можно через переменные окружения или прямо вписать ниже.

set -euo pipefail

LEGAL_ASSISTANT_REF="qjsilocrkvfsjvsrmpfs"
GARDEROBOT_REF="ngeekjycwdsksnxokhxw"

LEGAL_ASSISTANT_ANON_KEY="${LEGAL_ASSISTANT_ANON_KEY:-}"
GARDEROBOT_ANON_KEY="${GARDEROBOT_ANON_KEY:-}"

ping_project() {
  local name="$1" ref="$2" key="$3"

  if [[ -z "$key" ]]; then
    echo "[$name] пропущено: не задан anon-ключ"
    return
  fi

  local http_code
  http_code=$(curl -s -o /dev/null -w "%{http_code}" \
    "https://${ref}.supabase.co/rest/v1/" \
    -H "apikey: ${key}")

  echo "[$name] ping -> HTTP ${http_code}"
}

ping_project "legal-assistant" "$LEGAL_ASSISTANT_REF" "$LEGAL_ASSISTANT_ANON_KEY"
ping_project "garderobot"      "$GARDEROBOT_REF"      "$GARDEROBOT_ANON_KEY"
