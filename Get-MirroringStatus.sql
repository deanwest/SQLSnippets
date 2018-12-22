--please see books online for a description of sys.sp_dbmmonitorresults
--mirroring_state needs to be value 4 to be synchronized.
--performance counters are running total. query shows current state.
--script must be run on every server involved in database mirroring.

USE msdb;

DECLARE @dbname sysname;
DECLARE dbmirror_cursor CURSOR LOCAL FAST_FORWARD FOR 
   select d.name
   from sys.database_mirroring dm
         join sys.databases d 
         on (dm.database_id=d.database_id) 
   where dm.mirroring_guid is not null
   ORDER BY d.name;
   
OPEN dbmirror_cursor
FETCH NEXT FROM dbmirror_cursor INTO @dbname

WHILE @@FETCH_STATUS = 0
BEGIN
    exec sys.sp_dbmmonitorresults @database_name=@dbname, @mode = 0, @update_table = 1;
    FETCH NEXT FROM dbmirror_cursor INTO @dbname;
END
CLOSE dbmirror_cursor;
DEALLOCATE dbmirror_cursor;

select rtrim(object_name) as counter_obj
   ,rtrim(counter_name) as counter_name
   ,cntr_value
   ,getdate() as SampleDate
   ,rtrim(instance_name) as instance_name
from sys.dm_os_performance_counters
where object_name like '%:Database Mirroring%'
and rtrim(instance_name) = '_Total'

SELECT db_name(database_id) as dbname
   , CASE WHEN min([status]) < 4 THEN 'Recent Mirror Problem' ELSE 'Good' END as mirror_state
   , max([transactions_per_sec]) as [total_transactions]--contrary to name is the total transactions
   , max([transaction_delay]) as [worst_transaction_delay]
FROM msdb.dbo.dbm_monitor_data
WHERE [time] > DATEADD(d,-1,getutcdate())
GROUP BY db_name(database_id)
ORDER BY db_name(database_id)
