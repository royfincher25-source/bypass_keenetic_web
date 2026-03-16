#!/bin/sh

# Путь к конфигу
BOT_CONFIG="/opt/etc/bot/bot_config.py"
if [ ! -f "$BOT_CONFIG" ]; then
    echo "❌ Ошибка: Файл конфигурации $BOT_CONFIG не найден!" >&2
    exit 1
fi

# Чтение URL
BASE_URL=$(grep "^base_url" "$BOT_CONFIG" | awk -F'"' '{print $2}')
BOT_URL="$BASE_URL/src/bot3"

# Чтение IP и портов
lanip=$(grep "routerip" "$BOT_CONFIG" | awk -F"'" '{print $2}')
localportsh=$(grep "localportsh" "$BOT_CONFIG" | awk -F'=' '{print $2}' | awk '{print $1}')
dnsporttor=$(grep "dnsporttor" "$BOT_CONFIG" | awk -F'=' '{print $2}' | awk '{print $1}')
localporttor=$(grep "localporttor" "$BOT_CONFIG" | awk -F'=' '{print $2}' | awk '{print $1}')
localportvless=$(grep "localportvless" "$BOT_CONFIG" | awk -F'=' '{print $2}' | awk '{print $1}')
localporttrojan=$(grep "localporttrojan" "$BOT_CONFIG" | awk -F'=' '{print $2}' | awk '{print $1}')
dnsovertlsport=$(grep "dnsovertlsport" "$BOT_CONFIG" | awk -F'=' '{print $2}' | awk '{print $1}')
dnsoverhttpsport=$(grep "dnsoverhttpsport" "$BOT_CONFIG" | awk -F'=' '{print $2}' | awk '{print $1}')

# Чтение версии прошивки
if [ -f /proc/version ]; then
    keen_os_full=$(cat /proc/version | awk '{print $3}')
    keen_os_short=$(echo "$keen_os_full" | cut -d'.' -f1)
else
    echo "❌ Ошибка: файл /proc/version не найден. Не удалось получить версию ОС"
    exit 1
fi

