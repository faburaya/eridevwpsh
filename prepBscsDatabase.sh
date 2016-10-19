#!/bin/bash

##################################
# Define some helpers for colors #
##################################

export SetColorToRED='\033[0;31m';
export SetColorToLightRED='\033[1;31m';
export SetColorToYELLOW='\033[0;33m';
export SetColorToLightYELLOW='\033[1;33m';
export SetColorToGREEN='\033[0;32m';
export SetColorToLightGREEN='\033[1;32m';
export SetColorToBLUE='\033[0;34m';
export SetColorToLightBLUE='\033[1;34m';
export SetColorToWHITE='\033[0;37m';
export SetNoColor='\033[0m';

#############
# Functions #
#############

sqlScriptsPath=$(echo ~/scripts)
buildsPath=$(echo ~/builds/)

# Clean-up a given database
# param 1 = name of the database to clean-up
function cleanUpDatabase()
{
    local databaseName=$1
    printf "\n${SetColorToLightBLUE}Cleaning up ${databaseName}...${SetNoColor}\n"   

    local tablespaceName1=$(sqlplus -S SYSTEM/SYSADM@$BSCSDB << EOF | grep 'oradata'
SELECT '''' || FILE_NAME || '''' FROM DBA_DATA_FILES WHERE TABLESPACE_NAME='SYSAUX';
EOF
)
    local tablespaceName2=$(sqlplus -S SYSTEM/SYSADM@$BSCSDB << EOF | grep 'oradata'
SELECT '''' || FILE_NAME || '''' FROM DBA_DATA_FILES WHERE TABLESPACE_NAME='SYSTEM';
EOF
)
    local tablespaceName3=$(sqlplus -S SYSTEM/SYSADM@$BSCSDB << EOF | grep 'oradata'
SELECT '''' || FILE_NAME || '''' FROM DBA_DATA_FILES WHERE TABLESPACE_NAME='DATA';
EOF
)

    printf "ALTER DATABASE DATAFILE ${tablespaceName1} AUTOEXTEND ON MAXSIZE UNLIMITED;
            ALTER DATABASE DATAFILE ${tablespaceName2} AUTOEXTEND ON MAXSIZE UNLIMITED;
            ALTER DATABASE DATAFILE ${tablespaceName3} AUTOEXTEND ON MAXSIZE UNLIMITED;
            @${sqlScriptsPath}/clean_database_ora12.sql;
            quit\n" > fix.sql
    
    sqlplus -L SYSTEM/SYSADM@$BSCSDB @fix.sql || exit -1
}

# Exports a dump from a database into another one
# param 1 = name of the database whose dump will be exported
# param 2 = name of the database into which the dump will be imported
function exportDatabaseDump()
{
    local dumpDatabase=$1
    local targetDatabase=$2
    local dumpsDir="/home/$(whoami)/DUMPS"
    printf "\n${SetColorToLightBLUE}Exporting dump from ${dumpDatabase} to import into ${targetDatabase}...${SetNoColor}\n"
    
    # set data pump directory:
    ls ~/DUMPS > /dev/null 2> /dev/null || mkdir ~/DUMPS
    cp /home/systest/gitViews/GIT_qatd/util/datapump/config/.datapump.user.properties ~
    printf "global.localDumpDir=${dumpsDir}\n" > ~/.datapump.user.properties
    
    # set environment:
    export ST_TOOL_VIEW_ROOT=/home/systest/gitViews/GIT_qatd
    source /home/systest/util/shell/utilenv.sh > /dev/null
    source setapp java jdk1.7.0_76 > /dev/null
    
    if [ -n "$mustUseOracle12" ]
    then
        source setapp jdbc 12.1.0.2 > /dev/null
    else
        source setapp jdbc 11.2.0.3 > /dev/null
    fi
    
    # invoke dump export:
    cd /home/systest/ccviews/ST_TOOLS_generic/vobs/but_qatd/systest/util/
    exp_dp.sh $dumpDatabase $(whoami)
    
    # now import the dump into the target database:
    local fileNameDump=$(ls -tr $dumpsDir | grep -E "${dumpDatabase}.*\.dp\.dmp\.bz2$" | tail -1)
    if [ -n "${fileNameDump}" ]
    then
        printf "\n${SetColorToLightBLUE}Importing the dump into ${targetDatabase}...${SetNoColor}\n\n"
        imp_dp.sh $targetDatabase $fileNameDump
        imp_dp_BISADM.sh $targetDatabase $fileNameDump
    else
        printf "${SetColorToLightRED}ERROR: failed to create dump of database ${dumpDatabase}!${SetNoColor}\n\n"
        exit -2
    fi
}

