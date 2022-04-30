IF OBJECT_ID(N'[Reporting].[uspListFailedLogins]') IS NOT NULL
DROP PROCEDURE [Reporting].[uspListFailedLogins]
GO

CREATE PROCEDURE [Reporting].[uspListFailedLogins] 
    @ReportDate datetime = NULL,
    @ServerName nvarchar(128) = NULL,
    @IncludeArchive bit = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    IF (@ReportDate IS NULL)
        SET @ReportDate = DATEADD(D, -1, CAST(CURRENT_TIMESTAMP AS date));

    DECLARE @StartDate date = CAST(@ReportDate AS date);
    DECLARE @EndDate date = DATEADD(D, 1, CAST(@ReportDate AS date));

    WITH cteFailedLoginAttempts
    AS (
        SELECT
            [ServerName]
            ,[LogDate]
            ,[ProcessInfo]
            ,[LogText]
            -- Extract Login points
            ,(CHARINDEX('''', [LogText], 0)+1) AS [LoginStartPoint]
            ,((CHARINDEX('''', [LogText], (CHARINDEX('''', [LogText], 0)+1))-1) - (CHARINDEX('''', [LogText], 0))) AS [LoginEndPoint]
            -- Extract IP Address points
            ,(CHARINDEX('[', [LogText], 0)+1) AS [IPStartPoint]
            ,((CHARINDEX(']', [LogText], (CHARINDEX('[', [LogText], 0)+1))-1) - (CHARINDEX('[', [LogText], 0))) AS [IPEndPoint]
            -- Extract Reason points
            ,(CHARINDEX('Reason: ', [LogText], 0)+8) AS [ReasonStartPoint]
            ,((CHARINDEX('[', [LogText], (CHARINDEX('Reason: ', [LogText], 0)+8))-8) - (CHARINDEX('Reason: ', [LogText], 0))) AS [ReasonEndPoint]
        FROM [Monitor].[ServerErrorLog]
	    WHERE [LogText] LIKE N'Login failed for user%'
        AND [LogDate] BETWEEN @StartDate AND @EndDate
        AND [ServerName] LIKE COALESCE(NULLIF(@ServerName, ''), [ServerName])

        UNION ALL

        SELECT
            [ServerName]
            ,[LogDate]
            ,[ProcessInfo]
            ,[LogText]
            -- Extract Login points
            ,(CHARINDEX('''', [LogText], 0)+1) AS [LoginStartPoint]
            ,((CHARINDEX('''', [LogText], (CHARINDEX('''', [LogText], 0)+1))-1) - (CHARINDEX('''', [LogText], 0))) AS [LoginEndPoint]
            -- Extract IP Address points
            ,(CHARINDEX('[', [LogText], 0)+1) AS [IPStartPoint]
            ,((CHARINDEX(']', [LogText], (CHARINDEX('[', [LogText], 0)+1))-1) - (CHARINDEX('[', [LogText], 0))) AS [IPEndPoint]
            -- Extract Reason points
            ,(CHARINDEX('Reason: ', [LogText], 0)+8) AS [ReasonStartPoint]
            ,((CHARINDEX('[', [LogText], (CHARINDEX('Reason: ', [LogText], 0)+8))-8) - (CHARINDEX('Reason: ', [LogText], 0))) AS [ReasonEndPoint]
        FROM [Archive].[ServerErrorLog]
	    WHERE [LogText] LIKE N'Login failed for user%'
        AND [LogDate] BETWEEN @StartDate AND @EndDate
        AND [ServerName] LIKE COALESCE(NULLIF(@ServerName, ''), [ServerName])
        AND @IncludeArchive = 1

    )
    SELECT 
        [ServerName]
        ,CONVERT(varchar(19), [LogDate], 121) AS [LogDate]
        ,[ProcessInfo]
        --,[LogText]
        -- Extract Login
        ,SUBSTRING(
            [LogText], 
            [LoginStartPoint], 
            (CASE WHEN [LoginEndPoint] > 0 THEN [LoginEndPoint] ELSE 0 END)
        ) AS [LoginName]
        -- Extract IP Address
        ,REPLACE(
            SUBSTRING(
                    [LogText], 
                    [IPStartPoint], 
                    (CASE WHEN [IPEndPoint] > 0 THEN [IPEndPoint] ELSE 0 END)
            ),
            'CLIENT: ', 
            ''
        ) AS [IPAddress]
        -- Extract Reason
        ,SUBSTRING(
            [LogText], 
            [ReasonStartPoint], 
            [ReasonEndPoint]
        ) AS [ReasonForFailure]
    FROM cteFailedLoginAttempts;

END
GO

/*
@ECHO OFF
For /F "Tokens=1-3 Delims=/:. " %%d In ("%Date%") Do bcp "EXEC [Reporting].[uspListFailedLogins];" queryout ".\_export\FailedLogins_%%f%%e%%d.txt" -S "%1" -d "SqlMonitor" -T -c -k -t"|"
*/
