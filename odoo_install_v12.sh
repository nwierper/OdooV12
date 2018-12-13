#!/bin/bash
############################################################################################
# Script for installing Odoo V11 on Ubuntu
# Author: Odoo Experts
#-------------------------------------------------------------------------------------------
# This script will install Odoo on your Ubuntu server.
# It can install multiple Odoo instances in one Ubuntu because of the different xmlrpc_ports
#-------------------------------------------------------------------------------------------
############################################################################################

##fixed parameters
#odoo
OE_USER="odooexp"
OE_FOLDER='odoo'
OE_HOME="/opt/$OE_FOLDER"
OE_HOME_EXT="/opt/$OE_FOLDER"
#The default port where this Odoo instance will run under (provided you use the command -c in the terminal)
#Set to true if you want to install it, false if you don't need it or have it already installed.
INSTALL_WKHTMLTOPDF="True"
#mkdir $OE_HOME
##
###  WKHTMLTOPDF download links
## === Ubuntu Trusty x64 & x32 === (for other distributions please replace these two links,
## in order to have correct version of wkhtmltox installed, for a danger note refer to
## https://www.odoo.com/documentation/8.0/setup/install.html#deb ):
WKHTMLTOX_X64=https://builds.wkhtmltopdf.org/0.12.1.3/wkhtmltox_0.12.1.3-1~bionic_amd64.deb
WKHTMLTOX_X32=https://downloads.wkhtmltopdf.org/0.12/0.12.1/wkhtmltox-0.12.1_linux-trusty-i386.deb

#Set the default Odoo port (you still have to use -c /etc/odoo-server.conf for example to use this.)
OE_PORT="8069"

#Choose the Odoo version which you want to install.
OE_VERSION="12.0"

#set the superadmin password
OE_SUPERADMIN="admin"
OE_CONFIG="${OE_FOLDER}-server"
echo -n "Would you like to install Enterprice (y/n)? "
read answer

cd /opt/
echo -e "\n==== Cloning Odoo Community ===="
git clone -b $OE_VERSION https://github.com/odoo/odoo.git $OE_FOLDER

case ${answer} in
    y|Y )
        cd $OE_HOME
        echo -e "\n==== Cloning ODOO Enterprise ===="
        git clone -b $OE_VERSION https://github.com/odoo/enterprise.git enterprise
    ;;
    * )
        echo ''
    ;;
esac

#--------------------------------------------------
# Update Server
#--------------------------------------------------
echo -e "\n---- Update Server ----"
sudo apt-get update
sudo apt-get upgrade -y

#--------------------------------------------------
# Install PostgreSQL Server
#--------------------------------------------------
echo -e "\n---- Install PostgreSQL Server ----"
sudo apt-get install postgresql -y

echo -e "\n Restarting Postgresql"
sudo service postgresql restart

echo -e "\n---- Creating the ODOO PostgreSQL User  ----"
sudo su - postgres -c "createuser -s $OE_USER" 2> /dev/null || true

#--------------------------------------------------
# Install Dependencies
#--------------------------------------------------
echo -e "\n---- Install tool packages ----"
sudo apt-get install wget git gdebi-core nginx unzip -y

echo -e "\n--- Installing Python 3 + pip3 --"
sudo apt-get install python3 python3-pip -y

sudo apt install build-essential python3-dev libxslt-dev libzip-dev libldap2-dev libsasl2-dev -y
sudo pip3 install --upgrade pip

pip3 install -r /opt/odoo/requirements.txt --ignore-installed

echo -e "\n---- Install python libraries ----"

#--------------------------------------------------
# Install Wkhtmltopdf if needed
#--------------------------------------------------
if [ $INSTALL_WKHTMLTOPDF = "True" ]; then
  echo -e "\n---- Install wkhtml and place shortcuts on correct place for ODOO 12 ----"
  #pick up correct one from x64 & x32 versions:
  if [ "`getconf LONG_BIT`" == "64" ];then
      _url=$WKHTMLTOX_X64
  else
      _url=$WKHTMLTOX_X32
  fi
  sudo wget $_url
  sudo gdebi --n `basename $_url` -n
  sudo ln -s /usr/local/bin/wkhtmltopdf /usr/bin
  sudo ln -s /usr/local/bin/wkhtmltoimage /usr/bin
else
  echo "Wkhtmltopdf isn't installed due to the choice of the user!"
fi

