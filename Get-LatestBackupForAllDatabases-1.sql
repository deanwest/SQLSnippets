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

USE msdb;

SELECT d.name,
	d.recovery_model_desc,
	MAX(CASE WHEN b.type = 'D' THEN b.backup_finish_date END) AS last_full,
	MAX(CASE WHEN b.type = 'I' THEN b.backup_finish_date END) AS last_diff,
	MAX(CASE WHEN b.type = 'L' THEN b.backup_finish_date END) AS last_log,
	d.state_desc,
	d.create_date
FROM master.sys.databases d
	LEFT JOIN backupset b ON d.name = b.database_name
		AND b.server_name = @@SERVERNAME
WHERE d.database_id <> 2
GROUP BY d.name, d.state_desc, d.create_date, d.recovery_model_desc
ORDER BY d.name;
