# dumpmysql

Quick and dirty script wrapper for mysql dump. Be aware that this will not give you a clean dump on high trasnacational (ie InnoDB) databses, as you risk to have in flight transactions in your dump file. You are better off looking at InnoDB dump specific scripts for that sort of thing, or snapshotting an LV.

The script assumes an alias has been set up for the mysql user to email results
