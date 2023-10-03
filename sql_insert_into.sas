# inserting into autoincremented tables_to_drop variable
 
 select tablename, count(*) into:tables_to_drop1 - , :tables_to_drop_no from connection to TERADATA(
		sel upper(tablename) as tablename from "dbc"."tablesv" 
		where 
			upper(databasename)=upper(%str(%')EDWDSA&cry._&tdmiljo.%str(%')) 
			and upper(tablename) like upper('LINKGRC%')
      group by 1;
	);
