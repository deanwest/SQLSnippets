--SQL 2005 onwards
SELECT db_name() as DatabaseName
      ,s.name AS SchemaName
      ,o.name AS ObjectName
      ,t.row_count
      ,t.reserved_page_count_data * .008 AS [Data Size (MB)]
      ,t.reserved_page_count * .008 AS [Object Size (MB)]
      ,CASE WHEN t.row_count = 0 THEN 0 ELSE (t.reserved_page_count * 8192) / t.row_count END AS [Average Row Size (Bytes)]
      --,t.in_row_data_page_count
      --,t.in_row_used_page_count
      --,t.in_row_reserved_page_count
      --,t.lob_used_page_count
      --,t.lob_reserved_page_count
      --,t.row_overflow_used_page_count
      --,t.row_overflow_reserved_page_count
      --,t.used_page_count
      --,t.reserved_page_count
      ,t.data_compression_desc
FROM  (
      SELECT ps.[object_id]
         ,SUM(CASE WHEN ps.index_id IN (0,1) THEN ps.row_count ELSE 0 END) AS row_count
         ,SUM(ps.in_row_data_page_count) AS in_row_data_page_count--Number of pages in use for storing in-row data in this partition. If the partition is part of a heap, the value is the number of data pages in the heap. If the partition is part of an index, the value is the number of pages in the leaf level. (Nonleaf pages in the B-tree are not included in the count.) IAM (Index Allocation Map) pages are not included in either case.
         ,SUM(ps.in_row_used_page_count) AS in_row_used_page_count--Total number of pages in use to store and manage the in-row data in this partition. This count includes nonleaf B-tree pages, IAM pages, and all pages included in the in_row_data_page_count column.
         ,SUM(ps.in_row_reserved_page_count) AS in_row_reserved_page_count--Total number of pages reserved for storing and managing in-row data in this partition, regardless of whether the pages are in use or not.
         ,SUM(ps.lob_used_page_count) AS lob_used_page_count--Number of pages in use for storing and managing out-of-row text, ntext, image, varchar(max), nvarchar(max), varbinary(max), and xml columns within the partition. IAM pages are included.
         ,SUM(ps.lob_reserved_page_count) AS lob_reserved_page_count--Total number of pages reserved for storing and managing out-of-row text, ntext, image, varchar(max), nvarchar(max), varbinary(max), and xml columns within the partition, regardless of whether the pages are in use or not. IAM pages are included.
         ,SUM(ps.row_overflow_used_page_count) AS row_overflow_used_page_count--Number of pages in use for storing and managing row-overflow varchar, nvarchar, varbinary, and sql_variant columns within the partition. IAM pages are included.
         ,SUM(ps.row_overflow_reserved_page_count) AS row_overflow_reserved_page_count--Total number of pages reserved for storing and managing row-overflow varchar, nvarchar, varbinary, and sql_variant columns within the partition, regardless of whether the pages are in use or not. IAM pages are included.
         ,SUM(ps.used_page_count) AS used_page_count--Total number of pages used for the partition. Computed as in_row_used_page_count + lob_used_page_count + row_overflow_used_page_count.
         ,SUM(CASE WHEN ps.index_id IN (0,1) THEN ps.reserved_page_count ELSE 0 END) AS reserved_page_count_data
         ,SUM(ps.reserved_page_count) AS reserved_page_count--Total number of pages reserved for the partition. Computed as in_row_reserved_page_count + lob_reserved_page_count + row_overflow_reserved_page_count.
	 ,CASE 
		WHEN AVG(p.data_compression * 10) = 0 THEN 'NONE'
		WHEN AVG(p.data_compression * 10) = 10 THEN 'ROW'
		WHEN AVG(p.data_compression * 10) = 20 THEN 'PAGE'
		WHEN AVG(p.data_compression * 10) = 30 THEN 'COLUMNSTORE'
		WHEN AVG(p.data_compression * 10) between 11 and 19 THEN 'NONE/ROW/PAGE'
		WHEN AVG(p.data_compression * 10) between 1 and 9 THEN 'NONE/ROW/PAGE'
		ELSE cast(AVG(p.data_compression * 10) as varchar(30))
		END as data_compression_desc
	  FROM  sys.dm_db_partition_stats AS ps
		JOIN sys.partitions as p
			On ps.[partition_id] = p.[partition_id]
      GROUP BY ps.[object_id]
      ) AS t
      INNER JOIN sys.tables AS o
         ON t.[object_id] = o.[object_id]
      INNER JOIN sys.schemas AS s
         ON o.[schema_id] = s.[schema_id]
ORDER BY t.reserved_page_count DESC