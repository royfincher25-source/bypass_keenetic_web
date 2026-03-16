# Bypass Keenetic Web

Web-интерфейс для управления bypass_keenetic на роутерах Keenetic.

## Описание

Web-интерфейс заменяет Telegram-бота и предоставляет тот же функционал через браузер.
Основное преимущество — не зависит от доступности Telegram.

## Требования

- Python 3.8+
- Flask 3.0.0
- Jinja2 3.1.2
- Werkzeug 3.0.0
- requests >= 2.31.0
- waitress==2.1.2 (production server, опционально)

## Зависимости

### Основные зависимости

| Пакет | Версия | Размер | Назначение |
|-------|--------|--------|------------|
| **Flask** | 3.0.0 | ~2.5MB | Веб-фреймворк |
| **Jinja2** | 3.1.2 | ~1MB | Шаблонизатор |
| **Werkzeug** | 3.0.0 | ~1MB | WSGI-утилиты |
| **requests** | >=2.31.0 | ~500KB | HTTP-клиент |
| **waitress** | 2.1.2 | ~200KB | Production server |

**Итого:** ~7MB (с waitress), ~5MB (без waitress)

### Production server (waitress)

> [!tip] Рекомендуется для production
> Waitress легче чем gunicorn (~2MB vs ~5MB) и оптимизирован для embedded-устройств

**Настройки по умолчанию:**
- `threads=2` — минимум воркеров для 128MB RAM
- `connection_limit=10` — защита от перегрузки
- `cleanup_interval=30` — очистка каждые 30 секунд

**Если waitress не установлен:**
- Автоматический fallback на Flask development server
- Режим `threaded=True` для многопоточности

## Установка

### Оптимизация для роутеров (128MB RAM)

> [!important] Критические оптимизации
> Проект оптимизирован для работы на роутерах с ограниченными ресурсами:
> - Ротация логов: 100KB × 3 = 300KB макс.
> - LRU-кэш: 50 записей (was 100)
> - MD5-хэш для кэширования VPN-ключей
> - Кэширование статусов сервисов: 30с TTL
> - ThreadPoolExecutor: 2 воркера max

1. Скопировать директорию `bypass_keenetic_web/` на роутер:
   ```bash
   scp -r bypass_keenetic_web/ root@192.168.1.1:/opt/etc/
   ```

2. Установить зависимости:
   ```bash
   pip3 install -r /opt/etc/bypass_keenetic_web/requirements.txt
   ```

3. Настроить `.env` по примеру `.env.example`:
   ```bash
   cp /opt/etc/bypass_keenetic_web/.env.example /opt/etc/bypass_keenetic_web/.env
   nano /opt/etc/bypass_keenetic_web/.env
   ```

4. Запустить:
   ```bash
   cd /opt/etc/bypass_keenetic_web
   python3 app.py &
   ```

## Рекомендации по установке

### 1. Проверка перед установкой

```bash
# 1. Проверить свободное место
df -h /opt

# Требуется: минимум 20MB, рекомендуется 50MB+

# 2. Проверить доступную память
free -m

# Требуется: минимум 64MB свободной

# 3. Проверить версию Python
python3 --version

# Требуется: Python 3.8+
```

### 2. Установка зависимостей

```bash
# Вариант А: Из requirements.txt (рекомендуется)
cd /opt/etc/bypass_keenetic_web
pip3 install -r requirements.txt

# Вариант Б: Прямая установка
pip3 install Flask==3.0.0 Jinja2==3.1.2 Werkzeug==3.0.0 requests>=2.31.0 waitress==2.1.2
```

### 3. Проверка установки

```bash
# Проверить установленные пакеты
pip3 list | grep -E "Flask|Jinja2|Werkzeug|requests|waitress"

# Проверить импорт модулей
python3 -c "import flask, jinja2, werkzeug, requests; print('OK')"
```

### 4. Первый запуск

```bash
# Запуск в фоновом режиме
cd /opt/etc/bypass_keenetic_web
nohup python3 app.py > /opt/var/log/web_ui.log 2>&1 &

# Проверка процесса
ps | grep python

# Проверка порта
netstat -tlnp | grep 8080
```

## Чек-лист проверки

### После установки

```bash
# 1. Проверка процесса
ps | grep python
# Ожидается: python3 app.py запущен

# 2. Проверка порта
netstat -tlnp | grep 8080
# Ожидается: порт 8080 открыт

# 3. Проверка логов
tail -f /opt/var/log/web_ui.log
# Ожидается: нет ошибок ERROR/CRITICAL

# 4. Проверка доступности
curl -I http://localhost:8080
# Ожидается: HTTP/1.0 302 Found (редирект на /login)

# 5. Проверка размера логов
ls -lh /opt/var/log/web_ui.log*
# Ожидается: <300KB (3 файла по 100KB)
```

### После оптимизаций

```bash
# 1. Потребление памяти
ps | grep python | awk '{print $2}'
# Ожидается: ~10-15MB (was ~25MB)

# 2. Проверка кэширования
time curl http://localhost:8080/keys
# 2-й запрос должен быть быстрее (кэш статусов 30с)

# 3. Проверка ротации логов
ls -lh /opt/var/log/web_ui.log*
# Ожидается: 3 файла по ~100KB

# 4. Проверка ThreadPoolExecutor
curl http://localhost:8080/keys &
curl http://localhost:8080/service &
wait
# Оба запроса выполнятся параллельно
```

### Диагностика проблем

