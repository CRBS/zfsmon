#!/usr/bin/env bash
export http_proxy="http://webproxy.ucsd.edu:3128"
export https_proxy="http://webproxy.ucsd.edu:3128"

function install_setuptools() {
    wget http://pypi.python.org/packages/2.6/s/setuptools/setuptools-0.6c11-py2.6.egg
    sudo sh setuptools-0.6c11-py2.6.egg
    rm -f setuptools-0.6c11-py2.6.egg
}

echo -n "Checking for easy_install... "
which easy_install 2>/dev/null || (echo -e "not found.\nInstalling setuptools..." && install_setuptools)
echo ""

if [[ -f /usr/lib/python2.6/site-packages/zfsmond-latest.egg ]]; then
    echo "zfsmond is already installed. performing upgrade..."
    sudo rm -rf /usr/lib/python2.6/site-packages/zfsmond-latest.egg
fi

echo "Installing latest requests library..."
easy_install requests >/dev/null

echo -n "Installing latest zfsmond egg... "
wget http://devilray.crbs.ucsd.edu/skip-proxy/zfsmond-latest.egg --quiet && sudo easy_install zfsmond-latest.egg >/dev/null && echo "done."

if [[ ! -f /etc/zfsmond.conf ]]; then
    echo "Getting configuration file... "
    wget http://devilray.crbs.ucsd.edu/skip-proxy/zfsmond.conf --quiet && sudo cp zfsmond.conf /etc/ && echo "placed at /etc/zfsmond.conf"
    rm -f zfsmond.conf
fi

(which updater.py &>/dev/null && echo "updater.py is installed.") || (echo "Something went wrong during installation." && return 1)
read -p "updater.py should be added to the crontab to run every 15 minutes. Do this now? (y/n) " -n 1

if [[ $REPLY =~ ^[Yy]$ ]]; then
    ( crontab -l 2>/dev/null | grep -Fv updater.py ; echo "0,15,30,45 * * * * /usr/bin/updater.py 2>&1 >> /var/log/zfsmond" ) | crontab
elif [[ $REPLY =~ ^[Nn]$ ]]; then
    echo "Add the following line to root\'s crontab if you\'d like to do it yourself."
    echo "0,15,30,45 * * * * /usr/bin/updater.py 2>&1 >> /var/log/zfsmond"
else
    echo "updater.py needs to be added to root's crontab to run every 15 minutes. Add the following line: "
    echo "0,15,30,45 * * * * /usr/bin/updater.py 2>&1 >> /var/log/zfsmond"
fi
echo ""
unset install_setuptools
rm -f zfsmond-latest.egg