#!/usr/bin/env bash
# Выполнение задачи через Antigravity API (Google Cloud Code) напрямую.
# Вход:  TASK — задача, ANTIGRAVITY_TOKEN — OAuth refresh-токен (GitHub Secrets).
# Опции: AGY_MODEL (default gemini-3-flash-agent), AGY_TOOLS (default googleSearch|none).
# Выход: output/result.md — ответ модели, output/raw.json — сырой ответ API.
set -euo pipefail

CLIENT_ID="${AGY_CLIENT_ID:?AGY_CLIENT_ID не задан (GitHub Secrets)}"
CLIENT_SECRET="${AGY_CLIENT_SECRET:?AGY_CLIENT_SECRET не задан (GitHub Secrets)}"
API="https://cloudcode-pa.googleapis.com/v1internal"
MODEL="${AGY_MODEL:-gemini-3-flash-agent}"
TOOLS="${AGY_TOOLS:-googleSearch}"
UA="antigravity-cli/1.2.3"

mkdir -p output
fail() { echo "ОШИБКА: $*" >&2; exit 1; }

[ -n "${ANTIGRAVITY_TOKEN:-}" ] || fail "ANTIGRAVITY_TOKEN не задан (GitHub Secrets)"
[ -n "${TASK:-}" ] || fail "TASK не задан"

echo "=== Antigravity agent ==="
echo "Задача: ${TASK:0:200}"
echo "Модель: $MODEL"

echo "1/4 Обновляю access-токен…"
ACCESS=$(curl -sS --max-time 30 https://oauth2.googleapis.com/token \
  --data-urlencode "client_id=$CLIENT_ID" \
  --data-urlencode "client_secret=$CLIENT_SECRET" \
  --data-urlencode "refresh_token=$ANTIGRAVITY_TOKEN" \
  --data-urlencode "grant_type=refresh_token" \
  | jq -r '.access_token // empty')
[ -n "$ACCESS" ] || fail "не удалось обновить токен — refresh-токен невалиден или отозван. Перевыпусти через повторную авторизацию Antigravity."

echo "2/4 Определяю проект (loadCodeAssist)…"
PROJECT=$(curl -sS --max-time 30 -X POST "$API:loadCodeAssist" \
  -H "Authorization: Bearer $ACCESS" \
  -H "Content-Type: application/json" \
  -H "User-Agent: $UA" \
  -d '{"metadata":{"ideType":"ANTIGRAVITY"}}' \
  | jq -r '.cloudaicompanionProject // empty')
[ -n "$PROJECT" ] || PROJECT="aicode-consumers"
echo "   проект: $PROJECT"

echo "3/4 Отправляю задачу (может думать несколько минут)…"
if [ "$TOOLS" = "googleSearch" ]; then
  jq -n --arg t "$TASK" --arg m "$MODEL" --arg p "$PROJECT" '{
    model: $m, project: $p,
    request: {
      contents: [ { role: "user", parts: [ { text: $t } ] } ],
      tools: [ { googleSearch: {} } ]
    }
  }' > output/request.json
else
  jq -n --arg t "$TASK" --arg m "$MODEL" --arg p "$PROJECT" '{
    model: $m, project: $p,
    request: { contents: [ { role: "user", parts: [ { text: $t } ] } ] }
  }' > output/request.json
fi

HTTP=$(curl -sS --max-time 900 -X POST "$API:generateContent" \
  -H "Authorization: Bearer $ACCESS" \
  -H "Content-Type: application/json" \
  -H "User-Agent: $UA" \
  -d @output/request.json -o output/raw.json -w "%{http_code}")
echo "   HTTP $HTTP"
[ "$HTTP" = "200" ] || {
  head -c 800 output/raw.json >&2 || true
  fail "API вернул HTTP $HTTP (сырой ответ в output/raw.json). 429 = дневная квота Antigravity исчерпана — повтори после сброса (~07:00 МСК)."
}

echo "4/4 Извлекаю ответ модели…"
jq -r '(.response.candidates // .candidates // [])[0].content.parts
       | map(.text // "") | join("")' output/raw.json > output/result.md

if [ -s output/result.md ]; then
  {
    echo
    echo "---"
    echo "*Модель: $MODEL · проект: $PROJECT · $(date -u +%Y-%m-%dT%H:%M:%SZ)*"
  } >> output/result.md
  echo "Символов в ответе: $(wc -c < output/result.md)"
else
  echo "Не удалось распарсить ответ — кладу сырой JSON как результат."
  cp output/raw.json output/result.md
fi

echo "=== Готово: output/result.md ==="
