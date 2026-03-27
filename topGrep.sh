#!/bin/bash

FILTER=$1

OUTPUT=`top -b -n 1 -o RES`

if [ -z "$FILTER" ]
then
	echo "$OUTPUT" > report.txt
	echo "`tail +7 report.txt`" > report.txt
	cat report.txt
else
	echo "$OUTPUT" > report.txt
	echo "`tail +7 report.txt`" > report.txt
	ENTRIES=""
	ENTRIES=$(awk -F' ' '{print $1, $12}' report.txt | grep $FILTER)
	
	i=0
	
	for pid in $ENTRIES; do
	    r=`expr $i % 2`
	    if [ $r -eq 0 ]
	    then
	    	top -b -n 1 -p $pid | tail +8
	    fi
	    i=$((i+1))
	done
fi

RAM=$(awk -F' ' '{print $1, $12, $6}' report.txt | tail +2)
i=0
pid=0
name=""
	
for x in $RAM; do
    r=`expr $i % 3`
    if [ $r -eq 0 ]
    then
    	pid=$x
    else
        if [ $r -eq 2 ]
        then
            SPACE_USED=$(echo "$x / 1000000" | bc -l)
            COND=$(echo "$SPACE_USED > 1" | bc -l)
            SPACE_USED=$(echo $SPACE_USED | cut -c 1-6)
            if [ $COND -eq 1 ]
            then
                echo "Process $name (PID = $pid) RAM usage exceded 1GB (Used: $SPACE_USED GB)"
                echo "Process $pid killed"
            else
                break
            fi
        else
            name=$x
        fi
    fi
    i=$((i+1))
done
