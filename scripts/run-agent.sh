#!/usr/bin/env bash
# Выполнение задачи через локальный agy на сервере (self-hosted runner).
# Требования на сервере: agy в ~/.local/bin, пропатчен против регион-лока,
# прокси для модельных запросов — в ~/agy_proxy.env (см. handoff §5.3).
# Вход: TASK. Выход: output/result.md.
set -euo pipefail

fail() { echo "ОШИБКА: $*" >&2; exit 1; }
[ -n "${TASK:-}" ] || fail "TASK не задан"
OUT_DIR="${GITHUB_WORKSPACE:-$(pwd)}/output"
mkdir -p "$OUT_DIR"

export PATH="$HOME/.local/bin:$PATH"
command -v agy >/dev/null 2>&1 || fail "agy не найден на сервере (~/.local/bin/agy)"

# Прокси для модельных запросов: ~/agy_proxy.env (HTTPS_PROXY=socks5://IP:PORT и т.п.)
if [ -f "$HOME/agy_proxy.env" ]; then
    set -a
    . "$HOME/agy_proxy.env"
    set +a
fi

AGY_MODEL="${AGY_MODEL:-gemini-3.8-flash-high}"

echo "=== Antigravity agent (agy на сервере) ==="
echo "Задача: ${TASK:0:200}"
echo "Модель: $AGY_MODEL"

cd "$HOME"
set +e
timeout 900 agy -p --dangerously-skip-permissions --model "$AGY_MODEL" "$TASK" \
  > "$OUT_DIR/raw_answer.txt" 2> "$OUT_DIR/agy.err"
RC=$?
set -e
echo "agy exit=$RC"

if [ $RC -ne 0 ] || [ ! -s "$OUT_DIR/raw_answer.txt" ]; then
  echo "--- stderr agy (последние 20 строк) ---" >&2
  tail -20 "$OUT_DIR/agy.err" >&2 2>/dev/null || true
  fail "agy завершился с кодом $RC (подробности в agy.err — уйдут в артефакт)"
fi

cp "$OUT_DIR/raw_answer.txt" "$OUT_DIR/result.md"
{
  echo
  echo "---"
  echo "*Antigravity · $AGY_MODEL · $(date -u +%Y-%m-%dT%H:%M:%SZ)*"
} >> "$OUT_DIR/result.md"
echo "Символов в ответе: $(wc -c < "$OUT_DIR/result.md")"
echo "=== Готово: output/result.md ==="
