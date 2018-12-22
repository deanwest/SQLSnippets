IF CAST(CAST(SERVERPROPERTY('ProductVersion') AS varchar(4)) as decimal(4,2)) >= 9
BEGIN
	DECLARE @dbCount NUMERIC(10,2)
	CREATE TABLE #DBs (
          Id int identity(1,1) primary key clustered,
          ParentObject varchar(255),
          Object varchar(255),
          Field varchar(255),
          Value varchar(255),
          dbID int
   )

   Insert Into #DBs (ParentObject, Object, Field, Value)
   Exec sp_msforeachdb N'DBCC DBInfo(''?'') With TableResults';

   DELETE FROM #DBs WHERE Field NOT IN('dbi_dbccLastKnownGood','dbi_dbccFlags','dbi_dbname');

   ALTER TABLE #DBs ADD dbName sysname NULL;

   UPDATE u
   SET dbName = (
       SELECT TOP 1 CAST(Value as sysname) as dbName
       FROM #DBs as s
       WHERE s.Field = 'dbi_dbname'
       AND   s.Id <= u.Id
       ORDER BY Id DESC
       )
   FROM #DBs as u;

   select @dbCount=COUNT(*) FROM sys.databases;


   SELECT @@servername as ServerName
      ,a.dbName
      ,b.LastIntegrityCheck
      ,cast(CASE c.DataPurity WHEN 2 THEN 'checked' ELSE 'never checked' end as varchar(30)) as DataPurity 
   FROM (SELECT DISTINCT dbName FROM #DBs) as a
        LEFT OUTER JOIN
        (
        SELECT dbName, MAX(cast(Value as datetime)) as LastIntegrityCheck
        FROM #DBs
        WHERE Field = 'dbi_dbccLastKnownGood'
        GROUP BY dbName
        ) as b
            ON a.dbName = b.dbName
        LEFT OUTER JOIN
        (
        SELECT dbName, MAX(cast(Value as int)) as DataPurity
        FROM #DBs
        WHERE Field = 'dbi_dbccFlags'
        GROUP BY dbName
        ) as c
            ON a.dbName = c.dbName;
            
   DROP TABLE #DBs;
END

/****** SQL 2000 method ****/
ELSE
BEGIN
	CREATE TABLE #ErrorLog2000 (LogText nvarchar(4000), ContRow int);
	
	INSERT INTO #ErrorLog2000
	EXEC master.dbo.xp_readerrorlog;
	
   SELECT @@servername as ServerName
      ,DBName
      ,MAX(LogDate) as LastIntegrityCheck
      ,cast('N/A in 2000' as varchar(30)) AS DataPurity 
   FROM (
		SELECT CASE WHEN ISDATE(LEFT(LogText, 19)) = 1 
				THEN CAST(LEFT(LogText, 19) AS datetime)
				ELSE NULL END AS LogDate, 
				SUBSTRING(LogText,charindex('(',LogText)+1,charindex(')',LogText,charindex('(',LogText))-charindex('(',LogText)-1) as DBName
		FROM #ErrorLog2000 
		WHERE LEN(LogText) > 19 AND LogText LIKE '%DBCC CHECKDB%'
		) as t
   GROUP BY DBName
	ORDER BY DBName DESC;

	DROP TABLE #ErrorLog2000;
END