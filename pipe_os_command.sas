filename mypipe pipe "pip list"; /* Replace '/path/to/directory' with your desired directory */

data unix_output;
  length line $200; /* Define a character variable to hold the output */
  infile mypipe length=reclen; /* Read the output of the command */
  input line $varying200. reclen; /* Store the output in the 'line' variable */
run;
