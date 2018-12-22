/*===========================================================
** Copyright (c) Coeo 2017.  All rights reserved.
**
** THIS PROGRAM IS DISTRIBUTED WITHOUT ANY WARRANTY; WITHOUT 
** EVEN THE IMPLIED WARRANTY OF MERCHANTABILITY OR FITNESS 
** FOR PURPOSE.
** 
** File: Clear down old database mail sent items.sql
** Vers: 1.0
** Desc: Deletes database mail older than a number of days
**       Deleted one week at a time
===========================================================*/

USE msdb
GO

DECLARE 
	@DeleteBeforeDate AS datetime,
	@DaysToKeep AS smallint;

SET @DaysToKeep = 30;

-- Ensure @DaysToKeep is negative
SET @DaysToKeep = ABS(@DaysToKeep) * -1;

-- Find earliest date + week
SELECT @DeleteBeforeDate = MIN(sent_date) FROM sysmail_mailitems WITH (NOLOCK);
SET @DeleteBeforeDate = DATEADD(d, 7, @DeleteBeforeDate);

WHILE (@DeleteBeforeDate < DATEADD(d, @DaysToKeep, GETDATE()))
BEGIN
	EXEC sysmail_delete_mailitems_sp @sent_before = @DeleteBeforeDate;
	EXEC sysmail_delete_log_sp @logged_before = @DeleteBeforeDate;

	WAITFOR DELAY '00:01';

	SET @DeleteBeforeDate = DATEADD(d, 7, @DeleteBeforeDate);
END

SET @DeleteBeforeDate = DATEADD(d, @DaysToKeep, GETDATE());
EXEC sysmail_delete_mailitems_sp @sent_before = @DeleteBeforeDate;
EXEC sysmail_delete_log_sp @logged_before = @DeleteBeforeDate;
GO



