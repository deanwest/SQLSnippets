Declare @LogPath sql_variant
SET @logPath=(Select top 1 value FROM sys.fn_trace_getinfo(NULL) WHERE property= 2)

SELECT  tg.TextData,tg.DatabaseName,tg.Error,tg.ObjectName,tg.DatabaseName,te.name,
    tg.EventSubClass,tg.NTUserName,tg.NTDomainName,tg.HostName,tg.ApplicationName,tg.Spid,
     tg.Duration,tg.StartTime,tg.EndTime,tg.Reads,tg.Writes,tg.CPU
FROM  fn_trace_gettable(cast(@LogPath as varchar(250)),default)AS tg
     Inner join sys.trace_events as te
     on tg.EventClass=te.trace_event_id
Where  tg.DatabaseName <>'tempdb'
-- WHERE   te.name = 'Data File Auto Grow' OR te.name = 'Data File Auto Shrink' = Database events
-- WHERE   te.name = 'Missing Column Statistics' OR te.name = 'Missing Join Predicate' = Errors and warnings events
-- WHERE  te.name IN ('Audit Addlogin Event', 'Audit Add DB User Event', 'Audit Add Member to DB Role Event') = Security and Audit events
-- WHERE   te.name IN ('Server Memory Change') = Memory events
-- WHERE  te.name IN ('Object Altered','Object Created','Object Deleted') = Object Events
-- WHERE  te.name IN ('FT Crawl Aborted','FT Crawl Started','FT Crawl Stopped') = Full Text events
