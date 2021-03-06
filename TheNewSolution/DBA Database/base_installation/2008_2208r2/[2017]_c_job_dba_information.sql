USE [msdb]
GO

/****** Object:  Job [_DBA_Information]    Script Date: 02/08/2017 12:00:00 AM ******/
EXEC msdb.dbo.sp_delete_job @job_id=N'a736a6e9-0d74-47ed-8b99-5bafd2e40c61', @delete_unused_schedule=1
GO

/****** Object:  Job [_DBA_Information]    Script Date: 02/08/2017 12:00:00 AM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [Data Collector]    Script Date: 02/08/2017 12:00:00 AM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Data Collector' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Data Collector'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'_DBA_Information', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'These steps gather various performance and usage metrics bout the server.', 
		@category_name=N'Data Collector', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Physical Disk Usage]    Script Date: 02/08/2017 12:00:00 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Physical Disk Usage', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'PowerShell', 
		@command=N'#Get The Instance.
$Instance="$(ESCAPE_DQUOTE(SRVR))"

#Load the Modules.
$Modules = Invoke-SqlCmd -Query "SELECT ModuleName, ModuleText FROM PowershellModule" -ServerInstance $Instance -Database "DBA" -MaxCharLength ([int32][system.int32]::maxvalue)

ForEach ($Row In $Modules)
{

	#Module Code...	
	$ModuleText = [string]$Row[1]

	#Add the module to the current PS Session...
	Invoke-Expression -command $ModuleText
	
}

#Get the Disk drive information and load it into the proper table.

#######################################################################

$RightNow = [string](Get-Date -Format "MM/dd/yyyy hh:mm:ss tt")

$Disks = Get-WMIObject Win32_logicaldisk -Filter "DriveType=3" | Select @{n=''ServerName'';e={$Instance}} , @{n=''DateGathered'';e={$RightNow}} , @{n=''DriveLetter'';e={[string]$_.Caption}} , @{n=''VolumeName'';e={[string]$_.VolumeName}}, @{n=''Capacity_GB'';e={[decimal]$_.Size/1Gb}}, @{n=''Used_GB'';e={[decimal]($_.Size - $_.FreeSpace)/1GB}}, @{n=''FreeSpace_GB'';e={[decimal]$_.FreeSpace/1GB}}

Write-DataTable -ServerInstance $Instance -Database "DBA" -TableName "Data_SystemDisk" -Data ($Disks | Out-DataTable)', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Login Data]    Script Date: 02/08/2017 12:00:00 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Login Data', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DECLARE @ForceUpdateAll BIT

--0/false will alert on changes.
SET @ForceUpdateAll = 0

EXEC DBA.dbo.spGetLoginData @ForceUpdateAll

/****************************************/

EXEC DBA.dbo.spAuditLoginServer

EXEC DBA.dbo.sp_auditlogindb', 
		@database_name=N'DBA', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Server Information]    Script Date: 02/08/2017 12:00:00 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Server Information', 
		@step_id=3, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DECLARE @ForceUpdateAll BIT

SET @ForceUpdateAll = 0

EXEC DBA.dbo.sp_GetSqlInstInfo @ForceUpdateAll', 
		@database_name=N'DBA', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Database Information]    Script Date: 02/08/2017 12:00:00 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Database Information', 
		@step_id=4, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'
--Gets information about each database.
EXEC DBA.dbo.spGetDatabaseData

--Gets information about the file structure of each database.
EXEC DBA.dbo.spGetDatabaseFiles', 
		@database_name=N'DBA', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Error and Trace Log Reading and Analysis]    Script Date: 02/08/2017 12:00:00 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Error and Trace Log Reading and Analysis', 
		@step_id=5, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'
--This will get the entirety of the SQL Error Log data
EXEC DBA.dbo.sp_GetSqlErrLog

--This compiles a daily summary of the Logon frequency and success rate (using the data from the Error Log)
EXEC DBA.dbo.sp_GetSqlUsrFreqncy

--This reads the default trace file information into the system.
EXEC DBA.dbo.sp_GetSqlTrcInfo', 
		@database_name=N'DBA', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Agent Job Data]    Script Date: 02/08/2017 12:00:00 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Agent Job Data', 
		@step_id=6, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'
--Get Agent Job
EXEC DBA.dbo.sp_GetAgtJoblist

--Get Job History
EXEC DBA.dbo.sp_agntJobHist', 
		@database_name=N'DBA', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Logging Cleanup]    Script Date: 02/08/2017 12:00:00 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Logging Cleanup', 
		@step_id=7, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'SET QUOTED_IDENTIFIER ON
GO

DECLARE @RowCount BIGINT

SET @RowCount = 1
WHILE (ISNULL(@RowCount, 0) <> 0)
BEGIN
	
	--Cleanup Database Information
	DELETE TOP (10000) FROM DBA.dbo.Data_Database 
	WHERE DateGathered <= DATEADD(dd, -30, GETDATE())

	SET @RowCount = @@ROWCOUNT

END

/** Cleanup Database File Information **/

SET @RowCount = 1
WHILE (ISNULL(@RowCount, 0) <> 0)
BEGIN

	--Keep Daily Data for 30 days.
	DELETE TOP (10000) FROM DBA.dbo.Data_DatabaseFiles
	WHERE DATEPART(dw, DateGathered) <> 2
		AND DateGathered <= DATEADD(dd, -30, GETDATE())
	
	SET @RowCount = @@ROWCOUNT

END

