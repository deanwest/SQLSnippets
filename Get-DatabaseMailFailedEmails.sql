SELECT el.[description], fi.*
FROM [msdb].[dbo].[sysmail_faileditems] as fi
    JOIN [msdb].[dbo].[sysmail_event_log] as el
        ON fi.mailitem_id = el.mailitem_id WHERE fi.[sent_date] > DATEADD(dd,-1,GETDATE()) ORDER BY fi.[sent_date]
