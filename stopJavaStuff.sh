#!/bin/bash

printf "\nStopping tomcat web server...\n"
$TOMCAT_HOME/bin/shutdown.sh

# Should clean CX & AX deployment?
if [ "$1" = "clean" ]
then
    printf "\nCleaning web app installation... "
    rm -rf $TOMCAT_HOME/webapps/ax_full
    rm -rf $TOMCAT_HOME/webapps/custcare_cu
    printf "DONE!\n"
fi

ps -ef | grep $(whoami) | grep -v grep | grep -v 'ps -ef' | grep -v sshd: |  grep -i 'tao_cosnaming\|fedfactory\|cms\|pms\|billsrv' | awk -F" " '{ print $2 }' | xargs -I{} kill {}

stopGMD()
{
    printf "\nStopping GMD...\n"
    $BSCS_SCRIPTS/STOP_GMD 1> /dev/null
    sleep 3
}

ls $BSCS_BIN/stop_md && stopGMD

printf "\n##### My Processes #####\n\n"
ps -ef | grep $(whoami) | grep -v grep | grep -v 'ps -ef' | grep -v sshd:
printf "\n"
