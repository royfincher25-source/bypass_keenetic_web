#!/bin/sh

# =============================================================================
# SCRIPT.SH ДЛЯ WEB_UI
# Адаптированная версия для bypass_keenetic-web
# =============================================================================

# Путь к конфигурации веб-интерфейса
WEB_CONFIG="/opt/etc/web_ui/core/web_config.py"
if [ ! -f "$WEB_CONFIG" ]; then
    echo "❌ Ошибка: Файл конфигурации $WEB_CONFIG не найден!" >&2
    echo "Создайте файл конфигурации перед запуском установки." >&2
    exit 1
fi

# Чтение URL из конфигурации
BASE_URL=$(grep "^base_url" "$WEB_CONFIG" | awk -F'"' '{print $2}')
WEB_URL="$BASE_URL/src/web_ui"

# Чтение IP и портов
lanip=$(grep "routerip" "$WEB_CONFIG" | awk -F'=' '{print $2}' | tr -d ' "')
localportsh=$(grep "localportsh" "$WEB_CONFIG" | awk -F'=' '{print $2}' | tr -d ' ')
dnsporttor=$(grep "dnsporttor" "$WEB_CONFIG" | awk -F'=' '{print $2}' | tr -d ' ')
localporttor=$(grep "localporttor" "$WEB_CONFIG" | awk -F'=' '{print $2}' | tr -d ' ')
localportvless=$(grep "localportvless" "$WEB_CONFIG" | awk -F'=' '{print $2}' | tr -d ' ')
localporttrojan=$(grep "localporttrojan" "$WEB_CONFIG" | awk -F'=' '{print $2}' | tr -d ' ')
dnsovertlsport=$(grep "dnsovertlsport" "$WEB_CONFIG" | awk -F'=' '{print $2}' | tr -d ' ')
dnsoverhttpsport=$(grep "dnsoverhttpsport" "$WEB_CONFIG" | awk -F'=' '{print $2}' | tr -d ' ')

# Чтение версии прошивки
if [ -f /proc/version ]; then
    keen_os_full=$(cat /proc/version | awk '{print $3}')
    keen_os_short=$(echo "$keen_os_full" | cut -d'.' -f1)
else
    echo "❌ Ошибка: файл /proc/version не найден. Не удалось получить версию ОС" >&2
    exit 1
fi

# Функция для чтения путей из конфига
read_path() {
    sed -n "/\"$1\":/s/.*\": *\"\([^\"]*\)\".*/\1/p" "$WEB_CONFIG"
}

# Чтение путей из paths
UNBLOCK_DIR=$(read_path "unblock_dir")
TOR_CONFIG=$(read_path "tor_config")
SHADOWSOCKS_CONFIG=$(read_path "shadowsocks_config")
TROJAN_CONFIG=$(read_path "trojan_config")
VLESS_CONFIG=$(read_path "vless_config")
TEMPLATES_DIR=$(read_path "templates_dir")
DNSMASQ_CONF=$(read_path "dnsmasq_conf")
CRONTAB=$(read_path "crontab")
REDIRECT_SCRIPT=$(read_path "redirect_script")
VPN_SCRIPT=$(read_path "vpn_script")
IPSET_SCRIPT=$(read_path "ipset_script")
UNBLOCK_IPSET=$(read_path "unblock_ipset")
UNBLOCK_DNSMASQ=$(read_path "unblock_dnsmasq")
UNBLOCK_UPDATE=$(read_path "unblock_update")
KEENSNAP_DIR=$(read_path "keensnap_dir")
SCRIPT_BU=$(read_path "script_bu")
WEB_DIR=$(read_path "web_dir")
TOR_TMP_DIR=$(read_path "tor_tmp_dir")
TOR_DIR=$(read_path "tor_dir")
XRAY_DIR=$(read_path "xray_dir")
TROJAN_DIR=$(read_path "trojan_dir")
INIT_SHADOWSOCKS=$(read_path "init_shadowsocks")
INIT_TROJAN=$(read_path "init_trojan")
INIT_XRAY=$(read_path "init_xray")
INIT_TOR=$(read_path "init_tor")
INIT_DNSMASQ=$(read_path "init_dnsmasq")
INIT_UNBLOCK=$(read_path "init_unblock")
INIT_WEB=$(read_path "init_web")
HOSTS_FILE=$(read_path "hosts_file")

