#!/bin/sh

[ "$type" = "ip6tables" ] && exit 0
[ "$table" != "mangle" ] && [ "$table" != "nat" ] && exit 0

ip4t() {
    if ! iptables -C "$@" &>/dev/null; then
        iptables -A "$@" || exit 0
    fi
}

local_ip=$(ip -4 addr show br0 | awk '/inet /{print $2}' | cut -d/ -f1 | grep -E '^(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.)' | head -n1)

RULES=$(iptables-save 2>/dev/null)
IPSETS=$(ipset list -n 2>/dev/null)

for protocol in udp tcp; do
    if [ -z "$(echo "$RULES" | grep "$protocol --dport 53 -j DNAT")" ]; then
        iptables -I PREROUTING -w -t nat -p "$protocol" --dport 53 -j DNAT --to "$local_ip"
    fi
done

add_redirect() {
    name="$1"
    port="$2"

    if echo "$IPSETS" | grep -q "^${name}$"; then
        [ -z "$(echo "$RULES" | grep "$name")" ] || return 0
    else
        ipset create "$name" hash:net -exist 2>/dev/null
    fi

    iptables -I PREROUTING -w -t nat -p tcp -m set --match-set "$name" dst -j REDIRECT --to-port "$port"
    iptables -I PREROUTING -w -t nat -p udp -m set --match-set "$name" dst -j REDIRECT --to-port "$port"
}

add_redirect unblocksh 1082
add_redirect unblocktor 9141
add_redirect unblockvless 10810
add_redirect unblocktroj 10829

TAG="100-redirect.sh"

if ls -d /opt/etc/unblock/vpn-*.txt >/dev/null 2>&1; then
    for vpn_file_name in /opt/etc/unblock/vpn*; do
        vpn_unblock_name=$(echo $vpn_file_name | awk -F '/' '{print $5}' | sed 's/.txt//')
        unblockvpn=$(echo unblock"$vpn_unblock_name")

        vpn_type=$(echo "$unblockvpn" | sed 's/-/ /g' | awk '{print $NF}')
        vpn_link_up=$(curl -s localhost:79/rci/show/interface/"$vpn_type"/link | tr -d '"')
        if [ "$vpn_link_up" = "up" ]; then
            vpn_type_lower=$(echo "$vpn_type" | tr [:upper:] [:lower:])
            get_vpn_fwmark_id=$(grep "$vpn_type_lower" /opt/etc/iproute2/rt_tables | awk '{print $1}')

            if [ -n "${get_vpn_fwmark_id}" ]; then
                vpn_table_id=$get_vpn_fwmark_id
            else
                break
            fi
            vpn_mark_id=$(echo 0xd"$vpn_table_id")

            if echo "$RULES" | grep -q "$unblockvpn"; then
                vpn_rule_ok=$(echo Правила для "$unblockvpn" уже есть.)
                echo "$vpn_rule_ok"
            else
                info_vpn_rule=$(echo ipset: "$unblockvpn", mark_id: "$vpn_mark_id")
                logger -t "$TAG" "$info_vpn_rule"

                ipset create "$unblockvpn" hash:net -exist 2>/dev/null

                fastnat=$(curl -s localhost:79/rci/show/version | grep ppe)
                software=$(curl -s localhost:79/rci/show/rc/p lobes | grep software -C1  | head -1 | awk '{print $2}' | tr -d ",")
                hardware=$(curl -s localhost:79/rci/show/rc/ppe | grep hardware -C1  | head -1 | awk '{print $2}' | tr -d ",")
                if [ -z "$fastnat" ] && [ "$software" = "false" ] && [ "$hardware" = "false" ]; then
                    info=$(echo "VPN: fastnat, swnat и hwnat ВЫКЛЮЧЕНЫ, правила добавлены")
                    logger -t "$TAG" "$info"
                    iptables -A PREROUTING -w -t mangle -p tcp -m set --match-set "$unblockvpn" dst -j MARK --set-mark "$vpn_mark_id"
                    iptables -A PREROUTING -w -t mangle -p udp -m set --match-set "$unblockvpn" dst -j MARK --set-mark "$vpn_mark_id"
                else
                    info=$(echo "VPN: fastnat, swnat и hwnat ВКЛЮЧЕНЫ, правила добавлены")
                    logger -t "$TAG" "$info"
                    iptables -A PREROUTING -w -t mangle -m conntrack --ctstate NEW -m set --match-set "$unblockvpn" dst -j CONNMARK --set-mark "$vpn_mark_id"
                    iptables -A PREROUTING -w -t mangle -j CONNMARK --restore-mark
                fi
            fi
        fi
    done
fi

exit 0
