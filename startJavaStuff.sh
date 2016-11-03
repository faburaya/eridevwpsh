#!/bin/bash

. ~/scripts/configGMD.sh

# Starts a BSCS module in a separate XTERM window
# Usage: startModule module_name param1 param2 param3 ...
startModule()
{
    modName=$1
    scriptFileName=$(echo ~/_tempScript_start)$modName$RANDOM".sh"
    printf "\nStarting $modName...\n"
    echo "#!/bin/bash" >> $scriptFileName
    echo "$BSCS_BIN/"$2 >> $scriptFileName
    echo "read -n 1 -p 'Press any key to close this window...' anything" >> $scriptFileName
    chmod +x $scriptFileName
    xterm -T $(hostname)" - "$modName $scriptFileName &
}

# Should deploy CX & AX from new java build?
if [ "$1" = "deploy" ]
then
    chmod +x $BSCS_SCRIPTS/*.sh
fi

printf "\nStarting naming service...\n"
#nohup $BSCS_SCRIPTS/startNamingService.sh > namingService.out &
startModule "Naming Service" $BSCS_SCRIPTS/startNamingService.sh
sleep 3
#tail -3 namingService.out

printf "\nStarting federated factory...\n"
#nohup $BSCS_SCRIPTS/startFF.sh > fedFactory.out &
startModule "Federated Factory" $BSCS_SCRIPTS/startFF.sh
sleep 10
#tail -3 fedFactory.out

printf "\nStarting CMS & PMS...\n"
#nohup $BSCS_SCRIPTS/start_cms.sh > cms.out &
#nohup $BSCS_SCRIPTS/start_pms.sh > pms.out &
startModule "CMS" $BSCS_SCRIPTS/start_cms.sh
startModule "PMS" $BSCS_SCRIPTS/start_pms.sh
sleep 15
#tail -3 cms.out
#tail -3 pms.out

printf "\nStarting billing server...\n"
#nohup $BSCS_SCRIPTS/startBillSrv.sh > billServer.out &
startModule "Billing Service" $BSCS_SCRIPTS/startBillSrv.sh
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
