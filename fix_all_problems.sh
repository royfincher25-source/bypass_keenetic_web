#!/bin/sh
# Полный скрипт исправления всех проблем с обновлением на роутере

echo "=== Полное исправление проблем обновления ==="

# 1. Остановить веб-интерфейс
echo "1. Остановка веб-интерфейса..."
/opt/etc/init.d/S99web_ui stop 2>/dev/null || echo "Веб-интерфейс уже остановлен"

# 2. Исправить web_config.py
WEB_CONFIG="/opt/etc/web_ui/core/web_config.py"
if [ -f "$WEB_CONFIG" ]; then
    echo "2. Исправление web_config.py..."
    # Проверить и исправить имя репозитория
    if grep -q "bypass_keenetic-web" "$WEB_CONFIG"; then
        sed -i 's|bypass_keenetic-web|bypass_keenetic_web|g' "$WEB_CONFIG"
        echo "   ✓ Исправлено имя репозитория"
    fi
    # Проверить и исправить ветку
    if grep -q 'base_url.*main' "$WEB_CONFIG"; then
        sed -i 's|/main"|/master"|g' "$WEB_CONFIG"
        echo "   ✓ Исправлена ветка на master"
    fi
fi

# 3. Исправить routes.py (добавить импорт jsonify)
ROUTES_FILE="/opt/etc/web_ui/routes.py"
if [ -f "$ROUTES_FILE" ]; then
    echo "3. Исправление routes.py..."
    # Проверить и исправить имя репозитория
    if grep -q "bypass_keenetic-web" "$ROUTES_FILE"; then
        sed -i 's|bypass_keenetic-web|bypass_keenetic_web|g' "$ROUTES_FILE"
        echo "   ✓ Исправлено имя репозитория"
    fi
    # Проверить и исправить ветку
    if grep -q "github_branch = 'main'" "$ROUTES_FILE"; then
        sed -i "s|github_branch = 'main'|github_branch = 'master'|g" "$ROUTES_FILE"
        echo "   ✓ Исправлена ветка на master"
    fi
    # Добавить импорт jsonify, если его нет
    if ! grep -q "from flask import.*jsonify" "$ROUTES_FILE"; then
        sed -i 's/from flask import Blueprint, render_template, redirect, url_for, request, session, flash, current_app/from flask import Blueprint, render_template, redirect, url_for, request, session, flash, current_app, jsonify/' "$ROUTES_FILE"
        echo "   ✓ Добавлен импорт jsonify"
    fi
fi

# 4. Исправить install_web.sh
INSTALL_FILE="/opt/etc/web_ui/scripts/install_web.sh"
if [ -f "$INSTALL_FILE" ]; then
    echo "4. Исправление install_web.sh..."
    # Исправить путь к templates_dir
    if grep -q 'templates_dir = "/opt/etc/bot/templates/"' "$INSTALL_FILE"; then
        sed -i 's|/opt/etc/bot/templates/|/opt/etc/web_ui/templates/|g' "$INSTALL_FILE"
        echo "   ✓ Исправлен путь к templates_dir"
    fi
fi

# 5. Исправить скрипты с ссылками на bot_config.py
echo "5. Исправление скриптов..."
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

# 6. Исправить env_parser.py
ENV_PARSER="/opt/etc/web_ui/env_parser.py"
if [ -f "$ENV_PARSER" ]; then
    echo "6. Исправление env_parser.py..."
    if grep -q "/opt/etc/bot/.env" "$ENV_PARSER"; then
        sed -i 's|/opt/etc/bot/.env|/opt/etc/web_ui/.env|g' "$ENV_PARSER"
        echo "   ✓ Исправлен путь к .env"
    fi
fi

# 7. Добавить файл VERSION, если его нет
echo "7. Проверка файла VERSION..."
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

# 8. Проверить права доступа
echo "8. Установка прав доступа..."
chmod -R 755 /opt/etc/web_ui/scripts/ 2>/dev/null || true
chmod -R 755 /opt/etc/web_ui/resources/scripts/ 2>/dev/null || true
chmod 644 /opt/etc/web_ui/*.py 2>/dev/null || true
chmod 644 /opt/etc/web_ui/core/*.py 2>/dev/null || true
chmod 644 /opt/etc/web_ui/VERSION 2>/dev/null || true

# 9. Перезапустить веб-интерфейс
echo "9. Перезапуск веб-интерфейса..."
/opt/etc/init.d/S99web_ui start

echo "=== Исправление завершено ==="
echo "Попробуйте кнопку 'Обновить' в веб-интерфейсе снова."