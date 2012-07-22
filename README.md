# zfsmon #
zfsmon is a combination of a Python script that runs on your storage servers as a cron job 
and a Sinatra-based webapp that runs elsewhere to keep track of your ZFS storage.

A picture is worth a thousand words, so [here are 5000 of them](http://imgur.com/a/4JP1g).

## Installing ##
### Storage server (client) ###
1. Download the egg [here](https://github.com/downloads/CRBS/zfsmon/zfsmond-0.2.2-py2.7.egg).
2. Make sure you have Python >= 2.6 and the [requests library](http://docs.python-requests.org/en/latest/index.html) installed.
3. ```easy_install zfsmond-0.2.2-py2.7.egg```
4. Copy zfsmond.conf.example to ```/etc/zfsmond.conf``` and edit as needed (you will definitely need to set the zfsmon server's hostname)
5. Add ```/usr/bin/updater.py``` to the crontab of someone who can run ```zfs list``` and ```zpool list```.
   Every 15 minutes is recommended.

### zfsmon server ###
1. Unzip the [webapp](oops this link doesn't work yet) download
2. ```bundle install```
3. ```ruby start.rb start```