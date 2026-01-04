#!/bin/bash

cpuLimit=$1
ramLimitMB=$2

if [ -z $cpuLimit ]
then
    cpuLimit=5
    echo "CPU LIMIT IS 5%"
else
    echo "CPU LIMIT IS $cpuLimit%"
fi
if [ -z $ramLimitMB ]
then
    ramLimitMB=1024
    echo "RAM LIMIT IS 1024 MB"
else
    if [[ $ramLimitMB > 255 ]]
    then
    	echo "RAM LIMIT IS $ramLimitMB MB"
    else
    	ramLimitMB=1024
    	echo "RAM LIMIT IS 1024 MB"
    fi
fi

KB=$(( ramLimitMB << 10 ))

checkFileExists() {
    if [ -f $1 ]
    then
    	echo "Checked for $1 file!"
    else
        echo "File $1 does not exist in the current directory!"
        exit
    fi
}

checkFileExists "report.txt"
checkFileExists "deviceUsage.txt"
checkFileExists "whitelist.txt"

echo "" > deviceUsage.txt
echo "" > report.txt

read -p "Choose what value to sort by [RAM/CPU]" SORTBY

if [[ $SORTBY == "RAM" || ($SORTBY != "RAM" && $SORTBY != "CPU") ]]
then
	SORTBY="RES"
	echo "Sorting by RAM USAGE"
fi
if [[ $SORTBY == "CPU" ]]
then
	SORTBY="%CPU"
	echo "Sorting by CPU USAGE"
fi

read -p "Do you want to see your processes in a UI? (y/n) " yn
if [[ $yn == "y" ]]
then
    checkFileExists "graphics.py"
    checkFileExists "graphicsDemo.py"
    python3 graphicsDemo.py &
    PYTHON_PID=$!
    trap "echo -e ' \n WATCHDOG TERMINATED' ; kill $PYTHON_PID ; echo "" > report.txt ; echo "" > deviceUsage.txt ; exit" SIGINT SIGTERM
    echo "Initializing window"
    sleep 3
    echo "Initialization done"
fi

getDeviceUsage() {
	CPU_USAGE=$( top -b -n 1 | head -n +5 | grep "Cpu(s)" | awk '{print 100 - $8}' )
	FREE_RAM=$(free --mega | tail +2 | head -1)
	echo $FREE_RAM | while read MEM TOTAL USED FREE SHARED CACHE AVAILABLE
	do
		P_USED=$(( $USED * 100 / $TOTAL ))
		P_SHR=$(( $SHARED * 100 / $TOTAL ))
		echo -e "\n $CPU_USAGE $P_USED $P_SHR $TOTAL" > deviceUsage.txt
	done
}

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
        	IGNORE=0
		while read -r ignoreElem
		do
		    if echo $name | grep -q $ignoreElem
		    then
			IGNORE=1
		    fi
		done < whitelist.txt
		if [[ $IGNORE == 0 ]]
		then
        	    diff=$(( KB - ram ))
		    if [ $diff -lt 0 ]
		    then
		        MBram=$(( ram >> 10 ))
		        echo "Process $name (PID = $pid) RAM usage exceded $ramLimitMB MB (USED: $MBram MB)"
		        echo "Process $pid will be stopped (SIGTERM)"
		        kill $pid
		    fi
		    cpu=$(echo $cpu | tr -d .)
		    cpu=$(( $cpu / 10 ))
		    diffCPU=$(( cpuLimit - cpu ))
		    if [ $diffCPU -lt 0 ]
		    then
		        echo "Process $name (PID = $pid) CPU usage exceded $cpuLimit% (Used: $cpu%)"
		        echo "Process $pid will be stopped (SIGSTOP)"
		        kill -19 $pid
		        (sleep 10; kill -18 $pid; echo "Process $name (PID = $pid) running... (SIGCONT)")&
                    fi
                fi
        fi
    done
    sleep 1
done
