#!/bin/bash
localnet="192.168.11.1/24"
localhost="127.0.0.1/32"

#Vypnuti ICMP broadcasts
echo 1 > /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts

#Vypnuti zdrojoveho smerovani
echo 0 > /proc/sys/net/ipv4/conf/all/accept_source_route
echo 0 > /proc/sys/net/ipv4/conf/all/send_redirects
echo 0 > /proc/sys/net/ipv4/conf/all/accept_redirects
echo 1 > /proc/sys/net/ipv4/icmp_ignore_bogus_error_responses

#Zapnuti routovani
echo 1 > /proc/sys/net/ipv4/ip_forward

#Martani
echo 1 > /proc/sys/net/ipv4/conf/all/log_martians

#Vymaz vsech pravidel
iptables -F
iptables -F -t filter
iptables -F -t nat
iptables -F -t mangle
iptables -X

#Zakladni politiky netfilteru
iptables -P INPUT DROP
iptables -P OUTPUT ACCEPT
iptables -P FORWARD DROP

iptables -A OUTPUT -p tcp --sport 22 -j ACCEPT
iptables -A INPUT -p tcp --sport 22 -j ACCEPT

#Prichozi NAT
iptables -A PREROUTING -t nat -p tcp -i eth0 --dport 22 -j DNAT --to-destination 192.168.11.13:22

#Odchozi NAT
iptables -A POSTROUTING -t nat -o eth0 -j MASQUERADE

#Pravidlo pro localhost
iptables -A INPUT -i lo -s $localhost -j ACCEPT

#Prichozi komunikace, ktera konci na tomto pocitaci
iptables -N icmp_in
iptables -N tcp_in
iptables -N udp_in

#ICMP
iptables -A icmp_in -p icmp --icmp-type 0 -j ACCEPT
iptables -A icmp_in -p icmp --icmp-type 3 -j ACCEPT
iptables -A icmp_in -p icmp --icmp-type 5 -j ACCEPT
iptables -A icmp_in -p icmp --icmp-type 8 -j ACCEPT
iptables -A icmp_in -p icmp --icmp-type 11 -j ACCEPT
iptables -A icmp_in -p icmp -j DROP

#UDP
iptables -A udp_in -p udp --dport 53 -j ACCEPT
iptables -A udp_in -p udp -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A udp_in -p udp -j DROP

#TCP
iptables -A tcp_in -p tcp -j DROP

#Trideni paketu
iptables -A INPUT -p icmp -j icmp_in
iptables -A INPUT -p udp -j udp_in
iptables -A INPUT -p tcp -j tcp_in

#Komunikace prochazejici pres tento pocitac z verejne site do vnitrni a obracene

#Prichozi komunikace, ktera konci na tomto pocitaci
iptables -N icmp_fw_in
iptables -N tcp_fw_in
iptables -N udp_fw_in

#ICMP
iptables -A icmp_fw_in -p icmp --icmp-type 0 -j ACCEPT
iptables -A icmp_fw_in -p icmp --icmp-type 3 -j ACCEPT
iptables -A icmp_fw_in -p icmp --icmp-type 5 -j ACCEPT
iptables -A icmp_fw_in -p icmp --icmp-type 8 -j ACCEPT
iptables -A icmp_fw_in -p icmp --icmp-type 11 -j ACCEPT
iptables -A icmp_fw_in -p icmp -j DROP

#UDP
iptables -A udp_fw_in -p udp -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A udp_fw_in -p udp --dport 53 -j ACCEPT
iptables -A udp_fw_in -p udp -j DROP

#TCP
iptables -A tcp_fw_in -p tcp -i eth0 -d 192.168.11.13 --dport 22 -j ACCEPT
iptables -A tcp_fw_in -p tcp -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A tcp_fw_in -p tcp -j DROP

#Trideni paketu
iptables -A FORWARD -p icmp -i eth0 -o eth1 ! -s $localnet -d $localnet -j icmp_fw_in
iptables -A FORWARD -p udp -i eth0 -o eth1 ! -s $localnet -d $localnet -j udp_fw_in
iptables -A FORWARD -p tcp -i eth0 -o eth1 ! -s $localnet -d $localnet -j tcp_fw_in

iptables -A FORWARD -p all -i eth1 -o eth0 -s $localnet ! -d $localnet -j ACCEPT
