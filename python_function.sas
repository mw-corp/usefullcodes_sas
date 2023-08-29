/***********************************************************

  Function sas_getTableStructure

	function is returning columns statement (name and datatype
	separated by comma) ready to be used in create table
	statement

************************************************************/
	proc fcmp outlib=work.myfuncs.pyfuncs;

		function sas_getTableStructure(path_to_files $,template_name $) $ 32000;
		   length  FCMP_out $ 32000;
			declare object py(python);
			rc = py.infile("&PY_SCRIPT_PATH.\getTableStructure.py");
			rc = py.publish();
			rc = py.call("getTableStructure", path_to_files,template_name);
			put path_to_files template_name;
  /* out has to be in a comment in py file */
			FCMP_out = py.results["out"]; 
			return(FCMP_out);
		endsub;

	run;
