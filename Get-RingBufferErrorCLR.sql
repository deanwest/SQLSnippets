SELECT  t.Notification_time 
	,t.ring_buffer_type
	,t.record.value('/Record[1]/AppDomain[1]/@address','varbinary(20)') as appdomain_address
	,t.record.value('/Record[1]/AppDomain[1]/@dbId','int') as dbId
	,t.record.value('/Record[1]/AppDomain[1]/@ownerId','int') as ownerId
	,t.record.value('/Record[1]/AppDomain[1]/@type','varchar(50)') as type
	,t.record.value('/Record[1]/AppDomain[1]/@gen','int') as gen
	,t.record.value('/Record[1]/AppDomain[1]/State[1]','varchar(50)') as appdomain_address
	,t.record.value('/Record[1]/AppDomain[1]/Ref[1]','varchar(20)') as Ref
	,t.record.value('/Record[1]/AppDomain[1]/RefWeak[1]','varchar(20)') as RefWeak
	,t.record.value('/Record[1]/AppDomain[1]/DoomReason[1]','varchar(50)') as DoomReason
FROM (
	SELECT DATEADD (s, -1 * (sys.ms_ticks - a.timestamp)/1000, GETDATE()) AS Notification_time 
		,a.ring_buffer_type
		 ,cast(a.record as xml) as record
	FROM sys.dm_os_ring_buffers a
		CROSS JOIN sys.dm_os_sys_info sys
	where ring_buffer_type = 'RING_BUFFER_CLRAPPDOMAIN'
	) as t
ORDER BY Notification_time DESC
