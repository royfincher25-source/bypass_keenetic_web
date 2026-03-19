#!/bin/sh
# Полный скрипт исправления всех проблем с обновлением на роутере

echo "=== Полное исправление всех проблем ==="
echo "1. Исправление репозитория и ветки"
echo "2. Добавление импорта jsonify"
echo "3. Удаление ссылок на bot3"
echo "4. Добавление файла VERSION"
echo "5. Перезапуск веб-интерфейса"
echo ""

# 1. Остановить веб-интерфейс
echo "1. Остановка веб-интерфейса..."
/opt/etc/init.d/S99web_ui stop 2>/dev/null || echo "Веб-интерфейс уже остановлен"

# 2. Исправить web_config.py
WEB_CONFIG="/opt/etc/web_ui/core/web_config.py"
if [ -f "$WEB_CONFIG" ]; then
    echo "2. Исправление web_config.py..."
    if grep -q "bypass_keenetic-web" "$WEB_CONFIG"; then
        sed -i 's|bypass_keenetic-web|bypass_keenetic_web|g' "$WEB_CONFIG"
        echo "   ✓ Исправлено имя репозитория"
    fi
    if grep -q 'base_url.*main' "$WEB_CONFIG"; then
        sed -i 's|/main"|/master"|g' "$WEB_CONFIG"
        echo "   ✓ Исправлена ветка на master"
    fi
fi

# 3. Исправить routes.py
ROUTES_FILE="/opt/etc/web_ui/routes.py"
if [ -f "$ROUTES_FILE" ]; then
    echo "3. Исправление routes.py..."
    if grep -q "bypass_keenetic-web" "$ROUTES_FILE"; then
        sed -i 's|bypass_keenetic-web|bypass_keenetic_web|g' "$ROUTES_FILE"
        echo "   ✓ Исправлено имя репозитория"
    fi
    if grep -q "github_branch = 'main'" "$ROUTES_FILE"; then
        sed -i "s|github_branch = 'main'|github_branch = 'master'|g" "$ROUTES_FILE"
        echo "   ✓ Исправлена ветка на master"
    fi
    if ! grep -q "from flask import.*jsonify" "$ROUTES_FILE"; then
        sed -i 's/from flask import Blueprint, render_template, redirect, url_for, request, session, flash, current_app/from flask import Blueprint, render_template, redirect, url_for, request, session, flash, current_app, jsonify/' "$ROUTES_FILE"
        echo "   ✓ Добавлен импорт jsonify"
    fi
fi

# 4. Исправить services.py для отображения версии
SERVICES_FILE="/opt/etc/web_ui/core/services.py"
if [ -f "$SERVICES_FILE" ]; then
    echo "4. Исправление services.py..."
    if grep -q "project_root = os.path.dirname" "$SERVICES_FILE"; then
        # Заменяем функцию get_local_version
        sed -i '/def get_local_version():/,/return .N/A./c\
def get_local_version():\
    """Получить локальную версию"""\
    # На роутере VERSION файл находится в /opt/etc/web_ui/\
    version_file = "/opt/etc/web_ui/VERSION"\
    try:\
        with open(version_file, "r", encoding="utf-8") as f:\
            return f.read().strip()\
    except FileNotFoundError:\
        return "N/A"' "$SERVICES_FILE"
        echo "   ✓ Исправлен путь к VERSION файлу"
    fi
fi

# 5. Добавить файл VERSION
echo "5. Проверка файла VERSION..."
if [ ! -f "/opt/etc/web_ui/VERSION" ]; then
    echo "   Файл VERSION не найден, скачиваем..."
    curl -sL -o "/opt/etc/web_ui/VERSION" "https://raw.githubusercontent.com/royfincher25-source/bypass_keenetic_web/master/VERSION"
    if [ -f "/opt/etc/web_ui/VERSION" ]; then
        echo "   ✓ Файл VERSION скачан"
    else
        echo "   ✗ Не удалось скачать VERSION"
    fi
else
    echo "   ✓ Файл VERSION уже существует"
fi

# 6. Исправить другие скрипты
echo "6. Исправление других скриптов..."
if [ -f "/opt/etc/web_ui/resources/scripts/100-unblock-vpn-v4.sh" ]; then
    if grep -q "bot_config.py" "/opt/etc/web_ui/resources/scripts/100-unblock-vpn-v4.sh"; then
        sed -i 's|/opt/etc/bot/bot_config.py|/opt/etc/web_ui/core/web_config.py|g' "/opt/etc/web_ui/resources/scripts/100-unblock-vpn-v4.sh"
        echo "   ✓ Исправлено в 100-unblock-vpn-v4.sh"
    fi
fi

if [ -f "/opt/etc/web_ui/resources/scripts/keensnap.sh" ]; then
    if grep -q "bot_config.py" "/opt/etc/web_ui/resources/scripts/keensnap.sh"; then
        sed -i 's|bot_config.py|web_config.py|g' "/opt/etc/web_ui/resources/scripts/keensnap.sh"
        echo "   ✓ Исправлено в keensnap.sh"
    fi
fi

if [ -f "/opt/etc/web_ui/env_parser.py" ]; then
    if grep -q "/opt/etc/bot/.env" "/opt/etc/web_ui/env_parser.py"; then
        sed -i 's|/opt/etc/bot/.env|/opt/etc/web_ui/.env|g' "/opt/etc/web_ui/env_parser.py"
        echo "   ✓ Исправлено в env_parser.py"
    fi
fi

# 7. Установить права доступа
echo "7. Установка прав доступа..."
chmod -R 755 /opt/etc/web_ui/scripts/ 2>/dev/null || true
chmod -R 755 /opt/etc/web_ui/resources/scripts/ 2>/dev/null || true
chmod 644 /opt/etc/web_ui/*.py 2>/dev/null || true
chmod 644 /opt/etc/web_ui/core/*.py 2>/dev/null || true
chmod 644 /opt/etc/web_ui/VERSION 2>/dev/null || true

# 8. Перезапустить веб-интерфейс
echo "8. Перезапуск веб-интерфейса..."
/opt/etc/init.d/S99web_ui start

echo "=== Исправление завершено ==="
echo "Проверьте страницу обновлений: http://192.168.1.1:8080/service/updates"
echo "Текущая версия должна отображаться правильно."