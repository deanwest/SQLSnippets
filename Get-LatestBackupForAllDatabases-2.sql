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

SELECT
 QUOTENAME(d.[name]) [DatabaseName]
,SUSER_SNAME(d.[owner_sid]) [DatabaseOwner]
,d.[compatibility_level] [Compatibility]
,d.[collation_name] [CollationName]
,d.[is_read_only] [IsReadOnly]
,d.[is_auto_close_on] [IsAutoClose]
,d.[is_auto_shrink_on] [IsAutoShrink]
,d.[recovery_model_desc] [RecoveryModel]
,d.[page_verify_option_desc] [PageVerify]
,d.[state_desc] [State]
,d.[log_reuse_wait_desc] [LogReuse]
,pivbus.[D] [Database]
,pivbus.[I] [DifferentialDatabase]
,pivbus.[L] [Log]
,pivbus.[F] [FileOrFilegroup]
,pivbus.[G] [DifferentialFile]
,pivbus.[P] [Partial]
,pivbus.[Q] [DifferentialPartial]
FROM sys.databases d
LEFT OUTER JOIN
(
SELECT
piv.[database_name],[D],[I],[L],[F],[G],[P],[Q]
FROM
(
SELECT [database_name],[backup_finish_date],[type]
FROM msdb..backupset
) bus PIVOT
(MAX([backup_finish_date]) FOR [type] IN ([D],[I],[L],[F],[G],[P],[Q])) piv
) pivbus ON d.[name] = pivbus.[database_name]