# Чтение пакетов
installed_packages=$(opkg list-installed | awk '{print $1}')
PACKAGES=$(awk '/^packages = \[/,/\]/ {
    if ($0 ~ /".*"/) {
        gsub(/^[[:space:]]*"|".*$/, "")
        printf "%s ", $0
    }
}' "$WEB_CONFIG")

# =============================================================================
# УДАЛЕНИЕ (-remove)
# =============================================================================
if [ "$1" = "-remove" ]; then
    echo "=== Удаление bypass_keenetic ==="

    # Удаление пакетов
    for pkg in $PACKAGES; do
        if echo "$installed_packages" | grep -q "^$pkg$"; then
            echo "Удаляем пакет: $pkg"
            opkg remove "$pkg" --force-removal-of-dependent-packages
        else
            echo "❕Пакет $pkg не установлен, пропускаем..."
        fi
    done
    echo "Все пакеты удалены. Начинаем удаление папок, файлов и настроек"

    # Очистка ipset
    ipset flush unblocktor 2>/dev/null || true
    ipset flush unblocksh 2>/dev/null || true
    ipset flush unblockvless 2>/dev/null || true
    ipset flush unblocktroj 2>/dev/null || true

    if ls -d "${UNBLOCK_DIR}vpn-"*.txt >/dev/null 2>&1; then
        for vpn_file_names in "${UNBLOCK_DIR}vpn-"*; do
            vpn_file_name=$(echo "$vpn_file_names" | awk -F '/' '{print $5}' | sed 's/.txt//')
            unblockvpn=$(echo "unblock$vpn_file_name")
            ipset flush "$unblockvpn" 2>/dev/null || true
        done
    fi

    # Список для удаления
    for file in \
        "$CRONTAB" \
        "$INIT_SHADOWSOCKS" \
        "$INIT_TROJAN" \
        "$INIT_XRAY" \
        "$INIT_TOR" \
        "$INIT_DNSMASQ" \
        "$INIT_UNBLOCK" \
        "$REDIRECT_SCRIPT" \
        "$VPN_SCRIPT" \
        "$IPSET_SCRIPT" \
        "$UNBLOCK_IPSET" \
        "$UNBLOCK_DNSMASQ" \
        "$UNBLOCK_UPDATE" \
        "$DNSMASQ_CONF" \
        "$TOR_TMP_DIR" \
        "$TOR_DIR" \
        "$XRAY_DIR" \
        "$TEMPLATES_DIR" \
        "$TROJAN_DIR"
    do
        [ -e "$file" ] && rm -rf "$file" && echo "Удалён файл или директория: \"$file\""
    done

    # Удаление веб-интерфейса
    if [ -n "$WEB_DIR" ] && [ -d "$WEB_DIR" ]; then
        rm -rf "$WEB_DIR"
        echo "Удалена директория веб-интерфейса: $WEB_DIR"
    fi

    # Удаление init скрипта веб-интерфейса
    if [ -n "$INIT_WEB" ] && [ -f "$INIT_WEB" ]; then
        rm -f "$INIT_WEB"
        echo "Удалён скрипт автозапуска веб-интерфейса: $INIT_WEB"
    fi

    echo "✅ Созданные папки, файлы и настройки удалены"
    echo "Для отключения DNS Override перейдите в веб-интерфейсе: ⚙️ Сервис -> ⁉️ DNS Override -> ✖️ ВЫКЛ"
    exit 0
fi

