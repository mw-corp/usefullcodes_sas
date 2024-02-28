%macro check;
   data _null_;
   run;
   * This resets SYSERR;
   %if &sqlrc = 4 or &syscc = 4 %then
      %do;
         %let syscc = 0;
         * Only reset if 4, otherwise there may have been more serious issues earlier;
         %let sqlrc = 0;
      %end;
%mend;
