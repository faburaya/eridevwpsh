#!/bin/bash

printf "Shutting down DaTA...\n"
dmh --shutdown
sleep 5

printf "\nCleaning shared memory:\n"
~/gitViews/release_bscsix4_master/lhsj_main/bscs/batch/src/rdh/delShm.sh

rm ~/_tempScript_*.sh 2> /dev/null

printf "\n##### My Processes #####\n\n"
ps -ef | grep $(whoami) | grep -v grep | grep -v 'ps -ef' | grep -v sshd:
printf "\n"
