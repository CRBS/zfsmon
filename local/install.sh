#!/usr/bin/env bash
export http_proxy="http://webproxy.ucsd.edu:3128"
export https_proxy="http://webproxy.ucsd.edu:3128"

function install_setuptools() {
    wget http://pypi.python.org/packages/2.6/s/setuptools/setuptools-0.6c11-py2.6.egg
    sudo sh setuptools-0.6c11-py2.6.egg
    rm -f setuptools-0.6c11-py2.6.egg
}

printf '%s' "Checking for easy_install... "
which easy_install 2>/dev/null || (printf '%s' "not found.\nInstalling setuptools..." && install_setuptools)
printf '\n'

if [[ -f /usr/lib/python2.6/site-packages/zfsmond-latest.egg ]]; then
    printf '%s\n' "zfsmond is already installed. performing upgrade..."
    sudo rm -rf /usr/lib/python2.6/site-packages/zfsmond-latest.egg
fi

printf '%s\n' "Installing latest requests library..."
easy_install requests >/dev/null

printf '%s' "Installing latest zfsmond egg... "
wget http://devilray.crbs.ucsd.edu/skip-proxy/zfsmond-latest.egg --quiet && sudo easy_install zfsmond-latest.egg >/dev/null && printf '%s\n' "done."

if [[ ! -f /etc/zfsmond.conf ]]; then
    printf '%s\n' "Getting configuration file... "
    wget http://devilray.crbs.ucsd.edu/skip-proxy/zfsmond.conf --quiet && sudo cp zfsmond.conf /etc/ && printf '%s\n' "placed at /etc/zfsmond.conf"
    rm -f zfsmond.conf
fi

(which updater.py &>/dev/null && printf '%s\n' "updater.py is installed.") || (printf '%s\n' "Something went wrong during installation." && return 1)
read -p "updater.py should be added to the crontab to run every 15 minutes. Do this now? (y/n) " -n 1

if [[ $REPLY =~ ^[Yy]$ ]]; then
    ( crontab -l 2>/dev/null | grep -Fv updater.py ; printf '%s\n' "0,15,30,45 * * * * /usr/bin/updater.py 2>&1 >> /var/log/zfsmond" ) | crontab
elif [[ $REPLY =~ ^[Nn]$ ]]; then
    printf '%s\n' "Add the following line to root\'s crontab if you\'d like to do it yourself."
    printf '%s\n' "0,15,30,45 * * * * /usr/bin/updater.py 2>&1 >> /var/log/zfsmond"
else
    printf '%s\n' "updater.py needs to be added to root's crontab to run every 15 minutes. Add the following line: "
    printf '%s\n' "0,15,30,45 * * * * /usr/bin/updater.py 2>&1 >> /var/log/zfsmond"
fi
printf '\n'
unset install_setuptools
rm -f zfsmond-latest.egg