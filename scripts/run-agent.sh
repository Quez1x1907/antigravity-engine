#!/usr/bin/env bash
# Выполнение задачи через Antigravity CLI (agy): сессия владельца восстанавливается
# из зашифрованного архива session/agy_session.enc (AES-256-CBC, пароль в секрете
# AGY_SESSION_PASS), затем agy -p выполняет задачу на лимитах подписки владельца.
# Выход: output/result.md — ответ агента, output/agy.err — stderr, output/raw_answer.txt — сырой вывод.
set -euo pipefail

fail() { echo "ОШИБКА: $*" >&2; exit 1; }
PASS="${AGY_SESSION_PASS:?AGY_SESSION_PASS не задан (GitHub Secrets)}"
[ -n "${TASK:-}" ] || fail "TASK не задан"
OUT_DIR="${GITHUB_WORKSPACE:-$(pwd)}/output"
mkdir -p "$OUT_DIR" "$HOME/.gemini"

echo "=== Antigravity agent (agy) ==="
echo "Задача: ${TASK:0:200}"

echo "1/4 Устанавливаю Antigravity CLI…"
curl -fsSL https://antigravity.google/cli/install.sh | bash -s -- --skip-path 2>&1 | tail -2
export PATH="$HOME/.local/bin:$PATH"
command -v agy >/dev/null 2>&1 || fail "agy не установился"

echo "2/4 Восстанавливаю сессию владельца…"
ENC="$(cd "$(dirname "$0")" && pwd)/../session/agy_session.enc"
[ -f "$ENC" ] || fail "нет файла сессии $ENC"
openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 -in "$ENC" -out /tmp/agy_session.tar.gz -pass "pass:$PASS"
tar -xzf /tmp/agy_session.tar.gz -C "$HOME/.gemini"
rm -f /tmp/agy_session.tar.gz

echo "3/4 Отправляю задачу agy (до 15 минут)…"
cd "$HOME"
set +e
timeout 900 agy -p --dangerously-skip-permissions --print-timeout 15m "$TASK" \
  > "$OUT_DIR/raw_answer.txt" 2> "$OUT_DIR/agy.err"
RC=$?
set -e
echo "agy exit=$RC"

echo "4/4 Оформляю результат…"
if [ $RC -eq 0 ] && [ -s "$OUT_DIR/raw_answer.txt" ]; then
  cp "$OUT_DIR/raw_answer.txt" "$OUT_DIR/result.md"
  {
    echo
    echo "---"
    echo "*Antigravity · $(date -u +%Y-%m-%dT%H:%M:%SZ)*"
  } >> "$OUT_DIR/result.md"
  echo "Символов в ответе: $(wc -c < "$OUT_DIR/result.md")"
else
  echo "--- stderr agy (последние 20 строк) ---" >&2
  tail -20 "$OUT_DIR/agy.err" >&2 2>/dev/null || true
  fail "agy завершился с кодом $RC (подробности уйдут в артефакт: output/agy.err)"
fi

echo "=== Готово: output/result.md ==="