# Функция для чтения путей из конфига
read_path() {
    sed -n "/\"$1\":/s/.*\": *\"\([^\"]*\)\".*/\1/p" "$BOT_CONFIG"
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
BOT_DIR=$(read_path "bot_dir")
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
INIT_BOT=$(read_path "init_bot")
HOSTS_FILE=$(read_path "hosts_file")

# Чтение пакетов
installed_packages=$(opkg list-installed | awk '{print $1}')
PACKAGES=$(awk '/^packages = \[/,/\]/ {
    if ($0 ~ /".*"/) {
        gsub(/^[[:space:]]*"|".*$/, "")
        printf "%s ", $0
    }
}' "$BOT_CONFIG")

if [ "$1" = "-remove" ]; then

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
    ipset flush unblocktor
    ipset flush unblocksh
    ipset flush unblockvless
    ipset flush unblocktroj
	
    if ls -d "${UNBLOCK_DIR}vpn-"*.txt >/dev/null 2>&1; then
        for vpn_file_names in "${UNBLOCK_DIR}vpn-"*; do
            vpn_file_name=$(echo "$vpn_file_names" | awk -F '/' '{print $5}' | sed 's/.txt//')
            unblockvpn=$(echo unblock"$vpn_file_name")
            ipset flush "$unblockvpn"
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
    echo "Созданные папки, файлы и настройки удалены"
    echo "Для отключения DNS Override перейдите в меню \"⚙️ Сервис\" -> \"⁉️ DNS Override\" -> \"✖️ ВЫКЛ\". После чего включится встроенный (штатный) DNS и роутер перезагрузится"
    exit 0
fi


if [ "$1" = "-install" ]; then
    echo "ℹ️ Ваша версия KeenOS" "${keen_os_full}"
    
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
    echo "Установка пакетов завершена. Продолжаем установку"

    # Проверяем есть ли поддержка множества hash:net
    set_type=$(ipset --help 2>/dev/null | grep -q "hash:net" && echo "hash:net" || echo "hash:ip")
    [ "$set_type" = "hash:net" ] && echo "☑️ Поддержка множества типа hash:net есть" || echo "❕Поддержка множества типа hash:net отсутствует"
    
    # Установка скрипта для маршрутизации с помощью ipset
    curl -s -o "$IPSET_SCRIPT" "$BASE_URL/100-ipset.sh" || exit 1
    sed -i "s/hash:net/${set_type}/g" "$IPSET_SCRIPT" && \
    chmod 755 "$IPSET_SCRIPT" || chmod +x "$IPSET_SCRIPT"
    "$IPSET_SCRIPT" start
    echo "Созданы файлы под множества"

    # Создание директории и шаблонов конфигов
    mkdir -p "$TEMPLATES_DIR"
    for template in tor_template.torrc vless_template.json trojan_template.json shadowsocks_template.json; do
        curl -s -o "$TEMPLATES_DIR/$template" "$BASE_URL/$template"
    done
    echo "Загружены темплейты конфигураций для Tor, Shadowsocks, Vless, Trojan"

    # Установка конфигов из шаблонов
    mkdir -p "$TOR_TMP_DIR"
    cp "$TEMPLATES_DIR/tor_template.torrc" "$TOR_CONFIG" && \
    echo "Установлены базовые настройки Tor"

    cp "$TEMPLATES_DIR/shadowsocks_template.json" "$SHADOWSOCKS_CONFIG" && \
    sed -i "s/ss-local/ss-redir/g" "$INIT_SHADOWSOCKS" && \
    echo "Установлены базовые настройки Shadowsocks"

    cp "$TEMPLATES_DIR/trojan_template.json" "$TROJAN_CONFIG" && \
    echo "Установлены базовые настройки Trojan"

    cp "$TEMPLATES_DIR/vless_template.json" "$VLESS_CONFIG" && \
    sed -i "s|ARGS=\"run -confdir $XRAY_DIR\"|ARGS=\"run -c $XRAY_DIR/config.json\"|" "$INIT_XRAY" > /dev/null && \
    echo "Установлены базовые настройки Xray"

    # Создание unblock папки и файлов
    mkdir -p "$UNBLOCK_DIR"
    # если не нужны списки с git строки ниже можно закомментировать, если нужны - оставить
    curl -s -o "${UNBLOCK_DIR}vless.txt" "$BASE_URL/deploy/lists/unblockvless.txt"
    curl -s -o "${UNBLOCK_DIR}tor.txt" "$BASE_URL/deploy/lists/unblocktor.txt"
    # Создание пустых файлов если их нет, команда touch не изменит содержимое файлов, если они есть, изменится только метка времени
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
    echo "Созданы файлы под домены и ip-адреса"

    # Установка скриптов для заполнения множеств unblock, для формирования конфигурации dnsmasq, скрипт обновления системы после редактирования списка доменов
    curl -s -o "$UNBLOCK_IPSET" "$BASE_URL/unblock_ipset.sh" || exit 1
    sed -i "s/40500/${dnsovertlsport}/g" "$UNBLOCK_IPSET" && \
    chmod 755 "$UNBLOCK_IPSET" || chmod +x "$UNBLOCK_IPSET"
    echo "Установлен скрипт для заполнения множеств unblock IP-адресами заданного списка доменов"

    curl -s -o "$UNBLOCK_DNSMASQ" "$BASE_URL/unblock_dnsmasq.sh" || exit 1
    sed -i "s/40500/${dnsovertlsport}/g" "$UNBLOCK_DNSMASQ" && \
    chmod 755 "$UNBLOCK_DNSMASQ" || chmod +x "$UNBLOCK_DNSMASQ"
    "$UNBLOCK_DNSMASQ"
    echo "Установлен скрипт для формирования дополнительного конфигурационного файла dnsmasq из заданного списка доменов и его запуск"

    curl -s -o "$UNBLOCK_UPDATE" "$BASE_URL/unblock_update.sh" || exit 1
    chmod 755 "$UNBLOCK_UPDATE" || chmod +x "$UNBLOCK_UPDATE"
    echo "Установлен скрипт ручного принудительного обновления системы после редактирования списка доменов"

    # Установка скриптов инициализации
    curl -s -o "$INIT_UNBLOCK" "$BOT_URL/S99unblock" || exit 1
    chmod 755 "$INIT_UNBLOCK" || chmod +x "$INIT_UNBLOCK"
    echo "Установлен cкрипт автоматического заполнения множества unblock при загрузке маршрутизатора"

    curl -s -o "$INIT_BOT" "$BOT_URL/S99telegram_bot" || exit 1
    chmod 755 "$INIT_BOT" || chmod +x "$INIT_BOT"
    echo "Установлен cкрипт автоматического запуска бота при загрузке маршрутизатора"

    # ✅ Создание директорий (критично если директории не существуют!)
    mkdir -p "$BOT_DIR"
    mkdir -p "$BOT_DIR/core"
    mkdir -p "$TEMPLATES_DIR"
    mkdir -p "$KEENSNAP_DIR"
    echo "✅ Директории созданы"

    # ✅ Установка основных файлов бота (критично для запуска!)
    echo "Загрузка файлов бота..."
    curl -s -o "$BOT_DIR/main.py" "$BOT_URL/main.py" || exit 1
    curl -s -o "$BOT_DIR/handlers.py" "$BOT_URL/handlers.py" || exit 1
    curl -s -o "$BOT_DIR/menu.py" "$BOT_URL/menu.py" || exit 1
    curl -s -o "$BOT_DIR/utils.py" "$BOT_URL/utils.py" || exit 1
    curl -s -o "$BOT_DIR/bot_config.py" "$BOT_URL/bot_config.py" || exit 1
    curl -s -o "$BOT_DIR/version.md" "$BOT_URL/version.md" || exit 1
    curl -s -o "$BOT_DIR/.env.example" "$BASE_URL/.env.example" || echo "⚠️ Не удалось загрузить .env.example"
    echo "✅ Основные файлы бота загружены"

    # ✅ Установка core модулей
    echo "Загрузка core модулей..."
    mkdir -p "$BOT_DIR/core"
    curl -s -o "$BOT_DIR/core/config.py" "$BASE_URL/src/core/config.py" || exit 1
    curl -s -o "$BOT_DIR/core/env_parser.py" "$BASE_URL/src/core/env_parser.py" || exit 1
    curl -s -o "$BOT_DIR/core/http_client.py" "$BASE_URL/src/core/http_client.py" || exit 1
    curl -s -o "$BOT_DIR/core/logging.py" "$BASE_URL/src/core/logging.py" || exit 1
    curl -s -o "$BOT_DIR/core/logging_async.py" "$BASE_URL/src/core/logging_async.py" || exit 1
    curl -s -o "$BOT_DIR/core/parsers.py" "$BASE_URL/src/core/parsers.py" || exit 1
    curl -s -o "$BOT_DIR/core/services.py" "$BASE_URL/src/core/services.py" || exit 1
    curl -s -o "$BOT_DIR/core/validators.py" "$BASE_URL/src/core/validators.py" || exit 1
    curl -s -o "$BOT_DIR/core/backup.py" "$BASE_URL/src/core/backup.py" || exit 1
    curl -s -o "$BOT_DIR/core/handlers_shared.py" "$BASE_URL/src/core/handlers_shared.py" || exit 1
    curl -s -o "$BOT_DIR/core/__init__.py" "$BASE_URL/src/core/__init__.py" || exit 1
    echo "✅ Core модули загружены"

    # Установка прав на файлы бота
    chmod 755 "$BOT_DIR"
    chmod 644 "$BOT_DIR"/*.py
    chmod 755 "$BOT_DIR"/S99*
    echo "✅ Права на файлы установлены"

    # ✅ Обновление дополнительных файлов (для consistency с -update)
    echo "Загрузка дополнительных файлов..."
    curl -s -o "$TEMPLATES_DIR/tor_template.torrc" "$BASE_URL/tor_template.torrc" && echo "✅ Шаблон Tor загружен"
    curl -s -o "$BOT_DIR/S99unblock" "$BOT_URL/S99unblock" || exit 1
    chmod 755 "$BOT_DIR/S99unblock"
    echo "✅ Дополнительные файлы загружены"

    # Установка скрипта перенаправления (с настройкой переменных)
    curl -s -o "$REDIRECT_SCRIPT" "$BASE_URL/100-redirect.sh" || exit 1
    sed -i -e "s/hash:net/${set_type}/g" \
           -e "s/192.168.1.1/${lanip}/g" \
           -e "s/1082/${localportsh}/g" \
           -e "s/9141/${localporttor}/g" \
           -e "s/10810/${localportvless}/g" \
           -e "s/10829/${localporttrojan}/g" \
           "$REDIRECT_SCRIPT" && \
    chmod 755 "$REDIRECT_SCRIPT" || chmod +x "$REDIRECT_SCRIPT"
    echo "Установлено перенаправление пакетов с адресатами из unblock в Tor, Shadowsocks, VPN, Trojan, Vless"

    # Установка VPN скрипта
    if [ "${keen_os_short}" = "4" ]; then
        echo "VPN для KeenOS 4+"
        curl -s -o "$VPN_SCRIPT" "$BASE_URL/100-unblock-vpn-v4.sh" || exit 1
    else
        echo "VPN для KeenOS 3"
        curl -s -o "$VPN_SCRIPT" "$BASE_URL/100-unblock-vpn.sh" || exit 1
    fi
    chmod 755 "$VPN_SCRIPT" || chmod +x "$VPN_SCRIPT"
    echo "Установлен скрипт проверки подключения и остановки VPN"

    # Настройка dnsmasq и crontab
    rm -f "$DNSMASQ_CONF"
    curl -s -o "$DNSMASQ_CONF" "$BASE_URL/dnsmasq.conf" || exit 1
    sed -i -e "s/192.168.1.1/${lanip}/g" -e "s/40500/${dnsovertlsport}/g" -e "s/40508/${dnsoverhttpsport}/g" "$DNSMASQ_CONF" && \
    echo "Подключен дополнительный конфигурационный файл к dnsmasq"

    rm -f "$CRONTAB"
    curl -s -o "$CRONTAB" "$BASE_URL/crontab" || exit 1
    echo "Добавлены задачи в cron для периодического обновления содержимого множества"
    
    "$UNBLOCK_UPDATE"

    # Установка скрипта для создания бекапов через telegram
    mkdir -p "$KEENSNAP_DIR"
    curl -s -o "$SCRIPT_BU" "$BASE_URL/deploy/backup/keensnap/keensnap.sh" || exit 1
    chmod 755 "$SCRIPT_BU"
    echo "Установлен скрипт для создания бекапов через telegram"
    
    echo "Выполнена основная настройка бота"
    curl -s "$BOT_URL/version.md" > "$BOT_DIR/version.md"
    echo "Через меню \"🔑 Ключи и мосты\" добавьте ваши мосты Tor, ключи Vless, Shadowsocks, Trojan"
    echo "Через меню \"📑 Списки обхода\" добавьте домены и IP-адреса для обхода"
    echo "Далее пройдите в меню \"⚙️ Сервис\" -> \"⁉️ DNS Override\" -> \"✅ ВКЛ\". После чего выключится встроенный (штатный) DNS и роутер перезагрузится"
    exit 0
fi


if [ "$1" = "-update" ]; then
    echo "ℹ️ Ваша версия KeenOS" "${keen_os_full}"
    opkg update > /dev/null 2>&1 && echo "Пакеты обновлены"
	(opkg install webtunnel-client && echo "Webtunnel-client установлен") || echo "Webtunnel-client не был установлен"
    
    #"$INIT_SHADOWSOCKS" stop > /dev/null 2>&1
    #"$INIT_XRAY" stop > /dev/null 2>&1
    #"$INIT_TROJAN" stop > /dev/null 2>&1
    #"$INIT_TOR" stop > /dev/null 2>&1
    #echo "S35 tor остановлен"
	
    # Что нужно обновить
    echo "Обновление основных файлов бота..."
    curl -s -o "$BOT_DIR/main.py" "$BOT_URL/main.py" || exit 1
    curl -s -o "$BOT_DIR/utils.py" "$BOT_URL/utils.py" || exit 1
    curl -s -o "$BOT_DIR/menu.py" "$BOT_URL/menu.py" || exit 1
    curl -s -o "$BOT_DIR/handlers.py" "$BOT_URL/handlers.py" || exit 1
    curl -s -o "$BOT_DIR/bot_config.py" "$BOT_URL/bot_config.py" || exit 1
    curl -s -o "$BOT_DIR/version.md" "$BOT_URL/version.md" || exit 1
    
    echo "Обновление core модулей..."
    mkdir -p "$BOT_DIR/core"
    curl -s -o "$BOT_DIR/core/config.py" "$BASE_URL/src/core/config.py" || exit 1
    curl -s -o "$BOT_DIR/core/env_parser.py" "$BASE_URL/src/core/env_parser.py" || exit 1
    curl -s -o "$BOT_DIR/core/http_client.py" "$BASE_URL/src/core/http_client.py" || exit 1
    curl -s -o "$BOT_DIR/core/logging.py" "$BASE_URL/src/core/logging.py" || exit 1
    curl -s -o "$BOT_DIR/core/logging_async.py" "$BASE_URL/src/core/logging_async.py" || exit 1
    curl -s -o "$BOT_DIR/core/parsers.py" "$BASE_URL/src/core/parsers.py" || exit 1
    curl -s -o "$BOT_DIR/core/services.py" "$BASE_URL/src/core/services.py" || exit 1
    curl -s -o "$BOT_DIR/core/validators.py" "$BASE_URL/src/core/validators.py" || exit 1
    curl -s -o "$BOT_DIR/core/backup.py" "$BASE_URL/src/core/backup.py" || exit 1
    curl -s -o "$BOT_DIR/core/handlers_shared.py" "$BASE_URL/src/core/handlers_shared.py" || exit 1
    curl -s -o "$BOT_DIR/core/__init__.py" "$BASE_URL/src/core/__init__.py" || exit 1
    
    echo "Обновление init скриптов..."
    curl -s -o "$INIT_BOT" "$BOT_URL/S99telegram_bot" || exit 1
    curl -s -o "$BOT_DIR/S99unblock" "$BOT_URL/S99unblock" || exit 1
    
    echo "Обновление дополнительных файлов..."
    curl -s -o "$TEMPLATES_DIR/tor_template.torrc" "$BASE_URL/tor_template.torrc" && echo "Шаблон Tor обновлен"
    curl -s -o "$SCRIPT_BU" "$BASE_URL/deploy/backup/keensnap/keensnap.sh" || echo "keensnap.sh не обновлён"
    curl -s -o "$REDIRECT_SCRIPT" "$BASE_URL/100-redirect.sh" || exit 1
    
    echo "Обновления для бота загружены, применяем права"
    chmod 755 "$BOT_DIR"
    chmod 644 "$BOT_DIR"/*.py
    chmod 755 "$BOT_DIR"/S99*
    chmod 755 "$SCRIPT_BU"

    #"$INIT_DNSMASQ" restart > /dev/null 2>&1 || echo "❌ Ошибка при перезапуске dnsmasq"
    #"$INIT_SHADOWSOCKS" start > /dev/null 2>&1 || echo "❕S22shadowsocks не запущен, проверьте конфигурацию"
    #"$INIT_XRAY" start > /dev/null 2>&1 || echo "❕S24xray не запущен, проверьте конфигурацию"
    #"$INIT_TROJAN" start > /dev/null 2>&1 || echo "❕S22trojan не запущен, проверьте конфигурацию"
    #"$INIT_TOR" start > /dev/null 2>&1 || echo "❕S35tor не запущен, проверьте конфигурацию"

    bot_old_version=$(cat "$BOT_DIR/version.md")
    curl -s "$BOT_URL/version.md" > "$BOT_DIR/version.md"
    bot_new_version=$(cat "$BOT_DIR/version.md")
    echo "Версия бота \"${bot_old_version}\" обновлена до \"${bot_new_version}\""
    sleep 2
    echo "✅ Обновление выполнено"
    echo "Бот будет перезапущен, после запуска введите ключи Tor! Теперь поддерживаются obfs4 и webtunnel ключи!"
    sleep 2
    "$INIT_BOT" restart

    exit 0
fi


if [ "$1" = "-var" ]; then
    echo -e "\n=== Путь до bot_config.py ==="
    echo "BOT_CONFIG: $BOT_CONFIG"
    echo -e "\n=== URL-адреса для скачиваемых файлов ==="
    echo "BASE_URL: $BASE_URL"
    echo "BOT_URL: $BOT_URL"
    echo -e "\n=== Версия прошивки ==="
    echo "Ваша версия KeenOS" "${keen_os_full}"
    echo "Ваша версия KeenOS" "${keen_os_short}"
    echo -e "\n=== IP и порты ==="
    echo "lanip: $lanip"
    echo "localportsh: $localportsh"
    echo "dnsporttor: $dnsporttor"
    echo "localporttor: $localporttor"
    echo "localportvless: $localportvless"
    echo "localporttrojan: $localporttrojan"
    echo "dnsovertlsport: $dnsovertlsport"
    echo "dnsoverhttpsport: $dnsoverhttpsport"
    echo -e "\n=== Пути из paths ==="
    echo "UNBLOCK_DIR: $UNBLOCK_DIR"
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
    echo "BOT_DIR: $BOT_DIR"
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
    echo "INIT_BOT: $INIT_BOT"
    echo "HOSTS_FILE: $HOSTS_FILE"
    echo -e "\n=== Пакеты ==="
    echo "PACKAGES: $PACKAGES"
fi


if [ "$1" = "-help" ]; then
    echo "-install для установки"
    echo "-remove для удаления"
    echo "-update для обновления"
    echo "-var для проверки чтения переменных"
fi
if [ -z "$1" ]; then
    echo "-help посмотреть список доступных аргументов"
fi
