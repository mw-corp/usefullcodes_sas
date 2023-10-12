signon p1 sascmd="sas -config '\\SF600SV90745\u8\sasv9.cfg'";

rsubmit p1  wait=no log='S:\SAS\TEST\Data\External_Files\XML_LOADER\GLEIF\T7430_log.txt';

 

 

proc options option=encoding;
run;
 

/*data test;*/
/*	set sashelp.class;*/
/*run;*/



endrsubmit;
