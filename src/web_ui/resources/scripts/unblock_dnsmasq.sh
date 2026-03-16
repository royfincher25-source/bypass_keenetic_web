#!/bin/sh

until dig +short google.com @localhost -p 40500 | grep -q .; do
  sleep 5
done

process_file() {
  input_file="$1"
  ipset_name="$2"
  support_wildcard="$3"

  if [ ! -f "$input_file" ]; then
    return
  fi

  sort -u "$input_file" | while read -r line || [ -n "$line" ]; do
    [ -z "$line" ] && continue
    [ "${line#?}" = "#" ] && continue
    echo "$line" | grep -Eq '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' && continue

    if [ "$support_wildcard" = "1" ] && echo "${line}" | grep -q '\*'; then
      host=$(echo "${line}" | sed 's/\*//;')
      echo "ipset=/*.${host}/${ipset_name}" >> /opt/etc/unblock.dnsmasq
      echo "server=/*.${host}/127.0.0.1#40500" >> /opt/etc/unblock.dnsmasq
      echo "ipset=/${host}/${ipset_name}" >> /opt/etc/unblock.dnsmasq
      echo "server=/${host}/127.0.0.1#40500" >> /opt/etc/unblock.dnsmasq
    else
      echo "ipset=/$line/${ipset_name}" >> /opt/etc/unblock.dnsmasq
      echo "server=/$line/127.0.0.1#40500" >> /opt/etc/unblock.dnsmasq
    fi
  done
}

cat /dev/null > /opt/etc/unblock.dnsmasq

process_file /opt/etc/unblock/shadowsocks.txt unblocksh 1
process_file /opt/etc/unblock/tor.txt unblocktor 1
process_file /opt/etc/unblock/vless.txt unblockvless 0
process_file /opt/etc/unblock/trojan.txt unblocktroj 0

if ls -d /opt/etc/unblock/vpn-*.txt >/dev/null 2>&1; then
  for vpn_file_names in /opt/etc/unblock/vpn-*; do
    vpn_file_name=$(echo "$vpn_file_names" | awk -F '/' '{print $5}' | sed 's/.txt//')
    unblockvpn=$(echo unblock"$vpn_file_name")
    process_file "$vpn_file_names" "$unblockvpn" 0
  done
fi
