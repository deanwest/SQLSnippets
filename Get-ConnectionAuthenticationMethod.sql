select c.session_id as spid
	, s.login_time
	, s.login_name
	, s.HOST_NAME
	, c.auth_scheme, c.client_net_address, c.net_transport,p.loginame,p.[program_name],p.login_time
	,db_name(p.dbid) as dbname
FROM sys.dm_exec_sessions s
	JOIN
	sys.dm_exec_connections c
		ON s.session_id = c.session_id
	join
	sys.sysprocesses p
		on p.spid=c.session_id 
where c.session_id>50 --not system spid
--and c.client_net_address like '192.168.31.[1-6]0'
order by c.client_net_address
