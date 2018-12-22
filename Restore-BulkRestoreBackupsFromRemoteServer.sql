/*===========================================================
** Copyright (c) Coeo 2017.  All rights reserved.
**
** THIS PROGRAM IS DISTRIBUTED WITHOUT ANY WARRANTY; WITHOUT 
** EVEN THE IMPLIED WARRANTY OF MERCHANTABILITY OR FITNESS 
** FOR PURPOSE.
** 
** File: .
** Vers: 1.0
** Desc: Automated restore
===========================================================*/

use master
go

if exists(select 1 from sys.objects where name = 'sp__GetBackupDiskCmd')
	drop procedure sp__GetBackupDiskCmd
go

create procedure sp__GetBackupDiskCmd
(
	@database_name		varchar(128),
	@bkup_path_is_unc	bit,
	@backup_path		varchar(8000),
	@unc_share			varchar(8000),
	@litespeed			bit = 0,
	@bkup_path_is_local	bit = 0,
	@local_path			varchar(1000),
	@disk_cmd			varchar(max) output
)

/*
	Note that this procedure will only every work when called from the procedure sp__RestoreDB due 
	to the use of a global temporary table

*/

as 

set nocount on


set @disk_cmd = ''



begin try
	declare file_cursor cursor
	for
	select physical_device_name
	from ##databases
	where database_name = @database_name

	open file_cursor

	fetch next from file_cursor into @backup_path

	while @@fetch_status = 0
	begin

		if @bkup_path_is_local = 1
		begin
			set @backup_path = @local_path + reverse(substring(reverse(@backup_path), 1, charindex('\',reverse(@backup_path))))
		end
		else
		begin
			--if the backup path was not to a unc, replace the drive letter with the @unc_share (NOTE THAT THIS ONLY WORKS FOR NON-MOUNT-POINTS
			if @bkup_path_is_unc <> 1 and @unc_share is not null
				set @backup_path = replace(@backup_path,substring(@backup_path, 1, 3), @unc_share)
		end
				
		if @litespeed = 0
			set @disk_cmd = @disk_cmd + 'disk = ''' + @backup_path + ''',' + char(10)
		else
			set @disk_cmd = @disk_cmd + @backup_path + ',' + char(10)

		fetch next from file_cursor into @backup_path
	end
end try
begin catch

end catch

close file_cursor
deallocate file_cursor


set @disk_cmd = substring(@disk_cmd, 1, len(@disk_cmd) - 2)




go

use master
go


use master
go

if exists(select 1 from sys.objects where name = 'sp__GetBackupFileList')
	drop procedure sp__GetBackupFileList
go

create procedure sp__GetBackupFileList
(
	@disk				varchar(max),
	@move_to_data		varchar(max),
	@move_to_log		varchar(max),
	@move_to_filestream	varchar(max),
	@litespeed			bit = 0,
	@move_to_option		varchar(max) output,
	@has_filestream		bit output
)

as

set nocount on

if right(@move_to_data,1) <> '\' set @move_to_data = @move_to_data + '\'
if right(@move_to_log,1) <> '\' set @move_to_log = @move_to_log + '\'
if right(@move_to_filestream,1) <> '\' set @move_to_filestream = @move_to_filestream + '\'

if @litespeed = 0
	create table #filelist
	(
		logical_name	nvarchar(128),
		physical_name	nvarchar(260),
		[type]			char(1),
		[filegroup]		nvarchar(128),
		size			numeric(20,0),
		max_size		numeric(20,0),
		[file_id]		bigint,
		create_lsn		numeric(25,0),
		drop_lsn		numeric(25,0),
		unique_id		uniqueidentifier,
		readonly_lsn	numeric(25,0),
		readwrite_lsn	numeric(25,0),
		backup_size		bigint,
		sourceblock		int,
		file_group		int,
		log_group		uniqueidentifier,
		diff_base		numeric(25,0),
		diff_base_guid	uniqueidentifier,
		is_read_only	bit,
		is_present		bit,
		TDE				varbinary(32)
	)
else
	create table #filelist_litespeed
	(
		logical_name	nvarchar(128),
		physical_name	nvarchar(260),
		[type]			char(1),
		[filegroup]		nvarchar(128),
		size			numeric(20,0),
		max_size		numeric(20,0),
		[file_id]		bigint,
		backup_size		bigint,
		file_group		int		
	)

declare @restore_filelist_cmd nvarchar(max)

if @litespeed = 0
	set @restore_filelist_cmd = 'restore filelistonly from ' + @disk
else
	set @restore_filelist_cmd = 'exec master.dbo.xp_restore_filelistonly @filename = ''' + @disk + ''''

begin try

	if @litespeed = 0
		insert into #filelist
		exec sp_executesql @restore_filelist_cmd
	else
		insert into #filelist_litespeed
		exec sp_executesql @restore_filelist_cmd

	
	
	declare @logical_name nvarchar(128)
	declare @file_name nvarchar(260)
	declare @type char(1)

	set @move_to_option = ''

	if @litespeed = 0
		declare filelist_cursor cursor
		for 
		select logical_name, reverse(substring(reverse(physical_name), 1, charindex('\',reverse(physical_name)) - 1)) as [filename], [type]
		from #filelist
	else
		declare filelist_cursor cursor
		for 
		select logical_name, reverse(substring(reverse(physical_name), 1, charindex('\',reverse(physical_name)) - 1)) as [filename], [type]
		from #filelist_litespeed

	open filelist_cursor

	fetch next from filelist_cursor into @logical_name, @file_name, @type

	while @@fetch_status = 0
	begin

		
		if @type = 'D' and @move_to_data is not null
		begin
			if @litespeed = 0
				set @move_to_option = @move_to_option + 'move ''' + @logical_name + ''' to ''' + @move_to_data + @file_name + ''',' + char(10)
			else
				set @move_to_option = @move_to_option + 'move ''''' + @logical_name + ''''' to ''''' + @move_to_data + @file_name + ''''', ' 
		end
		
		if @type = 'L' and @move_to_log is not null
		begin
			if @litespeed = 0
				set @move_to_option = @move_to_option + 'move ''' + @logical_name + ''' to ''' + @move_to_log + @file_name + ''',' + char(10)
			else
				set @move_to_option = @move_to_option + 'move ''''' + @logical_name + ''''' to ''''' + @move_to_log + @file_name + ''''', ' 
		end

		if @type = 'S' and @move_to_filestream is not null
		begin
			set @has_filestream = 1

			if @litespeed = 0
				set @move_to_option = @move_to_option + 'move ''' + @logical_name + ''' to ''' + @move_to_filestream + ''',' + char(10)
			else
				set @move_to_option = @move_to_option + 'move ''''' + @logical_name + ''''' to ''''' + @move_to_filestream + ''''', ' 
		end



		fetch next from filelist_cursor into @logical_name, @file_name, @type
	end

	close filelist_cursor
	deallocate filelist_cursor

	if @litespeed = 0
		set @move_to_option = substring(@move_to_option, 1, len(@move_to_option) - 2)
	else
		set @move_to_option = substring(@move_to_option, 1, len(@move_to_option) - 1)
		
	return
end try

begin catch

end catch

go

use master
go

if exists(select 1 from sys.objects where name = 'sp__RestoreDB')
	drop procedure sp__RestoreDB
go

create procedure sp__RestoreDB
(
       @databases                   varchar(max),				--'USER_DATABASES, -Apps' or 'DB1,DB2,-DB3'
       @destination_db				varchar(128) = null,		--only use if restoring one database to a different database name
       @unc_share					varchar(256) = null,		--the name of the UNC share that the backup file is stored on. 
       @source_linked_server		varchar(128) = null,		--the name of the linked server which serves as the source of the backup file.  If null, we're restoring from a local database backup
       @bkup_path_is_unc			bit = 0,                    --indicates whether the backup path is a UNC or physical drive
       @bkup_path_is_local			bit = 0,					--indicates that the backup path is on a local disk
       @local_path                  varchar(1000) = null,		--local path
       @move_to_data				varchar(max) = null,		--the location of the move-to data path
       @move_to_log					varchar(max) = null,		--the location of the move-to log path
	   @move_to_filestream			varchar(max) = null,		--the location of the move-to filestream path
	   @create_filestream_folder	bit = 0,					--if true, will create a filestream folder (database name) in the above filestream folder
       @backup_date_offset			int = 0,                    --days to go back for backup
       @set_simple_recovery			bit = 0,					--set database to simple recovery after restore
       @litespeed                   bit = 0,                    --use litespeed extended procedures to restore a litespeed backup
       @keep_cdc                    bit = 0,					--use the keep_cdc restore option
       @norecovery                  bit=0,						--keep the database in norecovery after restore	   	
	   @bkup_file_path				varchar(1000) = null,		--if populated, will restore directly from this filepath.
       @debug                       tinyint = 0
)

/*
       examples:
       
       exec sp__RestoreDB @databases = 'USER_DATABASES', 
              @source_linked_server= 'DCTPMSC2S3\C2S3',
              @unc_share = '\\DCTPMSC2S3\H\',
              @bkup_path_is_unc = 0,
              @set_simple_recovery = 1,
              @backup_date_offset = 0,
              @litespeed = 0,
              @debug = 1          
			  
		exec sp__RestoreDB @databases = 'DB1', 
							@bkup_file_path = 'C:\Utilities\Backups\', 
							@move_to_filestream = 'c:\utilities\backups\', 
							@create_filestream_folder = 1, 
							@norecovery = 1, 
							@debug = 1
		
*/


                     
                     
as

set nocount on

declare @database_name varchar(128)
declare @backup_path varchar(1000)
declare @current_db varchar(128)
declare @sql_cmd nvarchar(max)
declare @error_occurred bit
declare @error_message nvarchar(4000);


begin try

       
       create table ##include_list
       (
              database_name varchar(128)
       )

       create table ##backups
       (
              database_name varchar(128),
              physical_device_name varchar(1000),
              backup_finish_date datetime
       )

       create table ##databases
       (
              database_name varchar(128),
              physical_device_name varchar(1000)
       )

       if right(@unc_share,1) <> '\' set @unc_share = @unc_share + '\'

       
       if substring(reverse(@databases),1,1) <> ',' set @databases = @databases + ','

       declare @source varchar(128)

       if @source_linked_server is null
              set @source = ''
       else
              set @source = '[' + @source_linked_server + '].'
       
       while len(@databases) > 0
       begin
       
              set @current_db = ltrim(rtrim(substring(@databases,1,charindex(',',@databases) - 1)))

              

              if @current_db = 'USER_DATABASES'
              begin
                     declare @cmd nvarchar(max)
                     set @cmd = 'insert into ##include_list 
           select name from ' + @source + 'master.sys.databases where name not in (''master'', ''model'', ''msdb'', ''tempdb'', ''distribution'', ''ReportServer'', ''ReportServerTempDB'')'

                     exec sp_executesql @cmd
              end

              --if the current database is excluded remove it from the ##include_list table
              if substring(@current_db, 1, 1) = '-'
                     delete ##include_list where database_name = substring(@current_db, 2, len(@current_db))
              else
                     insert into ##include_list 
                     select @current_db
                     where @current_db <> 'USER_DATABASES'
                     and not exists (select * from ##include_list where database_name = @current_db)
       
              set @databases = substring(@databases,charindex(',',@databases) + 1,len(@databases))
       
       end
       
       --select * from ##include_list

	   if @bkup_file_path is null
	   begin
       
		   set @sql_cmd = 'insert into ##backups
		   select database_name, physical_device_name, backup_finish_date
		   from ' + @source + 'msdb.dbo.backupset bs
				  join ' + @source + 'msdb.dbo.backupmediafamily bf on bf.media_set_id = bs.media_set_id
		   where database_name in (select database_name from ##include_list)
						 and type = ''D''
						 and backup_finish_date < convert(datetime, convert(varchar(11), getdate()' + case when @backup_date_offset = 0 then '+1' when @backup_date_offset = 1 then '-0' else convert(varchar(11), (@backup_date_offset - 1)*-1 ) end + ', 106))   
                                  
						 '

			exec sp_executesql @sql_cmd
       
			insert into ##databases
			select database_name, physical_device_name
			from ##backups b
			where backup_finish_date in (select max(backup_finish_date) from ##backups where database_name = b.database_name)
		end
		else
		begin
			create table #files(backup_file varchar(1000), depth tinyint, is_file bit)
			insert into #files exec xp_dirtree @bkup_file_path, 1, 1

			if right(@bkup_file_path,1) <> '\' set @bkup_file_path = @bkup_file_path + '\'

			delete #files where is_file = 0 

			declare @file_name varchar(1000)

			select top 1 @file_name = @bkup_file_path + backup_file from #files order by backup_file desc

			insert into ##databases select @current_db,@file_name
		end

       --print @sql_cmd
       
             

       if @debug = 2 select * from ##databases

       declare backup_cursor cursor
       for 
       select distinct database_name
       from ##databases


       open backup_cursor

       fetch next from backup_cursor into @database_name 

       while @@fetch_status = 0
       begin

              declare @restore_db varchar(128)

              if @destination_db is null 
                     set @restore_db = @database_name
              else
                     set @restore_db = @destination_db

                     

              declare @disk_cmd varchar(max)

              exec sp__GetBackupDiskCmd @database_name = @database_name, @bkup_path_is_unc = @bkup_path_is_unc, @backup_path = @backup_path, @unc_share = @unc_share, 
                                                              @litespeed = @litespeed, @bkup_path_is_local = @bkup_path_is_local, @local_path = @local_path, @disk_cmd = @disk_cmd output
              

              declare @restore_cmd nvarchar(max)
              declare @alter_cmd nvarchar(max)

              if @debug = 2 print @disk_cmd

                           
              set @restore_cmd = 'restore database [' + @restore_db + ']' + char(10) +
                                                'from ' + @disk_cmd + char(10) + 
                                                'with stats = 1, replace'

              
              if @debug = 2 print @restore_cmd

              if @move_to_data is not null or @move_to_log is not null or @move_to_filestream is not null
              begin
                     declare @move_option varchar(max)
					 declare @has_filestream bit

					 if right(@move_to_filestream,1) <> '\' set @move_to_filestream = @move_to_filestream + '\'

					 declare @full_filestream_path varchar(1000) = @move_to_filestream + @database_name

                     exec sp__GetBackupFileList @disk = @disk_cmd, @move_to_data = @move_to_data, @move_to_log = @move_to_log, @move_to_filestream = @full_filestream_path, @litespeed = @litespeed, @move_to_option = @move_option output, @has_filestream = @has_filestream output
                     
					 
					 if @move_option is not null and @move_option <> '' set @restore_cmd = @restore_cmd + ',' + char(10) + @move_option

					 if @create_filestream_folder = 1 and @has_filestream = 1 and @debug = 0
					 begin
						exec master.sys.xp_create_subdir @full_filestream_path
					 end
                     
              end

              if @keep_cdc = 1
              begin
                     set @restore_cmd = @restore_cmd + ', keep_cdc'
              end

              if @norecovery = 1
              begin
                     set @restore_cmd = @restore_cmd + ', norecovery'
              end

              if @debug = 2 print @move_option
              
              if @debug = 2 print @restore_cmd
                           
              set @alter_cmd = 'if exists(select * from sys.databases where state_desc = ''ONLINE'' and name = ''' + @restore_db + ''')' + 
                                                char(10) + 'alter database [' + @restore_db + '] set offline with rollback immediate' + char(10) 

              declare @simple_cmd nvarchar(max)
              set @simple_cmd = 'alter database [' + @restore_db + '] set recovery simple with no_wait' + char(10) 
              
              declare @options varchar(max) = 'replace'

              print '--Restoring database [' + @restore_db + ']....'
              print ''

              

              if @debug >= 1
              begin
                     print @alter_cmd + 'go' + char(10) + char(10)
                     if @litespeed = 1
                           begin
                                  if @move_option is not null set @options = @options + ', ' + @move_option
                                  print 'exec master.dbo.xp_restore_database @database = ''' + @restore_db + ''',  
                                                              @filename = ''' + @disk_cmd + ''', 
                                                              @with = ''' + @options + '''' + char(10) 
                           end
                           else
                           begin
                                  print @restore_cmd + char(10) + 'go' + char(10) + char(10)
                           end
                     if @set_simple_recovery = 1 print @simple_cmd + 'go' + char(10) + char(10)
              end
              else
              begin
                     begin try
                           
                           exec sp_executesql @alter_cmd

                           if @litespeed = 1
                           begin
                                  if @move_option is not null set @options = @options + ', ' + @move_option
                                  exec master.dbo.xp_restore_database @database = @restore_db, @filename = @disk_cmd, @with = @options
                           end
                           else
                           begin
                                  exec sp_executesql @restore_cmd
                           end
                           if @set_simple_recovery = 1 exec sp_executesql @simple_cmd                         
                     end try
                     begin catch
                           select @error_message = 'Error whilst restoring database [' + @restore_db + ']...' + error_message(), @error_occurred = 1

                       print @error_message
                           print ''
                     end catch
              end

              fetch next from backup_cursor into @database_name 
       end


       
end try

begin catch

       
    declare @error_severity int;
    declare @error_state int;

    select @error_message = error_message(),
           @error_severity = error_severity(),
           @error_state = error_state();

    
    raiserror (@error_message, -- message text.
               @error_severity, -- severity.
               @error_state -- state.
               );

end catch

close backup_cursor
deallocate backup_cursor

drop table ##include_list
drop table ##databases
drop table ##backups

if @error_occurred = 1
       raiserror ('An error occurred whilst restoring a database.  Please review the output for details', 16, 1)


