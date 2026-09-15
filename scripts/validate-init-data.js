#!/usr/bin/env node
/**
 * Валидация Telegram initData: подпись HMAC-SHA256 секретом BOT_TOKEN
 * + белый список владельца. Чужой dispatch здесь отклоняется.
 *
 * Использование: node validate-init-data.js <BOT_TOKEN> <OWNER_TG_ID> <initData>
 */
'use strict';
const crypto = require('crypto');

const [botToken, ownerTgId, initData] = process.argv.slice(2);

if (!botToken || !initData) {
  console.error('FAIL: нет BOT_TOKEN или initData');
  process.exit(1);
}

// 1. Разбор initData (URL-encoded пары key=value, разделённые &)
const params = new URLSearchParams(initData);
const hash = params.get('hash');
params.delete('hash');
params.delete('signature');

if (!hash) {
  console.error('FAIL: нет hash в initData');
  process.exit(1);
}

// 2. data-check-string: пары, отсортированные по ключу, через \n
const dataCheckString = [...params.entries()]
  .sort(([a], [b]) => a.localeCompare(b))
  .map(([k, v]) => `${k}=${v}`)
  .join('\n');

// 3. HMAC по алгоритму Telegram:
//    secret_key = HMAC-SHA256(key="WebAppData", data=BOT_TOKEN)
//    hash       = HMAC-SHA256(key=secret_key, data=data-check-string)
const secretKey = crypto.createHmac('sha256', 'WebAppData').update(botToken).digest();
const computed = crypto.createHmac('sha256', secretKey).update(dataCheckString).digest('hex');

if (computed !== hash) {
  console.error('FAIL: подпись initData неверна — подделка или устаревшие данные');
  process.exit(1);
}

// 4. Свежесть: auth_date не старше 24 ч (replay-защита)
const authDate = parseInt(params.get('auth_date') || '0', 10);
const ageSec = Math.floor(Date.now() / 1000) - authDate;
if (!authDate || ageSec > 86400) {
  console.error(`FAIL: initData устарел (${ageSec} c)`);
  process.exit(1);
}

// 5. Владелец
const user = JSON.parse(params.get('user') || '{}');
if (String(user.id) !== String(ownerTgId)) {
  console.error(`FAIL: user.id=${user.id} не владелец (${ownerTgId})`);
  process.exit(1);
}

console.log(`OK: владелец подтверждён — @${user.username || user.id}`);
