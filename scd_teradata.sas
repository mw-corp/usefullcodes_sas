/* macro edw_load_using_eff_end_dates*/
%macro edw_load_using_eff_end_dates();



	/* DI cannot properly set commas between variables ... need to do ist myself */
	%let UPDATE_KEY_COLUMNS = %sysfunc(translate(%sysfunc(strip(%sysfunc(COMPBL(&UPDATE_KEY_COLUMNS.)))),',',' '));
	%let UPDATE_DATA_COLUMNS = %sysfunc(translate(%sysfunc(strip(%sysfunc(COMPBL(&UPDATE_DATA_COLUMNS.)))),',',' '));

	/* Extract schema for input */
	proc sql noprint;
		select 
			 upcase(libname)
			,upcase(sysvalue)
		into
			 : _INPUT1_libname
			,: _INPUT1_sysvalue
		from
			dictionary.libnames
		where 
			engine = "TERADATA" 
			and libname = scan("&_INPUT1.",1);
	quit;

	/* Extract schema for output */
	proc sql noprint;
		select 
			 upcase(libname)
			,upcase(sysvalue)
		into
			 : _OUTPUT1_libname
			,: _OUTPUT1_sysvalue
		from
			dictionary.libnames
		where 
			engine = "TERADATA" 
			and libname = scan("&_OUTPUT1.",1);
	quit;


	
	/* Show calculated schemas */
	%put _INPUT1_libname: &_INPUT1_libname.;
	%put _INPUT1_sysvalue: &_INPUT1_sysvalue.;
	%put _OUTPUT1_libname: &_OUTPUT1_libname.;
	%put _OUTPUT1_sysvalue: &_OUTPUT1_sysvalue.;

	/* Prepare input and output tables in Teradata format */
	%let IN_CALCULATED = ;
	%let OUT_CALCULATED = ;
	%let IN_CALCULATED = %sysfunc(strip(&_INPUT1_sysvalue.)).%SCAN(&_INPUT1.,2);
	%let OUT_CALCULATED = %sysfunc(strip(&_OUTPUT1_sysvalue.)).%SCAN(&_OUTPUT1.,2);
	%put IN_CALCULATED: &IN_CALCULATED.;
	%put OUT_CALCULATED: &OUT_CALCULATED.;

	
	/* check if load of same date or newer data only - if not - do not accept */	
	%let IS_OK_F=;
	proc sql;
	   connect to TERADATA
	   ( 
	       &_OUTPUT1_connect. 
	   ); 
		select strip(IS_OK_F)  
			into :IS_OK_F
			from connection to TERADATA	   
	   ( 
		sel 
				case when (&&UPDATE_DATE_EFF. >= max(EFF_DT) or max(eff_dt) is null) then '1' else '0' end as IS_OK_F
			from &OUT_CALCULATED.
			where EFF_DT <= END_DT 
	   ) ; 
	   /*execute (commit) by TERADATA; */
	   disconnect from TERADATA; 
	quit;
	
	/* ABORT if trying to load older data */
	%put IS_OK_F: &IS_OK_F.;
	%IF &IS_OK_F. eq 0 %then %do;
		%put Stopping because newest EFF_DT in output table is newer than date used as input "&&UPDATE_DATE_EFF.";
		%abort abend 123;
	%end;
	
	
	/* Check if the temporary table exist, if yes then drop it */
	%LET tmpData  =  EDWVOLAT.EFFENDTMP_DIFF01&BTCH_POOL.;
	%LET tmpData2 =  EDWVOLAT.EFFENDTMP_DIFF02&BTCH_POOL.;
	
	%if %SYSFUNC(exist(&tmpData, DATA)) %then %do;
		proc sql;
		drop table &tmpData;
		drop table &tmpData2;
		quit;
		
	%end;

	
	
	
	/* calculate new data that has changed */
	proc sql;
	   connect to TERADATA
	   ( 
	       &_OUTPUT1_connect. 
	   ); 
	   execute 
	   ( 
			create volatile multiset table EFFENDTMP_DIFF01&BTCH_POOL., no log as (
				sel &UPDATE_KEY_COLUMNS. , &UPDATE_DATA_COLUMNS. 
					from &IN_CALCULATED.
				minus 
				sel &UPDATE_KEY_COLUMNS. , &UPDATE_DATA_COLUMNS. 
					from &OUT_CALCULATED.
					where &&UPDATE_DATE_EFF. between EFF_DT and END_DT 
			) with data on commit preserve rows
	   ) by TERADATA; 
	   execute (commit) by TERADATA; 
	   disconnect from TERADATA; 
	quit;



	/* update in output the data that needs to be closed */
	proc sql;
	   connect to TERADATA
	   ( 
	       &_OUTPUT1_connect. 
	   ); 
	   execute 
	   ( 
			update &OUT_CALCULATED.
				set END_DT = &&UPDATE_DATE_EFF. - 1
				where 1=1
					and (&UPDATE_KEY_COLUMNS.) in (sel &UPDATE_KEY_COLUMNS. from EFFENDTMP_DIFF01&BTCH_POOL.)
					and &&UPDATE_DATE_EFF. between EFF_DT and END_DT 
	   ) by TERADATA;
	   execute (commit) by TERADATA; 
	   disconnect from TERADATA; 
	quit;


	/* Create volatile table with inserts with new data */
	proc sql;
	   connect to TERADATA
	   ( 
	       &_OUTPUT1_connect. 
	   ); 
	   execute 
	   ( 
			create volatile multiset table EFFENDTMP_DIFF02&BTCH_POOL., no log as (
				sel 
						  &UPDATE_KEY_COLUMNS.
						, &UPDATE_DATA_COLUMNS.
						, &&UPDATE_DATE_EFF. as EFF_DT
						, date'2999-12-31' as END_DT
						, &PPN_EV_ID. as PPN_EV_ID
					from EFFENDTMP_DIFF01&BTCH_POOL.
			) with data on commit preserve rows
	   ) by TERADATA; 
	   execute (commit) by TERADATA; 
	   disconnect from TERADATA; 
	quit;



	/* Insert to ouptut new rows */
	proc sql;
	   connect to TERADATA
	   ( 
	       &_OUTPUT1_connect. 
	   ); 
	   execute 
	   ( 
			insert into &OUT_CALCULATED.
				(	  &UPDATE_KEY_COLUMNS.
					, &UPDATE_DATA_COLUMNS.
					, EFF_DT
					, END_DT
					, PPN_EV_ID)
			sel 
					  &UPDATE_KEY_COLUMNS.
					, &UPDATE_DATA_COLUMNS.
					, EFF_DT
					, END_DT
					, PPN_EV_ID
				from EFFENDTMP_DIFF02&BTCH_POOL.
	   ) by TERADATA; 
	   execute (commit) by TERADATA; 
	   disconnect from TERADATA; 
	quit;

	
	
	
	/* If defined, SQL will remove from output data where EFF_DT > END_DT (logically closed) */
	%if &OUT_REMOVE_UNNECESSARY. = Y %then %do;
		
		proc sql;
		   connect to TERADATA
		   ( 
			   &_OUTPUT1_connect. 
		   ); 
		   execute 
		   ( 
				delete from &OUT_CALCULATED.
					where EFF_DT > END_DT
		   ) by TERADATA; 
		   execute (commit) by TERADATA; 
		   disconnect from TERADATA; 
		quit;
		
	%end;
	

%mend;
