#!/bin/sh
# =============================================================================
# БЫСТРЫЙ СКРИПТ ЗАПОЛНЕНИЯ IPSET (v3.5.4)
# =============================================================================
# Оптимизации:
# - Параллелизм через & (фон) вместо xargs -P (BusyBox не поддерживает -P)
# - nslookup вместо dig (быстрее на Entware)
# - Пакетная загрузка в ipset через restore -!
# - Проверка пустых списков
# =============================================================================

TAG="unblock_ipset"
DNS_SERVER="8.8.8.8"
MAX_PARALLEL=20

cut_local() {
    grep -vE '^0\.|^127\.|^10\.|^172\.16\.|^192\.168\.|^::1$'
}

resolve_one() {
    domain="$1"
    outfile="$2"
    nslookup "$domain" "$DNS_SERVER" 2>/dev/null | \
        grep -i 'address' | \
        grep -v '8\.8\.8\.8' | \
        sed 's/.*Address [0-9]*: //' | \
        grep -E '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' >> "$outfile"
}

process_list() {
    ipset_name="$1"
    list_file="$2"
    tmpips="/tmp/ipset_${ipset_name}_$$.ips"

    if [ ! -f "$list_file" ]; then
        echo "⚠️ Нет файла: $list_file"
        return 1
    fi

    ipset create "$ipset_name" hash:net family inet hashsize 4096 maxelem 65536 -exist 2>/dev/null
    ipset flush "$ipset_name" 2>/dev/null

    : > "$tmpips"

    count=0
    pids=""
    while read -r domain; do
        [ -z "$domain" ] && continue
        resolve_one "$domain" "$tmpips" &
        pids="$pids $!"
        count=$((count + 1))

        if [ $count -ge $MAX_PARALLEL ]; then
            for pid in $pids; do
                wait $pid 2>/dev/null
            done
            pids=""
            count=0
        fi
    done << EOF
$(grep -vE '^#|^[0-9]|^$' "$list_file" 2>/dev/null)
EOF

    for pid in $pids; do
        wait $pid 2>/dev/null
    done

    grep -E '^[0-9]' "$list_file" 2>/dev/null | cut_local >> "$tmpips"

    ip_count=$(sort -u "$tmpips" | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | wc -l)
    sort -u "$tmpips" | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | cut_local | \
        sed "s/^/add $ipset_name /" | ipset restore -! 2>/dev/null

    echo "✅ $ipset_name: $ip_count IP"
    rm -f "$tmpips"
}

# =============================================================================
# ОСНОВНАЯ ЧАСТЬ
# =============================================================================

START_TIME=$(date +%s)
echo "🚀 Запуск (параллельно: $MAX_PARALLEL, nslookup)"

process_list "unblocksh" "/opt/etc/unblock/shadowsocks.txt"
process_list "unblocktor" "/opt/etc/unblock/tor.txt"
process_list "unblockvless" "/opt/etc/unblock/vless.txt"
process_list "unblocktroj" "/opt/etc/unblock/trojan.txt"

for vpn_file in /opt/etc/unblock/vpn-*.txt; do
    [ -f "$vpn_file" ] || continue
    vpn_name=$(basename "$vpn_file" .txt)
    ipset_name="unblock${vpn_name#vpn-}"
    process_list "$ipset_name" "$vpn_file"
done

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""
echo "✅ Завершено за ${DURATION}c"
echo "📊 Статистика:"
for ipset in unblocksh unblocktor unblockvless unblocktroj; do
    if ipset list "$ipset" -n 2>/dev/null | grep -q "^$ipset$"; then
        count=$(ipset list "$ipset" 2>/dev/null | grep -c "^[0-9]")
        echo "  $ipset: $count IP"
    else
        echo "  $ipset: 0 IP"
    fi
done
