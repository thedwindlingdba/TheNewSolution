USE [DBA]
GO
INSERT [dbo].[Opt] ([OptionLevel], [OptionName], [OptionValue], [OptionDescription]) VALUES (N'Server', N'AgentJobError_ONLY_DBA', N'1', N'Setting this to 1 will cause the Agent History to only treat _DBA_* job failures as severity 4.  Other job failures will be severity 1.  Setting this to 0 will cause all job failures to be severity 4.')
GO
INSERT [dbo].[Opt] ([OptionLevel], [OptionName], [OptionValue], [OptionDescription]) VALUES (N'Server', N'BackupCheckSUM', N'1', N'Will require backups to use the CheckSUM parameter')
GO
INSERT [dbo].[Opt] ([OptionLevel], [OptionName], [OptionValue], [OptionDescription]) VALUES (N'Server', N'BackupCompression', N'0', N'If the server supports it, should the backups be compressed? 1=true/yes, 0-false/no')
GO
INSERT [dbo].[Opt] ([OptionLevel], [OptionName], [OptionValue], [OptionDescription]) VALUES (N'Server', N'BackupFolderRoot', N'\\DMDBAPRDbak02\f$\sqlbackups', N'Root location for backup files.')
GO
INSERT [dbo].[Opt] ([OptionLevel], [OptionName], [OptionValue], [OptionDescription]) VALUES (N'Server', N'BackupRetention_MonthlyCount', N'0', N'Number of monthly backup copies to keep; I.e. keep three monthly backups.')
GO
INSERT [dbo].[Opt] ([OptionLevel], [OptionName], [OptionValue], [OptionDescription]) VALUES (N'Server', N'BackupRetention_WeeklyCount', N'0', N'Number of weekly backup copies to keep; I.e. keep three weekly backups..')
GO
INSERT [dbo].[Opt] ([OptionLevel], [OptionName], [OptionValue], [OptionDescription]) VALUES (N'Server', N'BackupRetentionFull_Days', N'1', N'Number of days to retain full backups.')
GO
INSERT [dbo].[Opt] ([OptionLevel], [OptionName], [OptionValue], [OptionDescription]) VALUES (N'Server', N'BackupRetentionTran_Days', N'1', N'Number of days to retain transaction log backups.')
GO


/** Update Server Type Information **/
DECLARE @ServerType VARCHAR(10)
SET @ServerType = 'PROD'

IF(UPPER(@@SERVERNAME) LIKE 'DMDBAPRD%')
BEGIN
	SET @ServerType = 'PROD'
END

IF(UPPER(@@SERVERNAME) LIKE 'DMDBATA%')
BEGIN
	SET @ServerType = 'PROD'
END

IF(UPPER(@@SERVERNAME) LIKE 'DMDBADEV%')
BEGIN
	SET @ServerType = 'DEV'
END

IF(UPPER(@@SERVERNAME) LIKE 'ARIDR%')
BEGIN
	SET @ServerType = 'DR'
END

INSERT [dbo].[Opt] ([OptionLevel], [OptionName], [OptionValue], [OptionDescription]) VALUES (N'Server', 'ServerType', @ServerType, N'The type of server (DEV, PROD, DR, etc.)')
GO

/** Update Option_Database **/
EXEC DBA.dbo.spFillOptionDatabase