/*===========================================================
** Copyright (c) Coeo 2017.  All rights reserved.
**
** THIS PROGRAM IS DISTRIBUTED WITHOUT ANY WARRANTY; WITHOUT 
** EVEN THE IMPLIED WARRANTY OF MERCHANTABILITY OR FITNESS 
** FOR PURPOSE.
** 
** File: .
** Vers: 1.0
** Desc: Reports full backup history for all databases, for either full, diff, or log
===========================================================*/


SELECT
 bs.[database_name] [DatabaseName]
,bs.[type] [Type]
,bs.[backup_start_date] [BackupStartDate]
,bs.[backup_finish_date] [BackupFinishDate]
,CONVERT(DECIMAL(15,3),(bs.[backup_size]/1048576)) [Size MB]
,CONVERT(DECIMAL(15,3),(bs.[compressed_backup_size]/1048576)) [CompressedSize MB] --SQL2008
,LTRIM(STR((bs.[backup_size])/(bs.[compressed_backup_size]),38,3))+':1' [CompressionRatio] --SQL2008
,DATEDIFF(SECOND,bs.[backup_start_date],bs.[backup_finish_date]) [Duration Sec]
,CONVERT(DECIMAL(15,3),(bs.[backup_size]/COALESCE(NULLIF(DATEDIFF(SECOND,bs.[backup_start_date],bs.[backup_finish_date]),0),1))/1048576) [Backup MB Sec]
,bmf.[physical_device_name]
,bs.[first_lsn] [FirstLSN]
,bs.[last_lsn] [LastLSN]
,bs.[checkpoint_lsn] [CheckpointLSN]
,bs.[database_backup_lsn] [DatabaseBackupLSN]
,bs.[is_copy_only] [IsCopyOnly]
,bs.[differential_base_lsn] [DifferentialBaseLSN]
,bs.[first_recovery_fork_guid] [FirstRecoveryForkID]
,bs.[last_recovery_fork_guid] [LastRecoveryForkID]
,bs.[fork_point_lsn] [ForkPointLSN]
,bs.[user_name] [UserName]
,bs.[compatibility_level] [CompatibilityLevel]
,bs.[database_version] [DatabaseVersion]
,bs.[collation_name] [CollationName]
FROM [msdb].[dbo].[backupset] bs
INNER JOIN [msdb].[dbo].[backupmediafamily] bmf 
ON bs.[media_set_id] = bmf .[media_set_id]
ORDER BY bs.[backup_start_date] DESC

