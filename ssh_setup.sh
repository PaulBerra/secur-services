#!/bin/bash

# Variables
SSH_HARDENING_CONF="/etc/ssh/sshd_config.d/hardening.conf"
FAIL2BAN_JAIL_LOCAL="/etc/fail2ban/jail.local"
ALLOWED_IPS="127.0.0.1 192.168.1.0/24 10.10.0.0/16"
SSH_PORT="22"
BAN_TIME="180"
MAX_RETRY="3"

# Ensure the script is run as root
if [[ "$EUID" -ne 0 ]]; then
    printf "Please run this script as root or using sudo.\n" >&2
    exit 1
fi

# Update and install necessary packages
install_packages() {
    sudo apt update || { printf "apt update failed.\n" >&2; return 1; }
    sudo apt install -y openssh-server fail2ban ufw || { printf "Package installation failed.\n" >&2; return 1; }
}

# Enable and start SSH service
configure_ssh() {
    sudo systemctl start ssh || { printf "Failed to start ssh service.\n" >&2; return 1; }
    sudo systemctl enable ssh || { printf "Failed to enable ssh service.\n" >&2; return 1; }
}

# Harden SSH configuration
harden_ssh() {
    sudo touch "$SSH_HARDENING_CONF" || { printf "Failed to create SSH hardening config.\n" >&2; return 1; }
    printf "PermitRootLogin no\nPubkeyAuthentication yes\n" | sudo tee "$SSH_HARDENING_CONF" > /dev/null || { printf "Failed to write SSH hardening config.\n" >&2; return 1; }
    sudo systemctl reload ssh || { printf "Failed to reload ssh service.\n" >&2; return 1; }
}

# Enable and configure UFW
configure_ufw() {
    sudo ufw enable || { printf "Failed to enable UFW.\n" >&2; return 1; }
    sudo ufw allow "$SSH_PORT/tcp" || { printf "Failed to allow SSH through UFW.\n" >&2; return 1; }
    sudo ufw reload || { printf "Failed to reload UFW.\n" >&2; return 1; }
}

# Configure Fail2Ban
configure_fail2ban() {
    sudo systemctl stop fail2ban || { printf "Failed to stop Fail2Ban.\n" >&2; return 1; }

    sudo bash -c "cat > $FAIL2BAN_JAIL_LOCAL <<EOL
[DEFAULT]
bantime = $BAN_TIME
maxretry = $MAX_RETRY
ignoreip = $ALLOWED_IPS

[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s

[apache-auth]
enabled = true
port = http,https
logpath = %(apache_error_log)s

[nginx-http-auth]
enabled = true
port = http,https
logpath = %(nginx_error_log)s

[vsftpd]
enabled = true
port = ftp,ftp-data,ftps,ftps-data
logpath = /var/log/vsftpd.log

[postfix]
enabled = true
port = smtp,ssmtp
logpath = /var/log/mail.log

[dovecot]
enabled = true
port = pop3,pop3s,imap,imaps,submission,submissions
logpath = /var/log/mail.log

[mysqld-auth]
enabled = true
port = 3306
logpath = /var/log/mysql/error.log
EOL" || { printf "Failed to write Fail2Ban configuration.\n" >&2; return 1; }

    sudo systemctl enable fail2ban || { printf "Failed to enable Fail2Ban.\n" >&2; return 1; }
    sudo systemctl start fail2ban || { printf "Failed to start Fail2Ban.\n" >&2; return 1; }
}

# Start Fail2Ban and jails
start_fail2ban_jails() {
    sudo fail2ban-client reload || { printf "Failed to reload Fail2Ban.\n" >&2; return 1; }
    sudo fail2ban-client start sshd || { printf "Failed to start sshd jail.\n" >&2; return 1; }
    sudo fail2ban-client start apache-auth || { printf "Failed to start apache-auth jail.\n" >&2; return 1; }
    sudo fail2ban-client start nginx-http-auth || { printf "Failed to start nginx-http-auth jail.\n" >&2; return 1; }
    sudo fail2ban-client start vsftpd || { printf "Failed to start vsftpd jail.\n" >&2; return 1; }
    sudo fail2ban-client start postfix || { printf "Failed to start postfix jail.\n" >&2; return 1; }
    sudo fail2ban-client start dovecot || { printf "Failed to start dovecot jail.\n" >&2; return 1; }
    sudo fail2ban-client start mysqld-auth || { printf "Failed to start mysqld-auth jail.\n" >&2; return 1; }
}

# Main function
main() {
    install_packages
    configure_ssh
    harden_ssh
    configure_ufw
    configure_fail2ban
    start_fail2ban_jails
}

# Execute main function
main
