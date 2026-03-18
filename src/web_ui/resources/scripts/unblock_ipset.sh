#!/bin/sh
# unblock_ipset.sh - Заполнение IPSET с DNS разрешением
# Копия из работающего архива (адаптированная для nslookup)

mkdir -p /opt/var/log
LOGFILE="/opt/var/log/unblock_ipset.log"
echo "=== $(date '+%Y-%m-%d %H:%M:%S') ===" >> "$LOGFILE"

cut_local() {
	grep -vE 'localhost|^0\.|^127\.|^10\.|^172\.16\.|^192\.168\.|^::|^fc..:|^fd..:|^fe..:'
}

# Проверка DNS
until nslookup google.com 8.8.8.8 >/dev/null 2>&1; do sleep 5; done

while read -r line || [ -n "$line" ]; do

  [ -z "$line" ] && continue
  [ "${line#?}" = "#" ] && continue

  cidr=$(echo "$line" | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}' | cut_local)

  if [ -n "$cidr" ]; then
    ipset -exist add unblocksh "$cidr"
    continue
  fi

  range=$(echo "$line" | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}-[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | cut_local)

  if [ -n "$range" ]; then
    ipset -exist add unblocksh "$range"
    continue
  fi

  addr=$(echo "$line" | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | cut_local)

  if [ -n "$addr" ]; then
    ipset -exist add unblocksh "$addr"
    continue
  fi

  # DNS разрешение домена через nslookup
  nslookup "$line" 8.8.8.8 2>/dev/null | \
    grep -v '8\.8\.8\.8' | \
    grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | \
    while read -r ip; do
      ipset -exist add unblocksh "$ip"
    done

done < /opt/etc/unblock/shadowsocks.txt


while read -r line || [ -n "$line" ]; do

  [ -z "$line" ] && continue
  [ "${line#?}" = "#" ] && continue

  cidr=$(echo "$line" | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}' | cut_local)

  if [ -n "$cidr" ]; then
    ipset -exist add unblocktor "$cidr"
    continue
  fi

  range=$(echo "$line" | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}-[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | cut_local)

  if [ -n "$range" ]; then
    ipset -exist add unblocktor "$range"
    continue
  fi

  addr=$(echo "$line" | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | cut_local)

  if [ -n "$addr" ]; then
    ipset -exist add unblocktor "$addr"
    continue
  fi

  nslookup "$line" 8.8.8.8 2>/dev/null | \
    grep -v '8\.8\.8\.8' | \
    grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | \
    while read -r ip; do
      ipset -exist add unblocktor "$ip"
    done

done < /opt/etc/unblock/tor.txt


while read -r line || [ -n "$line" ]; do

  [ -z "$line" ] && continue
  [ "${line#?}" = "#" ] && continue

  cidr=$(echo "$line" | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}' | cut_local)

  if [ -n "$cidr" ]; then
    ipset -exist add unblockvless "$cidr"
    continue
  fi

  range=$(echo "$line" | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}-[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | cut_local)

  if [ -n "$range" ]; then
    ipset -exist add unblockvless "$range"
    continue
  fi

  addr=$(echo "$line" | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | cut_local)

  if [ -n "$addr" ]; then
    ipset -exist add unblockvless "$addr"
    continue
  fi

  nslookup "$line" 8.8.8.8 2>/dev/null | \
    grep -v '8\.8\.8\.8' | \
    grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | \
    while read -r ip; do
      ipset -exist add unblockvless "$ip"
    done

done < /opt/etc/unblock/vless.txt


while read -r line || [ -n "$line" ]; do

  [ -z "$line" ] && continue
  [ "${line#?}" = "#" ] && continue

  cidr=$(echo "$line" | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}' | cut_local)

  if [ -n "$cidr" ]; then
    ipset -exist add unblocktroj "$cidr"
    continue
  fi

  range=$(echo "$line" | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}-[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | cut_local)

  if [ -n "$range" ]; then
    ipset -exist add unblocktroj "$range"
    continue
  fi

  addr=$(echo "$line" | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | cut_local)

  if [ -n "$addr" ]; then
    ipset -exist add unblocktroj "$addr"
    continue
  fi

  nslookup "$line" 8.8.8.8 2>/dev/null | \
    grep -v '8\.8\.8\.8' | \
    grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | \
    while read -r ip; do
      ipset -exist add unblocktroj "$ip"
    done

done < /opt/etc/unblock/trojan.txt

if ls -d /opt/etc/unblock/vpn-*.txt >/dev/null 2>&1; then
for vpn_file_names in /opt/etc/unblock/vpn-*; do
  vpn_file_name=$(echo "$vpn_file_names" | awk -F '/' '{print $5}' | sed 's/.txt//')
  unblockvpn=$(echo unblock"$vpn_file_name")
  cat "$vpn_file_names" | while read -r line || [ -n "$line" ]; do
    [ -z "$line" ] && continue
    [ "${line#?}" = "#" ] && continue

    cidr=$(echo "$line" | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}' | cut_local)

    if [ -n "$cidr" ]; then
      ipset -exist add "$unblockvpn" "$cidr"
      continue
    fi

    range=$(echo "$line" | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}-[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | cut_local)

    if [ -n "$range" ]; then
      ipset -exist add "$unblockvpn" "$range"
      continue
    fi

    addr=$(echo "$line" | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | cut_local)

    if [ -n "$addr" ]; then
      ipset -exist add "$unblockvpn" "$addr"
      continue
    fi

    nslookup "$line" 8.8.8.8 2>/dev/null | \
      grep -v '8\.8\.8\.8' | \
      grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | \
      while read -r ip; do
        ipset -exist add "$unblockvpn" "$ip"
      done
  done
done
fi

echo "✅ IPSET заполнен"
ipset list unblocksh | wc -l

echo "Final counts:" >> "$LOGFILE"
for name in unblocksh unblocktor unblockvless unblocktroj; do
    cnt=$(ipset list "$name" 2>/dev/null | grep -c "^[0-9]" || echo 0)
    echo "  $name: $cnt" >> "$LOGFILE"
done