# Imports an already existing dump into the given database
# param 1 = name of the database whose dump will be imported
# param 2 = name of the database into which the dump will be imported
function importDatabaseDump()
{
    local dbDumpOrigin=$1
    local dbDumpDestination=$2
    local dumpsDir="/home/$(whoami)/DUMPS"
    printf "\n${SetColorToLightBLUE}Importing dump from ${dbDumpOrigin} into ${dbDumpDestination}...${SetNoColor}\n"
    
    # set data pump directory:
    ls ~/DUMPS > /dev/null 2> /dev/null || mkdir ~/DUMPS
    cp /home/systest/gitViews/GIT_qatd/util/datapump/config/.datapump.user.properties ~
    printf "global.localDumpDir=${dumpsDir}\n" > ~/.datapump.user.properties
    
    # set environment:
    export ST_TOOL_VIEW_ROOT=/home/systest/gitViews/GIT_qatd
    source /home/systest/util/shell/utilenv.sh > /dev/null
    source setapp java jdk1.7.0_76 > /dev/null
    
    if [ -n "$mustUseOracle12" ]
    then
        source setapp jdbc 12.1.0.2 > /dev/null
    else
        source setapp jdbc 11.2.0.3 > /dev/null
    fi
    
    # invoke dump import:
    local fileNameDump=$(ls -tr $dumpsDir | grep -E "${dbDumpOrigin}.*\.dp\.dmp\.bz2$" | tail -1)
    if [ -n "${fileNameDump}" ]
    then
        cd /home/systest/ccviews/ST_TOOLS_generic/vobs/but_qatd/systest/util
        imp_dp.sh $dbDumpDestination $fileNameDump
        imp_dp_BISADM.sh $dbDumpDestination $fileNameDump
    else
        printf "${SetColorToLightRED}ERROR: dump for database ${dbDumpOrigin} could not be found!${SetNoColor}\n\n"
        exit -3
    fi
}

# Downloads a DMF build from Jenkins and extracts the content
# param 1 = the URL to download
function downloadAndExtractDmfBuild()
{
    local url=$1
    printf "\n${SetColorToLightBLUE}Downloading DMF build from Jenkins...${SetNoColor}\n\n"
    fileName=$(echo "${url}" | sed 's/.*\/\([^\/]*\)$/\1/')
    subDir="DMF["$(date +"%Y-%b-%d-%H%M%S")"]"
    cd $buildsPath || exit -4
    mkdir $subDir
    cd $subDir
    pathToDmfBuild=$(pwd)
    wget $url && tar -xvf $fileName | xargs -I{} tar -xf {}
    rm d*.tar 1> /dev/null
    ls $fileName || exit -5
}

