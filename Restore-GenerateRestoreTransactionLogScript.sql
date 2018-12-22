/*
Scripts out all the restore log statements for a given database from the specified @start_date to the @end_date.
*/


declare @source_database_name varchar(128)
declare @destination_database_name varchar(128)
declare @start_date datetime
declare @end_date datetime




set @source_database_name = 'SunwebTools'
set @destination_database_name = 'SunwebTools_Copy'
set @start_date = '10 March 2014 21:30:08.000'
set @end_date = getdate()


select 'RESTORE LOG [' + @destination_database_name  + '] FROM  
DISK = N''' + physical_device_name + '''
WITH  FILE = 1,  NORECOVERY,  NOUNLOAD,  STATS = 10
GO'
from msdb..backupset b
join msdb..backupmediafamily mf on b.media_set_id = mf.media_set_id
where database_name = @source_database_name
and backup_start_date >= @start_date and backup_start_date < @end_date
and type = 'L'
order by backup_start_date asc