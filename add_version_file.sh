#!/bin/sh
# Скрипт для добавления файла VERSION на роутер

echo "=== Добавление файла VERSION ==="

# Проверить, существует ли VERSION на роутере
VERSION_FILE="/opt/etc/web_ui/VERSION"
if [ -f "$VERSION_FILE" ]; then
    echo "✓ Файл VERSION уже существует:"
    cat "$VERSION_FILE"
else
    echo "Файл VERSION не найден, скачиваем..."
    # Скачать VERSION из репозитория
    curl -sL -o "$VERSION_FILE" "https://raw.githubusercontent.com/royfincher25-source/bypass_keenetic_web/master/VERSION"
    if [ -f "$VERSION_FILE" ]; then
        echo "✓ Файл VERSION скачан:"
        cat "$VERSION_FILE"
    else
        echo "✗ Не удалось скачать VERSION"
    fi
fi

# Проверить, установлены ли права
chmod 644 "$VERSION_FILE" 2>/dev/null || true

echo "=== Готово ==="