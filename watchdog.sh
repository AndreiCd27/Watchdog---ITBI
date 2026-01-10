#!/bin/bash

HELP=$1
if [[ $HELP == "--help" ]]
then
	echo -e "----------------- COMMAND STRUCTURE --------------------------------- \n"
	echo "./watchdog.sh [CPU_LIMIT] [RAM_LIMIT] [*WHITELIST ( KEYWORD_1 KEYWORD_2 ... ) ]"
	echo -e "\n [CPU_LIMIT] --> Maximum workload of CPU (per core) per process, expressed as a percentage"
	echo -e "\n [RAM_LIMIT] --> Maximum physical memory per process, expressed in MB"
	echo -e "\n [*WHITELIST] --> A list of keywords used to exclude processes with matching command names"
	echo -e "\n \n EXAMPLE: ./watchdog.sh 5 1024 firefox gnome \n"
	echo -e '--> All processes using more than 5% of CPU or using more than 1024MB memory (excluding commands matching "firefox" & "gnome") will be suspended'
	exit
fi

cpuLimit=$1
ramLimitMB=$2
keywords=${@:3}

if [ -z $cpuLimit ]
then
    cpuLimit=5
else
    if [[ cpuLimit < 5 ]]
    then
    	echo -e "\e[31m CPU LIMIT TOO LOW (<5%) \e[0m"
    	exit
    fi
fi
if [ -z $ramLimitMB ]
then
    ramLimitMB=1024
else
    if [[ ramLimitMB < 256 ]]
    then
    	echo -e "\e[31m RAM LIMIT TOO LOW (<256MB) \e[0m"
    	exit
    fi
fi
echo -e "\e[35m CPU LIMIT IS $cpuLimit% \e[0m"
echo -e "\e[35m RAM LIMIT IS $ramLimitMB MB \e[0m"

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

checkFileExists "whitelist.txt"

echo -e "WHITELIST: \n \e[35m-- $keywords\e[0m (from input) \n\e[35m`cat whitelist.txt`\e[0m \n(from whitelist.txt)"

read -p "Choose what value to sort by [RAM/CPU]" SORTBY

if [[ $SORTBY == "RAM" || ($SORTBY != "RAM" && $SORTBY != "CPU") ]]
then
	SORTBY="rss"
	echo "Sorting by RAM USAGE"
fi
if [[ $SORTBY == "CPU" ]]
then
	SORTBY="%cpu"
	echo "Sorting by CPU USAGE"
fi

testPID() {
    if [ -d "/proc/$1" ]
    then
    	return 0
    else
        echo -e "\e[33m Process $2 with ID $1 NOT FOUND IN /proc \e[0m"
        return 1
    fi
}

read -p "Do you want to see your processes in Python UI? (y/n)" yn

touch "report.txt"
touch "deviceUsage.txt"
touch "ended.txt"

if [[ $yn == "y" ]]
then
    checkFileExists "graphics.py"
    checkFileExists "graphicsDemo.py"
    python3 graphicsDemo.py &
    PYTHON_PID=$!
    echo -e "\e[35mInitializing window (PID=$PYTHON_PID)\e[0m"
    trap "echo -e ' \n WATCHDOG TERMINATED' ; kill $PYTHON_PID ; rm report.txt ; rm deviceUsage.txt ; rm ended.txt ; exit" SIGINT SIGTERM
    sleep 2
    echo -e "\e[35mInitialization done\e[0m"
else
    trap "echo -e ' \n WATCHDOG TERMINATED' ; rm report.txt ; rm deviceUsage.txt ; rm ended.txt ; exit" SIGINT SIGTERM
fi

getDeviceUsage() {
	read -rs cpustxt user nice system idle iowait irq softirq x0 x1 x2 < /proc/stat
	sum1=$(( user + nice + system + idle + iowait + irq + softirq + x0 + x1 + x2 ))
	idle1=$idle
	sleep 3
	read -rs cpustxt user nice system idle iowait irq softirq x0 x1 x2 < /proc/stat
	sum2=$(( user + nice + system + idle + iowait + irq + softirq + x0 + x1 + x2 ))
	idle2=$idle
	idleTotal=$(( idle2 * 100 - idle1 * 100 ))
	sumTotal=$(( sum2 - sum1 ))
	CPU_USAGE=$(( 100 - idleTotal / sumTotal ))
	free --mega | tail +2 | head -1 | while read MEM TOTAL USED FREE SHARED CACHE AVAILABLE
	do
	    P_USED=$(( USED * 100 / TOTAL ))
	    P_SHR=$(( SHARED * 100 / TOTAL ))
	    echo -e "\n $CPU_USAGE $P_USED $P_SHR $TOTAL" > deviceUsage.txt
	done
	echo $CPU_USAGE
}

USER=$(whoami)

reNI() {
    ni=$(( $1 + 2 ))
    if (( ni > 19 ))
    then
        kill $2
    else
        renice $ni $2
    fi
}

while [[ 0==0 ]]
do
    #top -b -o $SORTBY -n 1 | tail -n +7 | awk -F' ' '{print $1, $2, $6, $9, $11, $12}' > report.txt
    ps -eo pid,ni,user,rss,%cpu,time,comm --sort=-$SORTBY > report.txt
    cpuUsage=$(getDeviceUsage)
	
    tail +2 report.txt |
    while read pid ni usr ram cpu t name
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
		for ignoreElem in $keywords
		do
		    if echo $name | grep -q $ignoreElem
		    then
			IGNORE=1
		    fi
		done
		if (( IGNORE == 0 ))
		then
		    if (( ram > KB ))
		    then
		        MBram=$(( ram >> 10 ))
		        testPID $pid $name && (
		        echo -e "\e[31m Process $name (PID = $pid) RAM usage exceded $ramLimitMB MB (USED: $MBram MB) \e[0m"
		        echo -e "\e[31m Process $pid will be stopped (SIGTERM) \e[0m"
		        kill $pid
		        )
		    fi
		    cpu=$(echo $cpu | awk '{print int($1)}' )
		    if (( cpu > cpuLimit ))
		    then
		    	testPID $pid $name && (
		        echo -e "\e[31m Process $name (PID = $pid) CPU usage exceded $cpuLimit% (Used: $cpu%) \e[0m"
		        echo -e "\e[31m Process $pid will be stopped (SIGSTOP) \e[0m"
		        kill -19 $pid
		        (while (( $cpuUsage > 30 ))
		         do
		             echo "Waiting for less CPU usage!"
		             sleep 1; 
		         done
		         kill -18 $pid
		         reNI $ni $pid
		         echo -e "\e[32m Process $name (PID = $pid) running... (SIGCONT) \e[0m")&
			)
                    fi
                fi
        fi
    done
done
