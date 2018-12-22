DECLARE @start datetime;
DECLARE @end datetime;

SET @start = GETDATE();

IF CAST(CAST(SERVERPROPERTY('ProductVersion') AS varchar(4)) as decimal(4,2)) <= 8
BEGIN
	-- SQL 2000
	CREATE TABLE #ErrorLog2000 (LogText nvarchar(4000), ContRow int)
	
	INSERT INTO #ErrorLog2000
	EXEC master.dbo.xp_readerrorlog
	SET @end = GETDATE()
	
	SELECT * FROM (
		SELECT CASE WHEN ISDATE(LEFT(LogText, 19)) = 1 
				THEN CAST(LEFT(LogText, 19) AS smalldatetime)
				ELSE NULL END AS LogDate, 
			SUBSTRING(LogText, 22, LEN(LogText) - 22) AS LogText
		FROM #ErrorLog2000 
		WHERE LEN(LogText) > 19
		AND (LogText LIKE '%error%'
		    OR LogText LIKE '%kill%' 
		    OR LogText LIKE '%fail%' 
		    OR LogText LIKE '%timed%'
		    OR LogText LIKE '%cancelled%' 
		    OR LogText LIKE '%exception%'
		    OR LogText LIKE '%encountered%' 
		    OR LogText LIKE '%memory%' 
		    OR LogText LIKE '% not %' 
		    OR LogText LIKE '%privilege%' 
		    OR LogText LIKE '%distributed%' 
		    OR LogText LIKE '%yield%' 			
		    OR LogText LIKE '%scheduler%' 
		    OR LogText LIKE '%BobMgr%' 
		    OR LogText LIKE '%offset%' 
		    OR LogText like '%dump%'
		    OR LogText LIKE 'Microsoft SQL Server%'
		    OR LogText LIKE '%reinitialized%')
	    AND LogText NOT LIKE '%Database backed up%'
	    AND LogText NOT LIKE '%Log was backed up%'
		AND LogText NOT LIKE '%Log backed up%'
	    AND LogText NOT LIKE '%Database differential changes%'
	    AND LogText NOT LIKE '%0 error%'
	    --AND LogText NOT LIKE '%login fail%'
	    --AND LogText NOT LIKE '%Error: 18456, Severity: 14%'
	    AND LogText NOT LIKE '%without errors%'
	    AND LogText NOT LIKE '%Logging SQL Server messages%'
	    AND LogText NOT LIKE '%SQL server listening%'
 		 AND LogText NOT LIKE '%Attempting to initialize %Distributed Transaction Coordinator%'
	    AND LogText NOT LIKE '%Attempting to load library ''xplog70.dll'' into memory. This is an informational message only. No user action is required.%'
	    AND LogText NOT LIKE '%Attempting to load library ''odsole70.dll'' into memory. This is an informational message only. No user action is required.%'
	    AND LogText NOT LIKE '%Attempting to load library ''xpstar.dll'' into memory. This is an informational message only. No user action is required.%'
	    AND LogText NOT LIKE '%Attempting to load library ''xpsqlbot.dll'' into memory. This is an informational message only. No user action is required.%'
	    AND LogText NOT LIKE '%This is an informational message only. No user action is required%'
	    AND LogText NOT LIKE '%error log has been reinitialized%'
		AND LogText NOT LIKE '%Login succeeded%'
		AND LogText NOT LIKE '%Copyright (c)%'
		AND LogText NOT LIKE '%Attempting to cycle error log%'
	) t
	WHERE LogDate > DATEADD(day, DATEDIFF(day, 10, GETDATE()), 0)
	ORDER BY LogDate DESC

	DROP TABLE #ErrorLog2000
