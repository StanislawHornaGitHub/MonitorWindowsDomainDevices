# Process Coordinator
Main process constantly running in infinite loop which starts subsequent scripts, as PowerShell Background Jobs within refresh interval time configured in Config.json 
The process involves regularly running scripts in Powershell and Transact-SQL. 
Uses SQL Device_Monitoring_Maintenance Database to store and process all information related to starting jobs, to optimize run times and reduce CPU usage spikes, by shifting scripts start times in thresholds calculated based on data from Config.json and historical data gathered in SQL Device_Monitoring_Maintenance Database. An additional mechanism has been implemented to track devices that have connected to the network recently, in order to execute, selected in config file, PowerShell scripts on them outside the schedule, to get some information or information changes as soon as possible To gracefully stop the process use commands in Config.json by changing 0 to 1, for the command which you would like to invoke.

```mermaid
    flowchart TB
0.0.While_loop_beginning ==> 1.1.Create_Log_FileName
1.1.Create_Log_FileName ==> 1.2.Remove_Old_Logs
1.2.Remove_Old_Logs ==> 2.1.Read_Config_file
2.1.Read_Config_file ==> 2.2.1.Find_lowest_refresh_interval ==> 2.2.Count_number_of_scripts_with_lowest_refresh_interval
2.1.Read_Config_file ==> 2.2.2.Count_scripts_to_run_out_of_schedule ==> 2.2.Count_number_of_scripts_with_lowest_refresh_interval
2.1.Read_Config_file ==> 2.2.3.Create_columns_for_data_from_SQL ==> 2.2.Count_number_of_scripts_with_lowest_refresh_interval
2.1.Read_Config_file --Commands--> 7.1.Check_status_of_Commands_section_in_config_file
2.2.Count_number_of_scripts_with_lowest_refresh_interval --number_of_scripts_with_lowest_refresh_interval--> 2.6.Divide_time_between_subsequent_scripts_by_number_of_scripts_with_lowest_refresh_interval
2.2.Count_number_of_scripts_with_lowest_refresh_interval ==> 2.3.Update_SQL_LastExecution_Table_with_refresh_intervals
2.3.Update_SQL_LastExecution_Table_with_refresh_intervals ==> 2.4.Retrieve_SQL_LastExecution_details
2.4.Retrieve_SQL_LastExecution_details ==> 2.4.1.Lookup_from_SQL_Last_execution_date ==> 2.5.Find_minimum_time_between_subsequent_script_executions
2.4.Retrieve_SQL_LastExecution_details ==> 2.4.2.Lookup_from_SQL_Next_execution_date ==> 2.5.Find_minimum_time_between_subsequent_script_executions
2.4.Retrieve_SQL_LastExecution_details ==> 2.4.3.Lookup_from_SQL_AVG_Processing_Duration_ms ==> 2.5.Find_minimum_time_between_subsequent_script_executions
2.5.Find_minimum_time_between_subsequent_script_executions --time_between_subsequent_script--> 4.3.1.2.Used_sleep_time_is_less_than_time_between_subsequent_script_executions
2.5.Find_minimum_time_between_subsequent_script_executions ==> 2.6.Divide_time_between_subsequent_scripts_by_number_of_scripts_with_lowest_refresh_interval
2.6.Divide_time_between_subsequent_scripts_by_number_of_scripts_with_lowest_refresh_interval --Time_between_subsequent_scripts_per_script--> 4.3.1.3.If_AVG_Processing_Duration_ms_for_previous_script_is_less_than_Time_between_subsequent_scripts_per_script
2.6.Divide_time_between_subsequent_scripts_by_number_of_scripts_with_lowest_refresh_interval ==> 3.1.Get_number_of_recently_started_devices

3.1.Get_number_of_recently_started_devices ==> 3.2.If_number_of_scripts_to_run_out_of_schedule_greater_than_0_and_number_of_recently_started_devices_greater_than_0
3.2.If_number_of_scripts_to_run_out_of_schedule_greater_than_0_and_number_of_recently_started_devices_greater_than_0 -.TRUE.-> 3.2.1.Start_Recently_Started_Process ==> 4.1.Loop_through_PowerShell_script_types
3.2.If_number_of_scripts_to_run_out_of_schedule_greater_than_0_and_number_of_recently_started_devices_greater_than_0 -.FALSE.-> 4.1.Loop_through_PowerShell_script_types
4.1.Loop_through_PowerShell_script_types ==> 4.2.Loop_through_PowerShell_Scripts_in_a_given_type
4.2.Loop_through_PowerShell_Scripts_in_a_given_type ==> 4.3.If_next_run_time_is_right_now_or_already_passed
4.3.If_next_run_time_is_right_now_or_already_passed -.TRUE.-> 4.3.1.1.If_any_script_was_triggered 
4.3.1.1.If_any_script_was_triggered -.TRUE.-> 4.3.1.2.Used_sleep_time_is_less_than_time_between_subsequent_script_executions
4.3.1.1.If_any_script_was_triggered -.FALSE.-> 4.3.2.1.Prepare_to_invoke_PowerShell_Script_as_Background_job
4.3.1.2.Used_sleep_time_is_less_than_time_between_subsequent_script_executions -.TRUE.-> 4.3.1.3.If_AVG_Processing_Duration_ms_for_previous_script_is_less_than_Time_between_subsequent_scripts_per_script 
4.3.1.2.Used_sleep_time_is_less_than_time_between_subsequent_script_executions -.FALSE.-> 4.3.2.1.Prepare_to_invoke_PowerShell_Script_as_Background_job
4.3.1.3.If_AVG_Processing_Duration_ms_for_previous_script_is_less_than_Time_between_subsequent_scripts_per_script -.TRUE_AVG_Processing_Duration_ms_for_previous_script.-> 4.3.1.4.Invoke_sleep
4.3.1.3.If_AVG_Processing_Duration_ms_for_previous_script_is_less_than_Time_between_subsequent_scripts_per_script -.FALSE_Time_between_subsequent_scripts_per_script.-> 4.3.1.4.Invoke_sleep
4.3.1.4.Invoke_sleep ==> 4.3.2.1.Prepare_to_invoke_PowerShell_Script_as_Background_job
4.3.2.1.Prepare_to_invoke_PowerShell_Script_as_Background_job ==> 4.3.2.1.1.If_this_script_is_still_running_since_previous_execution
4.3.2.1.1.If_this_script_is_still_running_since_previous_execution -.TRUE.-> 4.3.2.1.2.Force_script_to_stop ==> 4.3.2.1.3.Remove_previous_execution_job
4.3.2.1.1.If_this_script_is_still_running_since_previous_execution -.FALSE.-> 4.3.2.1.3.Remove_previous_execution_job
4.3.2.1.3.Remove_previous_execution_job ==> 4.3.2.1.4.Update_SQL_LastExecution_and_logs
4.3.2.1.4.Update_SQL_LastExecution_and_logs ==> 4.3.2.2.1.Ping_all_active_devices ==> 4.3.2.2.2.Mark_devices_without_reply_as_inactive
4.3.2.2.2.Mark_devices_without_reply_as_inactive ==> 4.3.2.3.Invoke_PowerShell_Script_as_Background_job
4.3.2.3.Invoke_PowerShell_Script_as_Background_job ==> 4.3.3.Save_script_details_as_triggered_before
4.3.3.Save_script_details_as_triggered_before --TRUE--> 4.3.1.1.If_any_script_was_triggered
4.3.3.Save_script_details_as_triggered_before --AVG_Processing_Duration_ms_for_previous_script--> 4.3.1.3.If_AVG_Processing_Duration_ms_for_previous_script_is_less_than_Time_between_subsequent_scripts_per_script 
4.3.3.Save_script_details_as_triggered_before ==> 5.1.Loop_through_Transact-SQL_scripts
5.1.Loop_through_Transact-SQL_scripts ==> 5.2.If_next_run_time_is_right_now_or_already_passed
5.2.If_next_run_time_is_right_now_or_already_passed -.TRUE.-> 5.3.If_this_script_is_still_running_since_previous_execution
5.3.If_this_script_is_still_running_since_previous_execution -.TRUE.-> 5.3.1.Force_script_to_stop ==> 5.3.2.Remove_previous_execution_job
5.3.If_this_script_is_still_running_since_previous_execution -.FALSE.->5.3.2.Remove_previous_execution_job
5.3.2.Remove_previous_execution_job ==> 5.4.Invoke_Transact-SQL_script_using_PowerShell_Background_job
5.4.Invoke_Transact-SQL_script_using_PowerShell_Background_job ==> 6.1.Get_date_of_script_execution_in_nearest_future
6.1.Get_date_of_script_execution_in_nearest_future ==> 6.2.Calculate_number_of_ms_to_next_execution_date
6.2.Calculate_number_of_ms_to_next_execution_date ==> 6.3.Start_Sleep
6.3.Start_Sleep ==> 7.1.Check_status_of_Commands_section_in_config_file
7.1.Check_status_of_Commands_section_in_config_file ==> 7.1.1.At_least_one_command_is_set_to_true
7.1.1.At_least_one_command_is_set_to_true -.TRUE.-> 7.2.1.If_Stop_Process_and_Disable_Task_Scheduler_set_to_1
7.1.1.At_least_one_command_is_set_to_true -.FALSE.-> 0.0.While_loop_beginning
7.2.1.If_Stop_Process_and_Disable_Task_Scheduler_set_to_1 -.TRUE.-> 7.2.2.Disable_Task_Scheduler_task ==> 7.3.Exit_While_loop
7.2.1.If_Stop_Process_and_Disable_Task_Scheduler_set_to_1 -.FALSE.-> 7.3.Exit_While_loop
7.3.Exit_While_loop ==> 7.4.Close_all_completed_jobs ==> 7.5.Wait_for_remaining_ones_for_configured_time 
7.5.Wait_for_remaining_ones_for_configured_time ==> 7.6.Force_remaining_scripts_to_stop
7.6.Force_remaining_scripts_to_stop ==> 7.7.Exit_the_Process_Coordinator
```