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

SELECT bs.server_name,
	bs.database_name,
	CASE bs.type
		WHEN 'D' THEN 'Full'
		WHEN 'I' THEN 'Differential'
		WHEN 'L' THEN 'Log'
		ELSE 'Other (' + bs.type + ')'
	END AS type,
	bs.backup_start_date,
	bs.backup_finish_date,
	STUFF(CONVERT(char(8), bs.backup_finish_date - bs.backup_start_date, 108), 1, 2, DATEDIFF(hh, 0, bs.backup_finish_date - bs.backup_start_date)) AS duration,
	CONVERT(decimal(10,2), bs.backup_size / 1024 / 1024) AS size_MB,
	CONVERT(decimal(10,2), bs.compressed_backup_size / 1024 / 1024) AS comp_size_MB, --2008+
	CONVERT(decimal(4,1), 100 * (bs.backup_size - bs.compressed_backup_size) / bs.backup_size) AS [comp_%], --2008+
	CONVERT(decimal(10,2), bs.backup_size / 1024 / 1024 / ISNULL(NULLIF(DATEDIFF(ss, bs.backup_start_date, bs.backup_finish_date), 0), 1)) AS [rate_MB/s],
	(
		SELECT MIN(physical_device_name)
		FROM msdb..backupmediafamily
		WHERE media_set_id = bs.media_set_id
	) AS first_backup_file,
	(
		SELECT COUNT(*)
		FROM msdb..backupmediafamily
		WHERE media_set_id = bs.media_set_id
	) AS backup_file_count,
	bs.user_name,
	bs.name,
	bs.description
FROM msdb..backupset bs
WHERE bs.backup_start_date >= DATEADD(mm, -1, GETDATE())
	AND bs.type IN ('D', 'I')
	AND (DB_ID() = 1 OR bs.database_name = DB_NAME())
ORDER BY bs.backup_start_date DESC, bs.database_name DESC
