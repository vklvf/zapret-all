# zapret-all

Настроено для:

- YouTube
- Discord
- Telegram Desktop через локальный MTProto-прокси
- SoundCloud
- GitHub

## Быстрый старт

1. Скачайте или клонируйте репозиторий.
2. Запустите `pick-strategy.cmd` от имени администратора.
3. Дождитесь строки `Best strategy: ...`.
4. Запустите `zapret-all.cmd` от имени администратора.
5. Для Telegram Desktop используйте TG WS Proxy из трея или настройте MTProto
   вручную:
   - сервер: `127.0.0.1`
   - порт: `1443`
   - secret: показывается TG WS Proxy при первом запуске, в ссылке из трея
     или в логах

`zapret-all.cmd` запускает TG WS Proxy, а затем запускает выбранную стратегию
zapret из `utils/combo-strategy.txt`. Если стратегия ещё не выбрана,
используется `general.bat`.

## Запуск и остановка

Запустить всё:

```bat
zapret-all.cmd
```

Запустить только Telegram-прокси:

```bat
zapret-all.cmd telegram-only
```

Остановить zapret и Telegram-прокси:

```bat
zapret-all.cmd stop
```

Скачать TG WS Proxy без запуска:

```bat
zapret-all.cmd download-telegram
```

## Secure DNS

В браузере рекомендуется включить Secure DNS / DNS-over-HTTPS. В Firefox:

1. Настройки
2. Приватность и защита
3. DNS через HTTPS
4. Максимальная защита
5. Пользовательский провайдер:

```txt
https://dns.google/dns-query
```

Это особенно важно для YouTube и AI-сервисов, если провайдер блокирует DNS.

## Добавленные домены

В общий список доменов добавлены:

```txt
soundcloud.com
sndcdn.com
github.com
githubassets.com
githubusercontent.com
```

## Примечания

- Запускайте `.cmd` файлы от имени администратора.
