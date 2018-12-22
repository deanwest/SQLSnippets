/*===========================================================
** Copyright (c) Coeo 2017.  All rights reserved.
**
** THIS PROGRAM IS DISTRIBUTED WITHOUT ANY WARRANTY; WITHOUT 
** EVEN THE IMPLIED WARRANTY OF MERCHANTABILITY OR FITNESS 
** FOR PURPOSE.
** 
** File: .
** Vers: 1.0
** Desc: Database restore history for all databases
===========================================================*/

SELECT rh.restore_date,
	rh.destination_database_name,
	rh.user_name,
	CASE rh.restore_type
		WHEN 'D' THEN 'Full'
		WHEN 'I' THEN 'Differential'
		WHEN 'L' THEN 'Log'
		ELSE 'Other (' + rh.restore_type + ')'
	END AS restore_type,
	rh.stop_at,
	(
		SELECT MIN(physical_device_name)
		FROM msdb..backupmediafamily
		WHERE media_set_id = bs.media_set_id
	) AS first_backup_file,
	bs.server_name AS backup_server,
	bs.database_name AS backup_database,
	bs.backup_start_date,
	bs.backup_finish_date
FROM msdb..restorehistory rh
	JOIN msdb..backupset bs ON rh.backup_set_id = bs.backup_set_id
WHERE rh.restore_date >= DATEADD(mm, -12, GETDATE())
ORDER BY rh.restore_date DESC
