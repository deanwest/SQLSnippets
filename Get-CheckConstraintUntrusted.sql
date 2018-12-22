with chk as
(
	select name as chkname, object_name(parent_object_id) as tblname, is_not_trusted
	from sys.check_constraints
	where is_not_trusted = 1
	union all
	select name as chkname, object_name(parent_object_id) as tblname, is_not_trusted
	from sys.foreign_keys
	where is_not_trusted = 1
)
select 'alter table [' + tblname + '] with check check constraint [' + chkname + ']'
from chk
order by tblname, chkname;
