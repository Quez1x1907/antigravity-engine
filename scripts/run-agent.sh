#!/usr/bin/env bash
# Запуск Antigravity-агента. ЗАДАЧА приходит в $TASK, токен — в $ANTIGRAVITY_TOKEN.
# Результаты писать в output/ — они уедут в артефакты workflow.
set -euo pipefail

echo "=== Antigravity agent ==="
echo "Задача: ${TASK:0:200}"

if [ -z "${ANTIGRAVITY_TOKEN:-}" ]; then
  echo "ОШИБКА: ANTIGRAVITY_TOKEN не задан (GitHub Secrets репозитория)"
  exit 1
fi

mkdir -p output

# TODO: здесь вызов Antigravity CLI/API.
# Шаблон: разовая авторизация выполнена ранее, токен лежит в секрете.
# Конкретная команда появится после подключения Antigravity (шаг 2 плана).
echo "Планируемая задача принята. Токен найден (длина ${#ANTIGRAVITY_TOKEN})."
echo "Интеграция Antigravity будет добавлена следующим шагом."

# Пока — демо-результат, чтобы pipeline был проверяем end-to-end.
cat > output/result.md << EOF
# Результат агента

- Задача: ${TASK}
- Время: $(date -u +%Y-%m-%dT%H:%M:%SZ)
- Статус: пайплайн работает, интеграция Antigravity на шаге 2
EOF

echo "=== Готово, результат в output/ ==="
