#! /bin/bash
sudo apt install -y vsftpd
sudo systemctl enable vsftpd
sudo systemctl stop vsftpd
sudo mv /etc/vsftpd.conf vsftpd.conf.default
sudo cp /home/ubuntu/vsftpd.conf /etc/vsftpd.conf
sudo systemctl restart vsftpd
sudo adduser ftpuser
echo "ftpuser:admin" | sudo chpasswd
echo "ftpuser" | sudo tee -a /etc/vsftpd.user_list
sudo mkdir -p /home/ftpuser/ftp/incoming
sudo chmod 550 /home/ftpuser/ftp
sudo chmod 750 /home/ftpuser/ftp/incoming
sudo chown -R ftpuser:ftpuser /home/ftpuser/ftp
