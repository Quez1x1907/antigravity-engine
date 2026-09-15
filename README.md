# antigravity-engine 🤖

Публичный репозиторий-движок: ИИ-агент [Antigravity](https://antigravity.google) выполняет задачи
в **GitHub Actions** (16 ГБ RAM). Пульт управления — Mini App
[tg-miniapp](https://github.com/Quez1x1907/tg-miniapp) в Telegram.

## Безопасность

- Запуск workflow доступен **только владельцу**: Mini App передаёт подписанный
  Telegram `initData`, шаг `Validate Telegram initData` проверяет подпись
  HMAC-SHA256 секретом бота, свежесть (24 ч) и Telegram ID. Чужой dispatch отклоняется.
- Секреты: `BOT_TOKEN` (проверка initData), `ANTIGRAVITY_TOKEN` (доступ агента).
  В коде секретов нет.

## Как запустить задачу

Из Mini App (вкладка «Задача») — вручную через GitHub UI:
Actions → Antigravity agent → Run workflow → текст задачи.

## Результат

- Лог — в Actions и в Mini App (вкладка «Статус»).
- Файлы — артефакт `agent-result-<run_id>` (30 дней), скачивается из Mini App.
