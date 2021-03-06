#########################
#
# Name: Execute Script Against Servers
#
# Author: Dustin Marzolf
# Created: 2/26/2016
# Purpose: To more easily handle executing scripts against multiple servers.
#
# You will need to modify the two variables at the beginning of this script.
#
# 	$SQLInstanceList - The full path and name of a text file containing the names of
#		the instances to run against.  One entry per line, Ex: DMDBAPRDSQL06\SCCM
#
#	$ScriptFile - The full path and name of the .sql file to execute.
#
#	$DatabaseToUse - The name of the database to use.  You must specify something here that
#   	will exist on the destination server.  It's ok if your script begins with a USE statement.
#
########################

# Modify the below items to the necessary values.
$SQLInstanceList = "C:\Users\ari157\Desktop\Maintenance Weekend\2008\SQLInstance.txt"
$ScriptToRunDirectory = "C:\Users\ari157\Desktop\Maintenance Weekend\2008"
$DatabaseToUse = "DBA"

# You shouldn't need to modify anything below this line.
################################################################################################

# For Each
ForEach ($Instance In Get-Content $SQLInstanceList)
{

	Write-Host "Connecting to: " $Instance

	[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null 
	$SMO = new-object ('Microsoft.SqlServer.Management.Smo.Server') $Instance
	
	ForEach ($File In (Get-ChildItem -Path $ScriptToRunDirectory -Filter "*.sql") | Sort-Object $_.name)
	{
		
		$Script = [System.IO.File]::ReadAllText($File.FullName)
		Write-Host "  " $File.name 
		$SMO.Databases[$DatabaseToUse].ExecuteNonQuery($Script)		
		
	}
	
}
