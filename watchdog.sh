#!/bin/bash

#culori
r="\e[31m" #red
g="\e[32m" #green
b="\e[34m" #blue
y="\e[33m" #yellow
p="\e[35m" #pink
en="\e[0m" #end color

HELP=$1
if [[ $HELP == "--help" ]]
then
	echo -e "----------------- COMMAND STRUCTURE --------------------------------- \n"
	echo -e "$p./watchdog.sh [CPU_LIMIT] [RAM_LIMIT]$en [*WHITELIST ( KEYWORD_1 KEYWORD_2 ... ) ]"
	echo -e "\n $p[CPU_LIMIT]$en --> Maximum workload of CPU (per core) per process, expressed as a percentage"
	echo -e "\n $p[RAM_LIMIT]$en --> Maximum physical memory per process, expressed in$p Megabytes$en"
	echo -e "\n $p[*WHITELIST]$en --> A list of$p keywords$en used to$p exclude$en processes with matching command names"
	echo -e "\n \n EXAMPLE: ./watchdog.sh 5 1024 firefox gnome \n"
	echo -e '--> All processes using more than 5% of CPU or using more than 1024MB memory (excluding commands matching "firefox" & "gnome") will be suspended \n'
	echo -e "If the keyword argument NO_COL_ is given, text will print without color. This can be used to redirect the output of this file to a log file. \n"
	exit
fi

cpuLimit=$1
ramLimitMB=$2
keywords=${@:3}

echo $keywords | grep -q "NO_COL_" && r="" && g="" && b="" && y="" && p="" && en=""

if [ -z $cpuLimit ]
then
    cpuLimit=5
else
    if [[ cpuLimit < 5 ]]
    then
    	echo -e "$r CPU LIMIT TOO LOW (<5%) $en"
    	exit
    fi
fi
if [ -z $ramLimitMB ]
then
    ramLimitMB=1024
else
    if [[ ramLimitMB < 256 ]]
    then
    	echo -e "$r RAM LIMIT TOO LOW (<256MB) $en"
    	exit
    fi
fi
echo -e "$p CPU LIMIT IS $cpuLimit% $en"
echo -e "$p RAM LIMIT IS $ramLimitMB MB $en"

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

if [ -f stall.txt ]
then
    rm stall.txt
fi

checkFileExists "whitelist.txt"

echo -e "WHITELIST: \n $p-- $keywords$en (from input) \n $p`cat whitelist.txt`$en \n(from whitelist.txt)"

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

testPID() {
    if [ -d "/proc/$1" ]
    then
    	return 0
    else
        #echo -e "\e[33m Process $2 with ID $1 NOT FOUND IN /proc $en"
        return 1
    fi
}

read -p "Do you want to see your processes in Python UI? (y/n)" yn

touch "report.txt"
touch "deviceUsage.txt"

if [[ $yn == "y" ]]
then
    checkFileExists "graphics.py"
    checkFileExists "graphicsDemo.py"
    python3 graphicsDemo.py &
    PYTHON_PID=$!
    echo -e "$p Initializing window (PID=$PYTHON_PID)$en"
    trap "echo -e ' \n WATCHDOG TERMINATED' ; kill $PYTHON_PID ; rm report.txt ; rm deviceUsage.txt ; exit" SIGINT SIGTERM
    sleep 2
    echo -e "$p Initialization done$en"
else
    trap "echo -e ' \n WATCHDOG TERMINATED' ; rm report.txt ; rm deviceUsage.txt ; exit" SIGINT SIGTERM
fi

getDeviceUsage() {
	read -rs cpustxt user nice system idle iowait irq softirq x0 x1 x2 < /proc/stat
	sum1=$(( user + nice + system + idle + iowait + irq + softirq + x0 + x1 + x2 ))
	idle1=$idle
	#sleep 3
	for i in 1-12
	do
	    read -t 0.25 -n 1 key && touch stall.txt && read -p "| Program stalled! Press Enter to continue: " && rm stall.txt
	done
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
    currentNI=$( ps -p $1 -o ni | tail -1 )
    if [[ $currentNI == "-" ]]
    then
    	currentNI=0
    fi
    ni=$(( $currentNI + 3 ))
    if (( ni > 19 ))
    then
        kill $1
    else
        renice $ni $1
    fi
}

while [[ 0==0 ]]
do
    top -b -o $SORTBY -n 1 | tail -n +7 > report.txt
    #ps -eo pid,ni,user,rss,%cpu,time,comm --sort=-$SORTBY > report.txt
    cpuUsage=$(getDeviceUsage)

    tail +2 report.txt |
    while read pid usr pr ni virt ram shr S cpu mem t name
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
		        echo -e "$r Process $name (PID = $pid) RAM usage exceded $ramLimitMB MB (USED: $MBram MB) $en"
		        echo -e "$r Process $pid will be stopped (SIGTERM) $en"
		        kill $pid
		        )
		    fi
		    cpu=$(echo $cpu | awk '{print int($1)}' )
		    if (( cpu > cpuLimit ))
		    then
		    	testPID $pid $name || continue
		        echo -e "$r Process $name (PID = $pid) CPU usage exceded $cpuLimit% (Used: $cpu%) $en"
		        echo -e "$r Process $pid will be stopped (SIGSTOP) $en"
		        kill -19 $pid
		        (
		         i=0
		         while (( cpuUsage > 50 && i < 24 || i < $ni ))
		         do
		             sleep 3; 
		             i=$(( i + 3 ))
		         done
		         kill -18 $pid
		         reNI $pid
		         echo -e "$g Process $name (PID = $pid) running after waiting $i seconds... (SIGCONT) $en")&
                    fi
                fi
        fi
    done
done
