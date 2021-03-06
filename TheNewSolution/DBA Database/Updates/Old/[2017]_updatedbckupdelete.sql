USE DBA

--Update the Options.
DELETE FROM DBA.dbo.[Option]
WHERE OptionLevel = 'Server'
	AND OptionName IN ('BackupRetention_WeeklyCount', 'BackupRetention_MonthlyCount')

INSERT INTO DBA.dbo.[Option]
(OptionLevel, OptionName, OptionValue, OptionDescription)
SELECT 'Server', 'BackupRetention_WeeklyCount', 3, 'Number of weekly backup copies to keep; I.e. keep three weekly backups..'
UNION ALL
SELECT 'Server', 'BackupRetention_MonthlyCount', 3, 'Number of monthly backup copies to keep; I.e. keep three monthly backups.'

UPDATE DBA.dbo.[Option]
SET OptionValue = 5
WHERE OptionLevel = 'Server'
	AND OptionName LIKE 'BackupRetention%_Days'

GO

--Update the tables.

DROP TABLE Data_BackupSet

CREATE TABLE Data_BackupSet
	(
	ServerName SYSNAME NOT NULL DEFAULT @@SERVERNAME
	, DateGathered DATETIME NOT NULL DEFAULT GETDATE()
	, DatabaseName SYSNAME NOT NULL
	, BackupSetUUID UNIQUEIDENTIFIER NOT NULL
	, MediaSetID INT NULL
	, BackupType CHAR(1) NULL
	, BackupType_Desc VARCHAR(10) NULL
	, DateBackupStart DATETIME NULL
	, DateBackupEnd DATETIME NULL
	, BackupSize NUMERIC(18, 0) NULL
	, DatabaseRecoveryModel VARCHAR(10) NULL
	, DateBackupSetExpires DATETIME NULL
	, IsDailyBackup BIT NULL
	, IsWeeklyBackup BIT NULL
	, IsMonthlyBackup BIT NULL
	)

DROP TABLE Data_BackupMediaFiles

CREATE TABLE Data_BackupMediaFiles
	(
	ServerName SYSNAME NOT NULL DEFAULT @@SERVERNAME
	, DatabaseName SYSNAME NOT NULL
	, MediaSetID INT NOT NULL
	, FamilySeqNumber INT NOT NULL
	, FilePathName VARCHAR(1000) NOT NULL
	, DateFileDeleted DATETIME NULL
	)

GO

IF OBJECT_ID('DBA.dbo.[spBackupUpdateMediaInfo]') IS NOT NULL
BEGIN
	DROP PROCEDURE [spBackupUpdateMediaInfo]
END

GO

CREATE PROCEDURE [spBackupUpdateMediaInfo]
AS

SET NOCOUNT ON

/************
Name: spBackupUpdateMediaInfo
Author: Dustin Marzolf
Created: 2/25/2016

Purpose: To keep track of backup files and their expiration dates.

Update - 5/13/2016, Dustin Marzolf
	Updated logic to NOT delete the backup set and backup files tables upon execution.
	So only new backups will make their way in.
	Added logic to handle monthly and weekly backup retentions.  

Inputs:
	NONE
	
Outputs: 
	NONE

NOTES: 
	Defaults to one day retention of both full and log files.
	
Functionality Description:

This procedure uses the tables Data_BackupMediaFiles and Data_BackupSet to track
when specific backup files should be removed from the system.  

For FULL backups, the system keeps them for the days indicated.
For LOG backups, the system keeps them for the days indicated AFTER the expiration of the parent FULL backup.
	
**************/

DECLARE @RightNow DATETIME
SET @RightNow = GETDATE()

--Days To Keep Backups...
DECLARE @DaysToKeepFull INT 
SET @DaysToKeepFull = ISNULL((SELECT DBA.dbo.fn_GetOptVal('Server', 'BackupRetentionFull_Days')), 1)
DECLARE @DaysToKeepTran INT
SET @DaysToKeepTran = ISNULL((SELECT DBA.dbo.fn_GetOptVal('Server', 'BackupRetentionTran_Days')), 1)
DECLARE @CountMonthlyToKeep INT 
SET @CountMonthlyToKeep = ISNULL((SELECT DBA.dbo.fn_GetOptVal('Server', 'BackupRetention_MonthlyCount')), 0)
DECLARE @CountWeeklyToKeep INT
SET @CountWeeklyToKeep = ISNULL((SELECT DBA.dbo.fn_GetOptVal('Server', 'BackupRetention_WeeklyCount')), 0)

DECLARE @NewUUID TABLE
	(
	backup_set_uuid UNIQUEIDENTIFIER NULL
	)

--Populate new backup data.
INSERT INTO DBA.dbo.Data_BackupSet
(ServerName, DateGathered, DatabaseName, BackupSetUUID, MediaSetID, BackupType, BackupType_Desc
	, DateBackupStart, DateBackupEnd, BackupSize, DatabaseRecoveryModel)
OUTPUT Inserted.BackupSetUUID INTO @NewUUID (backup_set_uuid)
SELECT @@SERVERNAME
	, @RightNow
	, B.database_name 
	, B.backup_set_uuid 
	, B.media_set_id 
	, B.[type]
	, BackupType_Desc = CASE B.[type]	WHEN NULL THEN NULL
										WHEN 'D' THEN 'FULL'
										WHEN 'I' THEN 'Differential'
										WHEN 'L' THEN 'Log'
										WHEN 'F' THEN 'FileGroup'
										WHEN 'G' THEN 'DifferentialFile'
										WHEN 'P' THEN 'Partial'
										WHEN 'Q' THEN 'DifferentialPartial'
										ELSE NULL
										END
	, B.backup_start_date 
	, B.backup_finish_date 
	, B.backup_size 
	, B.recovery_model 
