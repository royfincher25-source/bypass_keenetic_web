#!/bin/sh
# unblock_dnsmasq.sh - Optimized version with parallel generation

mkdir -p /opt/var/log
LOGFILE="/opt/var/log/unblock_dnsmasq.log"
echo "=== $(date '+%Y-%m-%d %H:%M:%S') ===" >> "$LOGFILE"

# Clear dnsmasq config
cat /dev/null > /opt/etc/unblock.dnsmasq

# Function to generate config for a single file
generate_config() {
    local file="$1"
    local setname="$2"
    local temp_config="$3"
    
    if [ ! -f "$file" ]; then
        echo "Warning: $file not found" >> "$LOGFILE"
        return
    fi
    
    # Process file, skipping comments and empty lines
    while read -r line || [ -n "$line" ]; do
        [ -z "$line" ] && continue
        [ "${line#?}" = "#" ] && continue
        
        # Skip IP addresses (only process domains)
        if echo "$line" | grep -Eq '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}'; then
            continue
        fi
        
        # Handle wildcard domains (keep as is, dnsmasq ignores leading dots)
        echo "ipset=/$line/$setname" >> "$temp_config"
        echo "server=/$line/127.0.0.1#40500" >> "$temp_config"
    done < "$file"
}

# Define files to process
files=(
    "/opt/etc/unblock/shadowsocks.txt:unblocksh"
    "/opt/etc/unblock/tor.txt:unblocktor"
    "/opt/etc/unblock/vless.txt:unblockvless"
    "/opt/etc/unblock/trojan.txt:unblocktroj"
)

# Add VPN files
for vpn_file in /opt/etc/unblock/vpn-*.txt; do
    if [ -f "$vpn_file" ]; then
        vpn_name=$(basename "$vpn_file" .txt)
        files+=("$vpn_file:unblock$vpn_name")
    fi
done

# Process files in parallel
temp_dir="/tmp/dnsmasq_config_$$"
mkdir -p "$temp_dir"

i=0
for entry in "${files[@]}"; do
    file=$(echo "$entry" | cut -d: -f1)
    setname=$(echo "$entry" | cut -d: -f2)
    
    temp_config="$temp_dir/config_$i.txt"
    > "$temp_config"
    
    # Run in background
    generate_config "$file" "$setname" "$temp_config" &
    i=$((i + 1))
done

# Wait for all background jobs
wait

# Combine all configs
cat "$temp_dir"/config_*.txt >> /opt/etc/unblock.dnsmasq

# Cleanup
rm -rf "$temp_dir"

# Restart dnsmasq
/opt/etc/init.d/S56dnsmasq restart >> "$LOGFILE" 2>&1

echo "✅ Dnsmasq config generated" | tee -a "$LOGFILE"