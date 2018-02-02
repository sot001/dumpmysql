# dumpmysql

Quick and dirty script wrapper for mysql dump. Be aware that this will not give you a clean dump on high trasnacational (ie InnoDB) databses, as you risk to have in flight transactions in your dump file. You are better off looking at InnoDB dump specific scripts for that sort of thing, or snapshotting an LV. 

It also has the password for the dump user in the file, whcih isn't great so best to shift that into and encrypted configuration file and passign that in.

The script assumes an alias has been set up for the mysql user to email results

usage: 
````
./dumpmysql.sh
````
or via cron:
````
00 02 * * * /var/lib/mysql/bin/dumpmysql &> /dev/null
````