# Run DMF build from Jenkins
# param 1 = path to the already extracted DMF build from Jenkins
# param 2 = name of the database where the DMF must run
function runDmfBuild()
{
    local pathToBuild=$1
    local databaseName=$2
    
    eval "cd ${pathToBuild} || exit -6"
    
    # Apply fixes for FullStack bullshit:
    if [ -n "$isFullStack" ]
    then
        printf "\n${SetColorToLightBLUE}Applying fixes to FullStack database before running DMF...${SetNoColor}\n"

        sqlplus -S -L SYSTEM/SYSADM << EOF
ALTER USER SYS IDENTIFIED BY SYSADM;
EOF
        sqlplus -L SYS/SYSADM@$BSCSDB AS SYSDBA @dmf/dab/admin/orasys/MIGC_user_system_1_sys.sql || exit -7
        
        printf "GRANT SELECT ON DBA_SYNONYMS TO DMFADM;
                GRANT SELECT ON V_\$SESSION TO SYSADM WITH GRANT OPTION;
                GRANT SELECT ON V_\$DATABASE TO SYSADM WITH GRANT OPTION;
                GRANT SELECT ON DBA_TAB_COLUMNS TO DMFADM;
                GRANT INHERIT ANY PRIVILEGES TO DMFADM;
                ALTER PACKAGE DMFADM.DABUTIL COMPILE;
                ALTER PACKAGE DMFADM.MIGSERVICE COMPILE;
                UPDATE RTX_CONTROL SET NAME_RTX_DB='${BSCSDB}';
                COMMIT;
                quit\n" > fix.sql

        sqlplus -L SYS/SYSADM@$BSCSDB AS SYSDBA @fix.sql  || exit -8
    fi
    
    chmod +x dmf/scripts/*.esh

    printf "\n${SetColorToLightBLUE}Configuring DMF...${SetNoColor}\n"
    
    # disable MX:
    export lineNumberToReplace=$(cat database/share/standard_1_par.xml | grep -n '<PARA xsi:type="PString" Key="MX">' | awk '{print $1}' | cut -d ':' -f 1)
    let lineNumberToReplace+=1
    sed -ie $lineNumberToReplace" s/true/false/g" database/share/standard_1_par.xml
    
    # set environment:
    source setapp perl 5.8.8 > /dev/null
    source setapp cmp 5.8 > /dev/null
    source setapp xerces xerces_c2_3_0 > /dev/null

    cd dmf
    source scripts/dmfenv.esh > /dev/null
    source scripts/migenv.esh dmf > /dev/null
    cd ..
    source migenv.esh bscs --mig_root_dir $PWD --mig_setup_dir $PWD/database/share > /dev/null
    cd database/share
    sed -ie "s/<DB_NAME>.*.<\/DB_NAME>/<DB_NAME>${databaseName}<\/DB_NAME>/g" standard_1_res.xml
    
    printf "\n${SetColorToLightBLUE}Running DMF...${SetNoColor}\n"
    
    # show time:
    printf "\n${SetColorToLightYELLOW}MigStart.pl start --setup_file standard_upgrade_1_set.xml ...${SetNoColor}\n"
    MigStart.pl start --setup_file standard_upgrade_1_set.xml 2>&1 | grep -B8 -A8 DMF_ERROR > $pathToBuild/dmfRunLog.txt
    printf "\n${SetColorToLightYELLOW}MigStart.pl init --setup_file standard_upgrade_1_set.xml ...${SetNoColor}\n"
    MigStart.pl init --setup_file standard_upgrade_1_set.xml 2>&1 | grep -B8 -A8 DMF_ERROR >> $pathToBuild/dmfRunLog.txt
    printf "\n${SetColorToLightYELLOW}MigStart.pl start --setup_file standard_upgrade_1_set.xml ...${SetNoColor}\n"
    MigStart.pl start --setup_file standard_upgrade_1_set.xml 2>&1 | grep -B8 -A8 DMF_ERROR >> $pathToBuild/dmfRunLog.txt
}

##################################
# PARSING COMMAND LINE ARGUMENTS #
##################################

helpUsageText="
Usage:

prepBscsDatabase.sh targetDatabaseName
                    [ora12][fullstack]
                    [clean]
                    [build=pathToDirDmfBuildFromJenkins | download=urlToDownloadDmfBuildFromJenkins]
                    [export=databaseNameWhoseDumpMustBeExported | import=databaseNameWhoseDumpMustBeImported]
                    [dmf]
"

printf "\n"

targetDatabaseName=$1

# is the name of target database present?
if [ -z "$targetDatabaseName" ]
then
    printf "${SetColorToLightRED}Incorrect syntax: name of the target database is missing!${SetNoColor}\n$helpUsageText"
    exit 1

# does the first parameter looks like a name for target database?
elif [ $targetDatabaseName != $(echo "${targetDatabaseName}"  | grep '^[0-9a-zA-Z_\.]*$') ]
then
    printf "${SetColorToLightRED}Incorrect syntax: name for target database seems to be invalid ($targetDatabaseName)${SetNoColor}\n$helpUsageText"
    exit 2
fi

parameters=("$@")
for ((idx=1 ; idx < ${#parameters[*]} ; ++idx))
do
    param=${parameters[idx]}
    
    # must clean-up the database
    if [ $(echo $param | awk '{print tolower($0)}') = "ora12" ]
    then
        if [ -z "$mustUseOracle12" ]
        then
            mustUseOracle12=1
            echo "* Toolset for Oracle 12 will used"
        fi
    
    # is the BSCS database FullStack?
    elif [ $(echo $param | awk '{print tolower($0)}') = "fullstack" ]
    then
        isFullStack=1
        echo "* Fixes for FullStack database will be applied"
    
    # must clean-up the database
    elif [ $(echo $param | awk '{print tolower($0)}') = "clean" ]
    then
        if [ -z "$mustCleanUpDatabase" ]
        then
            mustCleanUpDatabase=1
            echo "* Database ${targetDatabaseName} will be cleaned up"
        fi

    # where the DMF build comes from?
    elif [ $(echo $param | grep -i '^build') ]
    then
        pathToDmfBuild=$(echo ${param} | awk -F"=" '{print $2}')
        echo "* Use jenkins build in ${pathToDmfBuild}"
    
    # has to download the DMF build?
    elif [ $(echo $param | grep -i '^download') ]
    then
        urlJenkinsDmfBuild=$(echo ${param} | awk -F"=" '{print $2}')
        echo "* Download DMF build from Jenkins"
    
    # must export dump from another database?
    elif [ $(echo $param | grep -i '^export') ]
    then
        # use of database dump implies that first the target must be cleaned up
        if [ -z "$mustCleanUpDatabase" ]
        then
            mustCleanUpDatabase=1
            echo "* Database ${targetDatabaseName} will be cleaned up"
        fi
        
        dbNameDumpToExport=$(echo ${param} | awk -F"=" '{print $2}')
        echo "* Export a dump from database ${dbNameDumpToExport}"
        echo "* Import the database dump into ${targetDatabaseName} (implies a previous clean-up)"
    
    # must import an already existent database dump?
    elif [ $(echo $param | grep -i '^import') ]
    then
        # use of database dump implies that first the target must be cleaned up
        if [ -z "$mustCleanUpDatabase" ]
        then
            mustCleanUpDatabase=1
            echo "* Database ${targetDatabaseName} will be cleaned up"
        fi
        
        dbNameDumpToImport=$(echo ${param} | awk -F"=" '{print $2}')
        echo "* Import a dump from database ${dbNameDumpToImport} into ${targetDatabaseName} (implies a previous clean-up)"
    
    # must run the DMF
    elif [ $(echo $param | awk '{print tolower($0)}') = "dmf" ]
    then
        mustRunDmf=1
        echo "* DMF build will run in ${targetDatabaseName}"
    
    # unrecognized option
    else
        printf "${SetColorToLightRED}Incorrect syntax: option '${param}' is not recognized!${SetNoColor}$helpUsageText"
        exit 3
    fi
done

printf "\n"
read -n 1 -p "Press any key to start" whatever

######################
# TEST FOR COHERENCE #
######################

# Wrong usage! Both options 'build' and 'download' have been specified
if [ -n "${pathToDmfBuild}" ] && [ -n "${urlJenkinsDmfBuild}" ]
then
    printf "${SetColorToLightRED}
    Wrong parameters: the jenkins build is either already available or must be downloaded.
    The options 'build' and 'download' are not supposed to be seen together!
    ${SetNoColor}$helpUsageText"
    exit 4

# Wrong usage! Has to run DMF, but none of the options build/download has been specified
elif [ -n "$mustRunDmf" ] && [ -z "${pathToDmfBuild}" ] && [ -z "${urlJenkinsDmfBuild}" ]
then
    printf "${SetColorToLightRED}
    Wrong parameters: the jenkins build must be available already extracted to a directory
    or to be downloaded. None of the options 'build' or 'download' have been specified!
    ${SetNoColor}$helpUsageText"
    exit 5

# Wrong usage! Both options 'export' and 'import' have been specified
elif [ -n "${dbNameDumpToExport}" ] && [ -n "${dbNameDumpToImport}" ]
then
    printf "${SetColorToLightRED}
    Wrong parameters: you can either export a dump from another database and apply it
    into yours, or import an already existing one. The options 'export' and 'import' are
    not supposed to be seen together!
    ${SetNoColor}$helpUsageText"
    exit 6

# Wrong usage! Database will be cleaned up before DMF run, but none of the options import/export has been specified
elif [ -n "$mustCleanUpDatabase" ] && [ -n "$mustRunDmf" ] && [ -z "${dbNameDumpToExport}" ] && [ -z "${dbNameDumpToImport}" ]
then
    printf "${SetColorToLightRED}
    Wrong parameters: after cleaning up the target database, you need a database dump
    before running the DMF. None of the options 'export' or 'import' have been specified!
    ${SetNoColor}$helpUsageText"
    exit 7
fi

#############
# SHOW TIME #
#############

if [ -n "$mustUseOracle12" ]
then
    source setapp oracle 12.1.0.2.0.64 1> /dev/null
else
    source setapp oracle 11.2.0.4.0.64 1> /dev/null
fi

source ~/definedb $targetDatabaseName 1> /dev/null

# Clean-up target database:
if [ -n "$mustCleanUpDatabase" ]
then
    cleanUpDatabase $targetDatabaseName
fi

# Export dump from another database and import it into the target:
if [ -n "${dbNameDumpToExport}" ]
then
    exportDatabaseDump $dbNameDumpToExport $targetDatabaseName
fi

# Import an existing dump into the target database:
if [ -n "${dbNameDumpToImport}" ]
then
    importDatabaseDump $dbNameDumpToImport $targetDatabaseName
fi

# Download a DMF build from Jenkins:
if [ -n "${urlJenkinsDmfBuild}" ]
then
    downloadAndExtractDmfBuild $urlJenkinsDmfBuild
fi

# Run DMF build:
if [ -n "$mustRunDmf" ]
then
    runDmfBuild $pathToDmfBuild $targetDatabaseName
fi
