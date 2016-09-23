#!/bin/bash

. ~/configGMD.sh

printf "\nStarting naming service...\n"
#nohup $BSCS_SCRIPTS/startNamingService.sh > namingService.out &
xterm -T $(hostname)' - Naming Service' $BSCS_SCRIPTS/startNamingService.sh &
sleep 3
#tail -3 namingService.out

printf "\nStarting federated factory...\n"
#nohup $BSCS_SCRIPTS/startFF.sh > fedFactory.out &
xterm -T $(hostname)' - Federated Factory' $BSCS_SCRIPTS/startFF.sh &
sleep 10
#tail -3 fedFactory.out

printf "\nStarting CMS & PMS...\n"
#nohup $BSCS_SCRIPTS/start_cms.sh > cms.out &
#nohup $BSCS_SCRIPTS/start_pms.sh > pms.out &
xterm -T $(hostname)' - CMS' $BSCS_SCRIPTS/start_cms.sh &
xterm -T $(hostname)' - PMS' $BSCS_SCRIPTS/start_pms.sh &
sleep 15
#tail -3 cms.out
#tail -3 pms.out

printf "\nStarting billing server...\n"
#nohup $BSCS_SCRIPTS/startBillSrv.sh > billServer.out &
xterm -T $(hostname)' - Billing Server' $BSCS_SCRIPTS/startBillSrv.sh &
sleep 3
#tail -3 billServer.out

# Should deploy CX & AX from new java build?
if [ "$1" = "deploy" ]
then
    $BSCS_SCRIPTS/deploy_custcare.sh cu
    $BSCS_SCRIPTS/deploy_ax.sh full
fi

printf "\nStarting tomcat web server...\n"
$TOMCAT_HOME/bin/startup.sh

# Automatic setup and start of GMD
configAndStartGMD
