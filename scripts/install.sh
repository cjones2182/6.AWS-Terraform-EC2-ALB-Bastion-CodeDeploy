#!/bin/bash

dnf update -y
dnf install httpd mariadb105-server -y
systemctl enable --now httpd
systemctl enable --now mariadb105-server -y

dnf install php php-intl php-mbstring php-apcu php-curl php-mysql php-xml -y

cd /tmp

wget -O wget https://releases.wikimedia.org/mediawiki/1.46/mediawiki-1.46.2.tar.gz

tar -xzvf /tmp/mediawiki-1.46.2.tar.gz -C /var/www/html

mv /var/www/html/mediawiki-1.46.2 /var/www/html/wiki

chown -R apache:apache /var/www/html/wiki
chmod -R 770 /var/www/html/wiki