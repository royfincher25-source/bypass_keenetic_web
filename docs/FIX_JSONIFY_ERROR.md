# Исправление ошибки NameError: name 'jsonify' is not defined

## Проблема

После обновления файлов через кнопку "Обновить" в веб-интерфейсе появляется ошибка:
```
NameError: name 'jsonify' is not defined
```

Эта ошибка возникает в файле `/opt/etc/web_ui/routes.py` в функции `system_stats` (строка 1527).

## Причина

В файле `routes.py` используется функция `jsonify()` из Flask, но она не импортирована.

## Решение

### Вариант 1: Простое исправление (рекомендуется)

1. Подключитесь к роутеру по SSH:
   ```bash
   ssh root@192.168.1.1
   ```

2. Скачайте и запустите скрипт исправления:
   ```bash
   cd /tmp
   curl -sL -o fix_all.sh "https://raw.githubusercontent.com/royfincher25-source/bypass_keenetic_web/master/fix_all_problems.sh"
   chmod +x fix_all.sh
   ./fix_all.sh
   ```

### Вариант 2: Ручное исправление

1. Подключитесь к роутеру по SSH:
   ```bash
   ssh root@192.168.1.1
   ```

2. Отредактируйте файл `routes.py`:
   ```bash
   nano /opt/etc/web_ui/routes.py
   ```

3. Найдите строку 6 (начало файла) и добавьте `jsonify` в импорты Flask:
   ```python
   from flask import Blueprint, render_template, redirect, url_for, request, session, flash, current_app, jsonify
   ```

4. Сохраните файл (Ctrl+O, Enter, Ctrl+X)

5. Перезапустите веб-интерфейс:
   ```bash
   /opt/etc/init.d/S99web_ui restart
   ```

## Проверка

После исправления:
1. Откройте веб-интерфейс: `http://192.168.1.1:8080`
2. Перейдите на страницу статистики системы
3. Убедитесь, что ошибка больше не появляется

## Дополнительные исправления

Скрипт `fix_all_problems.sh` также исправляет другие проблемы:
- Правильное имя репозитория (`bypass_keenetic_web` вместо `bypass_keenetic-web`)
- Правильную ветку (`master` вместо `main`)
- Ссылки на файлы `bot3` (удалённые)
- Пути к конфигурационным файлам