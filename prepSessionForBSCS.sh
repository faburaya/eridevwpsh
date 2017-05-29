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

if [ -z "$1" ]
then
    printf "${SetColorToRED}You must specify the database name!${SetNoColor}"
    exit 1
fi

########################################
# Environment Variables for BSCS batch #
########################################

export USE_DEBUG=1;
export RIH_SET_TRACE=1;
export TRACE_PRIH=1;
export TRACE_RIH=1;
export UDMAP_TRACEFILE=/home/aburayaf/BSCS/1/WORKDIR/TMP/UDMAP.trc
export AUT_DEBUG=1;
export BSCS_PASSWD=~/bscs.passwd;
export BSCS_WORKDIR=~/BSCS/1/WORKDIR;
export DATA_SERVER_ADDRESS=t:$(hostname):6960;
export SHM_ENTRY_KEY=0xdeedfeed;
export SHM_MAX_ENVIRONMENTS=30;
export SHM_MAX_SECTORS=10;
export SHM_MIN_SEGMENT_SIZE=16384;
export XFILESEARCHPATH=~/X11/%N;
export DCH_XML_FILENAME=dchflex_statement_configuration.xml;
export DCH_XML_PATHNAME=~/BSCS/1/DCH;
export CTQ_CFG_HOME_202=~/BSCS/1/VERTEX;
export ODBCINI=~/BSCS/1/VERTEX/odbc.ini;

echo Setting profile...
source setapp oracle 11.2.0.4.0.64 1> /dev/null
source ~/definedb $1 1> /dev/null
gitRepoPath=$(echo ~/gitViews/bss)
cd $gitRepoPath"/lhsj_main/bscs/bin"
source ./profile 1> /dev/null 2> /dev/null
cd $gitRepoPath"/lhsj_main/bscs/batch"

export PATH=$PATH:$BSCS_BIN;

echo "
###### ENVIRONMENT VARIABLES FOR BSCS BATCH ########

               USE_DEBUG = $USE_DEBUG
           RIH_SET_TRACE = $RIH_SET_TRACE
              TRACE_PRIH = $TRACE_PRIH
               TRACE_RIH = $TRACE_RIH
               AUT_DEBUG = $AUT_DEBUG
             BSCS_PASSWD = $BSCS_PASSWD
            BSCS_WORKDIR = $BSCS_WORKDIR
     DATA_SERVER_ADDRESS = $DATA_SERVER_ADDRESS
           SHM_ENTRY_KEY = $SHM_ENTRY_KEY
    SHM_MAX_ENVIRONMENTS = $SHM_MAX_ENVIRONMENTS
         SHM_MAX_SECTORS = $SHM_MAX_SECTORS
    SHM_MIN_SEGMENT_SIZE = $SHM_MIN_SEGMENT_SIZE
         XFILESEARCHPATH = $XFILESEARCHPATH
        DCH_XML_FILENAME = $DCH_XML_FILENAME
        DCH_XML_PATHNAME = $DCH_XML_PATHNAME
        CTQ_CFG_HOME_202 = $CTQ_CFG_HOME_202
                 ODBCINI = $ODBCINI
";

############################################
# Environment Variables for BSCS java shit #
############################################

# Get from TNSPING the database hostname and the port number for its connection:
oradb_tnsping_out=$(tnsping $BSCSDB | grep "Attempting to contact");

export SOISRV_DATABASE_NAME=$BSCSDB;
export SOISRV_DATABASE_PORT=$(echo $oradb_tnsping_out | sed 's/.*Port=\([0-9]*\).*/\1/');
export SOISRV_DATABASE_SERVER=$(echo $oradb_tnsping_out | sed 's/.*Host=\([^\)]*\).*/\1/');

if [ -z "$SOISRV_DATABASE_PORT" ]
then
    SOISRV_DATABASE_PORT="${SetColorToRED}[ERROR: tnsping failed to resolve port for $BSCSDB]${SetNoColor}"
fi

if [ -z "$SOISRV_DATABASE_SERVER" ]
then
    SOISRV_DATABASE_SERVER="${SetColorToRED}[ERROR: tnsping failed to resolve host for $BSCSDB]${SetNoColor}"
fi

export SOISRV_HOST=$(hostname);
export SOISRV_PORT=6961;

export TOMCAT_HOME=~/tomcat/tomcat-8.0.32;
export CATALINA_HOME=$TOMCAT_HOME;
export EMB_TOM_DIR=$TOMCAT_HOME;
export EMB_TOM_PORT=6966;

