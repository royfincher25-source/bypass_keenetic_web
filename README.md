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

## Установка

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
```

| Параметр | Описание | По умолчанию |
|----------|----------|--------------|
| WEB_HOST | Адрес прослушивания | 0.0.0.0 |
| WEB_PORT | Порт web-интерфейса | 8080 |
| WEB_PASSWORD | Пароль для авторизации | changeme |
| ROUTER_IP | IP-адрес роутера | 192.168.1.1 |

## Функционал

### Главное меню

5 основных разделов:

- 🔑 **Ключи и мосты** — настройка VPN ключей (Tor, Vless, Trojan, Shadowsocks)
- 📑 **Списки обхода** — управление списками доменов для обхода блокировок
- 📲 **Установка и удаление** — установка и удаление компонентов системы
- 📊 **Статистика** — статистика трафика (в разработке)
- ⚙️ **Сервис** — сервисные функции (перезапуск, бэкап, DNS override)

### Авторизация

Session-based авторизация с cookie:

- При первом входе требуется пароль
- Сессия действует 1 час
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
│   └── web/            # Папка для копирования на роутер
│       ├── app.py              # Flask приложение (factory function)
│       ├── routes.py           # Маршруты (Blueprint main)
│       ├── env_parser.py       # Лёгкий парсер .env
│       ├── core/
│       │   ├── __init__.py
│       │   ├── config.py       # WebConfig singleton
│       │   ├── utils.py        # Утилиты, LRU-кэш
│       │   └── services.py    # Парсеры VPN-ключей
│       ├── templates/
│       │   ├── base.html       # Базовый шаблон (Bootstrap 5.3 dark)
│       │   ├── login.html      # Страница авторизации
│       │   ├── index.html      # Главное меню (плитки)
│       │   ├── keys.html       # Ключи и мосты
│       │   ├── bypass.html     # Списки обхода
│       │   ├── install.html    # Установка/удаление
│       │   ├── stats.html      # Статистика
│       │   └── service.html    # Сервисное меню
│       ├── static/
│       │   └── style.css       # Custom стили
│       ├── requirements.txt    # Зависимости Python
│       └── .env.example        # Пример конфигурации
└── README.md
```

## Установка

1. Скопировать директорию `src/web/` на роутер:
   ```bash
   scp -r src/web/ root@192.168.1.1:/opt/etc/bypass_keenetic_web/
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
