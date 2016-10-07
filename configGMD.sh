#!/bin/bash

. ~/AUTOMATION/libs/shell/batch_common.sh

#####################
# GMD 
#####################

# Gets all endpoints of the local network interface.
# param 1 = network protocol as displayed in netstat (tcp, udp...)
function getLocalEndpoints()
{
    eval "netstat -anl | grep $1 | grep -o ' "$(ifconfig | grep -o 'addr:[ ]*[0-9\.:a-z]*' | sed 's/addr:[ ]*//g' | xargs -I{} echo "{}:[0-9]*\|")"dummy'" | sed 's/ //g' | sort | uniq;
}

# Selects ports from /etc/services
# param 1 = network protocol as displayed in /etc/services (egz.: tcp, udp...)
# param 2 = filter to apply (egz.: GMD, VMD, ...)
function getServicePorts()
{
    local reservedTcpPorts=$(cat /etc/services | grep $1 | grep $2 | sed 's/\/'$1'//g')
    
    if [ $(printf "${reservedTcpPorts}" | wc -l) -gt 0 ]
    then
        echo "${reservedTcpPorts}"
    else
        seq 50500 50515 | xargs -I{} echo "GMD{} {} # TCP port {}"
    fi
}

# Configures GMD in the database
function configAndStartGMD()
{
    printf "\n##### GMD Setup & Start #####\n\n"

    printf "Looking for an available TCP port for GMD service... "

    # Text for a command filter that removes all entries including TCP ports in use by the local NIC:
    txtCmdFilterOutLocalTcpPortsInUse=$(getLocalEndpoints tcp | grep -o ':[0-9]*$' | sed 's/://g' | xargs -I{} echo "| grep -v '{}[^0-9]'")

    # Query the database table MSDSVTAB so as to figure which have already been taken by other GMD services:
    query="SELECT PORT FROM MSDSVTAB WHERE SUBTYPE <> 'R';"
    sqlResult=$(executeQuery "${query}")
    txtCmdFilterOutPortsAlreadyTaken=$(echo $sqlResult | sed 's/ / \| grep -v /g')
    
    [[ $txtCmdFilterOutPortsAlreadyTaken = *[![:space:]]* ]] && txtCmdFilterOutPortsAlreadyTaken="| grep -v "$txtCmdFilterOutPortsAlreadyTaken

    # Get the key for the first free port available to our GMD service:
    gmdSvcTcpPortKey=$(eval "getServicePorts tcp GMD "$txtCmdFilterOutLocalTcpPortsInUse$txtCmdFilterOutPortsAlreadyTaken | head -1 | awk -F" " '{print $1}')

    if [ -z "$gmdSvcTcpPortKey" ]
    then
        printf "${SetColorToLightRED}FAILED!\nCould not find a free port available to GMD :(${SetNoColor}\n"
        exit 1
    fi

    printf "DONE!\n${SetColorToLightGREEN}GMD service will be configured to use TCP port '$gmdSvcTcpPortKey' :)${SetNoColor}\n"

    printf "Setting MSDSVTAB.PORT = '$gmdSvcTcpPortKey' for SUBTYPE 'R'...\n"
    query="UPDATE MSDSVTAB SET PORT = '${gmdSvcTcpPortKey}' WHERE SUBTYPE = 'R';"
    sqlResult=$(executeQuery "${query}")

    printf "Setting MSDSVTAB.HOST = '${HOSTNAME}' for all rows...\n"
    query="UPDATE MSDSVTAB SET HOST = '${HOSTNAME}';"
    sqlResult=$(executeQuery "${query}")

    printf "Selecting GMD service ID from MSDSVTAB... "
    query="SELECT SRV_ID FROM MSDSVTAB WHERE SUBTYPE = 'R';"
    gmdSvcId=$(executeQuery "${query}")

    if [ -z "$gmdSvcId" ]
    then
        printf "${SetColorToLightRED}FAILED!\nCould not get MSDSVTAB.SRV_ID for SUBTYPE 'R' :(${SetNoColor}\n"
        exit 2
    fi

    printf "DONE!\n${SetColorToLightGREEN}GMD service ID is '$gmdSvcId' :)${SetNoColor}\n"

    printf "Looking for an available TCP port for VMD... "

    # Query the database table MSDSVTAB so as to figure which have already been taken by other GMD services:
    query="SELECT PORT FROM MSDSVTAB;"
    sqlResult=$(executeQuery "${query}")
    txtCmdFilterOutPortsAlreadyTaken="| grep -v "$(echo $sqlResult | sed 's/ / \| grep -v /g')

    # Get the key for the first free port available to VMD:
    vmdTcpPortKey=$(eval "getServicePorts tcp VMD "$txtCmdFilterOutLocalTcpPortsInUse$txtCmdFilterOutPortsAlreadyTaken | head -1 | awk -F" " '{print $1}')

    if [ -z "$vmdTcpPortKey" ]
    then
        printf "${SetColorToLightRED}FAILED!\nCould not find a free port available to VMD :(${SetNoColor}\n"
        exit 3
    fi

    printf "DONE!\n${SetColorToLightGREEN}TCP port '$vmdTcpPortKey' will be used :)${SetNoColor}\n"

    printf "Setting GMD_DESTINATION.PORT = '$vmdTcpPortKey' for all rows...\n"
    query="UPDATE GMD_DESTINATION SET PORT = '${vmdTcpPortKey}';"
    sqlResult=$(executeQuery "${query}")

    printf "Setting GMD_DESTINATION.HOST = '${HOSTNAME}' for all rows...\n"
    query="UPDATE GMD_DESTINATION SET HOST = '${HOSTNAME}';"
    sqlResult=$(executeQuery "${query}")

    # Query the database tables of GMD so as to figure the SCCODE for the markets GSM & ISDN:
    printf "Turning on by-pass and clean-up for markets GSM and ISDN... "
    query="
        SELECT '''' || SCCODE || ''''
            FROM GMD_MARKET_SCHEMA schm
                INNER JOIN GMD_MARKET mrkt
                    ON mrkt.GMD_MARKET_ID = schm.GMD_MARKET_ID
            WHERE mrkt.DESCRIPTION IN ('GSM', 'ISDN');
    "
    sqlResult=$(executeQuery "${query}")
    csvListSCCodes=$(echo $sqlResult | sed 's/ /,/g')

    if [ -z "$csvListSCCodes" ]
    then
        printf "${SetColorToLightRED}FAILED!\nCould not retrieve SCCODE's for markets GSM and ISDN :(\n"
        exit 4
    fi

    query="
        UPDATE GMD_MPDSCTAB
            SET BYPASS_IND = 'Y',
                CLEAN_UP_LEVEL = 0
            WHERE SCCODE IN (${csvListSCCodes});
    "
    sqlResult=$(executeQuery "${query}")

    printf "\nFinished configuration of GMD. Starting services...\n\n"

    $BSCS_SCRIPTS/START_GMD -srv $gmdSvcId 1> /dev/null
    sleep 4
}

