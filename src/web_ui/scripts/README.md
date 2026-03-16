# Scripts Directory

Эта директория содержит скрипты для установки и удаления bypass_keenetic с веб-интерфейсом.

## Файлы

- `script.sh` — основной скрипт установки/удаления (адаптирован для web_ui)
- `script.sh.md5` — MD5 хэш для проверки целостности
- `script_web.sh` — исходный код адаптированной версии (для справки)
- `.gitkeep` — файл для отслеживания директории в git
- `README.md` — эта документация

## Отличия от версии Telegram-бота

| Параметр | Telegram-бот | Веб-интерфейс |
|----------|--------------|---------------|
| **Конфигурация** | `/opt/etc/bot/bot_config.py` | `/opt/etc/web_ui/core/web_config.py` |
| **Директория** | `/opt/etc/bot/` | `/opt/etc/web_ui/` |
| **Init скрипт** | `S99telegram_bot` | `S99web_ui` |
| **Порт** | Не требуется | 8080 |

## Обновление скрипта

Для обновления script.sh:

```bash
# Отредактировать script_web.sh
# Скопировать в script.sh
copy script_web.sh script.sh

# Обновить MD5 хэш
certutil -hashfile script.sh MD5 > script.sh.md5
```

## Использование

### Установка

```bash
/opt/root/script.sh -install
```

**Что делает:**
1. Устанавливает пакеты (curl, python3, python3-pip)
2. Настраивает ipset для маршрутизации
3. Загружает шаблоны конфигураций VPN
4. Устанавливает скрипты unblock
5. **Устанавливает веб-интерфейс** в `/opt/etc/web_ui/`
6. Создаёт `web_config.py` с параметрами
7. Устанавливает `S99web_ui` для автозапуска
8. Запускает веб-интерфейс

### Удаление

```bash
/opt/root/script.sh -remove
```

**Что делает:**
1. Удаляет пакеты
2. Очищает ipset множества
3. Удаляет файлы и директории bypass_keenetic
4. **Удаляет веб-интерфейс** из `/opt/etc/web_ui/`
5. Удаляет `S99web_ui`

### Обновление

```bash
/opt/root/script.sh -update
```

**Что делает:**
1. Обновляет пакеты
2. **Обновляет файлы веб-интерфейса**
3. Обновляет core модули
4. Перезапускает веб-интерфейс

### Диагностика

```bash
/opt/root/script.sh -var
```

Показывает все переменные конфигурации.

## Принцип работы

1. Веб-интерфейс копирует `script.sh` из локальной директории `scripts/`
2. Скрипт размещается в `/opt/root/script.sh` на роутере
3. Скрипт запускается с аргументом `-install`, `-remove` или `-update`
4. `script.sh` читает конфигурацию из `/opt/etc/web_ui/core/web_config.py`
5. Устанавливает/удаляет/обновляет компоненты bypass_keenetic и веб-интерфейс

## URL для загрузки файлов

Скрипт использует `base_url` из конфигурации:

```python
base_url = "https://raw.githubusercontent.com/royfincher25-source/bypass_keenetic/main"
```

**Важно:** Убедитесь, что `web_config.py` содержит правильный URL!

## Структура веб-интерфейса

После установки:

```
/opt/etc/web_ui/
├── app.py              # Flask приложение
├── routes.py           # Маршруты
├── env_parser.py       # Парсер .env
├── requirements.txt    # Зависимости Python
├── version.md          # Версия
├── .env.example        # Шаблон конфигурации
├── core/
│   ├── config.py
│   ├── utils.py
│   ├── services.py
│   ├── ipset_manager.py
│   ├── list_catalog.py
│   ├── dns_manager.py
│   ├── app_config.py
│   ├── web_config.py   # Конфигурация (генерируется)
│   └── __init__.py
└── templates/          # HTML шаблоны
```

## Автозапуск

Скрипт `S99web_ui`:

```bash
#!/bin/sh
case "$1" in
  start)
    cd /opt/etc/web_ui
    nohup python3 app.py > /opt/var/log/web_ui.log 2>&1 &
    ;;
  stop)
    pkill -f "python.*app.py"
    ;;
  restart)
    $0 stop
    sleep 2
    $0 start
    ;;
esac
```

**Проверка статуса:**

```bash
# Проверить процесс
ps | grep python

# Проверить порт
netstat -tlnp | grep 8080

# Проверить логи
tail -f /opt/var/log/web_ui.log
```
