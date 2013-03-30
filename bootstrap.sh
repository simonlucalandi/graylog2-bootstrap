#!/bin/bash -eu

release_src=https://github.com/downloads/Graylog2
graylog2_server=graylog2-server-0.11.0.tar.gz
graylog2_web_interface=graylog2-web-interface-0.11.0.tar.gz
graylog2_base=/var/graylog2
graylog2_collection_size=650000000

sudo apt-get install -y python-software-properties
sudo add-apt-repository 'deb http://downloads.mongodb.org/distros/ubuntu 10.4 10gen'
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv 7F0CEB10
sudo apt-get update

env='DEBIAN_FRONTEND=noninteractive'
for pkg in wget build-essential make rrdtool openjdk-6-jre ruby1.8 rubygems rake libopenssl-ruby libmysqlclient-dev ruby-dev libapache2-mod-passenger postfix mongodb-stable mysql-server
do
  sudo $env apt-get install -y $pkg
done

sudo mkdir -pv $graylog2_base/src

cd $graylog2_base/src

sudo wget --no-check-certificate $release_src/graylog2-server/$graylog2_server -O $graylog2_server
sudo tar -xvf $graylog2_server
folder=`echo $graylog2_server | sed 's/.tar.gz//'`
sudo ln -sf $graylog2_base/src/$folder $graylog2_base/server

sudo wget --no-check-certificate $release_src/graylog2-web-interface/$graylog2_web_interface -O $graylog2_web_interface
sudo tar -xvf $graylog2_web_interface
folder=`echo $graylog2_web_interface | sed 's/.tar.gz//'`
sudo ln -sf $graylog2_base/src/$folder $graylog2_base/web

sudo gem install rubygems-update
sudo /var/lib/gems/1.8/bin/update_rubygems
sudo gem install bundler

cd $graylog2_base/server

sudo mv -f graylog2.conf.example graylog2.conf
sudo sed -e "s/mongodb_useauth = true/mongodb_useauth = false/" -i graylog2.conf
sudo sed -e "s/messages_collection_size = 50000000/messages_collection_size = $graylog2_collection_size/" -i graylog2.conf
sudo ln -sf $graylog2_base/server/graylog2.conf /etc/graylog2.conf

cd bin && sudo ./graylog2ctl start

cd $graylog2_base/web

sudo bundle install

sudo sed -e "s/password: yourpass/password:/" -i config/database.yml
fqdn=`hostname --fqdn`
sudo sed -e "s/external_hostname: \"your-graylog2.example.org\"/external_hostname: \"$fqdn\"/" -i config/general.yml

sudo chown -R nobody:nogroup $graylog2_base

env='RAILS_ENV=production'
sudo -u nobody rake db:create $env
sudo -u nobody rake db:migrate $env

cd /etc/apache2

echo "
<VirtualHost *:80>
  DocumentRoot $graylog2_base/web/public
  <Directory $graylog2_base/web/public>
    Allow from all
    Options -MultiViews
  </Directory>
  ErrorLog /var/log/apache2/error.log
  LogLevel warn
  CustomLog /var/log/apache2/access.log combined
</VirtualHost>
" | sudo tee sites-available/graylog2

sudo a2ensite graylog2
sudo a2dissite default

sudo sed -e "s/APACHE_RUN_USER=www-data/APACHE_RUN_USER=nobody/" -i envvars
sudo sed -e "s/APACHE_RUN_GROUP=www-data/APACHE_RUN_GROUP=nogroup/" -i envvars

sudo /etc/init.d/apache2 restart

exit 0