# =============================================================================
# УСТАНОВКА (-install)
# =============================================================================
if [ "$1" = "-install" ]; then
    echo "=== Установка bypass_keenetic ==="
    echo "ℹ️ Ваша версия KeenOS: ${keen_os_full}"

    # Установка пакетов
    for pkg in $PACKAGES; do
        if echo "$installed_packages" | grep -q "^$pkg$"; then
            echo "❕Пакет $pkg уже установлен, пропускаем..."
        else
            echo "Устанавливаем пакет: $pkg"
            if ! opkg install "$pkg"; then
                echo "❌ Ошибка при установке $pkg" >&2
                exit 1
            fi
        fi
    done
    sleep 3
    echo "✅ Установка пакетов завершена. Продолжаем установку"

    # Проверяем есть ли поддержка множества hash:net
    set_type=$(ipset --help 2>/dev/null | grep -q "hash:net" && echo "hash:net" || echo "hash:ip")
    [ "$set_type" = "hash:net" ] && echo "☑️ Поддержка множества типа hash:net есть" || echo "❕Поддержка множества типа hash:net отсутствует"

    # Установка скрипта для маршрутизации с помощью ipset
    curl -s -o "$IPSET_SCRIPT" "$BASE_URL/100-ipset.sh" || exit 1
    sed -i "s/hash:net/${set_type}/g" "$IPSET_SCRIPT" && \
    chmod 755 "$IPSET_SCRIPT" || chmod +x "$IPSET_SCRIPT"
    "$IPSET_SCRIPT" start
    echo "✅ Созданы файлы под множества"

    # Создание директории и шаблонов конфигов
    mkdir -p "$TEMPLATES_DIR"
    for template in tor_template.torrc vless_template.json trojan_template.json shadowsocks_template.json; do
        curl -s -o "$TEMPLATES_DIR/$template" "$BASE_URL/$template"
    done
    echo "✅ Загружены темплейты конфигураций для Tor, Shadowsocks, Vless, Trojan"

    # Установка конфигов из шаблонов
    mkdir -p "$TOR_TMP_DIR"
    cp "$TEMPLATES_DIR/tor_template.torrc" "$TOR_CONFIG" && \
    echo "✅ Установлены базовые настройки Tor"

    cp "$TEMPLATES_DIR/shadowsocks_template.json" "$SHADOWSOCKS_CONFIG" && \
    sed -i "s/ss-local/ss-redir/g" "$INIT_SHADOWSOCKS" 2>/dev/null && \
    echo "✅ Установлены базовые настройки Shadowsocks"

    cp "$TEMPLATES_DIR/trojan_template.json" "$TROJAN_CONFIG" && \
    echo "✅ Установлены базовые настройки Trojan"

    cp "$TEMPLATES_DIR/vless_template.json" "$VLESS_CONFIG" && \
    sed -i "s|ARGS=\"run -confdir $XRAY_DIR\"|ARGS=\"run -c $XRAY_DIR/config.json\"|" "$INIT_XRAY" 2>/dev/null && \
    echo "✅ Установлены базовые настройки Xray"

    # Создание unblock папки и файлов
    mkdir -p "$UNBLOCK_DIR"
    # Загрузка списков с GitHub
    curl -s -o "${UNBLOCK_DIR}vless.txt" "$BASE_URL/deploy/lists/unblockvless.txt"
    curl -s -o "${UNBLOCK_DIR}tor.txt" "$BASE_URL/deploy/lists/unblocktor.txt"
    # Создание пустых файлов если их нет
    for file in \
        "$HOSTS_FILE" \
        "${UNBLOCK_DIR}shadowsocks.txt" \
        "${UNBLOCK_DIR}tor.txt" \
        "${UNBLOCK_DIR}trojan.txt" \
        "${UNBLOCK_DIR}vless.txt" \
        "${UNBLOCK_DIR}vpn.txt"
    do
        touch "$file" && chmod 644 "$file"
    done
    echo "✅ Созданы файлы под домены и ip-адреса"

    # Установка скриптов для заполнения множеств unblock
    curl -s -o "$UNBLOCK_IPSET" "$BASE_URL/unblock_ipset.sh" || exit 1
    sed -i "s/40500/${dnsovertlsport}/g" "$UNBLOCK_IPSET" && \
    chmod 755 "$UNBLOCK_IPSET" || chmod +x "$UNBLOCK_IPSET"
    echo "✅ Установлен скрипт для заполнения множеств unblock IP-адресами"

    curl -s -o "$UNBLOCK_DNSMASQ" "$BASE_URL/unblock_dnsmasq.sh" || exit 1
    sed -i "s/40500/${dnsovertlsport}/g" "$UNBLOCK_DNSMASQ" && \
    chmod 755 "$UNBLOCK_DNSMASQ" || chmod +x "$UNBLOCK_DNSMASQ"
    "$UNBLOCK_DNSMASQ"
    echo "✅ Установлен скрипт для формирования конфигурации dnsmasq"

    curl -s -o "$UNBLOCK_UPDATE" "$BASE_URL/unblock_update.sh" || exit 1
    chmod 755 "$UNBLOCK_UPDATE" || chmod +x "$UNBLOCK_UPDATE"
    echo "✅ Установлен скрипт обновления системы"

    # Установка скриптов инициализации
    curl -s -o "$INIT_UNBLOCK" "$WEB_URL/S99unblock" || exit 1
    chmod 755 "$INIT_UNBLOCK" || chmod +x "$INIT_UNBLOCK"
    echo "✅ Установлен скрипт автоматического заполнения множества unblock"

    # =============================================================================
    # УСТАНОВКА ВЕБ-ИНТЕРФЕЙСА (вместо Telegram-бота)
    # =============================================================================
    echo "=== Установка веб-интерфейса ==="

    # Создание директории веб-интерфейса
    mkdir -p "$WEB_DIR"
    mkdir -p "$WEB_DIR/core"

    # Загрузка основных файлов веб-интерфейса
    echo "Загрузка файлов веб-интерфейса..."
    curl -s -o "$WEB_DIR/app.py" "$WEB_URL/app.py" || exit 1
    curl -s -o "$WEB_DIR/routes.py" "$WEB_URL/routes.py" || exit 1
    curl -s -o "$WEB_DIR/env_parser.py" "$WEB_URL/env_parser.py" || exit 1
    curl -s -o "$WEB_DIR/requirements.txt" "$WEB_URL/requirements.txt" || exit 1
    curl -s -o "$WEB_DIR/version.md" "$WEB_URL/version.md" || exit 1
    curl -s -o "$WEB_DIR/.env.example" "$WEB_URL/.env.example" || echo "⚠️ Не удалось загрузить .env.example"

    # Загрузка core модулей
    echo "Загрузка core модулей..."
    curl -s -o "$WEB_DIR/core/config.py" "$BASE_URL/src/core/config.py" || exit 1
    curl -s -o "$WEB_DIR/core/utils.py" "$BASE_URL/src/core/utils.py" || exit 1
    curl -s -o "$WEB_DIR/core/services.py" "$BASE_URL/src/core/services.py" || exit 1
    curl -s -o "$WEB_DIR/core/ipset_manager.py" "$BASE_URL/src/core/ipset_manager.py" || exit 1
    curl -s -o "$WEB_DIR/core/list_catalog.py" "$BASE_URL/src/core/list_catalog.py" || exit 1
    curl -s -o "$WEB_DIR/core/dns_manager.py" "$BASE_URL/src/core/dns_manager.py" || exit 1
    curl -s -o "$WEB_DIR/core/app_config.py" "$BASE_URL/src/core/app_config.py" || exit 1
    curl -s -o "$WEB_DIR/core/__init__.py" "$BASE_URL/src/core/__init__.py" || exit 1

    # Создание web_config.py (генерация из шаблона)
    echo "Создание конфигурации веб-интерфейса..."
    cat > "$WEB_DIR/core/web_config.py" << EOF