END
ELSE
BEGIN
	-- SQL 2005
	CREATE TABLE #ErrorLog2005 (LogDate datetime, ProcessInfo nvarchar(100), LogText nvarchar(4000))
	
	INSERT INTO #ErrorLog2005
	EXEC master.dbo.xp_readerrorlog 0, 1
	SET @end = GETDATE()
	
	INSERT INTO #ErrorLog2005
	EXEC master.dbo.xp_readerrorlog 1, 1

	--INSERT INTO #ErrorLog2005
	--EXEC master.dbo.xp_readerrorlog 2, 1
	--INSERT INTO #ErrorLog2005
	--EXEC master.dbo.xp_readerrorlog 3, 1
	--INSERT INTO #ErrorLog2005
	--EXEC master.dbo.xp_readerrorlog 4, 1
	--INSERT INTO #ErrorLog2005
	--EXEC master.dbo.xp_readerrorlog 5, 1
	--INSERT INTO #ErrorLog2005
	--EXEC master.dbo.xp_readerrorlog 6, 1
	--INSERT INTO #ErrorLog2005
	--EXEC master.dbo.xp_readerrorlog 7, 1
	--INSERT INTO #ErrorLog2005
	--EXEC master.dbo.xp_readerrorlog 8, 1
	--INSERT INTO #ErrorLog2005
	--EXEC master.dbo.xp_readerrorlog 9, 1
	--INSERT INTO #ErrorLog2005
	--EXEC master.dbo.xp_readerrorlog 10, 1
	--INSERT INTO #ErrorLog2005
	--EXEC master.dbo.xp_readerrorlog 11, 1
	--INSERT INTO #ErrorLog2005
	--EXEC master.dbo.xp_readerrorlog 12, 1
	--INSERT INTO #ErrorLog2005
	--EXEC master.dbo.xp_readerrorlog 13, 1
	--INSERT INTO #ErrorLog2005
	--EXEC master.dbo.xp_readerrorlog 14, 1
	--INSERT INTO #ErrorLog2005
	--EXEC master.dbo.xp_readerrorlog 15, 1
	--INSERT INTO #ErrorLog2005
	--EXEC master.dbo.xp_readerrorlog 16, 1
	--INSERT INTO #ErrorLog2005
	--EXEC master.dbo.xp_readerrorlog 17, 1
	--INSERT INTO #ErrorLog2005
	--EXEC master.dbo.xp_readerrorlog 18, 1
	--INSERT INTO #ErrorLog2005
	--EXEC master.dbo.xp_readerrorlog 19, 1
	--INSERT INTO #ErrorLog2005
	--EXEC master.dbo.xp_readerrorlog 20, 1
	--INSERT INTO #ErrorLog2005
	--EXEC master.dbo.xp_readerrorlog 21, 1
	--INSERT INTO #ErrorLog2005
	--EXEC master.dbo.xp_readerrorlog 22, 1
	--INSERT INTO #ErrorLog2005
	--EXEC master.dbo.xp_readerrorlog 23, 1
	--INSERT INTO #ErrorLog2005
	--EXEC master.dbo.xp_readerrorlog 24, 1
	--INSERT INTO #ErrorLog2005
	--EXEC master.dbo.xp_readerrorlog 25, 1
	--INSERT INTO #ErrorLog2005
	--EXEC master.dbo.xp_readerrorlog 26, 1
	--INSERT INTO #ErrorLog2005
	--EXEC master.dbo.xp_readerrorlog 27, 1
	--INSERT INTO #ErrorLog2005
	--EXEC master.dbo.xp_readerrorlog 28, 1
	--INSERT INTO #ErrorLog2005
	--EXEC master.dbo.xp_readerrorlog 29, 1
	--INSERT INTO #ErrorLog2005
	--EXEC master.dbo.xp_readerrorlog 30, 1
	--INSERT INTO #ErrorLog2005
	--EXEC master.dbo.xp_readerrorlog 31, 1

	SELECT LogDate, LogText
	FROM #ErrorLog2005 
	WHERE (LogText LIKE '%error%'
			OR LogText LIKE '%kill%' 
			OR LogText LIKE '%fail%' 
		    OR LogText LIKE '%timed%'
		    OR LogText LIKE '%cancelled%' 
			OR LogText LIKE '%exception%'
			OR LogText LIKE '%encountered%' 
			OR LogText LIKE '%memory%' 
			OR LogText LIKE '% not %' 
			OR LogText LIKE '%privilege%' 
			OR LogText LIKE '%distributed%' 
			OR LogText LIKE '%yield%' 			
			OR LogText LIKE '%scheduler%' 
			OR LogText LIKE '%BobMgr%' 
			OR LogText LIKE '%offset%' 
			OR LogText like '%dump%'
			OR LogText LIKE 'Microsoft SQL Server%'
			OR LogText LIKE '%reinitialized%')
		AND LogText NOT LIKE '%Database backed up%'
		AND LogText NOT LIKE '%Log was backed up%'
		AND LogText NOT LIKE '%Log backed up%'
		AND LogText NOT LIKE '%Database differential changes%'
		AND LogText NOT LIKE '%0 error%'
	   --AND LogText NOT LIKE '%login fail%'
	   --AND LogText NOT LIKE '%Error: 18456, Severity: 14%'
		AND LogText NOT LIKE '%without errors%'
		AND LogText NOT LIKE '%Logging SQL Server messages%'
		AND LogText NOT LIKE '%SQL server listening%'
		AND LogText NOT LIKE '%Attempting to initialize %Distributed Transaction Coordinator%'
	   AND LogText NOT LIKE '%Attempting to load library ''xplog70.dll'' into memory. This is an informational message only. No user action is required.%'
	   AND LogText NOT LIKE '%Attempting to load library ''odsole70.dll'' into memory. This is an informational message only. No user action is required.%'
	   AND LogText NOT LIKE '%Attempting to load library ''xpstar.dll'' into memory. This is an informational message only. No user action is required.%'
	   AND LogText NOT LIKE '%Attempting to load library ''xpsqlbot.dll'' into memory. This is an informational message only. No user action is required.%'
	   AND LogText NOT LIKE '%This is an informational message only. No user action is required%'
	   AND LogText NOT LIKE 'Using conventional memory in the memory manager.%'
		AND LogText NOT LIKE '%error log has been reinitialized%'
		AND LogText NOT LIKE '%Login succeeded%'
		AND LogText NOT LIKE '%Copyright (c)%'
		AND LogText NOT LIKE '%Attempting to cycle error log%'
		AND LogDate > DATEADD(day, DATEDIFF(day, 10, GETDATE()), 0)
	ORDER BY LogDate DESC
		
	DROP TABLE #ErrorLog2005
END

SELECT DATEDIFF(ss, @start, @end) AS TimeToProcessLog, 'Log Rolled Over' AS ActionTaken
WHERE DATEDIFF(ss, @start, @end) > 120 
   
IF DATEDIFF(ss, @start, @end) > 120 --TimeToProcessLog
BEGIN
   PRINT 'sp_cycle_errorlog'
   --EXEC sp_cycle_errorlog
END