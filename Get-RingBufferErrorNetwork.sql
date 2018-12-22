SELECT  DATEADD (ms, -1 * (sys.ms_ticks - a.[Record Time]), GETDATE()) AS Notification_time,  
 a.*
 --INTO ZDBA.dbo.RING_BUFFER_CONNECTIVITY_20120829
 FROM(SELECT
 x.value('(//Record/@time)[1]', 'bigint') AS [Record Time],
	x.value('(//ConnectivityTraceRecord/RecordType)[1]', 'varchar(max)') as [RecordType], 
	x.value('(//ConnectivityTraceRecord/RecordSource)[1]', 'varchar(50)') RecordSource, 
	x.value('(//SniConsumerError)[1]', 'int') as SniConsumerError,
	x.value('(//SniProvider)[1]', 'int') as SNIProvider,
	x.value('(//RemoteHost)[1]', 'varchar(30)') as RemoteHost,
	x.value('(//RemotePort)[1]', 'int') as RemotePort,
	x.value('(//LocalHost)[1]', 'varchar(30)') as LocalHost,
	x.value('(//LocalPort)[1]', 'int') as LocalPort,
	x.value('(//TdsBuffersInformation/TdsInputBufferError)[1]', 'int') as TdsInputBufferError,
	x.value('(//TdsDisconnectFlags/DisconnectDueToReadError)[1]', 'int') as DisconnectDueToReadError,
	x.value('(//TdsDisconnectFlags/NetworkErrorFoundInInputStream)[1]', 'int') as NetworkErrorFoundInInputStream,
	--x.query('//Stack') as Stack
	x.query('.') as Record
FROM (SELECT CAST (record as xml) FROM sys.dm_os_ring_buffers 
WHERE ring_buffer_type = 'RING_BUFFER_CONNECTIVITY') AS R(x)) a 
	CROSS JOIN sys.dm_os_sys_info sys
WHERE	a.RecordType = 'Error'
AND SniConsumerError NOT IN (18456,18056,17187)
ORDER BY Notification_time DESC
