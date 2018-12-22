WITH maxvals AS
(
	SELECT 'tinyint' AS typ, 255 AS maxval
	UNION ALL SELECT 'smallint', 32767
	UNION ALL SELECT 'int', 2147483647
	UNION ALL SELECT 'bigint', 9223372036854775807
)
SELECT SCHEMA_NAME(t.schema_id) + '.' + t.name AS tblname,
	id.name AS colname,
	ty.name AS typename,
	id.seed_value,
	id.increment_value,
	ps.rows,
	id.last_value,
	CONVERT(decimal(5,2), (1.0 * CONVERT(bigint, id.last_value) / mv.maxval) * 100) AS percentused
FROM sys.identity_columns id
	JOIN sys.types ty ON id.user_type_id = ty.user_type_id
	JOIN sys.tables t ON id.object_id = t.object_id
	LEFT JOIN maxvals mv ON ty.name = mv.typ
	CROSS APPLY (SELECT SUM(row_count) AS rows FROM sys.dm_db_partition_stats ps WHERE ps.object_id = t.object_id AND ps.index_id IN (0, 1)) ps
ORDER BY CASE WHEN mv.typ IS NULL THEN 0 ELSE 1 END,
	percentused DESC,
	tblname;