wget -O /tmp/pfbfer.zip  http://www.reportlab.com/ftp/fonts/pfbfer.zip
unzip /tmp/pfbfer.zip -d /tmp
mkdir /usr/local/lib/python3.6/dist-packages/reportlab/fonts/
cp /tmp/*.pfb /usr/local/lib/python3.6/dist-packages/reportlab/fonts/


chmod 777 $OE_HOME/odoo-bin
echo -e "\n---- Create ODOO system user ----"
sudo adduser --system --quiet --shell=/bin/bash --home=$OE_HOME --gecos 'ODOO' --group $OE_USER
#The user should also be added to the sudo'ers group.
sudo adduser $OE_USER sudo

echo -e "\n---- Create Log directory ----"
sudo mkdir /var/log/$OE_FOLDER
sudo chown $OE_USER:$OE_USER /var/log/$OE_FOLDER

cd /opt/server_install
#--------------------------------------------------
# Install Odoo
#--------------------------------------------------

echo -e "\n---- Setting permissions on home folder ----"
sudo chown -R $OE_USER:$OE_USER $OE_HOME/*

echo -e "* Create server config file"
sudo cp $OE_HOME_EXT/debian/odoo.conf /etc/${OE_CONFIG}.conf
sudo chown $OE_USER:$OE_USER /etc/${OE_CONFIG}.conf
sudo chmod 640 /etc/${OE_CONFIG}.conf

echo -e "* Change server config file"
sudo sed -i s/"db_user = .*"/"db_user = $OE_USER"/g /etc/${OE_CONFIG}.conf
sudo sed -i s/"; admin_passwd.*"/"admin_passwd = $OE_SUPERADMIN"/g /etc/${OE_CONFIG}.conf
sudo sed -i s/"proxy_mode = False"/"proxy_mode = True"/g /etc/${OE_CONFIG}.conf
sudo su root -c "echo 'logfile = /var/log/$OE_FOLDER/$OE_CONFIG$1.log' >> /etc/${OE_CONFIG}.conf"
case ${answer} in
    y|Y )
        sudo su root -c "echo 'addons_path=$OE_HOME/enterprise,$OE_HOME_EXT/addons' >> /etc/${OE_CONFIG}.conf"
    ;;
    * )
        sudo su root -c "echo 'addons_path=$OE_HOME_EXT/addons' >> /etc/${OE_CONFIG}.conf"
    ;;
esac

mkdir $OE_HOME/.local
chown $OE_USER:$OE_USER /home/$OE_USER/
chown $OE_USER:$OE_USER $OE_HOME/.local/
chown $OE_USER:$OE_USER /home/$OE_USER/.local/

mkdir $OE_HOME/custom
chown $OE_USER:$OE_USER $OE_HOME/custom

#echo -e "* Create startup file"
#sudo su root -c "echo '#!/bin/sh' >> $OE_HOME_EXT/start.sh"
#sudo su root -c "echo 'sudo -u $OE_USER $OE_HOME_EXT/odoo-bin --config=/etc/${OE_CONFIG}.conf' >> $OE_HOME_EXT/start.sh"
#sudo chmod 755 $OE_HOME_EXT/start.sh

#--------------------------------------------------
# Adding Odoo as a deamon (initscript)
#--------------------------------------------------

echo -e "* Create init file"
cat <<EOF > ~/$OE_CONFIG
#!/bin/sh
### BEGIN INIT INFO
# Provides: $OE_CONFIG
# Required-Start: \$remote_fs \$syslog
# Required-Stop: \$remote_fs \$syslog
# Should-Start: \$network
# Should-Stop: \$network
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# Short-Description: Enterprise Business Applications
# Description: ODOO Business Applications
### END INIT INFO
PATH=/bin:/sbin:/usr/bin
DAEMON=$OE_HOME_EXT/odoo-bin
NAME=$OE_CONFIG
DESC=$OE_CONFIG

# Specify the user name (Default: odoo).
USER=$OE_USER

# Specify an alternate config file (Default: /etc/odoo-server.conf).
CONFIGFILE="/etc/${OE_CONFIG}.conf"

# pidfile
PIDFILE=/var/run/\${NAME}.pid

# Additional options that are passed to the Daemon.
DAEMON_OPTS="-c \$CONFIGFILE"
# DAEMON_OPTS="-c \$CONFIGFILE -u MODULENAME -d DATABASE"

[ -x \$DAEMON ] || exit 0
[ -f \$CONFIGFILE ] || exit 0
checkpid() {
[ -f \$PIDFILE ] || return 1
pid=\`cat \$PIDFILE\`
[ -d /proc/\$pid ] && return 0
return 1
}
case "\${1}" in
start)
echo -n "Starting \${DESC}: "
start-stop-daemon --start --quiet --pidfile \$PIDFILE \
--chuid \$USER --background --make-pidfile \
--exec \$DAEMON -- \$DAEMON_OPTS
echo "\${NAME}."
;;
stop)
echo -n "Stopping \${DESC}: "
start-stop-daemon --stop --quiet --pidfile \$PIDFILE \
--oknodo
echo "\${NAME}."
;;
restart|force-reload)
echo -n "Restarting \${DESC}: "
start-stop-daemon --stop --quiet --pidfile \$PIDFILE \
--oknodo
sleep 1
start-stop-daemon --start --quiet --pidfile \$PIDFILE \
--chuid \$USER --background --make-pidfile \
--exec \$DAEMON -- \$DAEMON_OPTS
echo "\${NAME}."
;;
*)
N=/etc/init.d/\$NAME
echo "Usage: \$NAME {start|stop|restart|force-reload}" >&2
exit 1
;;
esac
exit 0
EOF

echo -e "* Security Init File"
sudo cp ~/$OE_CONFIG /etc/init.d/$OE_CONFIG
sudo chmod 755 /etc/init.d/$OE_CONFIG
sudo chown root: /etc/init.d/$OE_CONFIG

#------------------------------------------------
# Adding Log roate
#------------------------------------------------

cp log_odoo.conf /etc/

grep -q 'log_odoo.conf' /etc/cron.daily/logrotate
if [ $? -eq 1 ]
then
  echo "/usr/sbin/logrotate /etc/log_odoo.conf" >> /etc/cron.daily/logrotate
fi

echo -e "* Change default xmlrpc port"
sudo su root -c "echo 'xmlrpc_port = $OE_PORT' >> /etc/${OE_CONFIG}.conf"

echo -e "* Start ODOO on Startup"
sudo update-rc.d $OE_CONFIG defaults
sudo update-rc.d postgresql enable
sudo systemctl enable postgresql

cp default /etc/nginx/sites-available/
cp odoo.conf /etc/nginx/sites-available/

ln -s /etc/nginx/sites-available/odoo.conf /etc/nginx/sites-enabled/

mkdir /etc/ssl/odoo_cloud
cp etc-ssl-odoo-cloud/* /etc/ssl/odoo_cloud
echo -e "* Starting Odoo Service"
sudo su root -c "service postgresql restart"
sudo su root -c "/etc/init.d/$OE_CONFIG start"
sudo su root -c "service nginx restart"
echo "-----------------------------------------------------------"
echo "Done! The Odoo server is up and running. Specifications:"
echo "Port: $OE_PORT"
echo "User service: $OE_FOLDER"
echo "User PostgreSQL: $OE_FOLDER"
echo "Code location: $OE_FOLDER"
echo "Addons folder: $OE_FOLDER/$OE_CONFIG/addons/"
echo "Start Odoo service: sudo service $OE_CONFIG start"
echo "Stop Odoo service: sudo service $OE_CONFIG stop"
echo "Restart Odoo service: sudo service $OE_CONFIG restart"
echo "-----------------------------------------------------------"

if grep -Fxq "sshd: .backup.odoo-cloud.nl" /etc/hosts.allow
then
  echo 'backup.odoo-cloud.nl is already in /etc/hosts.allow'
else
  sudo echo 'sshd: .backup.odoo-cloud.nl' >> /etc/hosts.allow
fi

if grep -Fxq "sshd: ALL EXCEPT backup.odoo-cloud.nl" /etc/hosts.deny
then
  echo 'There is already an ALL EXCEPT in /etc/hosts.deny'
else
  sudo echo 'sshd: ALL EXCEPT backup.odoo-cloud.nl' >> /etc/hosts.deny
fi

if grep -Fxq "Match User root" /etc/ssh/sshd_config
then
  echo 'There is already a rule to deny root user access for SSH!'
else
  sudo echo 'Match User root' >> /etc/ssh/sshd_config
  sudo echo 'PasswordAuthentication no' >> /etc/ssh/sshd_config
fi

# Check if SSH port is on port 22 still
if grep -Fxq "Port 22" /etc/ssh/sshd_config
then
  echo 'We have changed the SSH port from port 22 to port 3468'
  sudo sed -i '/Port 22/c\Port 3468' /etc/ssh/sshd_config
else
  echo 'The SSH port is not running on port 22 and has already been changed - aborting for safety reasons.'
fi

echo " "
echo "Restarting SSH service to apply changes"
sudo service ssh restart
echo "SSH service is restarted"
