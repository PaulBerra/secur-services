# installation
sudo apt update
sudo apt install openssh-server fail2ban

# activation au démarrage
sudo systemctl start sshd
sudo systemctl enable sshd

# durcissement 
sudo touch /etc/ssh/sshd_config.d/hardening.conf
