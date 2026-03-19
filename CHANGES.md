# Исправление ошибки обновления проекта

## Проблема
Кнопка "Обновить" в веб-интерфейсе не работала из-за:
1. Неправильного указания репозитория: `bypass_keenetic-web` (с дефисом) вместо `bypass_keenetic_web` (с подчёркиванием)
2. Неправильной ветки: `main` вместо `master`
3. Ссылок на несуществующие файлы `bot3` (Telegram-бот был удалён)

## Изменения в репозитории

### 1. Исправлено `src/web_ui/core/web_config.py`:
- Изменён URL репозитория с `bypass_keenetic-web/main` на `bypass_keenetic_web/master`

### 2. Исправлено `src/web_ui/env_parser.py`:
- Изменён путь от `/opt/etc/bot/.env` к `/opt/etc/web_ui/.env`

### 3. Исправлено `src/web_ui/resources/scripts/100-unblock-vpn-v4.sh`:
- Изменён путь от `/opt/etc/bot/bot_config.py` к `/opt/etc/web_ui/core/web_config.py`

### 4. Исправлено `src/web_ui/resources/scripts/keensnap.sh`:
- Изменён упоминание с `bot_config.py` на `web_config.py`

### 5. Исправлено `src/web_ui/routes.py`:
- Изменён `github_branch` с `'main'` на `'master'`

### 6. Исправлено `src/web_ui/scripts/install_web.sh`:
- Обновлена комментарий с неправильным URL
- Изменён путь от `/opt/etc/bot/templates/` к `/opt/etc/web_ui/templates/`

### 7. Добавлена документация:
- Создан файл `docs/INSTRUCTION_MANUAL_UPDATE.md` с пошаговой инструкцией по обновлению
- Создан скрипт `fix_bot3_references.sh` для автоматического исправления на роутере

### 8. Удалена устаревшая документация:
- Удалён `docs/FIX_ROUTING.md` (устаревшие инструкции)
- Удалён `docs/MIGRATION_TEST_TO_WEB.md` (неактуальная миграция)

## Как применить исправления на роутере

### Вариант 1: Быстрое исправление (рекомендуется)

Подключитесь к роутеру и выполните:
```bash
ssh root@192.168.1.1
cd /tmp
curl -sL -o fix_bot3.sh "https://raw.githubusercontent.com/royfincher25-source/bypass_keenetic_web/master/fix_bot3_references.sh"
chmod +x fix_bot3.sh
./fix_bot3.sh
```

### Вариант 2: Полное обновление

Смотрите инструкцию в `docs/INSTRUCTION_MANUAL_UPDATE.md`

## Проверка

После применения исправлений кнопка "Обновить" в веб-интерфейсе должна работать корректно. Все URL теперь указывают на правильный репозиторий `bypass_keenetic_web` и ветку `master`.

## Ссылки

- Репозиторий: `https://github.com/royfincher25-source/bypass_keenetic_web`
- Ветка: `master`
- RAW URL: `https://raw.githubusercontent.com/royfincher25-source/bypass_keenetic_web/master/`