/*===========================================================
** Copyright (c) Coeo 2017.  All rights reserved.
**
** THIS PROGRAM IS DISTRIBUTED WITHOUT ANY WARRANTY; WITHOUT 
** EVEN THE IMPLIED WARRANTY OF MERCHANTABILITY OR FITNESS 
** FOR PURPOSE.
** 
** File: .
** Vers: 1.0
** Desc: Change the default backup locations in the registry
===========================================================*/

DECLARE @regkey NVARCHAR(1000)

-- SQL2005 default (if databases engine was installed after reproting SSIS or analysis services
-- key may containt MSSQL.2 or MSSQL.3 instead of MSSQL.1). if it is not a default instance then MSSQLServer
-- may be \MSSQL.1\Instance
--SET @regkey = 'SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL.1\MSSQLServer' 

-- SQL2008 default (if databases engine was installed after reproting SSIS or analysis services
-- key may containt MSSQL.2 or MSSQL.3 instead of MSSQL.1). if it is not a default instance then MSSQLServer
-- may be \MSSQL.1\Instance
SET @regkey = 'SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL10.MSSQLSERVER\MSSQLServer' 

--read current default backup directory
--if the correct registry key is specified this will always return a value other than NULL.
DECLARE @BackupDirectory VARCHAR(100)
EXEC master..xp_regread @rootkey='HKEY_LOCAL_MACHINE',
  @key=@regkey,
  @value_name='BackupDirectory',
  @BackupDirectory=@BackupDirectory OUTPUT
SELECT @BackupDirectory

--setting new default backup dir
EXEC master..xp_regwrite
     @rootkey='HKEY_LOCAL_MACHINE',
     @key=@regkey,
     @value_name='BackupDirectory',
     @type='REG_SZ',
     @value='H:\SQLBackups'

--read new default backup directory
EXEC master..xp_regread @rootkey='HKEY_LOCAL_MACHINE',
  @key=@regkey,
  @value_name='BackupDirectory',
  @BackupDirectory=@BackupDirectory OUTPUT
SELECT @BackupDirectory