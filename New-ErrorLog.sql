--This system stored procedure closes the current server log and starts a new one
--the old logs are available through the management tools. 
--However, EXEC master.dbo.xp_readerrorlog will not pick up any errors for the dashboard

--NB CHECK THE LOG FOR ERRORS BEFORE RUNNING THIS.
EXEC sp_cycle_errorlog