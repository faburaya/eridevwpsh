#!/bin/bash

# Starts a BSCS module in a separate XTERM window
# Usage: startModule module_name param1 param2 param3 ...
startModule()
{
    modName=$(echo "$1" | awk '{print toupper($0)}')
    scriptFileName=$(echo ~/_tempScript_start)$modName".sh"
    printf "\nStarting $modName...\n"
    echo "#!/bin/bash" >> $scriptFileName
    echo "$BSCS_BIN/"$@ >> $scriptFileName
    echo "read  -n 1 -p 'Press any key to close this window...' anything" >> $scriptFileName
    chmod +x $scriptFileName
    xterm -T $(hostname)" - "$modName $scriptFileName &
    sleep 10
}

data &

rm $BSCS_WORKDIR/CTRL/RDH* 2> /dev/null

printf "\n##### RDH (UDMAP) #####\n\n"
rdh -t2 -udmap &
sleep 3

printf "\n##### RDH (PRIH) #####\n\n"
rdh -t2 -prih &
sleep 3

printf "\n##### RDH (RIH Partition 0) #####\n\n"
rdh -t2 -rih &
sleep 3

#printf "\n##### RDH (RIH Partition 2) #####\n\n"
#rdh -t2 -rih -p2 &
#sleep 3

#printf "\n##### RDH (CCH) #####\n\n"
#rdh -t2 -cch &
#sleep 3

startModule prih -e -t
startModule rih -e -t

printf "\n##### My Processes #####\n\n"
ps -ef | grep $(whoami) | grep -v grep | grep -v 'ps -ef' | grep -v sshd:
printf "\n"
