#! /bin/bash

###################################################################################################
# Write shell script that detects if child processes of crond have been running for too long
# (configurable in minutes or seconds, one threshold which
# yields a warning and one which is critical). It should output the PIDs and executable names
# of the long-runners and an exit code that corresponds to the oldest process under consideration.
###################################################################################################

AMBER=$((14*60*60)) # threshold in seconds for warning
RED=$((16*60*60)) # threshold in seconds for critical warning

#### END OF CONFIGURATION AREA ####

#### self checks ####
CRONID=$(pgrep -f crond)
# CRONID=$(ps ho %p -C crond) # it picks CROND as well

if [[ -z $CRONID ]] ; then
    echo "Could not find crond among running processes"
    exit 1
elif [[ $( echo $CRONID | wc -l ) -gt 1 ]] ; then
    echo "Please check the script, it thinks we have more than 1 crond"
    exit 2
fi

#### Loop through all child PIDs ####
PID_ARR=()
while read CH_PID ; do # < <(pgrep -P $(pgrep -d, -P $CRONID ))
#    echo "Analyzing PID $CH_PID"
    ETIME=$(ps -p $CH_PID -o etime=)
#   echo ETIME=$ETIME
    HOURS=$(  echo $ETIME | awk -F: '{ print $1 }' | sed 's/ //; s/^0//g')
    MINUTES=$(echo $ETIME | awk -F: '{ print $2 }' | sed 's/ //; s/^0//g')
    SECUNDS=$(echo $ETIME | awk -F: '{ print $3 }' | sed 's/ //; s/^0//g')
#   echo HOURS=$HOURS
    if [[ $HOURS =~ .*-.* ]] ; then
        echo "PID $CH_PID runs more than 1 day. (Dash (-) was found)"
        DAYS=$(echo $HOURS | awk -F- '{ print $1 }')
        H2=$(echo $HOURS | awk -F- '{ print $2 }' | sed 's/^0//g' )
        HOURS=$((DAYS*24+H2))
    else
        DAYS=0
    fi
    ELAPS_SECONDS=$((HOURS*60*60+MINUTES*60+SECUNDS))
#    echo "For PID $CH_PID (DAYS=$DAYS) HOURS=$HOURS, MINUTES=$MINUTES, SECUNDS=$SECUNDS ELAPS_SECONDS=$ELAPS_SECONDS"
#    echo "number of elements=${#PID_ARR[*]}"


    if [[ $((ELAPS_SECONDS-RED)) -gt 0  ]] ; then # looking if it runs longer than RED - critical threshold
#       echo "RED threshold for ID $CH_PID breached $((ELAPS_SECONDS-RED)) seconds ago."
        REDPIDs="$REDPIDs$CH_PID,"
        PID_ARR+=("$CH_PID::$ELAPS_SECONDS")

    elif [[ $((ELAPS_SECONDS-AMBER)) -gt 0 ]] ; then
#       echo "AMBER threshold for ID $CH_PID breached $((ELAPS_SECONDS-AMBER)) seconds ago."
        AMBERPIDs="$AMBERPIDs$CH_PID,"
        PID_ARR+=("$CH_PID::$ELAPS_SECONDS")
#    else
#    echo "PID $CH_PID is below threshold"
    fi

done < <(pgrep -P $(pgrep -d, -P $CRONID ))

REDPIDs=$(  echo $REDPIDs   | sed 's/,$//') # getting rid of trailing coma
AMBERPIDs=$(echo $AMBERPIDs | sed 's/,$//')

#echo "AMBERPIDs=$AMBERPIDs REDPIDs=$REDPIDs"
#echo "number of elements=${#PID_ARR[*]}"
#echo "all array items space delimited: ${PID_ARR[@]}"

if [[ -n $REDPIDs ]] ; then
    echo "RED - critically long running childs of crond:"
    ps -p $REDPIDs -o pid,ppid,lstart,etime,time,args
fi

if [[ -n $AMBERPIDs ]] ; then
    echo "AMBER - suspiciously long running childs of crond:"
    ps -p $AMBERPIDs -o pid,ppid,lstart,etime,time,args
fi

#### Generation of exitcode
INDEX=0
OLDESTAGE=1
EXITCODE=0
for ID_AGE in ${PID_ARR[@]}; do
    ID=$( echo $ID_AGE | awk -F:: '{ print $1 }' )
    AGE=$(echo $ID_AGE | awk -F:: '{ print $2 }' )
    INDEX=$((INDEX+1)) # ++
#    echo "ID_AGE=$ID_AGE ID=$ID AGE=$AGE INDEX=$INDEX"

    if [[ $OLDESTAGE -lt $AGE ]] ; then
        OLDESTAGE=$AGE
        EXITCODE=$INDEX
    fi
done

if [[ $EXITCODE -gt 0 ]] ; then
    echo "exiting with exitcode $EXITCODE, (Number stays for line number of most aged PID."
else
    echo "GREEN: No long-runners were found among cron childs."
fi
    exit $EXITCODE


#### SANDBOX area ####
# process start time
#ps -p 4488 -o lstart=
# process elapsed time
#ps -p 4488 -o etime=
# IDs of all childs of cron
#pgrep -d,  -P $(pgrep -d, -P $(pgrep -f 'crond'))
