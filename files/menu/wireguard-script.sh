#!/bin/bash

source /etc/wireguard/params

function add-user() {
	endpoint="${ip}:51820"

	clear
	echo -e ""
	echo -e "Add WireGuard User"
	echo -e "------------------"
	read -p "Username : " user
	if grep -qw "^### Client ${user}\$" /etc/wireguard/wg0.conf; then
		echo -e ""
		echo -e "User '$user' already exist."
		echo -e ""
		exit 0
	fi
	read -p "Duration (day) : " duration
	exp=$(date -d +${duration}days +%Y-%m-%d)
	expired=$(date -d "${exp}" +"%d %b %Y")

	for dot_ip in {2..254}; do
		dot_exists=$(grep -c "10.66.66.${dot_ip}" /etc/wireguard/wg0.conf)
		if [[ ${dot_exists} == '0' ]]; then
			break
		fi
	done
	if [[ ${dot_exists} == '1' ]]; then
		echo -e ""
		echo -e "The subnet configured only supports 253 clients."
		echo -e ""
		exit 1
	fi

	client_ipv4="10.66.66.${dot_ip}"
	client_priv_key=$(wg genkey)
	client_pub_key=$(echo "${client_priv_key}" | wg pubkey)
	client_pre_shared_key=$(wg genpsk)

	echo -e "$user\t$exp" >> /voidvpn/wireguard/wireguard-clients.txt
	echo -e "[Interface]
PrivateKey = ${client_priv_key}
Address = ${client_ipv4}/32
DNS = 8.8.8.8,8.8.4.4

[Peer]
PublicKey = ${server_pub_key}
PresharedKey = ${client_pre_shared_key}
Endpoint = ${endpoint}
AllowedIPs = 0.0.0.0/0" >> /voidvpn/wireguard/${user}.conf
	echo -e "\n### Client ${user}
[Peer]
PublicKey = ${client_pub_key}
PresharedKey = ${client_pre_shared_key}
AllowedIPs = ${client_ipv4}/32" >> /etc/wireguard/wg0.conf
	systemctl daemon-reload
	systemctl restart wg-quick@wg0

	clear
	echo -e ""
	echo -e "WireGuard User Information"
	echo -e "--------------------------"
	echo -e "Username : $user"
	echo -e "Expired date : $expired"
	echo -e ""
}

function delete-user(){
	clear
	echo -e ""
	echo -e "Delete WireGuard User"
	echo -e "---------------------"
	read -p "Username : " user
	if grep -qw "^### Client ${user}\$" /etc/wireguard/wg0.conf; then
		sed -i "/^### Client ${user}\$/,/^$/d" /etc/wireguard/wg0.conf
		if grep -q "### Client" /etc/wireguard/wg0.conf; then
			line=$(grep -n AllowedIPs /etc/wireguard/wg0.conf | tail -1 | awk -F: '{print $1}')
			head -${line} /etc/wireguard/wg0.conf > /tmp/wg0.conf
			mv /tmp/wg0.conf /etc/wireguard/wg0.conf
		else
			head -6 /etc/wireguard/wg0.conf > /tmp/wg0.conf
			mv /tmp/wg0.conf /etc/wireguard/wg0.conf
		fi
		rm -f /voidvpn/wireguard/${user}.conf
		sed -i "/\b$user\b/d" /voidvpn/wireguard/wireguard-clients.txt
		systemctl daemon-reload
		systemctl restart wg-quick@wg0
		echo -e ""
		echo -e "User '$user' deleted successfully."
		echo -e ""
	else
		echo -e ""
		echo -e "User '$user' does not exist."
		echo -e ""
		exit 0
	fi
}

function extend-user() {
	clear
	echo -e ""
	echo -e "Extend WireGuard User"
	echo -e "---------------------"
	read -p "Username : " user
	if ! grep -qw "$user" /voidvpn/wireguard/wireguard-clients.txt; then
		echo -e ""
		echo -e "User '$user' does not exist."
		echo -e ""
		exit 0
	fi
	read -p "Duration (day) : " extend

	exp_old=$(cat /voidvpn/wireguard/wireguard-clients.txt | grep -w $user | awk '{print $2}')
	diff=$((($(date -d "${exp_old}" +%s)-$(date +%s))/(86400)))
	duration=$(expr $diff + $extend + 1)
	exp_new=$(date -d +${duration}days +%Y-%m-%d)
	exp=$(date -d "${exp_new}" +"%d %b %Y")

	sed -i "/\b$user\b/d" /voidvpn/wireguard/wireguard-clients.txt
	echo -e "$user\t$exp_new" >> /voidvpn/wireguard/wireguard-clients.txt

	clear
	echo -e ""
	echo -e "WireGuard User Information"
	echo -e "--------------------------"
	echo -e "Username : $user"
	echo -e "Expired date : $exp"
	echo -e ""
}

function user-list() {
	clear
	echo -e ""
	echo -e "==============================="
	echo -e "Username          Exp. Date"
	echo -e "-------------------------------"
	while read expired
	do
		user=$(echo $expired | awk '{print $1}')
		exp=$(echo $expired | awk '{print $2}')
		exp_date=$(date -d"${exp}" "+%d %b %Y")
		printf "%-17s %2s\n" "$user" "$exp_date"
	done < /voidvpn/wireguard/wireguard-clients.txt
	total=$(wc -l /voidvpn/wireguard/wireguard-clients.txt | awk '{print $1}')
	echo -e "-------------------------------"
	echo -e "Total accounts: $total"
	echo -e "==============================="
	echo -e ""
}

function show-config() {
	clear
	echo -e ""
	echo -e "WireGuard Config"
	echo -e "----------------"
	read -p "User : " user
	if grep -qw "^### Client ${user}\$" /etc/wireguard/wg0.conf; then
		exp=$(cat /voidvpn/wireguard/wireguard-clients.txt | grep -w "$user" | awk '{print $2}')
		exp_date=$(date -d"${exp}" "+%d %b %Y")
		echo -e "Expired : $exp_date"
		echo -e ""
		echo -e "QR Code"
		echo -e "-------"
		qrencode -t ansiutf8 -l L < /voidvpn/wireguard/${user}.conf
		echo -e ""
		echo -e "Config"
		echo -e "------"
		cat /voidvpn/wireguard/${user}.conf
		echo -e ""
	else
		echo -e ""
		echo -e "User '$user' does not exist."
		echo -e ""
		exit 0
	fi
}

clear
echo -e ""
echo -e "==========[ WireGuard Menu ]=========="
echo -e ""
echo -e "  [1]  Add WireGuard user"
echo -e "  [2]  Delete WireGuard user"
echo -e "  [3]  Extend WireGuard user"
echo -e "  [4]  WireGuard user list"
echo -e "  [5]  Show WireGuard configuration"
echo -e ""
echo -e "  [x]  Exit"
echo -e ""
until [[ ${option} -ge 1 ]] && [[ ${option} -le 5 ]] || [[ ${option} == 'x' ]]; do
	read -rp "Select an option [1-5 or x]: " option
done
case "${option}" in
1)
	add-user
	;;
2)
	delete-user
	;;
3)
	extend-user
	;;
4)
	user-list
	;;
5)
	clear
	show-config
	;;
x)
	clear
	exit 0
	;;
esac