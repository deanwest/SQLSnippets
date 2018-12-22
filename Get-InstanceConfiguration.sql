DECLARE @CpuPhysicalCores INT
DECLARE @CpuVirtualCores INT
DECLARE @MemTotalRamMb INT
DECLARE @MemSqlRamMb INT
DECLARE @MemAppRamMb INT 
DECLARE @MemOSRamMb INT 
SET @MemOSRamMb = 1000 --minimum for Windows OS
DECLARE @MinimumSQLRamMb INT 
DECLARE @MajorVersion TINYINT
DECLARE @tempDbFiles TINYINT

SELECT @MinimumSQLRamMb = CASE
		WHEN @MajorVersion < 12 THEN 1000 --SQL 2012 or earlier minimum requirements is 1GB
		WHEN @MajorVersion = 12 THEN 4096 --SQL 2014 minimum requirements is 4GB
		END 

--change @MemAppRamMb to include application requirements. 0 assumes dedicated SQL server.
SET @MemAppRamMb = 0

SET @MajorVersion = CAST(SUBSTRING(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(5)),1,CHARINDEX('.',CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(5)))-1) AS TINYINT)

SELECT @tempDbFiles = (SELECT COUNT(*) FROM sys.dm_os_schedulers WHERE parent_node_id = 0 and STATUS ='VISIBLE ONLINE') 
	 /(cpu_count/hyperthread_ratio) 
FROM sys.dm_os_sys_info  

--Prior to SQL 2012 buffer pool (max server memory) didnt include CLR and lots of other things so more RAM needs to be given for OS.
SELECT @MemAppRamMb = CASE
		WHEN @MajorVersion >= 11 THEN 0 --SQL 2012 
		ELSE 1000 END

IF @MajorVersion >= 11 --SQL 2012 onwards has different column name (physical_memory_kb rather than physical_memory_in_bytes)
BEGIN
	EXEC sp_executesql 
	N'	SELECT 	@MemTotalRamMbOut = physical_memory_kb/1024.
		,@CpuPhysicalCoresOut = cpu_count
		, @CpuVirtualCoresOut = cpu_count - hyperthread_ratio
	FROM sys.dm_os_sys_info;'
	,N'@MemTotalRamMbOut int output, @CpuPhysicalCoresOut int output, @CpuVirtualCoresOut int output'
	,@MemTotalRamMbOut = @MemTotalRamMb output, @CpuPhysicalCoresOut = @CpuPhysicalCores output, @CpuVirtualCoresOut = @CpuVirtualCores output
END
ELSE
BEGIN
	EXEC sp_executesql 
	N'	SELECT 	@MemTotalRamMbOut = physical_memory_in_bytes/1024./1024.
		,@CpuPhysicalCoresOut = cpu_count
		, @CpuVirtualCoresOut = cpu_count - hyperthread_ratio
	FROM sys.dm_os_sys_info;'
	,N'@MemTotalRamMbOut int output, @CpuPhysicalCoresOut int output, @CpuVirtualCoresOut int output'
	,@MemTotalRamMbOut = @MemTotalRamMb output, @CpuPhysicalCoresOut = @CpuPhysicalCores output, @CpuVirtualCoresOut = @CpuVirtualCores output
END

SET @MemSqlRamMb = @MemTotalRamMb
	- @MemOSRamMb --deduct memory for OS
	- @MemAppRamMb --deduct memory for applications
	- CASE --deduct for memory required to manage server RAM
	WHEN @MemTotalRamMb < 16000 THEN CEILING(@MemTotalRamMb / 6. /1000.) * 1000 --1GB to manage every 6GB (4) up to 16GB
	WHEN @MemTotalRamMb >= 16000 THEN 2500 + (CEILING((@MemTotalRamMb - 16000) / 12. /1000.) * 1000) --1GB to manage every 12GB (8) over 16GB
	END

IF @MemSqlRamMb < @MinimumSQLRamMb --cant have less than minimum memory requirement for SQL
BEGIN
	SET @MemSqlRamMb = @MinimumSQLRamMb
END


DECLARE @configs TABLE (
	name nvarchar(35),
	default_value varchar(50),
	target_value varchar(50))

