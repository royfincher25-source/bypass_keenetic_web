# Миграция с test на web

## Обзор

Руководство по переходу с проекта `bypass_keenetic_test` (тестовая версия) на `bypass_keenetic_web` (новый веб-интерфейс).

## Что удалить на роутере

Удалите следующие папки и файлы:

```bash
# Остановить приложение (если запущено)
pkill -f "python.*test"

# Удалить тестовую директорию
rm -rf /opt/etc/bypass_keenetic_test/
```

Также удалите стартовые скрипты (если были созданы):

```bash
rm -f /opt/etc/init.d/S99bypass_test
```

## Что установить на роутер

### 1. Скопировать новую директорию web

```bash
# С локального компьютера на роутер
scp -r h:\disk_e\dell\bypass_keenetic-web\src\web\ root@192.168.1.1:/opt/etc/web_ui/
```

### 2. Переименовать (опционально)

Если нужна директория с другим именем:

```bash
# На роутере
mv /opt/etc/web_ui /opt/etc/bypass_keenetic
```

### 3. Настроить конфигурацию

```bash
# На роутере
cd /opt/etc/web_ui

# Создать .env из примера
cp .env.example .env

# Отредактировать настройки
nano .env
```

Минимальные настройки в `.env`:
```bash
WEB_PASSWORD=your_secure_password
ROUTER_IP=192.168.1.1
```

### 4. Установить зависимости

```bash
pip3 install -r requirements.txt
```

### 5. Запустить приложение

```bash
cd /opt/etc/web_ui
python3 app.py &
```

### 6. Создать автозапуск (опционально)

```bash
# Создать скрипт автозапуска
cat > /opt/etc/init.d/S99bypass_web << 'EOF'
#!/bin/sh
case "$1" in
  start)
    cd /opt/etc/web_ui
    python3 app.py &
    ;;
  stop)
    pkill -f "python.*app.py"
    ;;
esac
EOF

chmod +x /opt/etc/init.d/S99bypass_web
```

## Структура нового проекта

```
/opt/etc/web_ui/
├── app.py              # Flask приложение
├── routes.py           # Маршруты
├── env_parser.py       # Парсер .env
├── core/
│   ├── __init__.py
│   ├── config.py       # Конфигурация
│   ├── utils.py        # Утилиты
│   └── services.py     # Парсеры ключей
├── templates/          # HTML шаблоны
├── static/             # CSS стили
├── requirements.txt
├── .env
└── .env.example
```

## Доступ

- **URL:** http://192.168.1.1:8080
- **Порт по умолчанию:** 8080
- **Пароль:** из `.env` (параметр `WEB_PASSWORD`)

## Проверка работы

```bash
# Проверить, что процесс запущен
ps | grep app.py

# Проверить порт
netstat -tlnp | grep 8080
```

## Откат (если нужно)

Для возврата к старой версии:

```bash
# Остановить новое приложение
pkill -f "python.*app.py"

# Удалить новое
rm -rf /opt/etc/web_ui/

# Восстановить старое (если есть бэкап)
# scp -r backup/test/ root@192.168.1.1:/opt/etc/bypass_keenetic_test/
```
