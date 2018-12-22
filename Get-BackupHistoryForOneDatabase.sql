/*===========================================================
** Copyright (c) Coeo 2017.  All rights reserved.
**
** THIS PROGRAM IS DISTRIBUTED WITHOUT ANY WARRANTY; WITHOUT 
** EVEN THE IMPLIED WARRANTY OF MERCHANTABILITY OR FITNESS 
** FOR PURPOSE.
** 
** File: .
** Vers: 1.0
** Desc: Show backup history for current database (or specified)
===========================================================*/

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
GO

DECLARE @DbName sysname;
SET @DbName = '';

SELECT  
	d.[name] AS [Database name],
	CASE b.[type] WHEN 'L' THEN 'LOG' WHEN 'D' THEN 'FULL' WHEN 'I' THEN 'DIFF' ELSE b.[type] END AS [Type],
	b.backup_finish_date AS [Backup finish date],
	CAST(DATEDIFF(minute, b.backup_start_date, b.backup_finish_date) / 60.0 AS decimal(10,1)) AS [Backup duration (hours)],
	CAST(DATEDIFF(minute, b.backup_finish_date, GETDATE()) / 60.0 AS decimal(10,1)) AS [Backup age (hours)],
	CAST(b.backup_size / 1024 / 1024 /1024 AS decimal(10,2)) AS [Backup size (GB)],
	CAST(b.compressed_backup_size / 1024 / 1024 /1024 AS decimal(10,2)) AS [Compressed Backup size (GB)],
	b.[user_name] AS [Username],
	m.physical_device_name AS [Backup device]
FROM [master].sys.databases d
LEFT OUTER JOIN msdb.dbo.backupset b ON d.name = b.database_name 
LEFT OUTER JOIN msdb.dbo.backupmediafamily AS m	ON b.media_set_id = m.media_set_id
WHERE d.is_in_standby = 0	
AND d.state_desc = 'ONLINE'
AND d.source_database_id IS NULL	
AND d.[state] <> 1
--AND b.[type] <> 'L' /* exclude logs */
AND d.[name] = CASE WHEN @DbName = '' THEN DB_NAME() ELSE @DbName END
ORDER BY [Backup finish date] DESC;
GO