echo -e "
###### ENVIRONMENT VARIABLES FOR BSCS JAVA SHIT ######

      SOISRV_DATABASE_NAME = $SOISRV_DATABASE_NAME
      SOISRV_DATABASE_PORT = $SOISRV_DATABASE_PORT
    SOISRV_DATABASE_SERVER = $SOISRV_DATABASE_SERVER
    
               SOISRV_HOST = $SOISRV_HOST
               SOISRV_PORT = $SOISRV_PORT
               
               TOMCAT_HOME = $TOMCAT_HOME
             CATALINA_HOME = $CATALINA_HOME
               EMB_TOM_DIR = $EMB_TOM_DIR
              EMB_TOM_PORT = $EMB_TOM_PORT
"

###########
# Helpers #
###########

shopt -s expand_aliases

list_error_files() # list error log of (grep search key)
{
    ls -ltr $BSCS_WORKDIR/TMP | grep -i " $1.*\.err$";
    ls -ltr $BSCS_LOG/$(echo $1 | awk '{print tolower($0)}') 2> /dev/null | grep -i "\.err$";
}

view_last_error_file() #view last error log of (grep search key)
{
    less $BSCS_WORKDIR/TMP/$(ls -tr $BSCS_WORKDIR/TMP | grep -i "^$1.*\.ERR$" | tail -1);
}

list_log_trace_files() # list trace files of (grep search key)
{
    ls -ltr $BSCS_WORKDIR/LOG | grep -i " $1.*\.trc$";
    ls -ltr $BSCS_LOG/$(echo $1 | awk '{print tolower($0)}') 2> /dev/null | grep -i "\.trc$";
}

view_last_log_trace_file() #view last trace file of (grep search key)
{
    less $BSCS_WORKDIR/LOG/$(ls -tr $BSCS_WORKDIR/TMP | grep -i "^$1.*\.trc$" | tail -1);
}

list_log_files() # list log files of (grep search key)
{
    ls -ltr $BSCS_WORKDIR/LOG | grep -i " $1.*\.log$\| $1.*\.ctr$";
    ls -ltr $BSCS_LOG/$(echo $1 | awk '{print tolower($0)}') 2> /dev/null | grep -i "\.log$\|\.ctr$";
}

view_last_log_file() #view last log file of (grep search key)
{
    less $BSCS_WORKDIR/LOG/$(ls -tr $BSCS_WORKDIR/TMP | grep -i "^$1.*\.log$" | tail -1);
}

alias lserr=list_error_files;
alias vwlerr=view_last_error_file;
alias lslog=list_log_files;
alias vwllog=view_last_log_file;
alias lstrc=list_log_trace_files;
alias vwltrc=view_last_log_trace_file;

list_bch_xml_docs() # list billing documents for (grep search key: bill req no)
{
    find $BSCS_WORKDIR/DOCS/BCH$1/SEQ0/ | grep '\.xml$'
}

shutdown_module() # shutdown module (grep search key)
{
    fiot -MI -B 494:$(hostname):$(ps -ef | grep $(whoami) | grep '^$1' | grep -v grep | grep -v rdh | awk '{print $2}'):5
}

rebuild_batch_modules()
{
    cd $gitRepoPath"/lhsj_main/bscs/batch"
    gmake purge
    find . | grep '\.so$\|\.o$' | xargs rm
    gmake -s $@
    ls -ltr $BSCS_BIN
}

display_my_processes()
{
    printf "\n##### My Processes #####\n\n"
    ps -ef | grep $(whoami) | grep -v grep | grep -v 'ps -ef' | grep -v sshd:
    printf "\n"
}

alias bchdocs=list_bch_xml_docs;
alias shutmod=shutdown_module;
alias rebuild=rebuild_batch_modules;
alias lsbins="ls -ltr $BSCS_BIN";
alias myps=display_my_processes;

alias %headers="find . | grep '\.h$\|\.hpp$\|\.inc$\|\.def$'";
findInHeaders() { %headers | xargs grep -n "$@"; }
alias @headers=findInHeaders;

alias %source="find . | grep '\.c$\|\.cpp$\|\.pc$\|\.pcpp$'";
findInSource() { %source | xargs grep -n "$@"; }
alias @source=findInSource;

alias %sql="find . | grep '\.sql$'";
findInSql() { %sql | xargs grep -in "$@"; }
alias @sql=findInSql;

display_my_helpers()
{
    echo "
#################### HELPERS ######################

      lserr: list error log files
     vwlerr: view last error log file
      lslog: list log files
     vwllog: view last log file
      lstrc: list trace log files
     vwltrc: view last log trace file
    
    bchdocs: list BCH XML documents
    shutmod: shutdown BSCS module
    rebuild: clean all & build the given modules
     lsbins: list BSCS binaries
       myps: list my processes
    
    %headers: list C/C++ headers files
    @headers: search into C/C++ headers
     %source: list C/C++ source files
     @source: search into C/C++ source
    ";
}

alias helpers=display_my_helpers;
helpers
