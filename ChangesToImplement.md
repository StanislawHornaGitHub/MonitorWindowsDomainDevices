# Items to develop
## Done:
    From changes section:
        1. Done
        2. Refused - wraping it up would mask the logic behind this process
        3. Done
        4. Done
    
    From Improvements section
        1. Done
        2. Done
        3.
        4.
        5. Done


## Changes:
1. Convert current test active and recently started to be invoked via variable from VariableInventory.psm1.
2. Wrap up functions related to Recently started process startup.
3. Additional function before main loop to set command Stop_Process_Coordinator to 0 if it is set to 1 on startup.
4. Review the code to move some file paths etc to Variables modules.

## Improvements:
1. Change sleep time estimation to deadline datetime, convert it to miliseconds just before invoking Start-Sleep. Try to create only one loop for all script types. Move calculation of the next run to SQL query to speed up powershell part.
2. On each loop iteration check if some jobs are completed and can be removed. This will free up some ram consumption, especially of jobs which are not processing anything.
3. Mechanism to execute SQL queries configured in a config file.
4. Mechanism to prevent starting Process coordinator manually if X previous executions ended with error in a given time period.
5. Add file lock to be able to run only 1 instance, save PID to file, if new instance can not find process with pid from file than it can be started.
