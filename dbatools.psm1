foreach ($function in (Get-ChildItem "$PSScriptRoot\Functions\*.ps1")) { . $function  }

Function Update-dbatools {
	<# 
	 .SYNOPSIS 
	Updates dbatools. Deletes current copy and replaces it with freshest copy
	 
	  .EXAMPLE
    
	Update-dbatools
	#> 
	
	Invoke-Expression (Invoke-WebRequest  http://git.io/vn1hQ).Content
}

Function Connect-SqlServer  {
	<# 
	 .SYNOPSIS 
	 Creates SMO Server Object
	 
	  .EXAMPLE
     Connect-SqlServer -Server sqlserver -SqlCredential $SqlCredential

	#> 
	[CmdletBinding()]
        param(
			[Parameter(Mandatory = $true)]
            [object]$SqlServer,
            [System.Management.Automation.PSCredential]$SqlCredential,
			[switch]$ParameterConnection
		)
	
	if ($SqlServer.GetType() -eq [Microsoft.SqlServer.Management.Smo.Server]) {
	
		if ($ParameterConnection) { 
			$paramserver = New-Object Microsoft.SqlServer.Management.Smo.Server
			$paramserver.ConnectionContext.ConnectTimeout = 2
			$paramserver.ConnectionContext.ConnectionString = $SqlServer.ConnectionContext.ConnectionString
			$paramserver.ConnectionContext.Connect()
			return $paramserver
		}
		
		if ($SqlServer.ConnectionContext.IsOpen -eq $false) { $SqlServer.ConnectionContext.Connect() }
		return $SqlServer 
	}
	
	$server = New-Object Microsoft.SqlServer.Management.Smo.Server $SqlServer
	
	if ($SqlCredential.username -ne $null ) {
		$server.ConnectionContext.LoginSecure = $false
		$server.ConnectionContext.set_Login($SqlCredential.username)
		$server.ConnectionContext.set_SecurePassword($SqlCredential.Password)
	}
		
	try { 
		if ($ParameterConnection) { $server.ConnectionContext.ConnectTimeout = 2 }
		$server.ConnectionContext.Connect() } catch {
		throw "Can't connect to $sqlserver`: $($_.Exception.Message)" 
	}
	
	return $server
}

Function Get-ParamSqlCmsGroups {
	<# 
	 .SYNOPSIS 
	 Returns System.Management.Automation.RuntimeDefinedParameterDictionary 
	 filled with server groups from specified SQL Server Central Management server name.
	 
	  .EXAMPLE
      Get-ParamSqlCmsGroups sqlserver
	#> 
	[CmdletBinding()]
        param(
			[Parameter(Mandatory = $true)]
            [object]$SqlServer,
			[System.Management.Automation.PSCredential]$SqlCredential

		)

		if ([Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Management.RegisteredServers") -eq $null) {return}
		
		try { $SqlCms = Connect-SqlServer -SqlServer $SqlServer -SqlCredential $SqlCredential -ParameterConnection } catch { return }
		
		$sqlconnection = $SqlCms.ConnectionContext.SqlConnectionObject

		try { $cmstore = New-Object Microsoft.SqlServer.Management.RegisteredServers.RegisteredServersStore($sqlconnection)}
		catch { return }
		
		if ($cmstore -eq $null) { return }
		
		$newparams = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
		$paramattributes = New-Object System.Management.Automation.ParameterAttribute
		$paramattributes.ParameterSetName = "__AllParameterSets"
		$paramattributes.Mandatory = $false
		
		$argumentlist = $cmstore.DatabaseEngineServerGroup.ServerGroups.name
		
		if ($argumentlist -ne $null) {
			$validationset = New-Object System.Management.Automation.ValidateSetAttribute -ArgumentList $argumentlist
			
			$combinedattributes = New-Object -Type System.Collections.ObjectModel.Collection[System.Attribute]
			$combinedattributes.Add($paramattributes)
			$combinedattributes.Add($validationset)

			$SqlCmsGroups = New-Object -Type System.Management.Automation.RuntimeDefinedParameter("SqlCmsGroups", [String[]], $combinedattributes)
			$newparams.Add("SqlCmsGroups", $SqlCmsGroups)
			
			return $newparams
		} else { return }
}

Function Get-ParamSqlLinkedServers {
	<# 
	 .SYNOPSIS 
	 Returns System.Management.Automation.RuntimeDefinedParameterDictionary 
	 filled with Linked Servers from specified SQL Server Central Management server name.
	 
	  .EXAMPLE
      Get-ParamSqlLinkedServers -SqlServer $server -SqlCredential $SqlCredential
	#> 
	[CmdletBinding()]
        param(
			[Parameter(Mandatory = $true)]
            [object]$SqlServer,
			[System.Management.Automation.PSCredential]$SqlCredential
		)

		try { $server = Connect-SqlServer -SqlServer $SqlServer -SqlCredential $SqlCredential -ParameterConnection } catch { return }

		# Populate arrays
		$linkedserverlist = @()
		foreach ($linkedserver in $server.LinkedServers) {
			$linkedserverlist += $linkedserver.name
		}

		# Reusable parameter setup
		$newparams = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
		$attributes = New-Object System.Management.Automation.ParameterAttribute
		
		$attributes.ParameterSetName = "__AllParameterSets"
		$attributes.Mandatory = $false
		
		# Database list parameter setup
		if ($linkedserverlist) { $dbvalidationset = New-Object System.Management.Automation.ValidateSetAttribute -ArgumentList $linkedserverlist }
		$lsattributes = New-Object -Type System.Collections.ObjectModel.Collection[System.Attribute]
		$lsattributes.Add($attributes)
		if ($linkedserverlist) { $lsattributes.Add($dbvalidationset) }
		$LinkedServers = New-Object -Type System.Management.Automation.RuntimeDefinedParameter("LinkedServers", [String[]], $lsattributes)
		
		$newparams.Add("LinkedServers", $LinkedServers)			
		$server.ConnectionContext.Disconnect()
	
	return $newparams
}

Function Get-ParamSqlCredentials {
	<# 
	 .SYNOPSIS 
	 Returns System.Management.Automation.RuntimeDefinedParameterDictionary 
	 filled with SQL Credentials from specified SQL Server server name.
	 
	  .EXAMPLE
      Get-ParamSqlCredentials  -SqlServer $server -SqlCredential $SqlCredential
	#> 
	[CmdletBinding()]
        param(
			[Parameter(Mandatory = $true)]
            [object]$SqlServer,
			[System.Management.Automation.PSCredential]$SqlCredential
		)

		try { $server = Connect-SqlServer -SqlServer $SqlServer -SqlCredential $SqlCredential -ParameterConnection } catch { return }
	
		# Populate arrays
		$credentiallist = @()
		foreach ($credential in $server.credentials) {
			$credentiallist += $credential.name
		}

		# Reusable parameter setup
		$newparams = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
		$attributes = New-Object System.Management.Automation.ParameterAttribute
		
		$attributes.ParameterSetName = "__AllParameterSets"
		$attributes.Mandatory = $false
		
		# Database list parameter setup
		if ($credentiallist) { $dbvalidationset = New-Object System.Management.Automation.ValidateSetAttribute -ArgumentList $credentiallist }
		$lsattributes = New-Object -Type System.Collections.ObjectModel.Collection[System.Attribute]
		$lsattributes.Add($attributes)
		if ($credentiallist) { $lsattributes.Add($dbvalidationset) }
		$Credentials = New-Object -Type System.Management.Automation.RuntimeDefinedParameter("Credentials", [String[]], $lsattributes)
		
		$newparams.Add("Credentials", $Credentials)			
		$server.ConnectionContext.Disconnect()
	
	return $newparams
}

Function Get-ParamSqlDatabases {
	<# 
	 .SYNOPSIS 
	 Returns System.Management.Automation.RuntimeDefinedParameterDictionary 
	 filled with database list from specified SQL Server server.
	 
	  .EXAMPLE
      Get-ParamSqlDatabases -SqlServer $server -SqlCredential $SqlCredential
	#> 
	[CmdletBinding()]
        param(
			[Parameter(Mandatory = $true)]
            [object]$SqlServer,
			[System.Management.Automation.PSCredential]$SqlCredential
		)
		
		try { $server = Connect-SqlServer -SqlServer $SqlServer -SqlCredential $SqlCredential -ParameterConnection } catch { return }
		
		$SupportDbs = "ReportServer","ReportServerTempDb", "distribution"
		
		# Populate arrays
		$databaselist = @()
		foreach ($database in $server.databases) {
			if ((!$database.IsSystemObject) -and $SupportDbs -notcontains $database.name) {
					$databaselist += $database.name}
			}

		# Reusable parameter setup
		$newparams = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
		$attributes = New-Object System.Management.Automation.ParameterAttribute
		
		$attributes.ParameterSetName = "__AllParameterSets"
		$attributes.Mandatory = $false
		
		# Database list parameter setup
		if ($databaselist) { $dbvalidationset = New-Object System.Management.Automation.ValidateSetAttribute -ArgumentList $databaselist }
		$dbattributes = New-Object -Type System.Collections.ObjectModel.Collection[System.Attribute]
		$dbattributes.Add($attributes)
		if ($databaselist) { $dbattributes.Add($dbvalidationset) }
		$Databases = New-Object -Type System.Management.Automation.RuntimeDefinedParameter("Databases", [String[]], $dbattributes)
		$Exclude = New-Object -Type System.Management.Automation.RuntimeDefinedParameter("Exclude", [String[]], $dbattributes)

		$newparams.Add("Databases", $Databases)
		$newparams.Add("Exclude", $Exclude)
		
		$server.ConnectionContext.Disconnect()
	
	return $newparams

}

Function Get-ParamSqlLogins {
	<# 
	 .SYNOPSIS 
	 Returns System.Management.Automation.RuntimeDefinedParameterDictionary 
	 filled with login list from specified SQL Server server.
	 
	  .EXAMPLE
      Get-ParamSqlLogins -SqlServer $server -SqlCredential $SqlCredential
	#> 
	[CmdletBinding()]
        param(
			[Parameter(Mandatory = $true)]
            [object]$SqlServer,
			[System.Management.Automation.PSCredential]$SqlCredential
		)
		
		try { $server = Connect-SqlServer -SqlServer $SqlServer -SqlCredential $SqlCredential -ParameterConnection } catch { return }
		$loginlist = @()

		foreach ($login in $server.logins) { 
			if (!$login.name.StartsWith("##") -and $login.name -ne 'sa') {
			$loginlist += $login.name}
			}
				
		# Reusable parameter setup
		$newparams = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
		$attributes = New-Object System.Management.Automation.ParameterAttribute
		
		$attributes.ParameterSetName = "__AllParameterSets"
		$attributes.Mandatory = $false
		
		# Login list parameter setup
		if ($loginlist) { $loginvalidationset = New-Object System.Management.Automation.ValidateSetAttribute -ArgumentList $loginlist }
		$loginattributes = New-Object -Type System.Collections.ObjectModel.Collection[System.Attribute]
		$loginattributes.Add($attributes)
		if ($loginlist) { $loginattributes.Add($loginvalidationset) }
		$Logins = New-Object -Type System.Management.Automation.RuntimeDefinedParameter("Logins", [String[]], $loginattributes)
		$Exclude = New-Object -Type System.Management.Automation.RuntimeDefinedParameter("Exclude", [String[]], $loginattributes)

		$newparams.Add("Logins", $Logins)
		$newparams.Add("Exclude", $Exclude)
		
		$server.ConnectionContext.Disconnect()
	
	return $newparams
}

Function Get-SqlCmsRegServers {
	<# 
	 .SYNOPSIS 
	 Returns array of server names from CMS Server. If -Groups is specified,
	 only servers within the given groups are returned.
	 
	  .EXAMPLE
     Get-SqlCmsRegServers -Server sqlserver -Groups "Accounting", "HR"

	#> 
	[CmdletBinding()]
        param(
			[Parameter(Mandatory = $true)]
            [object]$SqlServer,
            [string[]]$groups,
			[System.Management.Automation.PSCredential]$SqlCredential
		)
	
	if ([Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Management.RegisteredServers") -eq $null) {return}

	$SqlCms = Connect-SqlServer -SqlServer $SqlServer -SqlCredential $SqlCredential
	$sqlconnection = $SqlCms.ConnectionContext.SqlConnectionObject

	try { $cmstore = New-Object Microsoft.SqlServer.Management.RegisteredServers.RegisteredServersStore($sqlconnection)}
	catch { throw "Cannot access Central Management Server" }
	
	$servers = @()
	if ($groups -ne $null) {
		foreach ($group in $groups) {
			$cms = $cmstore.ServerGroups["DatabaseEngineServerGroup"].ServerGroups[$group]
			$servers += ($cms.GetDescendantRegisteredServers()).servername	
		}
	} else {
		$cms = $cmstore.ServerGroups["DatabaseEngineServerGroup"]
		$servers = ($cms.GetDescendantRegisteredServers()).servername
	}

	return $servers
}

Function Get-OfflineSqlFileStructure {
 <#
            .SYNOPSIS
             Dictionary object that contains file structures for SQL databases
			
            .EXAMPLE
            $filestructure = Get-OfflineSqlFileStructure $server $dbname $filelist $ReuseFolderstructure
			foreach	($file in $filestructure.values) {
				Write-Output $file.physical
				Write-Output $file.logical
				Write-Output $file.remotepath
			}

            .OUTPUTS
             Dictionary
        #>
		[CmdletBinding()]
        param(
			[Parameter(Mandatory = $true,Position=0)]
			[ValidateNotNullOrEmpty()]
			[object]$SqlServer,
			
			[Parameter(Mandatory = $true,Position=1)]
			[string]$dbname,
			
			[Parameter(Mandatory = $true,Position=2)]
			[object]$filelist,
			
			[Parameter(Mandatory = $false,Position=3)]
			[bool]$ReuseFolderstructure,
			
			[System.Management.Automation.PSCredential]$SqlCredential
		)
	
	$server = Connect-SqlServer -SqlServer $SqlServer -SqlCredential $SqlCredential
	
	$destinationfiles = @{};
	$logfiles = $filelist | Where-Object {$_.Type -eq "L"}
	$datafiles = $filelist | Where-Object {$_.Type -ne "L"}
	$filestream = $filelist | Where-Object {$_.Type -eq "S"}
	
	if ($filestream) {
		$sql = "select coalesce(SERVERPROPERTY('FilestreamConfiguredLevel'),0) as fs"
		$fscheck = $server.databases['master'].ExecuteWithResults($sql)
		if ($fscheck.tables.fs -eq 0)  { return $false }
	}
	
	# Data Files
	foreach ($file in $datafiles) {
		# Destination File Structure
		$d = @{}
		if ($ReuseFolderstructure -eq $true) {
			$d.physical = $file.PhysicalName
		} else {
			$directory = Get-SqlDefaultPaths $server data
			$filename = Split-Path $($file.PhysicalName) -leaf		
			$d.physical = "$directory\$filename"
		}
		
		$d.logical = $file.LogicalName
		$destinationfiles.add($file.LogicalName,$d)
	}
	
	# Log Files
	foreach ($file in $logfiles) {
		$d = @{}
		if ($ReuseFolderstructure) {
			$d.physical = $file.PhysicalName
		} else {
			$directory = Get-SqlDefaultPaths $server log
			$filename = Split-Path $($file.PhysicalName) -leaf		
			$d.physical = "$directory\$filename"
		}
		
		$d.logical = $file.LogicalName
		$destinationfiles.add($file.LogicalName,$d)
	}

	return $destinationfiles
}

Function Get-SqlFileStructure {
 <#
            .SYNOPSIS
             Custom object that contains file structures and remote paths (\\sqlserver\m$\mssql\etc\etc\file.mdf) for
			 source and destination servers.
			
            .EXAMPLE
            $filestructure = Get-SqlFileStructure $sourceserver $destserver $ReuseFolderstructure
			foreach	($file in $filestructure.databases[$dbname].destination.values) {
				Write-Output $file.physical
				Write-Output $file.logical
				Write-Output $file.remotepath
			}

            .OUTPUTS
             Custom object 
        #>
		[CmdletBinding()]
        param(
			[Parameter(Mandatory = $true,Position=0)]
			[ValidateNotNullOrEmpty()]
			[object]$source,
			
			[Parameter(Mandatory = $true,Position=1)]
			[ValidateNotNullOrEmpty()]
			[object]$destination,
			
			[Parameter(Mandatory = $false,Position=2)]
			[bool]$ReuseFolderstructure,
			[System.Management.Automation.PSCredential]$SourceSqlCredential,
			[System.Management.Automation.PSCredential]$DestinationSqlCredential
		)
	
	$sourceserver = Connect-SqlServer -SqlServer $Source -SqlCredential $SourceSqlCredential
	$source = $sourceserver.name
	$destserver = Connect-SqlServer -SqlServer $Destination -SqlCredential $DestinationSqlCredential
	$destination = $destserver.name
	
	$sourcenetbios = Get-NetBiosName $sourceserver
	$destnetbios = Get-NetBiosName $destserver
	
	$dbcollection = @{}; 
	
		foreach ($db in $sourceserver.databases) {
			$dbstatus = $db.status.toString()
			if ($dbstatus.StartsWith("Normal") -eq $false) { continue }
			$destinationfiles = @{}; $sourcefiles = @{}
			
			# Data Files
			foreach ($filegroup in $db.filegroups) {
				foreach ($file in $filegroup.files) {
					# Destination File Structure
					$d = @{}
					if ($ReuseFolderstructure) {
						$d.physical = $file.filename
					} else {
						$directory = Get-SqlDefaultPaths $destserver data
						$filename = Split-Path $($file.filename) -leaf		
						$d.physical = "$directory\$filename"
					}
					$d.logical = $file.name
					$d.remotefilename = Join-AdminUnc $destnetbios $d.physical
					$destinationfiles.add($file.name,$d)
					
					# Source File Structure
					$s = @{}
					$s.logical = $file.name
					$s.physical = $file.filename
					$s.remotefilename = Join-AdminUnc $sourcenetbios $s.physical
					$sourcefiles.add($file.name,$s)
				}
			}
			
			# Add support for Full Text Catalogs in SQL Server 2005 and below
			if ($sourceserver.VersionMajor -lt 10) {
				foreach ($ftc in $db.FullTextCatalogs) {
					# Destination File Structure
					$d = @{}
					$pre = "sysft_"
					$name = $ftc.name
					$physical = $ftc.RootPath
					$logical = "$pre$name"
					if ($ReuseFolderstructure) {
						$d.physical = $physical
					} else {
						$directory = Get-SqlDefaultPaths $destserver data
						if ($destserver.VersionMajor -lt 10) { $directory = "$directory\FTDATA" }
						$filename = Split-Path($physical) -leaf	
						$d.physical = "$directory\$filename"
					}
					$d.logical = $logical
					$d.remotefilename = Join-AdminUnc $destnetbios $d.physical
					$destinationfiles.add($logical,$d)
					
					# Source File Structure
					$s = @{}
					$pre = "sysft_"
					$name = $ftc.name
					$physical = $ftc.RootPath
					$logical = "$pre$name"
					
					$s.logical = $logical
					$s.physical = $physical
					$s.remotefilename = Join-AdminUnc $sourcenetbios $s.physical
					$sourcefiles.add($logical,$s)
				}
			}

			# Log Files
			foreach ($file in $db.logfiles) {
				$d = @{}
				if ($ReuseFolderstructure) {
					$d.physical = $file.filename
				} else {
					$directory = Get-SqlDefaultPaths $destserver log
					$filename = Split-Path $($file.filename) -leaf		
					$d.physical = "$directory\$filename"
				}
				$d.logical = $file.name
				$d.remotefilename = Join-AdminUnc $destnetbios $d.physical
				$destinationfiles.add($file.name,$d)
				
				$s = @{}
				$s.logical = $file.name
				$s.physical = $file.filename
				$s.remotefilename = Join-AdminUnc $sourcenetbios $s.physical
				$sourcefiles.add($file.name,$s)
			}
			
		$location = @{}
		$location.add("Destination",$destinationfiles)
		$location.add("Source",$sourcefiles)	
		$dbcollection.Add($($db.name),$location)
		}
		
	$filestructure = [pscustomobject]@{"databases" = $dbcollection}
	return $filestructure
}

Function Get-SqlDefaultPaths     {
 <#
            .SYNOPSIS
			Gets the default data and log paths for SQL Server. Needed because SMO's server.defaultpath is sometimes null.

            .EXAMPLE
            $directory = Get-SqlDefaultPaths -Sqlserver $sqlserver -Filetype data -SqlCredential $SqlCredential
			$directory = Get-SqlDefaultPaths -Sqlserver $sqlserver -Filetype log -SqlCredential $SqlCredential

            .OUTPUTS
              String with file path.
			
        #>
		[CmdletBinding()]
        param(
			[Parameter(Mandatory = $true)]
			[ValidateNotNullOrEmpty()]
            [object]$SqlServer,
			
			[Parameter(Mandatory = $true)]
			[ValidateNotNullOrEmpty()]
            [string]$filetype,
			[System.Management.Automation.PSCredential]$SqlCredential
		)
	
	$server = Connect-SqlServer -SqlServer $SqlServer -SqlCredential $SqlCredential
	
	switch ($filetype) { "mdf" { $filetype = "data" } "ldf" {  $filetype = "log" } }
	
	if ($filetype -eq "log") {
		# First attempt
		$filepath = $server.DefaultLog
		# Second attempt
		if ($filepath.Length -eq 0) { $filepath = $server.Information.MasterDbLogPath }
		# Third attempt
		if ($filepath.Length -eq 0) {
			$sql = "select SERVERPROPERTY('InstanceDefaultLogPath') as physical_name"
			$filepath = $server.ConnectionContext.ExecuteScalar($sql)
		}
	} else {
		# First attempt
		$filepath = $server.DefaultFile
		# Second attempt
		if ($filepath.Length -eq 0) { $filepath = $server.Information.MasterDbPath }
		# Third attempt
		if ($filepath.Length -eq 0) {
			 $sql = "select SERVERPROPERTY('InstanceDefaultDataPath') as physical_name"
			 $filepath = $server.ConnectionContext.ExecuteScalar($sql)
		}
	}
	
	if ($filepath.Length -eq 0) { throw "Cannot determine the required directory path" }
	$filepath = $filepath.TrimEnd("\")
	return $filepath
}

Function Join-AdminUnc {
 <#
            .SYNOPSIS
             Parses a path to make it an admin UNC.   

            .EXAMPLE
             Join-AdminUnc sqlserver C:\windows\system32
			 Output: \\sqlserver\c$\windows\system32
			 
            .OUTPUTS
             String
			
        #>
		[CmdletBinding()]
        param(
			[Parameter(Mandatory = $true)]
			[ValidateNotNullOrEmpty()]
            [string]$servername,
			
			[Parameter(Mandatory = $true)]
			[ValidateNotNullOrEmpty()]
            [string]$filepath
			
		)
		
	if (!$filepath) { return }
	if ($filepath.StartsWith("\\")) { return $filepath }

	if ($filepath.length -gt 0 -and $filepath -ne [System.DbNull]::Value) {
		$newpath = Join-Path "\\$servername\" $filepath.replace(':','$')
		return $newpath
	}
	else { return }
}

Function Test-SqlSa {
 <#
            .SYNOPSIS
              Ensures sysadmin account access on SQL Server. $server is an SMO server object.

            .EXAMPLE
              if (!(Test-SqlSa -SqlServer $SqlServer -SqlCredential $SqlCredential)) { throw "Not a sysadmin on $source. Quitting." }  

            .OUTPUTS
                $true if syadmin
                $false if not
			
        #>
		[CmdletBinding()]
        param(
			[Parameter(Mandatory = $true)]
			[ValidateNotNullOrEmpty()]
            [object]$SqlServer,
			[System.Management.Automation.PSCredential]$SqlCredential
		)
		
try {
			
	if ($SqlServer.GetType() -eq [Microsoft.SqlServer.Management.Smo.Server]) {
		return ($SqlServer.ConnectionContext.FixedServerRoles -match "SysAdmin")
	}
	
	$server = Connect-SqlServer -SqlServer $SqlServer -SqlCredential $SqlCredential
	return ($server.ConnectionContext.FixedServerRoles -match "SysAdmin")
	}
	
	catch { return $false }
}

Function Get-NetBiosName {
 <#
	.SYNOPSIS
	Takes a best guess at the NetBIOS name of a server. 

	.EXAMPLE
	$sourcenetbios = Get-NetBiosName -SqlServer $server -SqlCredential $SqlCredential
	
	.OUTPUTS
	  String with netbios name.
			
 #>
		[CmdletBinding()]
        param(
			[Parameter(Mandatory = $true)]
			[ValidateNotNullOrEmpty()]
            [object]$SqlServer,
			[System.Management.Automation.PSCredential]$SqlCredential
		)
	
	$server = Connect-SqlServer -SqlServer $SqlServer -SqlCredential $SqlCredential
	$servernetbios = $server.ComputerNamePhysicalNetBIOS
	
	if ($servernetbios -eq $null) {
		$servernetbios = ($server.name).Split("\")[0]
		$servernetbios = $servernetbios.Split(",")[0]
	}
	
	return $($servernetbios.ToLower())
}

Function Restore-Database {
        <# 
            .SYNOPSIS
             Restores .bak file to SQL database. Creates db if it doesn't exist. $filestructure is
			a custom object that contains logical and physical file locations.

            .EXAMPLE
			 $filestructure = Get-SqlFileStructure $sourceserver $destserver $ReuseFolderstructure
             Restore-Database $destserver $dbname $backupfile $filetype $filestructure $norecovery

            .OUTPUTS
                $true if success
                $true if failure
        #>
		[CmdletBinding()]
        param(
			[Parameter(Mandatory = $true)]
            [ValidateNotNullOrEmpty()]
			[object]$SqlServer,
			
			[Parameter(Mandatory = $true)]
			[ValidateNotNullOrEmpty()]
            [string]$dbname,

			[Parameter(Mandatory = $true)]
			[ValidateNotNullOrEmpty()]
            [string]$backupfile,
		
            [string]$filetype = "Database",
			
			[Parameter(Mandatory = $true)]
			[ValidateNotNullOrEmpty()]
            [object]$filestructure,
			
			[switch]$norecovery = $true,
			
			[System.Management.Automation.PSCredential]$SqlCredential
        )
		
	$server = Connect-SqlServer -SqlServer $SqlServer -SqlCredential $SqlCredential
	$servername = $server.name
	$server.ConnectionContext.StatementTimeout = 0
	$restore = New-Object "Microsoft.SqlServer.Management.Smo.Restore"
	$restore.ReplaceDatabase = $true
	
	foreach	($file in $filestructure.values) {
		$movefile = New-Object "Microsoft.SqlServer.Management.Smo.RelocateFile" 
		$movefile.LogicalFileName = $file.logical
		$movefile.PhysicalFileName = $file.physical
		$null = $restore.RelocateFiles.Add($movefile)
	}
	
	try {
		
		$percent = [Microsoft.SqlServer.Management.Smo.PercentCompleteEventHandler] { 
			Write-Progress -id 1 -activity "Restoring $dbname to $servername" -percentcomplete $_.Percent -status ([System.String]::Format("Progress: {0} %", $_.Percent)) 
		}
		$restore.add_PercentComplete($percent)
		$restore.PercentCompleteNotification = 1
		$restore.add_Complete($complete)
		$restore.ReplaceDatabase = $true
		$restore.Database = $dbname
		$restore.Action = $filetype
		$restore.NoRecovery = $norecovery
		$device = New-Object -TypeName Microsoft.SqlServer.Management.Smo.BackupDeviceItem
		$device.name = $backupfile
		$device.devicetype = "File"
		$restore.Devices.Add($device)
		
		Write-Progress -id 1 -activity "Restoring $dbname to $servername" -percentcomplete 0 -status ([System.String]::Format("Progress: {0} %", 0))
		$restore.sqlrestore($server)
		Write-Progress -id 1 -activity "Restoring $dbname to $servername" -status "Complete" -Completed
		
		return $true
	} catch {
		Write-Error "Restore failed: $($_.Exception)"
		return $false
	}
}

Function Test-SqlAgent  {
 <#
            .SYNOPSIS
              Checks to see if SQL Server Agent is running on a server.  

            .EXAMPLE
              if (!(Test-SqlAgent -SqlServer $SqlServer -SqlCredential $SqlCredential)) { Write-Output "SQL Agent not running on $SqlServer"  }

            .OUTPUTS
                $true if running and accessible
                $false if not running or inaccessible
			
        #>
		[CmdletBinding()]
        param(
			[Parameter(Mandatory = $true)]
			[ValidateNotNullOrEmpty()]
            [object]$SqlServer,
			[System.Management.Automation.PSCredential]$SqlCredential
		)
	
	if ($SqlServer.GetType() -ne [Microsoft.SqlServer.Management.Smo.Server]) {
		$SqlServer = Connect-SqlServer -SqlServer $SqlServer -SqlCredential $SqlCredential
	}
	
	if ($SqlServer.JobServer -eq $null) { return $false }
	try { $null = $SqlServer.JobServer.script(); return $true } catch { return $false }
}

Function Update-SqlDbOwner  { 
        <#
            .SYNOPSIS
                Updates specified database dbowner.

            .EXAMPLE
                Update-SqlDbOwner $sourceserver $destserver -dbname $dbname

            .OUTPUTS
                $true if success
                $false if failure
        #>
		[CmdletBinding()]
        param(
			[Parameter(Mandatory = $true)]
			[ValidateNotNullOrEmpty()]
            [object]$source,
			
			[Parameter(Mandatory = $true)]
			[ValidateNotNullOrEmpty()]
            [object]$destination,
			
			[Parameter(Mandatory = $true)]
			[ValidateNotNullOrEmpty()]
            [string]$dbname,
			[System.Management.Automation.PSCredential]$SourceSqlCredential,
			[System.Management.Automation.PSCredential]$DestinationSqlCredential
        )

		
		$sourceserver = Connect-SqlServer -SqlServer $Source -SqlCredential $SourceSqlCredential
		$destserver = Connect-SqlServer -SqlServer $Destination -SqlCredential $DestinationSqlCredential

		$source = $sourceserver.name
		$destination = $destserver.name	
		
		$destdb = $destserver.databases[$dbname]
		$dbowner = $sourceserver.databases[$dbname].owner
		
		if ($destdb.Status -ne 'Normal') { Write-Output "Database status not normal. Skipping dbowner update."; break }
		
		
		if ($dbowner -eq $null -or $destserver.logins[$dbowner] -eq $null) { $dbowner = 'sa' }
				
		try {
			if ($destdb.ReadOnly -eq $true) 
			{
				$changeroback = $true
				Update-SqlDbReadOnly $destserver $dbname $false
			}
			
			$destdb.SetOwner($dbowner)
			Write-Output "Changed $dbname owner to $dbowner"
			
			if ($changeroback) {
				Update-SqlDbReadOnly $destserver $dbname $true
				$changeroback = $null
			}
			
			return $true
		} catch { 
			Write-Error "Failed to update $dbname owner to $dbowner."
			return $false 
		}
}

Function Update-SqlDbReadOnly  { 
        <#
            .SYNOPSIS
                Updates specified database to read-only or read-write. Necessary because SMO doesn't appear to support NO_WAIT.

            .EXAMPLE
               Update-SqlDbReadOnly -SqlServer $Source -SqlCredential $SourceSqlCredential -DBName $dbname -readonly $true

            .OUTPUTS
                $true if success
                $false if failure
        #>
		[CmdletBinding()]
        param(
			[Parameter(Mandatory = $true)]
			[ValidateNotNullOrEmpty()]
            [object]$SqlServer,

			[Parameter(Mandatory = $true)]
			[ValidateNotNullOrEmpty()]
            [string]$dbname,
			
			[Parameter(Mandatory = $true)]
			[ValidateNotNullOrEmpty()]
            [bool]$readonly
        )
		
		if ($readonly) {
			$sql = "ALTER DATABASE [$dbname] SET READ_ONLY WITH NO_WAIT"
		} else {
			$sql = "ALTER DATABASE [$dbname] SET READ_WRITE WITH NO_WAIT"
		}

		try {
			$server = Connect-SqlServer -SqlServer $SqlServer -SqlCredential $SqlCredential
			$null = $server.ConnectionContext.ExecuteNonQuery($sql)
			Write-Output "Changed ReadOnly status to $readonly for $dbname on $($server.name)"
			return $true
		} catch { 
			Write-Error "Could not change readonly status for $dbname on $($server.name)"
			return $false }

}

Function Remove-SqlDatabase {
 <#
            .SYNOPSIS
             Uses SMO's KillDatabase to drop all user connections then drop a database. $server is
			 an SMO server object.

            .EXAMPLE
              Remove-SqlDatabase -SqlServer $server -DBName $dbname -SqlCredential $SqlCredential

            .OUTPUTS
                $true if success
                $false if failure
			
        #>
		[CmdletBinding()]
        param(
			[Parameter(Mandatory = $true)]
			[ValidateNotNullOrEmpty()]
			[object]$SqlServer,
			[Parameter(Mandatory = $true)]
			[ValidateNotNullOrEmpty()]
			[string]$DBName,
			[System.Management.Automation.PSCredential]$SqlCredential

		)
		
	try {
		$server = Connect-SqlServer -SqlServer $SqlServer -SqlCredential $SqlCredential
		$server.KillDatabase($dbname)
		$server.refresh()
		Write-Output "Successfully dropped $dbname on $($server.name)"
		return $true
	}
	catch {	return $false }
}


