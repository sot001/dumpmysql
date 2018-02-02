#!/bin/bash

# mysql user needs certain privileges to run this file;
#
# grant SELECT, LOCK TABLES, reload ON *.* TO 'mysql'@'localhost' IDENTIFIED BY 'dump';
#
TODAY=`date '+%Y%m%d%H%M'`
DUMPDIR=/mysql_dumps
ARCH_DUMPDIR=/nfs_dumps/`hostname`
LOGFILE=$DUMPDIR/dump.$TODAY.log
BADDUMPS=/tmp/baddumps.txt
GOODSTRING='backup is good'
BADSTRING='backup is incomplete'
emailaddress=mysql

rm /tmp/backupsummary

if [ $(whoami) = "root" ]
then
  echo "You cannot run this script as root."  >> $LOGFILE
  exit 1
fi

echo "starting dump at $TODAY" >> $LOGFILE
echo "----------------------------" >> $LOGFILE
echo "show databases" | mysql -u dumpuser -pdumppassword | grep -v Database | while read line
do
	if [ ! -d $DUMPDIR/$line ]
	then
		mkdir $DUMPDIR/$line
	fi

	if [ ! "$line" = "information_schema" ]
	then
		# flush and lock tables
		echo "$line: flushing and locking tables" >> $LOGFILE
		echo "flush tables with read lock" | mysql -u dumpuser  -pdumppassword $line 

		CMD="mysqldump -u dumpuser -pdumppassword --quick --single-transaction $line"
		OUT="$DUMPDIR/$line/$line.$TODAY.dump"
		echo "$CMD > $OUT" #>> $LOGFILE
		$CMD 1> $OUT 2>> $LOGFILE

		# check veracity of dump
		found=`grep -l -e '-- Dump completed on' $OUT | wc -l`
		if [ "$found" = "0" ]; 
		then 
			echo "$OUT: $BADSTRING" >> $BADDUMPS
		else
			echo "$line is good" >> /tmp/backupsummary
			gzip $DUMPDIR/$line/$line.$TODAY.dump >> $LOGFILE 2>&1 
		fi


		# unlock tables
		echo "$line: dump complete, unlocking tables" >> $LOGFILE
		echo "unlock tables" | mysql -u dumpuser -pdumppassword $line
	else
		echo "skipping $line" >> $LOGFILE
	fi
done

# my.cnf backup
cnffile=my.cnf.`date '+%a'`
cp -fp /etc/my.cnf $DUMPDIR/$cnffile
echo $DUMPDIR/$cnffile created from /etc/my.cnf  >> $LOGFILE

# remove files older than 1 days from local
find $DUMPDIR/ -type f -name \*.dump\* -mtime 1 &>> $LOGFILE
find $DUMPDIR/ -type f -name \*.dump\* -mtime 1 -exec rm {} \; &>> $LOGFILE
find $DUMPDIR/ -type f -name \*.log\* -mtime 1  &>> $LOGFILE
find $DUMPDIR/ -type f -name \*.log\* -mtime 1 -exec rm {} \; &>> $LOGFILE

#### below here is archive to NAS ######
# rsync local to nfs
if [ -d $ARCH_DUMPDIR ]
then
	echo 'copy to nfs'  >> $LOGFILE
	rsync -avz $DUMPDIR/* $ARCH_DUMPDIR/  &>> $LOGFILE

	# remove files older than 3 days from nfs
	find $ARCH_DUMPDIR/ -type f -name \*.dump\* -mtime +3 &>> $LOGFILE
	find $ARCH_DUMPDIR/ -type f -name \*.log\* -mtime +3 &>> $LOGFILE
	find $ARCH_DUMPDIR/ -type f -name \*.dump\* -mtime +3 -exec rm {} \; &>> $LOGFILE
	find $ARCH_DUMPDIR/ -type f -name \*.log\* -mtime +3 -exec rm {} \; &>> $LOGFILE
else
	echo 'nfs is unavailable!' >> $BADDUMPS
fi

NOW=`date '+%Y%m%d%H%M'`
echo "dump completed by $NOW" >> $LOGFILE
echo >> $LOGFILE

SUBJ=`hostname`
if [ -f $BADDUMPS ]
then
	echo 'creating error email'  >> $LOGFILE

	mail -s "$SUBJ: MySql backup errors" mysql<<END
	`cat $BADDUMPS`
END
	rm $BADDUMPS
else
	mail -s "$SUBJ: MySql backup success" mysql<<END
        `find /mysql_dumps/ -type f -name \*.dump.gz -mtime 0`
END

fi 
