#!/bin/bash
# GNU General Public License v3.0
# skamales.com / @skamasle
# Run at your own risk | There is no warranty for this free software.
# Rsync backup
# Alpha 1
# bash script.sh user user2 user3 or bash script.sh --all
# This need a file /usr/local/vesta/conf/sk-rsync.conf with user, port, host, path
# asume than you use ssh rsa keys, and you have it setup and your server can connect with 
# backup server without password
# THIS SCRIPT JUST MAKE A BACKUP, IT CANT RESTORE, SO YOU NEED THE RESTORE SCRIPT
# This Script backup vesta data, user passwords, mails, data bases and user home dir ( /home/$user )
source /usr/local/vesta/conf/sk-rsync.conf
tmpdir=/tmp/sk_backup
sk_log=/var/log/sk-backup.log

function sk_sync () {
if [ -z $2 ];then
#extra=user
	rsync -az --delete -e "ssh -p $port" $1 $user@$host:$path/$extra
else
# 7 months a go I put this with good idea but not remember yet in what case can use it.
	rsync -az --delete -e "ssh -p $port" $1 $user@$host:$path/$extra/$2
fi

}
function backup_log () {
echo 1
}
function sk_clean () {
if [ -d $tmpdir ];then
    cd /tmp
	rm -rf "$tmpdir"
fi
}
function sk_checks () {
if [ ! -d $tmpdir ];then
	mkdir -p $tmpdir
else
    #remove tmp if some backup fail and have some no needed files
    sk_clean
    mkdir -p $tmpdir
fi
mkdir ${tmpdir}/${1}
sk_sync ${tmpdir}/${1}
extra=$1
# not used any more
if [ -d /etc/exim4 ];then
	EXI=/etc/exim4
else
	EXI=/etc/exim
fi
}
function getpass () {
sk_user=$1
mkdir ${tmpdir}/PAM
# improve sec, creating file and remove read permisions
touch $tmpdir/PAM/passwd
touch $tmpdir/PAM/shadow
touch $tmpdir/PAM/group 
chmod 600 $tmpdir/PAM/passwd $tmpdir/PAM/group  $tmpdir/PAM/shadow
grep "^$sk_user:" /etc/passwd > $tmpdir/PAM/passwd
grep "^$sk_user:" /etc/shadow > $tmpdir/PAM/shadow
grep "^$sk_user:" /etc/group > $tmpdir/PAM/group
sk_sync $tmpdir/PAM
}

function backup_home () {
	sk_sync /home/$1
}

function backup_vesta () {
	sk_sync /usr/local/vesta/data/users/$1/ VestaData
}

function backup_mysql () {
sk_user=$1
cd /tmp/sk_backup/
mkdir DataBases
# This restore all and then transfer not good for big databases
for db in $(v-list-databases $sk_user plain | awk '{ print  $1 }')
do
	mysqldump $db > DataBases/$db.sql
	gzip DataBases/$db.sql
done
	sk_sync DataBases
	rm -f DataBases/*.sql.gz
##
## Less space used, restore and transfer DBs one by one 
# Need code this with modification of sk_sync() - isnt urgent
}

function sk_back () {
sk_checks $1
backup_home $1
backup_vesta $1
backup_mysql $1
getpass $1
sk_clean
}

function sk_backup_all () {
for sk_u in $(v-list-users plain | awk '{ print  $1 }')
do
		sk_back $sk_u
done
}

sk_check_user () {
sk_user=$1
if v-list-users plain | awk '{ print  $1 }' |grep -wc $sk_user ;then
	sk_back $sk_user
fi
}
if [ "$1" == "--all" ]; then
	sk_backup_all

else
for sk_args in "$@"
    do
        sk_check_user $sk_args
    done
fi
