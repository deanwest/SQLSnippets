/*===========================================================
** Copyright (c) Coeo 2017.  All rights reserved.
**
** THIS PROGRAM IS DISTRIBUTED WITHOUT ANY WARRANTY; WITHOUT 
** EVEN THE IMPLIED WARRANTY OF MERCHANTABILITY OR FITNESS 
** FOR PURPOSE.
** 
** File: .
** Vers: 1.0
** Desc: Reports last backup time for all databases, for either full, diff, or log
===========================================================*/

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
GO

DECLARE 
	@SQL nvarchar(max),
	@BackupType char(1);

SET @BackupType = 'D'; -- or L or I

SET @SQL = '
WITH CTE AS 
(
	SELECT  
		d.[name] AS [Database name],
		b.backup_finish_date AS [Backup finish date],
		DATEDIFF(minute,b.backup_start_date,b.backup_finish_date) AS [Backup duration (minutes)],
		CAST(DATEDIFF(minute, b.backup_finish_date, GETDATE()) / 60.0 AS decimal(10,1)) AS [Backup age (hours)],
		CAST(DATEDIFF(minute, b.backup_finish_date, GETDATE()) / 1440.0 AS decimal(10,1)) AS [Backup age (days)],
		CAST(b.backup_size / 1024 / 1024 /1024 AS decimal(10,2)) AS [Backup size (GB)],
		CAST(b.compressed_backup_size / 1024 / 1024 /1024 AS decimal(10,2)) AS [Compressed Backup size (GB)],
		b.[user_name] AS [Username],
		m.physical_device_name AS [Backup device],
		ROW_NUMBER() OVER (PARTITION BY d.[name] ORDER BY b.backup_finish_date DESC) AS rn
	FROM [master].sys.databases d
	LEFT OUTER JOIN msdb.dbo.backupset b 
		ON d.name COLLATE SQL_Latin1_General_CP1_CI_AS = b.database_name COLLATE SQL_Latin1_General_CP1_CI_AS
		AND b.[type] = ''' + @BackupType + ''' 
		AND b.server_name = SERVERPROPERTY(''ServerName'') /* Backupset ran on current server */
	LEFT OUTER JOIN msdb.dbo.backupmediafamily AS m
		ON b.media_set_id = m.media_set_id
	WHERE d.is_in_standby = 0           /* Not a log shipping target database */
	AND d.state_desc = ''ONLINE''
	AND d.source_database_id IS NULL    /* Excludes database snapshots */
	AND d.[state] <> 1                  /* Not currently restoring, like log shipping databases */ '

IF (@BackupType IN ('D', 'I'))
BEGIN
	SET @SQL = @SQL + ' AND d.database_id <> 2 '
END
ELSE
BEGIN
	SET @SQL = @SQL + ' AND d.name NOT IN (''master'',''tempdb'',''msdb'') AND d.recovery_model_desc <> ''SIMPLE'' '
END

SET @SQL = @SQL + '	
)
SELECT 
	[Database name],
	[Backup finish date],
	[Backup duration (minutes)],
	[Backup age (hours)],
	[Backup age (days)],
	[Backup size (GB)],
	[Compressed Backup size (GB)],
	[Username],
	[Backup device]
FROM CTE
WHERE rn = 1
--AND [Backup age (days)] > 1
ORDER BY [Database name];';

EXEC(@SQL);
GO





