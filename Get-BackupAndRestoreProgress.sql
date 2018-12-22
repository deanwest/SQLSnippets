/*===========================================================
** Copyright (c) Coeo 2017.  All rights reserved.
**
** THIS PROGRAM IS DISTRIBUTED WITHOUT ANY WARRANTY; WITHOUT 
** EVEN THE IMPLIED WARRANTY OF MERCHANTABILITY OR FITNESS 
** FOR PURPOSE.
** 
** File: .
** Vers: 1.0
** Desc: Reports ETA for all backup and restore operations
===========================================================*/

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
GO

SELECT 
	Command,
	start_time AS [Start Time],
	st.[text] AS [SQL],
	CAST(((DATEDIFF(s,start_time, GETDATE()))/3600) as varchar) + ' hour(s), '
		+ CAST((DATEDIFF(s,start_time, GETDATE())%3600)/60 as varchar) + 'min, '
		+ CAST((DATEDIFF(s,start_time, GETDATE())%60) as varchar) + ' sec' as [Running Time],
	CAST((estimated_completion_time / 3600000) as varchar) + ' hour(s), '
		+ CAST((estimated_completion_time % 3600000) / 60000 AS varchar(50)) + 'min, '
		+ CAST((estimated_completion_time % 60000) / 1000 AS varchar(50)) + ' sec' as [Estimated Time Left],
	DATEADD(SECOND, estimated_completion_time/1000, GETDATE()) AS [Estimated Completion Time],
	CAST(percent_complete AS int) AS [Percent Complete]
FROM sys.dm_exec_requests AS req
CROSS APPLY sys.dm_exec_sql_text(req.[sql_handle]) AS st
WHERE req.command LIKE 'RESTORE%'
OR req.command LIKE 'BACKUP%';
GO
