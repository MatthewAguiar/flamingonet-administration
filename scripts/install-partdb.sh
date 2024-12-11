#!/bin/bash

#
# install-part-db.sh
#
# This script follows the steps on this page to install the Part-DB web app:
# https://docs.part-db.de/installation/installation_guide-debian.html
#
# Part-DB is an Open-Source inventory management system for electronic components
#

# Strict Mode - https://redsymbol.net/articles/unofficial-bash-strict-mode/
#
#   set -e           Causes script to immediately exit if any command's return status in non-zero
#   set -u           Causes script to immediately exit if a variable is referenced that is not defined
#   set -o pipefail  If an error happens in a pipeline, the return code is that of the failed command
#
set -euo pipefail

# Record where this script was called from so we can cd back to it anytime
script_dir=$(pwd)

# PartDB requires PHP but the Bookworm installation does not list it as
# a package so we download the package and install it manually
sudo curl -sSL https://packages.sury.org/php/README.txt | sudo bash -x

# Update the package registry and upgrade
sudo apt update && sudo apt upgrade -y

# For the installation of Part-DB, we need some prerequisites
sudo apt install -y git curl zip ca-certificates software-properties-common apt-transport-https lsb-release nano wget

# Install PHP 8.4 and the necessary packages
sudo apt install -y php8.4 libapache2-mod-php8.4 php8.4-opcache php8.4-curl php8.4-gd php8.4-mbstring php8.4-xml php8.4-bcmath php8.4-intl php8.4-zip php8.4-xsl php8.4-sqlite3 php8.4-mysql

#
# Part-DB uses composer to install required PHP libraries.
# As the version shipped in the repositories is pretty old, we will install it
# globally from source
#
wget -O /tmp/composer-setup.php https://getcomposer.org/installer
sudo php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer
sudo chmod +x /usr/local/bin/composer

# Install NodeJS as Part-DB uses yarn
curl -sL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt install -y nodejs

# Add yarn repository
curl -sL https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor | sudo tee /usr/share/keyrings/yarnkey.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/yarnkey.gpg] https://dl.yarnpkg.com/debian stable main" | sudo tee /etc/apt/sources.list.d/yarn.list

# Install yarn
sudo apt update && sudo apt install -y yarn

# Download Part-DB into the new folder /flamingonet/www/partdb
# Must use mv here so the current user is the owner of the repo
git clone https://github.com/Part-DB/Part-DB-symfony.git partdb
cd partdb
git checkout $(git describe --tags $(git rev-list --tags --max-count=1))
cd ..
sudo mkdir -p /flamingonet/www
sudo mv partdb /flamingonet/www
cd /flamingonet/www/partdb

# Make a copy of the .env file so we can configure Part-DB how we want it
# Set the owner to be www-data which is the apache user
sudo cp "$script_dir/../partdb/.env" .env.local
sudo chown -R www-data:www-data .

# Install Maria DB
sudo apt install -y mariadb-server

# Configure Maria DB
# Follow the directions here to get through this part because it is interactive
# https://docs.part-db.de/installation/installation_guide-debian.html#mysqlmariadb-database
echo -e "\nn\nn\ny\ny\ny\ny\n" | sudo mysql_secure_installation

# Then create the database and user
echo "CREATE DATABASE partdb;" | sudo mariadb || true
echo "GRANT ALL PRIVILEGES ON partdb.* TO 'partdb'@'127.0.0.1' IDENTIFIED BY 'Mypartdbaccount123^';" | sudo mariadb || true
echo "FLUSH PRIVILEGES;" | sudo mariadb || true

# Update the database schema with the following command
# Record the initial password
initial_password=$(sudo -u www-data php bin/console doctrine:migrations:migrate | grep "The initial password for the \"admin\" user is:")

# Putting this in brackets to catch any errors and still output the initial password
{

  # Install composer dependencies
  sudo -u www-data composer install --no-dev -o

  # Install yarn dependencies
  yarn install -y

  # Build frontend
  yarn build

  # To ensure everything is working, clear the cache:
  sudo -u www-data php bin/console cache:clear

  # Check if everything is installed, run the following command:
  sudo -u www-data php bin/console partdb:check-requirements

  # Copy the partdb.conf file to the sites-available directory to make it available for Apache
  cd "$script_dir"
  sudo cp -p ../partdb/partdb.conf /etc/apache2/sites-available/partdb.conf
  sudo ln -s /etc/apache2/sites-available/partdb.conf /etc/apache2/sites-enabled/partdb.conf
  sudo a2enmod rewrite

  # (Re)start the apache2 webserver with
  sudo service apache2 restart

  # Enable SSL for Part-DB
  # See last chapter of this video for SSL: https://www.youtube.com/watch?v=VXSgEvZKp-8
  # echo "Enabling SSL for Part-DB..."
  # echo -e "Please refer to the instructions here: https://www.youtube.com/watch?v=VXSgEvZKp-8\n"
  # sudo apt install -y certbot python3-certbot-apache
  # sudo certbot --apache -d flamingonet.io

  echo -e "\nSetup is complete!"
  echo $initial_password

} || {

  echo -e "\nAn error occured while setting up Part-DB, but the Database was created successfully."
  echo $initial_password

}
