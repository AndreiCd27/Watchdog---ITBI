#!/bin/bash

cpuLimit=$1
ramLimitMB=$2

if [ -z $cpuLimit ]
then
    echo "CPU LIMIT IS 5%"
else
    echo "CPU LIMIT IS $cpuLimit%"
fi
if [ -z $ramLimitMB ]
then
    echo "RAM LIMIT IS 1024 MB"
else
    echo "RAM LIMIT IS $ramLimitMB MB"
fi

echo "" > deviceUsage.txt
echo "" > report.txt

getDeviceUsage() {
	CPU_USAGE=$( top -b -o $SORTBY -d 1 -n 1 | head -n +5 | grep "Cpu(s)" | awk '{print 100 - $8}' )
	FREE_RAM=$(free --mega | tail +2 | head -1)
	echo $FREE_RAM | while read MEM TOTAL USED FREE SHARED CACHE AVAILABLE
	do
		P_USED=$(( $USED * 100 / $TOTAL ))
		P_SHR=$(( $SHARED * 100 / $TOTAL ))
		echo -e "\n $CPU_USAGE $P_USED $P_SHR $TOTAL" > deviceUsage.txt
	done
}

SELF_PID=$!

read -p "Choose what value to sort by [RAM/CPU]" SORTBY

if [[ $SORTBY == "RAM" || ($SORTBY != "RAM" && $SORTBY != "CPU") ]]
then
	SORTBY="RES"
	echo "Monitoring RAM USAGE"
fi
if [[ $SORTBY == "CPU" ]]
then
	SORTBY="%CPU"
	echo "Monitoring CPU USAGE"
fi

read -p "Do you want to see your processes in a UI? (y/n) " yn
if [[ $yn == "y" ]]
then
    python3 graphicsDemo.py &
    PYTHON_PID=$!
    trap "echo -e ' \n WATCHDOG TERMINATED' ; kill $PYTHON_PID ; echo "" > report.txt ; echo "" > deviceUsage.txt ; exit" SIGINT SIGTERM
    echo "Initializing window"
    sleep 3
    echo "Initialization done"
fi

USER=$(whoami)

while [[ 0==0 ]]
do
    top -b -o $SORTBY -d 1 -n 1 | tail -n +7 | awk -F' ' '{print $1, $2, $6, $9, $11, $12}' > report.txt
    getDeviceUsage
	
    tail +2 report.txt |
    while read pid usr ram cpu t name
    do
        if [[ $usr != "root" ]]
        then
		KB=$(( $ramLimitMB << 10 ))
		if [ $ram -gt $KB ]
		then
		    echo "Process $name (PID = $pid) RAM usage exceded {$ramLimitMB}MB"
		    echo "Process $pid will be stopped (SIGTERM)"
		    kill $pid
		fi
		cpu=$(echo $cpu | tr -d .)
		cpu=$(( $cpu / 10 ))
		if [ $cpu -gt $cpuLimit ]
		then
		    if [[ $? == 0 ]]
		    then
			IGNORE=0
			while read -r ignoreElem
			do
			    echo $name | grep $ignoreElem
			    if [[ $? == 0 ]]
			    then
				echo "Ignored $name (PID = $pid)"
				IGNORE=1
			    fi
			done < whitelist.txt
			if [[ $IGNORE == 0 ]]
			then
			    echo "Process $name (PID = $pid) CPU usage exceded $cpuLimit% (Used: $cpu%)"
			    echo "Process $pid will be stopped (SIGSTOP)"
			    kill -19 $pid
			    (sleep 10; kill -18 $pid; echo "Process $name (PID = $pid) running... (SIGCONT)")&
			fi
		fi
            fi
        fi
    done
    sleep 1
done

echo "Checked for processes using more than 1GB RAM or 5% CPU"