INSERT INTO @configs(name,target_value,default_value)
SELECT 'access check cache bucket count','0','0'
UNION ALL SELECT 'access check cache quota','0','0'
UNION ALL SELECT 'Ad Hoc Distributed Queries','0','0'
UNION ALL SELECT 'affinity I/O mask','0','0'
UNION ALL SELECT 'affinity mask','0','0'
UNION ALL SELECT 'affinity64 I/O mask','0','0'
UNION ALL SELECT 'affinity64 mask','0','0'
UNION ALL SELECT 'Agent XPs','1','1' --default 0. ignore as set by SQL Agent Service
UNION ALL SELECT 'allow updates','0','0'
UNION ALL SELECT 'backup checksum default','0','0'
UNION ALL SELECT 'backup compression default','1','0' --default 0
UNION ALL SELECT 'blocked process threshold (s)','5','0' --default 0
UNION ALL SELECT 'c2 audit mode','0','0'
UNION ALL SELECT 'clr enabled','1','0' --default 0
UNION ALL SELECT 'common criteria compliance enabled','0','0'
UNION ALL SELECT 'contained database authentication','0','0'
UNION ALL SELECT 'cost threshold for parallelism','25','5' --default 5, consider 25-50
UNION ALL SELECT 'cross db ownership chaining','0','0'
UNION ALL SELECT 'cursor threshold','-1','-1'
UNION ALL SELECT 'Database Mail XPs','0','0' --default 0
UNION ALL SELECT 'default full-text language','1033','1033'
UNION ALL SELECT 'default language','0','0'
UNION ALL SELECT 'default trace enabled','1','1'
UNION ALL SELECT 'disallow results from triggers','0','0'
UNION ALL SELECT 'EKM provider enabled','0','0'
UNION ALL SELECT 'filestream access level','1','0'
UNION ALL SELECT 'fill factor (%)','0','0'
UNION ALL SELECT 'ft crawl bandwidth (max)','100','100'
UNION ALL SELECT 'ft crawl bandwidth (min)','0','0'
UNION ALL SELECT 'ft notify bandwidth (max)','100','100'
UNION ALL SELECT 'ft notify bandwidth (min)','0','0'
UNION ALL SELECT 'index create memory (KB)','0','0'
UNION ALL SELECT 'in-doubt xact resolution','0','0'
UNION ALL SELECT 'lightweight pooling','0','0'
UNION ALL SELECT 'locks','0','0'
UNION ALL SELECT 'max degree of parallelism',@CpuPhysicalCores,'0' --https://support.microsoft.com/en-us/kb/2806535
UNION ALL SELECT 'max full-text crawl range','4','4'
UNION ALL SELECT 'max server memory (MB)',@MemSqlRamMb,'2147483647'
UNION ALL SELECT 'max text repl size (B)','65536','65536'
UNION ALL SELECT 'max worker threads','0','0'
UNION ALL SELECT 'media retention','0','0'
UNION ALL SELECT 'min memory per query (KB)','1024','1024'
UNION ALL SELECT 'min server memory (MB)','0','0'--consider @MinimumSQLRamMb
UNION ALL SELECT 'nested triggers','1','1'
UNION ALL SELECT 'network packet size (B)','4096','4096'
UNION ALL SELECT 'Ole Automation Procedures','0','0'
UNION ALL SELECT 'open objects','0','0'
UNION ALL SELECT 'optimize for ad hoc workloads','1','0'
UNION ALL SELECT 'PH timeout (s)','60','60'
UNION ALL SELECT 'precompute rank','0','0'
UNION ALL SELECT 'priority boost','0','0'
UNION ALL SELECT 'query governor cost limit','0','0'
UNION ALL SELECT 'query wait (s)','-1','-1'
UNION ALL SELECT 'recovery interval (min)','0','0'
UNION ALL SELECT 'remote access','1','0'
UNION ALL SELECT 'remote admin connections','1','0'
UNION ALL SELECT 'remote login timeout (s)','10','10'
UNION ALL SELECT 'remote proc trans','0','0'
UNION ALL SELECT 'remote query timeout (s)','600','600'
UNION ALL SELECT 'Replication XPs','0','0'
UNION ALL SELECT 'scan for startup procs','1','0'
UNION ALL SELECT 'server trigger recursion','1','1'
UNION ALL SELECT 'set working set size','0','0'
UNION ALL SELECT 'show advanced options','1','0'
UNION ALL SELECT 'SMO and DMO XPs','1','1'
UNION ALL SELECT 'transform noise words','0','0'
UNION ALL SELECT 'two digit year cutoff','2049','2049'
UNION ALL SELECT 'user connections','0','0'
UNION ALL SELECT 'user options','0','0'
UNION ALL SELECT 'xp_cmdshell','0','0'

SELECT s.Name
	,s.Value
	,s.Minimum
	,s.Maximum
	,s.[Description]
	,s.is_dynamic
	,s.is_advanced
	,c.target_value
	,c.default_value
	,'EXEC sp_configure '''+s.Name+''', '''+CAST(c.target_value as varchar(50))+'''' as changeScript
FROM sys.configurations as s
	INNER JOIN @configs as c
		ON s.name = c.name
WHERE CAST(s.Value as varchar(50)) <> c.target_value
--OR CAST(s.Value as varchar(50)) <> c.default_value