# =============================================================================
# WEB CONFIGURATION
# Auto-generated by script.sh during installation
# =============================================================================

base_url = "$BASE_URL"
routerip = "$lanip"

localportsh = $localportsh
dnsporttor = $dnsporttor
localporttor = $localporttor
localportvless = $localportvless
localporttrojan = $localporttrojan
dnsovertlsport = $dnsovertlsport
dnsoverhttpsport = $dnsoverhttpsport

unblock_dir = "$UNBLOCK_DIR"
tor_config = "$TOR_CONFIG"
shadowsocks_config = "$SHADOWSOCKS_CONFIG"
trojan_config = "$TROJAN_CONFIG"
vless_config = "$VLESS_CONFIG"
templates_dir = "$TEMPLATES_DIR"
dnsmasq_conf = "$DNSMASQ_CONF"
crontab = "$CRONTAB"
redirect_script = "$REDIRECT_SCRIPT"
vpn_script = "$VPN_SCRIPT"
ipset_script = "$IPSET_SCRIPT"
unblock_ipset = "$UNBLOCK_IPSET"
unblock_dnsmasq = "$UNBLOCK_DNSMASQ"
unblock_update = "$UNBLOCK_UPDATE"
script_sh = "$SCRIPT_BU"
web_dir = "$WEB_DIR"
tor_tmp_dir = "$TOR_TMP_DIR"
tor_dir = "$TOR_DIR"
xray_dir = "$XRAY_DIR"
trojan_dir = "$TROJAN_DIR"
init_shadowsocks = "$INIT_SHADOWSOCKS"
init_trojan = "$INIT_TROJAN"
init_xray = "$INIT_XRAY"
init_tor = "$INIT_TOR"
init_dnsmasq = "$INIT_DNSMASQ"
init_unblock = "$INIT_UNBLOCK"
init_web = "$INIT_WEB"
hosts_file = "$HOSTS_FILE"
EOF

    # Установка прав
    chmod 755 "$WEB_DIR"
    chmod 644 "$WEB_DIR"/*.py
    chmod 644 "$WEB_DIR/core"/*.py

    echo "✅ Файлы веб-интерфейса загружены"

    # Установка скрипта автозапуска веб-интерфейса
    echo "Установка скрипта автозапуска..."
    cat > "$INIT_WEB" << 'EOF'
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
  *)
    echo "Usage: $0 {start|stop|restart}"
    exit 1
    ;;
esac
EOF
    chmod 755 "$INIT_WEB"
    echo "✅ Скрипт автозапуска установлен"

    # Установка дополнительных файлов
    echo "Загрузка дополнительных файлов..."
    curl -s -o "$TEMPLATES_DIR/tor_template.torrc" "$BASE_URL/tor_template.torrc" && echo "✅ Шаблон Tor загружен"
    curl -s -o "$INIT_UNBLOCK" "$WEB_URL/S99unblock" || exit 1
    chmod 755 "$INIT_UNBLOCK"
    echo "✅ Дополнительные файлы загружены"

    # Установка скрипта перенаправления
    curl -s -o "$REDIRECT_SCRIPT" "$BASE_URL/100-redirect.sh" || exit 1
    sed -i -e "s/hash:net/${set_type}/g" \
           -e "s/192.168.1.1/${lanip}/g" \
           -e "s/1082/${localportsh}/g" \
           -e "s/9141/${localporttor}/g" \
           -e "s/10810/${localportvless}/g" \
           -e "s/10829/${localporttrojan}/g" \
           "$REDIRECT_SCRIPT" && \
    chmod 755 "$REDIRECT_SCRIPT" || chmod +x "$REDIRECT_SCRIPT"
    echo "✅ Установлено перенаправление пакетов"

    # Установка VPN скрипта
    if [ "${keen_os_short}" = "4" ]; then
        echo "VPN для KeenOS 4+"
        curl -s -o "$VPN_SCRIPT" "$BASE_URL/100-unblock-vpn-v4.sh" || exit 1
    else
        echo "VPN для KeenOS 3"
        curl -s -o "$VPN_SCRIPT" "$BASE_URL/100-unblock-vpn.sh" || exit 1
    fi
    chmod 755 "$VPN_SCRIPT" || chmod +x "$VPN_SCRIPT"
    echo "✅ Установлен скрипт проверки подключения VPN"

    # Настройка dnsmasq и crontab
    rm -f "$DNSMASQ_CONF"
    curl -s -o "$DNSMASQ_CONF" "$BASE_URL/dnsmasq.conf" || exit 1
    sed -i -e "s/192.168.1.1/${lanip}/g" -e "s/40500/${dnsovertlsport}/g" -e "s/40508/${dnsoverhttpsport}/g" "$DNSMASQ_CONF" && \
    echo "✅ Подключен дополнительный конфигурационный файл к dnsmasq"

    rm -f "$CRONTAB"
    curl -s -o "$CRONTAB" "$BASE_URL/crontab" || exit 1
    echo "✅ Добавлены задачи в cron"

    "$UNBLOCK_UPDATE"

    # Установка скрипта для создания бэкапов
    mkdir -p "$KEENSNAP_DIR"
    curl -s -o "$SCRIPT_BU" "$BASE_URL/deploy/backup/keensnap/keensnap.sh" || exit 1
    chmod 755 "$SCRIPT_BU"
    echo "✅ Установлен скрипт для создания бэкапов"

    # Запуск веб-интерфейса
    echo "=== Запуск веб-интерфейса ==="
    "$INIT_WEB" start
    sleep 2

    # Проверка запуска
    if pgrep -f "python.*app.py" > /dev/null; then
        echo "✅ Веб-интерфейс запущен"
    else
        echo "⚠️ Не удалось запустить веб-интерфейс"
    fi

    echo ""
    echo "=== Установка завершена ==="
    echo "🌐 Откройте веб-интерфейс: http://${lanip}:8080"
    echo ""
    echo "Далее:"
    echo "1. Откройте http://${lanip}:8080 в браузере"
    echo "2. Введите пароль из /opt/etc/web_ui/.env.example"
    echo "3. Через меню \"🔑 Ключи и мосты\" добавьте ваши мосты Tor, ключи VLESS, Shadowsocks, Trojan"
    echo "4. Через меню \"📑 Списки обхода\" добавьте домены и IP-адреса для обхода"
    echo "5. Пройдите в меню \"⚙️ Сервис\" -> \"⁉️ DNS Override\" -> \"✅ ВКЛ\""
    echo ""
    exit 0
fi

# =============================================================================
# ОБНОВЛЕНИЕ (-update)
# =============================================================================
if [ "$1" = "-update" ]; then
    echo "=== Обновление bypass_keenetic ==="
    echo "ℹ️ Ваша версия KeenOS: ${keen_os_full}"

    opkg update > /dev/null 2>&1 && echo "✅ Пакеты обновлены"
    (opkg install webtunnel-client && echo "✅ Webtunnel-client установлен") || echo "ℹ️ Webtunnel-client не был установлен"

    # Обновление файлов веб-интерфейса
    echo "Обновление файлов веб-интерфейса..."
    curl -s -o "$WEB_DIR/app.py" "$WEB_URL/app.py" || exit 1
    curl -s -o "$WEB_DIR/routes.py" "$WEB_URL/routes.py" || exit 1
    curl -s -o "$WEB_DIR/env_parser.py" "$WEB_URL/env_parser.py" || exit 1
    curl -s -o "$WEB_DIR/requirements.txt" "$WEB_URL/requirements.txt" || exit 1
    curl -s -o "$WEB_DIR/version.md" "$WEB_URL/version.md" || exit 1

    echo "Обновление core модулей..."
    mkdir -p "$WEB_DIR/core"
    curl -s -o "$WEB_DIR/core/config.py" "$BASE_URL/src/core/config.py" || exit 1
    curl -s -o "$WEB_DIR/core/utils.py" "$BASE_URL/src/core/utils.py" || exit 1
    curl -s -o "$WEB_DIR/core/services.py" "$BASE_URL/src/core/services.py" || exit 1
    curl -s -o "$WEB_DIR/core/ipset_manager.py" "$BASE_URL/src/core/ipset_manager.py" || exit 1
    curl -s -o "$WEB_DIR/core/list_catalog.py" "$BASE_URL/src/core/list_catalog.py" || exit 1
    curl -s -o "$WEB_DIR/core/dns_manager.py" "$BASE_URL/src/core/dns_manager.py" || exit 1
    curl -s -o "$WEB_DIR/core/app_config.py" "$BASE_URL/src/core/app_config.py" || exit 1
    curl -s -o "$WEB_DIR/core/__init__.py" "$BASE_URL/src/core/__init__.py" || exit 1

    echo "Обновление init скриптов..."
    curl -s -o "$INIT_WEB" "$WEB_URL/S99web_ui" || exit 1
    curl -s -o "$INIT_UNBLOCK" "$WEB_URL/S99unblock" || exit 1

    echo "Обновление дополнительных файлов..."
    curl -s -o "$TEMPLATES_DIR/tor_template.torrc" "$BASE_URL/tor_template.torrc" && echo "✅ Шаблон Tor обновлён"
    curl -s -o "$SCRIPT_BU" "$BASE_URL/deploy/backup/keensnap/keensnap.sh" || echo "ℹ️ keensnap.sh не обновлён"
    curl -s -o "$REDIRECT_SCRIPT" "$BASE_URL/100-redirect.sh" || exit 1

    echo "Применение прав..."
    chmod 755 "$WEB_DIR"
    chmod 644 "$WEB_DIR"/*.py
    chmod 644 "$WEB_DIR/core"/*.py
    chmod 755 "$INIT_WEB"

    # Перезапуск веб-интерфейса
    web_old_version=$(cat "$WEB_DIR/version.md" 2>/dev/null || echo "unknown")
    curl -s "$WEB_URL/version.md" > "$WEB_DIR/version.md"
    web_new_version=$(cat "$WEB_DIR/version.md" 2>/dev/null || echo "unknown")

    echo "Версия веб-интерфейса: ${web_old_version} → ${web_new_version}"
    sleep 2

    echo "Перезапуск веб-интерфейса..."
    "$INIT_WEB" restart
    sleep 3

    if pgrep -f "python.*app.py" > /dev/null; then
        echo "✅ Веб-интерфейс перезапущен"
    else
        echo "⚠️ Не удалось перезапустить веб-интерфейс"
    fi

    echo "✅ Обновление выполнено"
    exit 0
fi

# =============================================================================
# ДИАГНОСТИКА (-var)
# =============================================================================
if [ "$1" = "-var" ]; then
    echo "=== Путь к конфигурации ==="
    echo "WEB_CONFIG: $WEB_CONFIG"
    echo ""
    echo "=== URL-адреса ==="
    echo "BASE_URL: $BASE_URL"
    echo "WEB_URL: $WEB_URL"
    echo ""
    echo "=== Версия прошивки ==="
    echo "KeenOS: ${keen_os_full}"
    echo "KeenOS (short): ${keen_os_short}"
    echo ""
    echo "=== IP и порты ==="
    echo "lanip: $lanip"
    echo "localportsh: $localportsh"
    echo "dnsporttor: $dnsporttor"
    echo "localporttor: $localporttor"
    echo "localportvless: $localportvless"
    echo "localporttrojan: $localporttrojan"
    echo "dnsovertlsport: $dnsovertlsport"
    echo "dnsoverhttpsport: $dnsoverhttpsport"
    echo ""
    echo "=== Пути ==="
    echo "UNBLOCK_DIR: $UNBLOCK_DIR"
    echo "WEB_DIR: $WEB_DIR"
    echo "TOR_CONFIG: $TOR_CONFIG"
    echo "SHADOWSOCKS_CONFIG: $SHADOWSOCKS_CONFIG"
    echo "TROJAN_CONFIG: $TROJAN_CONFIG"
    echo "VLESS_CONFIG: $VLESS_CONFIG"
    echo "TEMPLATES_DIR: $TEMPLATES_DIR"
    echo "DNSMASQ_CONF: $DNSMASQ_CONF"
    echo "CRONTAB: $CRONTAB"
    echo "REDIRECT_SCRIPT: $REDIRECT_SCRIPT"
    echo "VPN_SCRIPT: $VPN_SCRIPT"
    echo "IPSET_SCRIPT: $IPSET_SCRIPT"
    echo "UNBLOCK_IPSET: $UNBLOCK_IPSET"
    echo "UNBLOCK_DNSMASQ: $UNBLOCK_DNSMASQ"
    echo "UNBLOCK_UPDATE: $UNBLOCK_UPDATE"
    echo "KEENSNAP_DIR: $KEENSNAP_DIR"
    echo "SCRIPT_BU: $SCRIPT_BU"
    echo "TOR_TMP_DIR: $TOR_TMP_DIR"
    echo "TOR_DIR: $TOR_DIR"
    echo "XRAY_DIR: $XRAY_DIR"
    echo "TROJAN_DIR: $TROJAN_DIR"
    echo "INIT_SHADOWSOCKS: $INIT_SHADOWSOCKS"
    echo "INIT_TROJAN: $INIT_TROJAN"
    echo "INIT_XRAY: $INIT_XRAY"
    echo "INIT_TOR: $INIT_TOR"
    echo "INIT_DNSMASQ: $INIT_DNSMASQ"
    echo "INIT_UNBLOCK: $INIT_UNBLOCK"
    echo "INIT_WEB: $INIT_WEB"
    echo "HOSTS_FILE: $HOSTS_FILE"
    echo ""
    echo "=== Пакеты ==="
    echo "PACKAGES: $PACKAGES"
fi

# =============================================================================
# СПРАВКА (-help)
# =============================================================================
if [ "$1" = "-help" ]; then
    echo "Доступные аргументы:"
    echo "  -install  - установка bypass_keenetic и веб-интерфейса"
    echo "  -remove   - удаление bypass_keenetic и веб-интерфейса"
    echo "  -update   - обновление веб-интерфейса"
    echo "  -var      - показать переменные конфигурации"
    echo "  -help     - показать эту справку"
fi

if [ -z "$1" ]; then
    echo "-help - показать список доступных аргументов"
fi