FROM msdb.dbo.backupset B
WHERE NOT(B.backup_set_uuid IN (SELECT D.BackupSetUUID FROM DBA.dbo.Data_BackupSet D))

--Get the actual filenames for each backup set.
INSERT INTO Data_BackupMediaFiles
(ServerName, DatabaseName, MediaSetID, FamilySeqNumber, FilePathName)
SELECT @@SERVERNAME
	, B.database_name 
	, M.media_set_id 
	, M.family_sequence_number 
	, M.physical_device_name 
FROM msdb.dbo.backupmediafamily M
	INNER JOIN msdb.dbo.backupset B ON B.media_set_id = M.media_set_id 
WHERE B.backup_set_uuid IN (SELECT E.backup_set_uuid FROM @NewUUID E)

/** Calculate Expiration Dates **/
DECLARE @BackupSetUUID UNIQUEIDENTIFIER
DECLARE @BackupType CHAR(1)
DECLARE @DbName SYSNAME
DECLARE @DateBackupStart DATETIME
DECLARE @DateLastFull DATETIME
DECLARE @DateLastMonthly DATETIME
DECLARE @DateLastWeekly DATETIME

DECLARE curBackups CURSOR LOCAL STATIC FORWARD_ONLY

FOR SELECT B.BackupSetUUID
		, B.BackupType
		, B.DatabaseName
		, B.DateBackupStart 
		, LF.DateBackupStart AS LastFullBackup
	FROM Data_BackupSet B
		OUTER APPLY (
					SELECT TOP 1 E.DateBackupStart 
					FROM Data_BackupSet E
					WHERE E.DatabaseName = B.DatabaseName
						AND E.BackupType = 'D'
						AND E.DateBackupStart < B.DateBackupStart
					ORDER BY E.DateBackupStart DESC
					) LF
	WHERE B.DateBackupSetExpires IS NULL
	ORDER BY B.DatabaseName
		, B.DateBackupStart

OPEN curBackups

FETCH NEXT FROM curBackups
INTO @BackupSetUUID, @BackupType, @DbName, @DateBackupStart, @DateLastFull

WHILE @@FETCH_STATUS = 0
BEGIN

	--Get the bits of data that may change during iterations...
	SET @DateLastMonthly = (
							SELECT TOP 1 DATEADD(MONTH, DATEDIFF(MONTH, 0, E.DateBackupStart), 0)
							FROM Data_BackupSet E
							WHERE E.DatabaseName = @DbName
								AND E.BackupType = 'D'
								AND E.DateBackupStart < @DateBackupStart
								AND E.IsMonthlyBackup = 1
							ORDER BY E.DateBackupStart DESC
							)

	SET @DateLastWeekly = (
							SELECT TOP 1 DATEADD(WEEK, DATEDIFF(WEEK, 0, E.DateBackupStart ), 0)
							FROM Data_BackupSet E
							WHERE E.DatabaseName = @DbName
								AND E.BackupType = 'D'
								AND E.DateBackupStart < @DateBackupStart
								AND E.IsWeeklyBackup = 1
							ORDER BY E.DateBackupStart DESC
							) 

	--Transaction Logs
	IF @BackupType = 'L'
	BEGIN

		UPDATE Data_BackupSet
		SET DateBackupSetExpires = DATEADD(DAY, @DaysToKeepTran, DateBackupStart)
		WHERE BackupSetUUID = @BackupSetUUID 

	END

	IF @BackupType = 'D'
	BEGIN

		--Only if this is the first full backup of the new month, OR if this is the first full backup.
		IF DATEADD(MONTH, DATEDIFF(MONTH, 0, @DateBackupStart), 0) > @DateLastMonthly OR @DateLastFull IS NULL
		BEGIN

			UPDATE Data_BackupSet
			SET DateBackupSetExpires = DATEADD(MONTH, @CountMonthlyToKeep, DateBackupStart)
				, IsMonthlyBackup = 1
			WHERE BackupSetUUID = @BackupSetUUID

		END

		IF DATEADD(WEEK, DATEDIFF(WEEK, 0, @DateBackupStart), 0) > @DateLastWeekly OR @DateLastFull IS NULL
		BEGIN

			UPDATE Data_BackupSet
			SET DateBackupSetExpires = CASE WHEN DateBackupSetExpires IS NULL THEN DATEADD(WEEK, @CountWeeklyToKeep, DateBackupStart)
										ELSE DateBackupSetExpires
										END
				, IsWeeklyBackup = 1
			WHERE BackupSetUUID = @BackupSetUUID

		END

		--Just normal Full Backups.
		UPDATE Data_BackupSet
		SET DateBackupSetExpires = CASE WHEN DateBackupSetExpires IS NULL THEN DATEADD(DAY, @DaysToKeepFull, DateBackupStart)
										ELSE DateBackupSetExpires
										END
			, IsDailyBackup = 1
		WHERE BackupSetUUID = @BackupSetUUID

	END

	
	--Get next backup set.
	FETCH NEXT FROM curBackups
	INTO @BackupSetUUID, @BackupType, @DbName, @DateBackupStart, @DateLastFull

END

CLOSE curBackups
DEALLOCATE curBackups

GO

EXEC [spBackupUpdateMediaInfo]