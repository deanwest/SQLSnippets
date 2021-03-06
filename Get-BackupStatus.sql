DECLARE @isCopyOnlyExists bit
DECLARE @isDamagedExists bit

IF EXISTS (SELECT 1 FROM msdb.INFORMATION_SCHEMA.COLUMNS	
        WHERE TABLE_SCHEMA='dbo'
        AND TABLE_NAME='backupset'
        AND COLUMN_NAME='is_copy_only')
    SET @isCopyOnlyExists = 1 --SQL 2005 onwards

IF EXISTS (SELECT 1 FROM msdb.INFORMATION_SCHEMA.COLUMNS	
        WHERE TABLE_SCHEMA='dbo'
        AND TABLE_NAME='backupset'
        AND COLUMN_NAME='is_damaged')
    SET @isDamagedExists = 1 --SQL 2008 onwards

SELECT *
FROM (
SELECT	d.name
	,CASE
		WHEN d.name IN ('tempdb')
			THEN '8 - Backup not required'
		WHEN db.last_db_backup_date IS NULL
			THEN '1 - Full Database Backup missing'
		WHEN d.RecoveryModel IN ('FULL','BULK_LOGGED')
			AND tlog.last_tlog_backup_date IS NULL
			THEN '2 - Transaction Log Backup missing'
		WHEN datediff(hh,db.last_db_backup_date,getdate()) > 24
			AND diff.last_db_backup_date IS NULL 
			THEN '3 - Full Database older than 24 hours'
		WHEN datediff(hh,db.last_db_backup_date,getdate()) > 24*7
			AND diff.last_db_backup_date IS NOT NULL 
			THEN '4 - Full Database older than 7 days when Incremental backups are being taken'
		WHEN datediff(hh,db.last_db_backup_date,getdate()) > 24
			AND datediff(hh,diff.last_db_backup_date,getdate()) > 24
			THEN '5 - Incremental backup older than 24 hours'
		WHEN d.RecoveryModel IN ('FULL','BULK_LOGGED')
			AND datediff(hh,tlog.last_tlog_backup_date,getdate()) > 24
			THEN '6 - Transaction Log Backup older than 24 hours'	
		ELSE '7 - Backup ok'
	END as BackupStatus
	,d.RecoveryModel
	,CASE
		WHEN db.last_db_backup_date > diff.last_db_backup_date AND diff.last_db_backup_date IS NOT NULL
		THEN datediff(hh,db.last_db_backup_date,getdate())
		WHEN db.last_db_backup_date IS NOT NULL AND diff.last_db_backup_date IS NOT NULL
		THEN datediff(hh,diff.last_db_backup_date,getdate())
		ELSE datediff(hh,db.last_db_backup_date,getdate()) END as HoursSinceLastDBBackup
	,datediff(hh,tlog.last_tlog_backup_date,getdate()) as HoursSinceLastTLogBackup
	,db.last_db_backup_date
	,diff.last_db_backup_date as last_diff_backup_date
	,tlog.last_tlog_backup_date
FROM (SELECT name, databasepropertyex(name,'Recovery') AS RecoveryModel
	FROM master..sysdatabases
	--SQL2000 compatability and no schema/owner in case default db is not master
	WHERE databasepropertyex(name,'Status') IN ('ONLINE')
	AND databasepropertyex(name,'Updateability') = 'READ_WRITE'
	)  AS d
	LEFT OUTER JOIN
	(
	SELECT  bs.database_name
	   ,MAX(bs.backup_finish_date) AS last_db_backup_date 
	FROM   msdb.dbo.backupmediafamily AS bmf
		INNER JOIN msdb.dbo.backupset AS bs
			ON bmf.media_set_id = bs.media_set_id  
	WHERE  bs.[type] = 'D' 
	AND (CASE WHEN @isCopyOnlyExists=1 THEN bs.is_copy_only ELSE 1 END) =  0 --SQL 2005 onwards
	AND (CASE WHEN @isDamagedExists=1 THEN bs.is_damaged ELSE 1 END) =  0 --SQL 2008 onwards
	--AND bs.name = 'CommVault Galaxy Backup'
	GROUP BY    bs.database_name  
	) AS db
		ON d.name = db.database_name
	LEFT OUTER JOIN
	(
	SELECT  bs.database_name
	   ,MAX(bs.backup_finish_date) AS last_db_backup_date 
	FROM   msdb.dbo.backupmediafamily AS bmf
		INNER JOIN msdb.dbo.backupset AS bs
			ON bmf.media_set_id = bs.media_set_id  
	WHERE  bs.[type] = 'I' 
	AND (CASE WHEN @isCopyOnlyExists=1 THEN bs.is_copy_only ELSE 1 END) =  0 --SQL 2005 onwards
	AND (CASE WHEN @isDamagedExists=1 THEN bs.is_damaged ELSE 1 END) =  0 --SQL 2008 onwards
	--AND bs.name = 'CommVault Galaxy Backup'
	GROUP BY    bs.database_name  
	) AS diff
		ON d.name = diff.database_name
	LEFT OUTER JOIN
	(
	SELECT  bs.database_name
	   ,MAX(bs.backup_finish_date) AS last_tlog_backup_date 
	FROM   msdb.dbo.backupmediafamily AS bmf
		INNER JOIN msdb.dbo.backupset AS bs
			ON bmf.media_set_id = bs.media_set_id  
	WHERE  bs.[type] = 'L' 
	AND (CASE WHEN @isCopyOnlyExists=1 THEN bs.is_copy_only ELSE 1 END) =  0 --SQL 2005 onwards
	AND (CASE WHEN @isDamagedExists=1 THEN bs.is_damaged ELSE 1 END) =  0 --SQL 2008 onwards
	--AND bs.name = 'CommVault Galaxy Backup'
	GROUP BY    bs.database_name  
	) AS tlog
		ON d.name = tlog.database_name
) as t
--WHERE BackupStatus not in ('7 - Backup ok','8 - Backup not required')
ORDER BY name

/*
--show backup history for one database
SELECT  bs.database_name
	   ,bs.backup_finish_date
	   ,bs.[type]
	   ,bs.name
	   ,bs.[user_name],bs.checkpoint_lsn, bs.database_backup_lsn
FROM   msdb.dbo.backupmediafamily AS bmf
	INNER JOIN msdb.dbo.backupset AS bs
		ON bmf.media_set_id = bs.media_set_id  
WHERE  bs.database_name='<Database_name>'
order by bs.backup_finish_date desc

Select differential_base_lsn, read_write_lsn, backup_lsn
from sys.master_files
where database_id = db_id('<Database_name>') and type = 0
*/