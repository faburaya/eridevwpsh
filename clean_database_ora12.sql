declare
cursor lcUsers is
   select username from dba_users
   where username not in
('AUDSYS','SYSBACKUP','SYSDG','SYSKM','XS$NULL','CTXSYS','OUTLN','SYS','SYSTEM','DBSNMP','WMSYS','TSMSYS','DIP', 'TALK', 'READ','DBADMIN','CARDADMIN', 'XDB', 'SYSMAN') order by 1 desc ;

cursor lcSynonyms is
   select owner,synonym_name from dba_synonyms
   where owner != 'PUBLIC'
     and table_owner not in
('AUDSYS','SYSBACKUP','SYSDG','SYSKM','XS$NULL','CTXSYS','OUTLN','SYS','SYSTEM','DBSNMP','WMSYS','TSMSYS','DIP', 'TALK', 'READ','DBADMIN','CARDADMIN','PERFSTAT', 'XDB', 'SYSMAN') order by 1 desc ;

cursor lcPSynonyms is
   select synonym_name from dba_synonyms
   where owner = 'PUBLIC'
     and table_owner not in
('AUDSYS','SYSBACKUP','SYSDG','SYSKM','XS$NULL','CTXSYS','OUTLN','SYS','SYSTEM','DBSNMP','WMSYS','TSMSYS','DIP', 'TALK', 'READ','DBADMIN','CARDADMIN','PERFSTAT', 'XDB', 'SYSMAN') order by 1 desc ;

cursor lcSequences is
   select sequence_name from all_sequences
   where sequence_owner not in
('AUDSYS','SYSBACKUP','SYSDG','SYSKM','XS$NULL','CTXSYS','OUTLN','SYS','SYSTEM','DBSNMP','WMSYS','TSMSYS','DIP', 'TALK', 'READ','DBADMIN','CARDADMIN','PERFSTAT', 'XDB', 'SYSMAN') order by 1 desc ;


begin

DBMS_OUTPUT.put_line('Dropping users...');
for i in lcUsers
loop
   execute immediate 'drop user "'||i.username ||'" cascade';
end loop;
DBMS_OUTPUT.put_line('Finished dropping users.');

DBMS_OUTPUT.put_line('Dropping synonyms...');
for i in lcSynonyms
loop
   execute immediate 'drop synonym ' || i.owner || '.' || i.synonym_name;
end loop;
DBMS_OUTPUT.put_line('Finished dropping synonyms.');

DBMS_OUTPUT.put_line('Dropping public synonyms...');
for i in lcPSynonyms
loop
   execute immediate 'drop public synonym ' || i.synonym_name;
end loop;
DBMS_OUTPUT.put_line('Finished dropping public synonyms.');

DBMS_OUTPUT.put_line('Dropping sequences...');
for i in lcSequences
loop
   execute immediate 'drop sequence ' || i.sequence_name;
end loop;
DBMS_OUTPUT.put_line('Finished dropping sequences.');


DBMS_OUTPUT.put_line('Clean up finished.');

end;
/

quit

