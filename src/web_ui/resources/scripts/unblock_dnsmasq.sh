#!/bin/sh
# unblock_dnsmasq.sh - Генерация правил для dnsmasq
# Упрощённая версия для стабильной работы

mkdir -p /opt/var/log
LOGFILE="/opt/var/log/unblock_dnsmasq.log"
echo "=== $(date '+%Y-%m-%d %H:%M:%S') ===" >> "$LOGFILE"

cat /dev/null > /opt/etc/unblock.dnsmasq

# Только для shadowsocks.txt
if [ ! -f "/opt/etc/unblock/shadowsocks.txt" ]; then
    echo "Warning: /opt/etc/unblock/shadowsocks.txt not found, skipping" >> "$LOGFILE"
else
while read -r line || [ -n "$line" ]; do
  [ -z "$line" ] && continue
  [ "${line#?}" = "#" ] && continue
  echo "$line" | grep -Eq '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' && continue

  # Обработка wildcard доменов (*.domain.com)
  if echo "$line" | grep -q '\*'; then
    # Заменяем "*." на "*" для wildcard доменов
    # *.googlevideo.com → *.googlevideo.com (оставляем как есть для ipset)
    # *.googlevideo.com → .googlevideo.com (для server)
    echo "ipset=/$line/unblocksh" >> /opt/etc/unblock.dnsmasq
    echo "server=/$line/127.0.0.1#40500" >> /opt/etc/unblock.dnsmasq
  else
    echo "ipset=/$line/unblocksh" >> /opt/etc/unblock.dnsmasq
    echo "server=/$line/127.0.0.1#40500" >> /opt/etc/unblock.dnsmasq
  fi
done < /opt/etc/unblock/shadowsocks.txt
fi

# Tor списки
if [ ! -f "/opt/etc/unblock/tor.txt" ]; then
    echo "Warning: /opt/etc/unblock/tor.txt not found, skipping" >> "$LOGFILE"
else
while read -r line || [ -n "$line" ]; do
  [ -z "$line" ] && continue
  [ "${line#?}" = "#" ] && continue
  echo "$line" | grep -Eq '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' && continue

  echo "ipset=/$line/unblocktor" >> /opt/etc/unblock.dnsmasq
  echo "server=/$line/127.0.0.1#40500" >> /opt/etc/unblock.dnsmasq
done < /opt/etc/unblock/tor.txt
fi

# VLESS списки
if [ ! -f "/opt/etc/unblock/vless.txt" ]; then
    echo "Warning: /opt/etc/unblock/vless.txt not found, skipping" >> "$LOGFILE"
else
while read -r line || [ -n "$line" ]; do
  [ -z "$line" ] && continue
  [ "${line#?}" = "#" ] && continue
  echo "$line" | grep -Eq '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' && continue

  echo "ipset=/$line/unblockvless" >> /opt/etc/unblock.dnsmasq
  echo "server=/$line/127.0.0.1#40500" >> /opt/etc/unblock.dnsmasq
done < /opt/etc/unblock/vless.txt
fi

# Trojan списки
if [ ! -f "/opt/etc/unblock/trojan.txt" ]; then
    echo "Warning: /opt/etc/unblock/trojan.txt not found, skipping" >> "$LOGFILE"
else
while read -r line || [ -n "$line" ]; do
  [ -z "$line" ] && continue
  [ "${line#?}" = "#" ] && continue
  echo "$line" | grep -Eq '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' && continue

  echo "ipset=/$line/unblocktroj" >> /opt/etc/unblock.dnsmasq
  echo "server=/$line/127.0.0.1#40500" >> /opt/etc/unblock.dnsmasq
done < /opt/etc/unblock/trojan.txt
fi

# VPN списки
if ls -d /opt/etc/unblock/vpn-*.txt >/dev/null 2>&1; then
  for vpn_file_names in /opt/etc/unblock/vpn-*; do
    vpn_file_name=$(echo "$vpn_file_names" | awk -F '/' '{print $5}' | sed 's/.txt//')
    unblockvpn=$(echo unblock"$vpn_file_name")
    cat "$vpn_file_names" | while read -r line || [ -n "$line" ]; do
      [ -z "$line" ] && continue
      [ "${line#?}" = "#" ] && continue
      echo "$line" | grep -Eq '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' && continue
      echo "ipset=/$line/$unblockvpn" >> /opt/etc/unblock.dnsmasq
      echo "server=/$line/127.0.0.1#40500" >> /opt/etc/unblock.dnsmasq
    done
  done
fi

# Перезапуск dnsmasq
/opt/etc/init.d/S56dnsmasq restart
