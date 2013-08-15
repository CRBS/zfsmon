#!/bin/bash
###############################################################################
## Author: Edmond Negado
## Description: This script test to see if the updater.py script is runnning.
##              If it is running, the script will not allow another instance
##              of the updater.py to run until the last process finishes.
##              This is needed so the sinatra web app doesn't time out on
##              zpools which have hundreds of zfs filesystems.
##
## Set the 'operator' crontab to be:
## 0,15,30,45 * * * * /bin/bash /usr/bin/zfsmon-updater.bash >> /var/log/zfsmond 2>&1
##
###############################################################################

TEST=`ps aux | grep updater.py | grep -v grep`

if [ $? -eq 0 ] 
then

    ## updater.py is still running or exists in the
    ## process tree. do not run the script until
    ## the process does not exist.
    
else
    ## updater.py is not running, run the script to update
    ## zfs monitor database.
    /usr/bin/python /usr/bin/updater.py
fi

exit 0
