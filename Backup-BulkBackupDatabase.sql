/*===========================================================
** Copyright (c) Coeo 2017.  All rights reserved.
**
** THIS PROGRAM IS DISTRIBUTED WITHOUT ANY WARRANTY; WITHOUT 
** EVEN THE IMPLIED WARRANTY OF MERCHANTABILITY OR FITNESS 
** FOR PURPOSE.
** 
** File: .
** Vers: <version>
** Desc: Comprehensive backup script for one or many databases
===========================================================*/

ALTER PROCEDURE [dbo].[sp__BackupDB]
	
	(	  @Type CHAR(1) = 'A'	-- Type of databases A - all, U - user, S - system, D - Individual db
		, @Database SYSNAME = NULL -- the name of the db to backup (only valid if @Type = 'D'
		, @FileGroup VARCHAR(8000) = NULL --the name of the file group to backup
		, @Path VARCHAR(2000) = 'B:\Backup'
		, @FileExtras VARCHAR(2000) = NULL
		, @Stamp CHAR(1)= 'T'	-- Stamp on the filename N - none, D - date only, T - date and time.
		, @DBList VARCHAR(8000)='' OUTPUT
		, @DEBUG INT = 0
		, @SQB BIT = 0 -- indicate whether to use SQLBackup.  0=false, 1=true
		, @Exclude VARCHAR(8000) = NULL -- list of databases to exclude (semi-colon seperated list)
		, @Include VARCHAR(8000) = NULL
		, @LogBackup BIT = 0
		, @DifBackup BIT = 0
		, @AzureBackup BIT = 0
		, @Credential Varchar(128) = NULL
		, @Compression bit  = 1
		, @CopyOnly bit = 0
		, @CheckSum bit = 1

	)
	
	AS
	set concat_null_yields_null off
	/*
	
	** Purpose: 
	** SQL procedure to dump a list of databases to the specified path.
	**
	
	** Example:
		exec sp__BackupDB @Database = 'master' -- backup an individual database
		exec sp__BackupDB @DEBUG = 1-- backs up all databases (including system database)
	
	
	Modification History:
		28 Apr 2004	KG	Created
		11 May 2005	KG	updated to check whether @path has a trailing '\' char.  If not it's automatically added.	
		23 May 2005	KG	placed double quotes in gzip command to allow for file names with spaces in the name.
		28 May 2006	KG	Added parameter @FileExtras, which allows for a string to be appended to the file name
						Also added @Database, allowing for an individual database to be backed up.
		21 Aug 2006	KG	Added @Exclude parameter to allow for a list of excluded databases to be added.
		23 Dec 2013	CP	Added @AzureBackup and @Credential to allow for Azure backups to be performed and credentials to be optionally passed
		24 Dec 2013 KG	Modified code to exclude databases in simple recovery mode if Log Backup is being performed
		24 Dec 2013 KG	Modified code to include read_only databases if the database is an AlwaysOn replica
		
		EXEC dbo.sp__BackupDB @Path = 'R:\SQLBackup\LogBackup\', @Stamp = 'T', @DEBUG = 1, @Include = 'EvolviDev;', @LogBackup = 0
	
	*/
	
	begin
	SET NOCOUNT ON
	DECLARE @ErrorStatus INT        -- Error status within the procedure.
	, @Msg VARCHAR(8000)           -- Message buffer string.
	, @ProcName SYSNAME            -- Name of the current procedure.
	, @SqlCmnd VARCHAR(8000)       -- Buffer to hold Dynamic SQL commands.
	, @Crlf CHAR(2)                -- Carraige return line feed.
	, @NextDB SYSNAME              -- Name of the next database to backup
	, @CursorOpen INT              -- Flag to indicate the cursor has been created.
	, @FileStamp VARCHAR(50)       -- Date or date and time to add to output file.
	, @SemiColon VARCHAR(1)        -- Seperator.
	, @CurrentDB SYSNAME
	, @Location varchar(5)		   --Specifies TO Disk/URL etc
	, @IsAlwaysOnReplica bit	   --specified whether the current database is an AlwaysOn replica
	, @BuildNumber int
	, @errorOccurred bit

	set @errorOccurred = 0

	select @BuildNumber = convert(integer, substring(convert(varchar(30), serverproperty('ProductVersion')), 1, charindex('.', convert(varchar(30), serverproperty('ProductVersion')))-1))

	CREATE TABLE #exclude_list	
	(
		DatabaseName SYSNAME
	)
	
	CREATE TABLE #include_list
	(
		DatabaseName SYSNAME
	)
	
	IF SUBSTRING(REVERSE(@Exclude),1,1) <> ';' SET @Exclude = @Exclude + ';'
	
	IF @Type <> 'D' SET @FileGroup = NULL
	
	WHILE LEN(@Exclude) > 0
	BEGIN
	
		
		SET @CurrentDB = SUBSTRING(@Exclude,1,CHARINDEX(';',@Exclude) - 1)
	
		INSERT INTO #exclude_list SELECT LTRIM(RTRIM(@CurrentDB))
	
		SET @Exclude = SUBSTRING(@Exclude,CHARINDEX(';',@Exclude) + 1,LEN(@Exclude))
	
	END

	IF @LogBackup = 1
		insert into #exclude_list 
		select name from sys.databases d where recovery_model_desc = 'SIMPLE'
		and not exists (select 1 from #exclude_list where DatabaseName = d.name)
	
	
	IF SUBSTRING(REVERSE(@Include),1,1) <> ';' SET @Include = @Include + ';'
	
	WHILE LEN(@Include) > 0
	BEGIN
	
		SET @CurrentDB = SUBSTRING(@Include,1,CHARINDEX(';',@Include) - 1)
		
		INSERT INTO #include_list SELECT LTRIM(RTRIM(@CurrentDB))
	
		SET @Include = SUBSTRING(@Include,CHARINDEX(';',@Include) + 1,LEN(@Include))
	
	END
		
	
	IF @Database IS NOT NULL SET @Type = 'D'
	IF @FileExtras IS NOT NULL SET @Stamp = 'N'
	IF @Include IS NOT NULL SET @Type = 'I'
	IF @LogBackup = 1 SET @SQB = 0
	
	SELECT @ErrorStatus = 0, @ProcName=OBJECT_NAME(@@PROCID), @SemiColon = ''
	, @Crlf = CHAR(13) + CHAR(10), @CursorOpen = 0, @FileStamp = ''
	, @DBList = ISNULL(@DBList, '')
	
	IF (@DEBUG = 1)
	begin
		SELECT @Msg = 'DEBUG: ' + @ProcName + ': Enterred at '
		+ CONVERT( VARCHAR, GETDATE(), 121 ) + @Crlf
		+ '       @Type=' + ISNULL(@Type, 'NULL') + @Crlf
		+ '       @Stamp=' + ISNULL(@Stamp, 'NULL') + @Crlf
		+ '       @Path=' + ISNULL(@Path, 'NULL')
		PRINT @Msg
	end
	
	
	-- Process the paramters.
	IF @AzureBackup = 0
	BEGIN
		IF RIGHT(@Path,1) <> '\' AND @Path <> 'NUL' SET @Path = @Path + '\'
		SET @Location = 'DISK'
	END
	
	IF @AzureBackup = 1
	BEGIN 
		IF RIGHT(@Path,1) <> '/'  AND @Path <> 'NUL' SET @Path = @Path + '/'
		SET @Location = 'URL'
	END

	-- Check the backup path is not empty.
	SELECT @Path = ISNULL(@Path, '')
	
	IF ( @Path = '')
	begin
		RAISERROR ('Backups not possible to a Null or empty backup path.', 16, 1) WITH LOG
		SET @ErrorStatus = @@error
	END
	
	-- Type of databases A - all, U - user, S - system, D - user; master; msdb
	IF (@ErrorStatus = 0)
	begin
		IF (@Type = 'U')
			DECLARE csrDBList CURSOR local fast_forward
			FOR SELECT NAME 
			FROM master.dbo.sysdatabases
			WHERE NAME NOT IN ('master', 'msdb', 'model', 'Northwind', 'pubs', 'tempdb')
				AND NAME NOT IN (SELECT DatabaseName FROM #exclude_list)
			ORDER BY NAME

		ELSE IF (@Type = 'S')
			DECLARE csrDBList CURSOR local fast_forward
			FOR SELECT NAME 
				FROM master.dbo.sysdatabases
				WHERE NAME IN ('master', 'msdb', 'model', 'Northwind', 'pubs')
					AND NAME NOT IN (SELECT DatabaseName FROM #exclude_list)
				ORDER BY NAME

		ELSE IF (@Type = 'D')
			DECLARE csrDBList CURSOR local fast_forward
			FOR SELECT NAME 
				FROM master.dbo.sysdatabases
				WHERE NAME = @Database
		
		ELSE IF (@Type = 'I')
			DECLARE csrDBList CURSOR local fast_forward
			FOR SELECT NAME 
				FROM master.dbo.sysdatabases
				WHERE NAME IN (SELECT DatabaseName FROM #include_list)
		
		ELSE
			DECLARE csrDBList CURSOR local fast_forward
			FOR SELECT NAME 
				FROM master.dbo.sysdatabases
				WHERE NAME NOT IN ('tempdb')
					AND NAME NOT IN (SELECT DatabaseName FROM #exclude_list)
				ORDER BY NAME
	end
	
	IF (@ErrorStatus = 0)
	begin
		OPEN csrDBList
		SET @ErrorStatus = @@error
	
		IF (@ErrorStatus = 0)
		begin
			SET @CursorOpen = 1
			FETCH NEXT FROM csrDBList INTO @NextDB

			WHILE @@fetch_status = 0
			begin
	
				if @BuildNumber > 10
					select @IsAlwaysOnReplica = case when replica_id is null then 0 else 1 end
					from sys.databases where name = @NextDB
				else
					select @IsAlwaysOnReplica = 0
				
	
	
				--if the database is read_only skip it (unless it's an AlwaysOn replica)
				IF EXISTS(SELECT 1 WHERE DATABASEPROPERTYEX(@NextDB, 'Updateability') <> 'READ_WRITE') and @IsAlwaysOnReplica = 0 GOTO Cursor_Loop
		
				--if the database is not online skip it
				IF EXISTS(SELECT 1 WHERE DATABASEPROPERTYEX(@NextDB, 'Status') <> 'ONLINE') GOTO Cursor_Loop

				
	
				-- Stamp on the filename N - none, D - date only, T - date and time.
				IF (@ErrorStatus = 0)
				begin
					IF (@Stamp = 'D') -- yyyymmdd
						SET @FileStamp = '_' + CONVERT(CHAR(8), GETDATE(), 112)
					ELSE IF (@Stamp = 'T') -- hhmmss
						SET @FileStamp = '_' + CONVERT(CHAR(8), GETDATE(), 112) + '_' + REPLACE(CONVERT(VARCHAR(8), GETDATE(), 108), ':', '')
				ELSE
					SET @FileStamp = @FileExtras
				end
	
				declare @db_name_filegroup varchar(512)
		
				if @FileGroup is null
					set @db_name_filegroup = '[' + @NextDB + ']'
				else
					set @db_name_filegroup = '[' + @NextDB + '] FILEGROUP = ''' + REPLACE(@FileGroup, ',', ''', FILEGROUP = ''') + ''''

				declare @filePath varchar(8000)

				set @filePath = 'NUL'

				if @Path <> 'NUL'
				begin
					set @filePath = @Path + REPLACE(@@SERVERNAME,'\','-')+'_' + @NextDB + @FileStamp

					if @DifBackup = 1 
						set @filePath = @filePath + '_diff.bak'
					else if @LogBackup = 1
						set @filePath = @filePath + '.trn'
					else
						set @filePath = @filePath + '.bak'

				end
	
				IF @DifBackup = 1
					SELECT @SqlCmnd = 'backup database ' + @db_name_filegroup + ' to '+ @Location + ' = ''' + @filePath + '''  with init, differential'
					, @DBList = @DBList + @SemiColon + @NextDB	
		
				IF @LogBackup = 0 AND @DifBackup = 0
					SELECT @SqlCmnd = 'backup database ' + @db_name_filegroup+ ' to '+ @Location + ' = ''' + @filePath + ''' with init'
					, @DBList = @DBList + @SemiColon + @NextDB		 
			
				IF @LogBackup = 1
					SELECT @SqlCmnd = 'backup log [' + @NextDB + '] to '+ @Location + ' = ''' + @filePath + ''' with init'
					, @DBList = @DBList + @SemiColon + @NextDB


				IF @Credential IS NOT NULL
					SELECT 	@Sqlcmnd = @Sqlcmnd + ', credential ='''+ @Credential +''''

				
				if @Compression = 1 and @BuildNumber > 9
					set @SqlCmnd = @SqlCmnd + ', compression'
				else if @BuildNumber > 9
					set @SqlCmnd = @SqlCmnd + ', no_compression'

				if @CopyOnly = 1
					set @SqlCmnd = @SqlCmnd + ', copy_only'

				if @CheckSum = 1
					set @SqlCmnd = @SqlCmnd + ', checksum'
					
		
				SET  @SemiColon = ';'
	
		
	
			IF (@DEBUG = 1) SELECT 'DEBUG: @SqlCmnd=' + @SqlCmnd
	
			IF (@DEBUG = 0)
				BEGIN

					begin try

					
						--run the backup command
						if @SQB = 0 
						begin
							exec (@SqlCmnd)
						end
			
						--IF @SQB = 1
						--BEGIN
						--	DECLARE @exitcode INT
						--	DECLARE @errorcode INT
				
						--	SET @SqlCmnd = '-SQL "backup database [' + @NextDB + '] to disk = [' + @Path	+ @NextDB + @FileStamp + '.sqb' + '] with init "'
							
						--	EXEC master.dbo.sqlbackup @SQLCmnd, @exitcode OUTPUT, @errorcode OUTPUT
				
						--	IF @exitcode > 0 OR @errorcode > 0
						--	BEGIN
						--		--need to raise an error to force the job to pick up the fact it failed
						--		RAISERROR('Backup failed',16,1)
						--	END
						--END
					end try

					begin catch
						
						select 'Error occurred on line number: ' + convert(varchar(11), error_line())  + char(13) + 'Error No: ' + convert(varchar(11), error_number()) + char(13) + 'Error Msg: ' + error_message()
						set @errorOccurred = 1
					end catch
	
				END 
	
				SET @ErrorStatus = @@error
	
				Cursor_Loop:
					
				FETCH NEXT FROM csrDBList 
				INTO @NextDB
			end
		end
	end
	
	IF (@CursorOpen > 0)
	begin
		CLOSE csrDBList
		DEALLOCATE csrDBList
	end
	
	IF (@DEBUG = 1)
	begin
		SELECT @Msg = 'DEBUG: ' + @ProcName + ': Exiting at ' 
		+ CONVERT( VARCHAR, GETDATE(), 121 ) + @Crlf
		+ '       @ErrorStatus=' + CONVERT( VARCHAR, @ErrorStatus) + @Crlf
		PRINT @Msg
	end

	if @errorOccurred = 1
	begin
		raiserror ('sp__Backup failed.  See error log for details', 16, 1)
	end
	
	RETURN @ErrorStatus
end



