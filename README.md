# zfsmon #
zfs monitor (a catchier name may be forthcoming) is a combination of a Python script that runs on your storage servers as a cron job 
and a Sinatra-based webapp that runs elsewhere to monitor your ZFS storage.

A picture is worth a thousand words, so [here are 5000 of them](http://imgur.com/a/4JP1g).

## Installing ##
### Storage server (client) ###
1. Download the egg [here](https://github.com/downloads/CRBS/zfsmon/zfsmond-0.3.1-py2.7.egg).
2. Make sure you have Python >= 2.6 and the [requests library](http://docs.python-requests.org/en/latest/index.html) installed.
3. ```easy_install zfsmond-0.3.1-py2.7.egg```
4. Copy [zfsmond.example.conf](https://github.com/downloads/CRBS/zfsmon/zfsmond.example.conf) 
   to ```/etc/zfsmond.conf``` and edit as needed (you will definitely need to set your zfsmon server's hostname)
5. Add ```/usr/bin/updater.py``` to the crontab of someone who can run ```zfs list``` and ```zpool list```.
   Every 15 minutes is recommended.

### zfsmon server ###
1. Unzip the [webapp](https://github.com/downloads/CRBS/zfsmon/webapp-1.0.0.tar.gz) tarball
2. ```bundle install```
3. Add a file called auth.yml to this directory with username-password combos for anyone you want
   to have access to protected resources (deleting hosts, etc.)
   For example,
   ```
        rainbowdash: cool123
        someguy: changeme
    ```
4. ```ruby start.rb start```
5. This will start a server on port 4567 using a sqlite database in the directory you unzipped to.
6. Next, add a reverse proxy from nginx or Apache to the Thin server on 4567. With Apache,
   you can usually just add these lines to your httpd.conf or to the Vhost you want to host
   the webapp on:
   ```
   ProxyPass           / http://localhost:4567/

   ProxyPassReverse    / http://localhost:4567/

   ProxyVia            On
   ```