SET @RowCount = 1
WHILE (ISNULL(@RowCount, 0) <> 0)
BEGIN

	--Keep weeklies for 6 months.
	DELETE TOP (10000) FROM DBA.dbo.Data_DatabaseFiles
	WHERE DATEPART(dw, DateGathered) = 2
		AND DateGathered <= DATEADD(mm, -6, GETDATE())
	
	SET @RowCount = @@ROWCOUNT

END

SET @RowCount = 1
WHILE (ISNULL(@RowCount, 0) <> 0)
BEGIN

	/** Cleanup Physical Disk Information **/
	--Keep Daily Data for 30 days.
	DELETE TOP (10000) FROM DBA.dbo.Data_SystemDisk
	WHERE DATEPART(dw, DateGathered) <> 2
		AND DateGathered <= DATEADD(dd, -30, GETDATE())
	
	SET @RowCount = @@ROWCOUNT

END


SET @RowCount = 1
WHILE (ISNULL(@RowCount, 0) <> 0)
BEGIN
	
	--Keep weeklies for 6 months.
	DELETE TOP (10000) FROM DBA.dbo.Data_SystemDisk
	WHERE DATEPART(dw, DateGathered) = 2
		AND DateGathered <= DATEADD(mm, -6, GETDATE())
	
	SET @RowCount = @@ROWCOUNT

END

SET @RowCount = 1
WHILE (ISNULL(@RowCount, 0) <> 0)
BEGIN

	/** Cleanup Detailed Login History Data **/
	DELETE TOP (10000) FROM DBA.dbo.Audit_LoginServer
	WHERE DateGathered <= DATEADD(mm, -2, GETDATE())
	
	SET @RowCount = @@ROWCOUNT

END

SET @RowCount = 1
WHILE (ISNULL(@RowCount, 0) <> 0)
BEGIN

	DELETE TOP (10000) FROM DBA.dbo.Audit_LoginDatabase
	WHERE DateGathered <= DATEADD(mm, -2, GETDATE())
	
	SET @RowCount = @@ROWCOUNT

END

SET @RowCount = 1
WHILE (ISNULL(@RowCount, 0) <> 0)
BEGIN

	/** Cleanup Agent Job History **/
	--Remove jobs that aren''t listed after 3 months.
	DELETE TOP (10000) FROM Data_AgentJobList
	WHERE ListedInServer = 0
		AND DateLastRun <= DATEADD(mm, -1, GETDATE())
	
	SET @RowCount = @@ROWCOUNT

END


SET @RowCount = 1
WHILE (ISNULL(@RowCount, 0) <> 0)
BEGIN

	--Remove detailed history if the job is no longer listed.
	DELETE TOP (10000) FROM Data_AgentJobHistory
	WHERE NOT(Job_ID IN (SELECT A.Job_ID FROM Data_AgentJobList A))
	
	SET @RowCount = @@ROWCOUNT

END
	
SET @RowCount = 1
WHILE (ISNULL(@RowCount, 0) <> 0)
BEGIN

	--Remove detailed history after three months.
	DELETE TOP (10000) FROM Data_AgentJobHistory
	WHERE DateStarted <= DATEADD(mm, -3, GETDATE())
	
	SET @RowCount = @@ROWCOUNT

END

SET @RowCount = 1
WHILE (ISNULL(@RowCount, 0) <> 0)
BEGIN

	--Remove job history from msdb table.
	DELETE TOP (10000) FROM msdb.dbo.sysjobhistory 
	WHERE DBA.dbo.fn_JOBrunToDT(run_date, run_time) <= DATEADD(mm, -3, GETDATE())
	
	SET @RowCount = @@ROWCOUNT

END

SET @RowCount = 1
WHILE (ISNULL(@RowCount, 0) <> 0)
BEGIN

	--Cleanup Trace file reading activity
	DELETE TOP (10000) FROM Data_SQLTrace
	WHERE DateStart <= DATEADD(DAY, -90, GETDATE())
	
	SET @RowCount = @@ROWCOUNT

END

SET @RowCount = 1
WHILE (ISNULL(@RowCount, 0) <> 0)
BEGIN

	DELETE TOP (10000) FROM Mnt_SQLTraceFile
	WHERE IsValid = 0
		AND (
			DateLastRead IS NULL 
			OR (
				DateLastRead <= DATEADD(DAY, -90, GETDATE()) 
				AND Start_Time <= DATEADD(DAY, -90, GETDATE())
				)
			)
	
	SET @RowCount = @@ROWCOUNT

END

SET @RowCount = 1
WHILE (ISNULL(@RowCount, 0) <> 0)
BEGIN
	
	--Cleanup Error Log reading activity
	DELETE TOP (100000) FROM Data_SQLLog
	WHERE LogDate <= DATEADD(DAY, -30, GETDATE())

	SET @RowCount = @@ROWCOUNT

END


SET @RowCount =1
WHILE (ISNULL(@RowCount, 0) <> 0)
BEGIN

	DELETE TOP (10000) FROM Data_SQLUserFrequency
	WHERE DateActivity <= DATEADD(DAY, -90, GETDATE())

	SET @RowCount = @@ROWCOUNT

END

SET @RowCount =1
WHILE (ISNULL(@RowCount, 0) <> 0)
BEGIN

	--Cleanup Mnt_DatabaseFile
	DELETE TOP (10000) FROM Mnt_DatabaseFile
	WHERE DateGathered <= DATEADD(DAY, -90, GETDATE())

	SET @RowCount = @@ROWCOUNT

END




', 
		@database_name=N'DBA', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'_DBA_Daily @ 5:00 AM', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20160306, 
		@active_end_date=99991231, 
		@active_start_time=170000, 
		@active_end_time=235959, 
		 '
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

GO