```bash
# Если не запускается:

# 1. Проверить логи
tail -n 50 /opt/var/log/web_ui.log

# 2. Проверить зависимости
pip3 show flask

# 3. Проверить .env
cat /opt/etc/bypass_keenetic_web/.env

# 4. Запустить в режиме отладки
cd /opt/etc/bypass_keenetic_web
python3 app.py
# Смотреть вывод в консоль
```

## Доступ

- **URL:** http://192.168.1.1:8080
- **Пароль:** из `.env` (WEB_PASSWORD)

## Конфигурация

Файл `.env`:

```bash
# Web Interface Configuration
WEB_HOST=0.0.0.0
WEB_PORT=8080
WEB_PASSWORD=your_secure_password

# Router Configuration
ROUTER_IP=192.168.1.1
UNBLOCK_DIR=/opt/etc/unblock/

# Logging
LOG_FILE=/opt/var/log/web_ui.log
```

| Параметр | Описание | По умолчанию |
|----------|----------|--------------|
| WEB_HOST | Адрес прослушивания | 0.0.0.0 |
| WEB_PORT | Порт web-интерфейса | 8080 |
| WEB_PASSWORD | Пароль для авторизации | changeme |
| ROUTER_IP | IP-адрес роутера | 192.168.1.1 |
| UNBLOCK_DIR | Директория bypass | /opt/etc/unblock/ |
| LOG_FILE | Путь к лог-файлу | /opt/var/log/web_ui.log |

## Функционал

### Главное меню

5 основных разделов:

- 🔑 **Ключи и мосты** — настройка VPN ключей (Tor, Vless, Trojan, Shadowsocks, VLESS+REALITY)
- 📑 **Списки обхода** — управление списками доменов для обхода блокировок
- 📲 **Установка и удаление** — установка и удаление bypass_keenetic с GitHub
- 📊 **Статистика** — статистика трафика
- ⚙️ **Сервис** — сервисные функции:
  - Перезапуск роутера
  - Перезапуск всех сервисов
  - DNS Override
  - Бэкап конфигурации
  - Обновление bypass_keenetic

### Авторизация

Session-based авторизация с cookie:

- При первом входе требуется пароль
- Сессия действует 24 часа
- При выходе сессия очищается

## Безопасность

⚠️ **Важно:** Измените пароль по умолчанию перед использованием!

```bash
WEB_PASSWORD=your_secure_password_here
```

## Архитектура

```
bypass_keenetic-web/
├── src/
│   └── web_ui/            # Папка для копирования на роутер
│       ├── app.py              # Flask приложение (factory function)
│       ├── routes.py           # Маршруты (Blueprint main)
│       ├── env_parser.py       # Лёгкий парсер .env
│       ├── core/
│       │   ├── __init__.py
│       │   ├── config.py       # WebConfig singleton
│       │   ├── utils.py        # Утилиты, LRU-кэш, логирование
│       │   └── services.py    # Парсеры VPN-ключей
│       ├── templates/
│       │   ├── base.html       # Базовый шаблон (Bootstrap 5.3 dark)
│       │   ├── login.html      # Страница авторизации
│       │   ├── index.html      # Главное меню (плитки)
│       │   ├── keys.html       # Ключи и мосты
│       │   ├── bypass.html     # Списки обхода
│       │   ├── install.html    # Установка/удаление
│       │   ├── stats.html      # Статистика
│       │   ├── service.html   # Сервисное меню
│       │   └── updates.html   # Обновления
│       ├── static/
│       │   └── style.css       # Custom стили
│       ├── requirements.txt    # Зависимости Python
│       ├── .env.example       # Пример конфигурации
│       └── version.md         # Версия приложения
└── README.md
```

## Установка

1. Скопировать директорию `src/web_ui/` на роутер:
   ```bash
   scp -r src/web_ui/ root@192.168.1.1:/opt/etc/bypass_keenetic_web/
   ```

2. Установить зависимости:
   ```bash
   pip3 install -r /opt/etc/bypass_keenetic_web/requirements.txt
   ```

3. Настроить `.env` по примеру `.env.example`:
   ```bash
   cp /opt/etc/bypass_keenetic_web/.env.example /opt/etc/bypass_keenetic_web/.env
   nano /opt/etc/bypass_keenetic_web/.env
   ```

4. Запустить:
   ```bash
   cd /opt/etc/bypass_keenetic_web
   python3 app.py &
   ```

## Логирование

Логи пишутся в файл, указанный в `LOG_FILE` (по умолчанию `/opt/var/log/web_ui.log`):

```bash
# Просмотр логов
tail -f /opt/var/log/web_ui.log

# Поиск ошибок
grep -i error /opt/var/log/web_ui.log
```

## Тестирование

Запуск тестов:

```bash
pytest tests/web/ -v
```

Тесты покрывают:

- Конфигурацию (WebConfig singleton, загрузка .env)
- Flask приложение (создание, маршруты)
- Шаблоны (существование, рендеринг, стили)

## Потребление ресурсов

- **Память:** ~15MB (vs 5MB у Telegram-бота)
- **Порт:** 8080 (локально)
- **CPU:** минимальное в простое

## Отличия от Telegram-бота

| Параметр | Telegram | Web |
|----------|----------|-----|
| Потребление памяти | ~5MB | ~15MB |
| Зависимость | Telegram API | Нет |
| Интерфейс | Inline кнопки | Плитки (cards) |
| Навигация | Callback queries | Полные перезагрузки |

## Лицензия

Лицензия аналогична основному проекту bypass_keenetic.

## Поддержка

Вопросы и предложения: https://github.com/royfincher25-source/bypass_keenetic_web/issues
