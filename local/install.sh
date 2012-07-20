#!/usr/bin/env bash

ZFSMON_UPDATER_PATH='/usr/bin/updater.py'
ZFSMON_LOG_PATH='/var/log/zfsmond'
ZFSMON_EGG_PATH='/usr/lib/python2.6/site-packages/zfsmond-latest.egg'
ZFSMON_CONF_PATH='/etc/zfsmond.conf'

ZFSMON_CRON="*/15 * * * * $ZFSMON_UPDATER_PATH 2>&1 >> $ZFSMON_LOG_PATH"

SETUPTOOLS_URI='http://pypi.python.org/packages/2.6/s/setuptools/setuptools-0.6c11-py2.6.egg'
ZFSMON_DOWNLOAD_EGG_URI='http://devilray.crbs.ucsd.edu/skip-proxy/zfsmond-latest.egg'
ZFSMON_DOWNLOAD_CONF_URI='http://devilray.crbs.ucsd.edu/skip-proxy/zfsmond-latest.egg'

# Use UCSD proxy in case we're in private IP space.
http_proxy="http://webproxy.ucsd.edu:3128"
export http_proxy
https_proxy="http://webproxy.ucsd.edu:3128"
export https_proxy

function install_setuptools() {
  curl -S "$SETUPTOOLS_URI" -o setuptools.egg && sudo sh ./setuptools.egg
  rm -f setuptools.egg
}


printf '%s' "Checking for easy_install... "
which easy_install 2>/dev/null || (printf '%s\n' 'easy_install not found.' 'Installing setuptools...' && install_setuptools)
printf '\n'


if [ -f "$ZFSMON_EGG_PATH" ]; then
  printf '%s\n' "zfsmond is already installed. performing upgrade..."
  sudo rm -rf "$ZFSMON_EGG_PATH"
fi


printf '%s\n' "Installing latest requests library..."
easy_install requests >/dev/null


printf '%s' "Installing latest zfsmond egg... "
curl -S "$ZFSMON_DOWNLOAD_EGG_URI" -O zfsmond-latest.egg && sudo easy_install zfsmond-latest.egg >/dev/null && printf '%s\n' "done."
rm -f zfsmond-latest.egg

if [[ ! -f /etc/zfsmond.conf ]]; then
    printf '%s\n' "Getting configuration file... "
    curl -S "$ZFSMON_DOWNLOAD_CONF_URI" -O zfsmond.conf && sudo cp zfsmond.conf "$ZFSMON_CONF_PATH" && printf '%s\n' "placed at $ZFSMON_CONF_PATH"
    rm -f zfsmond.conf
fi


if [ -f "$ZFSMON_UPDATER_PATH" ]; then
	printf '%s\n' "$ZFSMON_UPDATER_PATH is installed."
else
	printf '%s\n' 'Something went wrong during installation.'
	return 1
fi


# Prompt user: Add to crontab?
printf '%s\n' 'This script should be invoked by cron every 15 minutes.'
while : ; do
  printf '%s' "Add to $USER crontab? (y/n): "
  read REPLY
  case "$REPLY" in
    [Yy]) crontab -l 2>/dev/null | grep "$ZFSMON_UPDATER_PATH" 2>&1 >/dev/null || printf '%s\n' "$ZFSMON_CRON" | crontab
          break ;;
    [Nn]) printf '%s\n' "Okay, then you'll have to add this line to the crontab yourself: "
          printf '%s\n' "$ZFSMON_CRON"
          break ;;
       *) printf '%s\n' 'Invalid selection.' ;;
  esac
done
printf '\n'