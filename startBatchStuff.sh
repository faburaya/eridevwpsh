#!/bin/bash

# Starts a BSCS module in a separate XTERM window
# Usage: startModule module_name param1 param2 param3 ...
startModule()
{
    modName=$(echo "$1" | awk '{print toupper($0)}')
    scriptFileName=$(echo ~/_tempScript_start)$modName$RANDOM".sh"
    printf "\nStarting $modName...\n"
    echo "#!/bin/bash" >> $scriptFileName
    echo "$BSCS_BIN/"$@ >> $scriptFileName
    echo "read  -n 1 -p 'Press any key to close this window...' anything" >> $scriptFileName
    chmod +x $scriptFileName
    xterm -T $(hostname)" - "$modName $scriptFileName &
}

data &

# Start the modules before RDH instances, because X server takes a while to respond...
#startModule dih -r -s005 -t
#startModule fih -t
startModule prih -e -t
startModule rih -e -t
#startModule rih -e -t -p 2
startModule eoh -t
startModule cch -t
startModule rlh -13 -t1
startModule rlh --appl 3 --loadonly
startModule roh -mC -t1
startModule roh -mB -t1
startModule tsh -t1
#startModule aih -t
startModule bch -a0
startModule bch -a1
startModule bch -a2
startModule bch -a3
startModule bgh -l $BSCS_RESOURCE/bgh -b $BSCS_WORKDIR/DOCS

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

printf "\n##### RDH (CCH) #####\n\n"
rdh -t2 -cch &
sleep 3

printf "\n##### RDH (BCH) #####\n\n"
rdh -t2 -bch &
sleep 3

#prih -e -t &
#rih -e -t &
#eoh -t &
#cch -t &
#rlh -13 -t1 &
#bch -a0 &
#bch -a1 &
#bch -a2 &
#bch -a3 &
#bgh -l $BSCS_RESOURCE/bgh -b $BSCS_WORKDIR/DOCS &

# Wait for the modules to start...
sleep 30

printf "\n##### My Processes #####\n\n"
ps -ef | grep $(whoami) | grep -v grep | grep -v 'ps -ef' | grep -v sshd:
printf "\n"
