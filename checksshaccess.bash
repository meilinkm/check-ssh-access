#!/bin/bash

# Test for the root user
if [ "$(whoami)" != "root" ] ; then
	echo "Please run this script as the root user."
	exit 1
fi

# Set my temporary file name.
tempfile=./checksshaccess.myfile.$$

# Remove old temporary file, if any.
rm -f ${tempfile} 2>/dev/null

# Determine the hostname
myhostname=`hostname`

echo Discovering hosts....

# Look in /etc/hosts
if [ -f /etc/hosts ] ; then
	cat /etc/hosts | grep -v ^# | grep -v ^$ | grep -v ^: | grep -v 127.0.0.1 | cut -f1 -d'#' | tr '[[:space:]]' '\n' | grep -v ^$ | sort -dfu >> $tempfile
fi

# Look in .rhosts
if [ -f ~root/.rhosts ] ; then
	cat ~root/.rhosts | awk '{print $1}' | grep -v ^# | grep -v ^$ | sort -dfu >> $tempfile
fi

# Check who
who 2>/dev/null | grep pts | awk '{print $NF}' | sed "s/(//g" | sed "s/)//g" | sort -dfu >> $tempfile

# Look in known_hosts
if [ -f ~root/.ssh/known_hosts ] ; then
	cat ~root/.ssh/known_hosts | awk '{print $1}' | tr ',' '\n' | grep -v ^# | grep -v ^$ | cut -f1 -d':' | sed "s/\[//g" | sed "s/\]//g" | sort -dfu >> $tempfile
fi

# Look in authorized_keys / authorized_keys2
if [ -f ~root/.ssh/authorized_keys ] ; then
	cat ~root/.ssh/authorized_keys | grep ^ssh | awk '{print $NF}' | grep "root@" | sed "s/root@//g" | grep -v ^# | grep -v ^$ | sort -dfu >> $tempfile
fi
if [ -f ~root/.ssh/authorized_keys2 ] ; then
	cat ~root/.ssh/authorized_keys2 | grep ^ssh | awk '{print $NF}' | grep "root@" | sed "s/root@//g" | grep -v ^# | grep -v ^$ | sort -dfu >> $tempfile
fi

# Look in /etc/hosts.equiv
if [ -f /etc/hosts.equiv ] ; then
	cat /etc/hosts.equiv | grep -v ^# | grep -v ^$ | awk '{print $1}' | sort -dfu >> $tempfile
fi

# Check last
if [ "$(uname)" = "AIX" ] ; then
	last | grep pts | awk '{print $3}' | sort -dfu | grep -v ^: | grep -v ")$" >> $tempfile
fi
if [ "$(uname)" = "Linux" ] ; then
	last -a | grep pts | awk '{print $NF}' | sort -dfu | grep -v ^: | grep -v ")$" >> $tempfile
fi

# Look in id_rsa.pub and id_dsa.pub
if [ -f ~root/.ssh/id_rsa.pub ] ; then
	cat ~root/.ssh/id_rsa.pub | grep ^ssh | awk '{print $NF}' | grep "root@" | sed "s/root@//g" | grep -v ^$ | grep -v ^# | sort -dfu >> $tempfile
fi
if [ -f ~root/.ssh/id_dsa.pub ] ; then
	cat ~root/.ssh/id_dsa.pub | grep ^ssh | awk '{print $NF}' | grep "root@" | sed "s/root@//g" | grep -v ^$ | grep -v ^# | sort -dfu >> $tempfile
fi

# sort the entire file
if [ -f $tempfile ] ; then
	cat $tempfile | sort -dfu > $tempfile.1
	mv $tempfile.1 $tempfile
fi

# Report on the number of servers found.
mynumber=`cat $tempfile | wc -l | awk '{print $1}'`
if [ $mynumber -gt 2 ] ; then
	echo "Processing $mynumber unique hosts..."
fi
if [ $mynumber -eq 1 ] ; then
	echo "Processing $mynumber unique host..."
fi
if [ $mynumber -eq 0 ] ; then
	echo "Discovered no hosts at all. Exiting..."
	exit 0
fi

for thehost in `cat $tempfile` ; do
	unset myresult
	echo -n "Probing $thehost..."
	if [ -x /usr/bin/timeout ] ; then
		myresult=`timeout 5 /usr/bin/ssh -n -qTo ConnectTimeout=1 -o StrictHostKeyChecking=no -o BatchMode=yes -l root $thehost hostname 2>/dev/null`
	else
		myresult=`/usr/bin/ssh -n -qTo ConnectTimeout=1 -o StrictHostKeyChecking=no -o BatchMode=yes -l root $thehost hostname 2>/dev/null`
	fi
	if [ -z "${myresult}" ] ; then
		echo $myhostname $thehost no nohostname >> $tempfile.next
		echo "no"
	else
		echo $myhostname $thehost yes $myresult >> $tempfile.next
		echo "yes"
		if [ "$thehost" != "${myresult}" ] ; then
			unset thistest
			# see if we know this host already
			thistest=`grep -i ^$myresult$ $tempfile`
			if [ -z "$thistest" ] ; then
				# Test if we can access the host with the new found hostname
				unset myresult2
				echo -n "Probing $myresult..."
				if [ -x /usr/bin/timeout ] ; then
					myresult2=`timeout 5 /usr/bin/ssh -n -qTo ConnectTimeout=1 -o StrictHostKeyChecking=no -o BatchMode=yes -l root $myresult hostname 2>/dev/null`
				else
					myresult2=`/usr/bin/ssh -n -qTo ConnectTimeout=1 -o StrictHostKeyChecking=no -o BatchMode=yes -l root $myresult hostname 2>/dev/null`
				fi
				if [ -z "${myresult2}" ] ; then
					echo $myhostname $myresult2 no nohostname >> $tempfile.next
					echo "no"
				else
					echo $myhostname $myresult2 yes $myresult2 >> $tempfile.next
					echo "yes"
				fi
			fi
		fi

	fi
done

mynum=`cat $tempfile.next | grep yes | wc -l | awk '{print $1}'`

echo "Root access established to $mynum host(s)."

echo "Determinining unique hosts..."
if [ $mynum -gt 0 ] ; then
	cat $tempfile.next | grep -v " nohostname$" | grep " yes " | awk '{print $NF}' | sort -dfu | while read myhost ; do
		grep -E "^${myhost}$ | ${myhost} | ${myhost}$" $tempfile.next | awk '{print $2}' | sort -n | head -1 >> $tempfile.unique
	done

	# Sort the unique file
	sort $tempfile.unique > $tempfile.unique.2
	mv $tempfile.unique.2 $tempfile.unique
	mynum=`cat $tempfile.unique | wc -l | awk '{print $1}'`
	if [ ${mynum} -gt 1 ] ; then
		echo "Root access established to $mynum unique hosts:"
	else
		echo "Root access established to $mynum unique host:"
	fi
	echo
	cat $tempfile.unique
fi

rm -f $tempfile $tempfile.next $tempfile.unique

exit 0
