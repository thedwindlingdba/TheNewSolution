IF(@@SERVERNAME='DMDBAPRDSQL05')
BEGIN

USE [master]

ALTER DATABASE [appx] SET PAGE_VERIFY CHECKSUM  WITH NO_WAIT;
ALTER DATABASE [ARLEnterpriseDWH] SET PAGE_VERIFY CHECKSUM  WITH NO_WAIT;
ALTER DATABASE [DBA] SET PAGE_VERIFY CHECKSUM  WITH NO_WAIT;
ALTER DATABASE [ERP] SET PAGE_VERIFY CHECKSUM  WITH NO_WAIT;
ALTER DATABASE [model] SET PAGE_VERIFY CHECKSUM  WITH NO_WAIT;

END