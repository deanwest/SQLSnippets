CREATE TABLE #dbSpace (
	databaseId INT NOT NULL
	,fileID INT NOT NULL
	,dataSpace INT NOT NULL
	,PRIMARY KEY CLUSTERED (databaseId,fileID)
	)

CREATE TABLE #dbFileGroups (
	databaseId INT NOT NULL
	,fileGroupID INT NOT NULL
	,name SYSNAME NOT NULL
	,PRIMARY KEY CLUSTERED (databaseId,fileGroupID)
	)

EXEC sp_MSforeachDB "use [?] insert into #dbFileGroups select db_id(), data_space_id, name from sys.filegroups"

EXEC sp_MSforeachDB "use [?] insert into #dbSpace select db_id(),fileid, FILEPROPERTY(name, 'SpaceUsed') from sysfiles"

select coalesce(db_name(f.[dbid]),'MsSqlSystemResource') as DatabaseName
   ,CASE WHEN f.groupid = 0 then 'LOGS' ELSE fg.name END as FileGroupName
   ,f.name as LogicalFileName
   ,databasepropertyex(db_name(f.[dbid]),'Recovery ') as RecoveryModel
   ,LTRIM(CASE WHEN f.size = -1 THEN 'Unlimited' ELSE STR(f.size/128.0) END) AS [File size (MB)]
   ,CAST(dataSpace/128.0 AS DECIMAL(18,2)) AS [File usage (MB)]
   ,LTRIM(CASE WHEN f.maxsize = -1 THEN 'Unlimited' ELSE STR(f.maxsize/128.0) END) as [Max file size (MB)]
   ,LTRIM(CASE WHEN f.growth between 0 and 100 THEN STR(f.growth)+' %' ELSE STR(f.growth/128.0)+' MB' END) as [File Growth]
   ,f.filename as PhysicalFileName
from sys.sysaltfiles AS f
	LEFT OUTER JOIN
	#dbFileGroups as fg
		ON fg.databaseId = f.[dbid]
		AND fg.fileGroupID = f.groupid
	LEFT OUTER JOIN
	#dbSpace AS ds
		ON ds.databaseId = f.[dbid]
		AND ds.fileID = f.fileid
WHERE f.[dbid] NOT IN (32767)
order by DatabaseName
   ,FileGroupName
   ,LogicalFileName

DROP TABLE #dbFileGroups
DROP TABLE #dbSpace