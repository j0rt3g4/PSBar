<#
Created by Jose Gabriel Ortega Castro
All Right Reserved
https://www.j0rt3g4.com
email: j0rt3g4@j0rt3g4.com

Running the Script:
.\Get-MailboxesCountByDatabase -Count (Count all kind of mailboxes by databases)
.\Get-MailboxesCountByDatabase -Count -html (Count all kind of mailboxes by databases and export it to Html)

.\Get-MailboxesCountByDatabase (Get all kind of mailboxes by databases, and show it on screen)
.\Get-MailboxesCountByDatabase -Count -html (Get all kind of mailboxes by databases by databases and export it to Html)

Version: 2.0  (02/10/2016)
	* Corrected the 1000 limit on resultsize for big companies
	* added 3 more types of mailboxes by database (monitor,remotearchive,and public folder)
	* Changed the name of the "NumberofMailboxes" to "UserMailbox" count.

Version: 3.0 (03/24/2016)
    * Added a Log File
    * Added several funcions with functionality to the Script
	* Added a switch variable Called Count (Just to get the count of the mailboxes of each database when its added
	* Modified the way to run the script 
			* Get-MailboxesCountByDatabase.ps1"              : Will get the information of the mailboxes and show it in screen
			* Get-MailboxesCountByDatabase.ps1"  -Count      : Will get the Count information of the Mailboxes By database and show it in screen
			* Get-MailboxesCountByDatabase.ps1"  -Count -html: Will get the Count information of the Mailboxes By database, show it in screen and export it to a html file called: MailboxCount.htm in the same folder of the running script (variable line 45)
			* Get-MailboxesCountByDatabase.ps1"  -html       : Will get the information of the mailboxes by database, show it in screen and exported it to a html file called:  localed in the same folder of the running script  (variable line 46)
    * It was included a couple of Switch vars, one to only give the Count numbers, and $html to get the output in html.

Version 3.1 (03/28/2016)
    * Bug Corrected: Added multiple times variables to be cleaned up ("tempName" and "StadististObject")

Version 3.2 (04/27/2016)
    * Previous Version was removing variables ("tempName" and "StadististObject") incorrectly this issue was solved.

Version 4 (03/08/2017)
    * Enabled for Exchange 2010 
    * Required version lowered from 3 to 2
	
#>
#requires -version 2.0

param(
    [Parameter(Mandatory = $false, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)] [Switch]$Count,
    [Parameter(Mandatory = $false, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)] [Switch]$html
 )

#Clean Up Variable
#Stradegy of clean up save All the names of the variables during the run of the scripts and then just go foreach var in both scope (local and global, one variable for each).
$CleanUpVar=@()
$CleanUpGlobal=@()

#Start time of the script
$TimeStart=Get-Date
$CleanUpVar+="TimeStart"

#Global Variables
$Global:ScriptLocation = $(get-location).Path
$Global:DefaultLog = "$global:ScriptLocation\DatabaseCountByDatabase.log"
$Global:isES2010 = $false
$Global:isES2013= $false
$Global:isES2016= $false
$Global:isESLegacy = $false
$Global:CountHtml="$Global:ScriptLocation\MailboxCount.htm"
$Global:DatabaseHtml="$Global:ScriptLocation\MBxByDatabase.htm"

#Save VariableNames into CleanUpGlobal
$CleanUpGlobal+="ScriptLocation"
$CleanUpGlobal+="DefaultLog"
$CleanUpGlobal+="isES2010"
$CleanUpGlobal+="isES2013"
$CleanUpGlobal+="isES2016"
$CleanUpGlobal+="isESLegacy"
$CleanUpGlobal+="CountHtml"
$CleanUpGlobal+="DatabaseHtml"


#Local Variables and Functions
$today = get-date -format MM-dd-yyyy
$CleanUpVar+="today"

function Write-Log{
        [CmdletBinding()]
        #[Alias('wl')]
        [OutputType([int])]
        Param
        (
            # The string to be written to the log.
            [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, Position=0)] [ValidateNotNullOrEmpty()] [Alias("LogContent")] [string]$Message,
            # The path to the log file.
            [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true,Position=1)] [Alias('LogPath')] [string]$Path=$DefaultLog,
            [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true,Position=2)] [ValidateSet("Error","Warn","Info","Load","Execute")] [string]$Level="Info",
            [Parameter(Mandatory=$false)] [switch]$NoClobber
        )

     Process{
        
        if ((Test-Path $Path) -AND $NoClobber) {
            Write-Warning "Log file $Path already exists, and you specified NoClobber. Either delete the file or specify a different name."
            Return
            }

        # If attempting to write to a log file in a folder/path that doesn't exist
        # to create the file include path.
        elseif (!(Test-Path $Path)) {
            Write-Verbose "Creating $Path."
            $NewLogFile = New-Item $Path -Force -ItemType File
            }

        else {
            # Nothing to see here yet.
            }

        # Now do the logging and additional output based on $Level
        switch ($Level) {
            'Error' {
                Write-Warning $Message
                Write-Output "$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") ERROR: `t $Message" | Out-File -FilePath $Path -Append
                }
            'Warn' {
                Write-Warning $Message
                Write-Output "$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") WARNING: `t $Message" | Out-File -FilePath $Path -Append
                }
            'Info' {
                Write-Host $Message -ForegroundColor Green
                Write-Verbose $Message
                Write-Output "$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") INFO: `t $Message" | Out-File -FilePath $Path -Append
                }
            'Load' {
                Write-Host $Message -ForegroundColor Magenta
                Write-Verbose $Message
                Write-Output "$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") LOAD: `t $Message" | Out-File -FilePath $Path -Append
                }
            'Execute' {
                Write-Host $Message -ForegroundColor Green
                Write-Verbose $Message
                Write-Output "$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") EXEC: `t $Message" | Out-File -FilePath $Path -Append
                }
            }
    }
}
function ShowTimeMS{
  [CmdletBinding()]
  param(
    [Parameter(ValueFromPipeline=$True,position=0,mandatory=$true)]	[datetime]$timeStart,
	[Parameter(ValueFromPipeline=$True,position=1,mandatory=$true)]	[datetime]$timeEnd
  )
  BEGIN {
    
  }
  PROCESS {
		write-Verbose "Stamping time"
		write-Verbose  "initial time: $TimeStart"
		write-Verbose "End time: $TimeEnd"
		$diff=New-TimeSpan $TimeStart $TimeEnd
		Write-verbose "Timediff= $diff"
		$miliseconds = $diff.TotalMilliseconds
		Write-output " Total Time in miliseconds is: $miliseconds ms"
		
  }
}
function SetExchangeServerVersion{
 [CmdletBinding()]
  param(
    [Parameter(ValueFromPipeline=$True,position=0,mandatory=$true)]	[PSObject]$ExSrvObj
  )
  BEGIN {
    $Major= $ExSrvObj.Major
    $Minor= $ExSrvObj.Minor
    $Build= $ExSrvObj.Build
    $Revision=$ExSrvObj.Revision
  }

  PROCESS{
  $ObjA=$false
  $ObjB=$false
  $ObjC=$false
  if( ($Major -eq 15) -and ($Minor -eq 0) ){
    $Global:isES2013=$True
  }
  else{
    $ObjA=$True
  }

  if( ($Major -eq 15) -and ($Minor -eq 1) ){
   $Global:isES2016=$True
  }
  else{
    $ObjB=$true
  }
  if( ($Major -eq 14)){
   $Global:isES2010=$True
  }
  else{
    $objC=$true
  }

  If( $ObjA -and $ObjB -and $ObjC ){
    $Global:isESLegacy=$True
  }
  

}

  END{
    if( $Global:isES2013){
        Write-Log -Level Info "You are running Exchange Server 2013 ($Major.$Minor Build: $Build, Revision: $Revision)"
    }
    
    if($Global:isES2016){
        Write-Log -Level Info "You are running Exchange Server 2016 ($Major.$Minor Build: $Build, Revision: $Revision)"
    }
    if($Global:isES2010){
        Write-Log -Level Info "You are running Exchange Server 2010 ($Major.$Minor Build: $Build, Revision: $Revision)"
    }
    if($Global:isESLegacy){
        Write-Log -Level Info "You are running Exchange Server 2007 or inferior ($Major.$Minor Build: $Build, Revision: $Revision)"
    }

    Write-Log -Level Info "For more Details please check: https://technet.microsoft.com/en-us/library/hh135098(v=exchg.150).aspx"
  }
}
Function isNullorEmpty{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]$Name
    )
    PROCESS{
       Write-Verbose "Checking if $Name is null"
        $booleanvalue=[string]::IsNullOrEmpty($Name.Name)
        
    }
    END{
        return $booleanvalue
    }
}
Function isNullorEmptyGlobalVar{
    [CmdletBinding()]
    param(
        [Parameter(position=0)]$Name
    )
    PROCESS{
       Write-Verbose "Checking if $Name is null"
        $booleanvalue=[string]::IsNullOrEmpty($Name)
        
    }
    END{
        return $booleanvalue
    }
}
Function PrintOrExport{
	[CmdletBinding()]
	param(
    [Parameter(mandatory=$false, position=0)][PSObject]$Count,
    [Parameter(mandatory=$false, position=1)][PSObject]$html

)
  PROCESS{
	#both given $html and $Count
        Write-Verbose "Loading Active Directory  Module"
        Write-Log -Level Info "Checking if the Active Directory Module is Present"
        $item = (Get-Module -ListAvailable  | select Name) | where{ $_.Name -match "ActiveDirectory" }
        if( $item.Name -match "ActiveDirectory" ){ 
            Write-Log -Level Load "Loading Active Directory Module"
            Import-Module ActiveDirectory
        } else{ 
            Write-log -Level Warn "Active Directory Module is already loaded"
        }


		if($html -and $Count){
			$DomainName = (Get-ADDomain).DNSRoot
			$title="Mailboxes by Database Count for $DomainName"
            Write-Output $Global:usersByDatabase | ft -AutoSize
            Write-Log -Level Info "Exporting Users Count by database"
			$header='<style>h1,h3,th{text-align:center}table{margin:auto;font-family:Segoe UI;box-shadow:5px 5px 3px #555;border:thin ridge grey}th{background:#08298A;color:#fff;max-width:400px;padding:5px 10px}td{font-size:11px;padding:5px 20px;color:#000}tr,tr:nth-child(odd){background:#D3F0FF}tr:nth-child(even){background:#CEF6E3}</style>'
			$Global:usersByDatabase |  ConvertTo-Html  -Title $title -Head $header  -Body "<h1>$title</h1>`n<h3>Updated: on $today</h3>"  | Set-content $Global:CountHtml
            Write-Log -Level Info "done"
            write-log -Level Execute "Opening the default browser with the html content"
			Invoke-Item $Global:CountHtml
		}
		#Given html 
		if( $html -and (-not $Count) ){
			$DomainName = (Get-ADDomain).DNSRoot
			$title="Mailboxes by DatabaseCount for $DomainName"
            Write-Log -Level Info "Exporting Users by database"
            
			$header='<style>h1,h3,th{text-align:center}table{margin:auto;font-family:Segoe UI;box-shadow:5px 5px 3px #555;border:thin ridge grey}th{background:#08298A;color:#fff;max-width:400px;padding:5px 10px}td{font-size:11px;padding:5px 20px;color:#000}tr,tr:nth-child(odd){background:#D3F0FF}tr:nth-child(even){background:#CEF6E3}</style>'
			$Global:UsersByDatabaseInfo |  ConvertTo-Html  -Title $title -Head $header -Body "<h1>$title</h1>`n<h3>Updated: on $today</h3>"  | Set-content $Global:DatabaseHtml
            Write-Log -Level Info "done"
            write-log -Level Execute "Opening the default browser with the html content"
			Invoke-Item $Global:DatabaseHtml
		}
		#Given Count
		if( (-not $html) -and $Count){
            if($Global:isES2010){
               Write-Output $Global:usersByDatabase | Sort-Object -Descending | ft DBName,Arbitration,Archive,UsersMailbox  -AutoSize
            }

            if($Global:isES2013){
                Write-Output $Global:usersByDatabase | Sort-Object -Descending | ft DBName,Arbitration,Archive,Monitor,PublicFolder,RemoteArchive,UsersMailbox  -AutoSize
            }
            if($Global:isES2016){
                Write-Output $Global:usersByDatabase | Sort-Object -Descending | ft DBName,Arbitration,Archive,AuditLog,Monitor,PublicFolder,RemoteArchive,UsersMailbox  -AutoSize
            }
		}
		#not Given any		
		if( (-not $html) -and (-not $Count)){
			Write-Output $Global:UsersByDatabaseInfo | ft -AutoSize
		}
	}
}

#######################
#   *Start Script*    #
#######################

Write-Verbose "Importing Exchange server Management Console"
Write-Log -Level Info "Checking if the Exchange PS Snap in is present"
if ( (Get-PSSnapin -Name Microsoft.Exchange.Management.PowerShell.E2010 -ErrorAction SilentlyContinue) -eq $null ){
	Write-Log -Level Load "Loading Exchange PS Snap in"
    Add-PSSnapin Microsoft.Exchange.Management.PowerShell.E2010
}
else{
    Write-log -Level Warn "Exchange PS Snapin is already loaded"
}

Write-log -Level Info "Getting Information of the Exchange Server"
$Global:ExchangeVersion= (Get-ExchangeServer).AdminDisplayVersion
$CleanUpGlobal+="ExchangeVersion"

SetExchangeServerVersion $Global:ExchangeVersion

#PROCESS
Write-Verbose "Getting information from users on each databases"  
Write-Verbose "Getting Database on the server"  
$databases=  Get-MailboxDatabase | select Name  #Get all databases in server
$CleanUpVar+="databases"

$Global:usersByDatabase=@()
$CleanUpGlobal+="usersByDatabase"

if($Count){
	Write-log -Level Info "Getting Mailbox Count By Database"
#Count Enabled so Just Count Users by database
	if($Global:isES2010){
		$databases | ForEach-Object{
			$NewObject=New-Object PSObject -Property @{
					DBName = $_.Name
					Arbitration= (get-mailbox -database $_.name -Arbitration -ResultSize unlimited).count 
					Archive = (get-mailbox -database $_.name -Archive -ResultSize unlimited).count 
					UsersMailBox = (get-mailbox -database $_.name -ResultSize unlimited).count 
            }
        $Global:usersByDatabase+=$NewObject        
        }
	}

	if( $Global:isES2013){
		$databases | ForEach-Object{
			$NewObject=New-Object PSObject -Property @{
					DBName = $_.Name
					Archive = (get-mailbox -database $_.name -Archive -ResultSize unlimited).count 
					Arbitration= (get-mailbox -database $_.name -Arbitration -ResultSize unlimited).count 
					PublicFolder = (get-mailbox -database $_.name -PublicFolder -ResultSize unlimited).count 
					RemoteArchive= (get-mailbox -database $_.name -RemoteArchive -ResultSize unlimited).count 
					Monitor = (get-mailbox -database $_.name -Monitor -ResultSize unlimited).count
					UsersMailBox = (get-mailbox -database $_.name -ResultSize unlimited).count 
            }
        $Global:usersByDatabase+=$NewObject        
        }
	}

	if($Global:isES2016){
		$databases | ForEach-Object{
			$NewObject=New-Object PSObject -Property @{
					DBName = $_.Name
					Archive = (get-mailbox -database $_.name -Archive -ResultSize unlimited).count 
					Arbitration= (get-mailbox -database $_.name -Arbitration -ResultSize unlimited).count 
					PublicFolder = (get-mailbox -database $_.name -PublicFolder -ResultSize unlimited).count 
					RemoteArchive= (get-mailbox -database $_.name -RemoteArchive -ResultSize unlimited).count
					Monitor = (get-mailbox -database $_.name -Monitor -ResultSize unlimited).count
					UsersMailBox = (get-mailbox -database $_.name -ResultSize unlimited).count 
					AuditLog = (get-mailbox -database $_.name -Auditlog -ResultSize unlimited).count 
            }
       $Global:usersByDatabase+=$NewObject        
        }
	}

	if($Global:isESLegacy){
		Write-Log -Level Error "You're running the script in a unsupported system (Exchange2007 or previous), Exiting..."
		exit(-1)
	}
	
	
    
}
else{
  #Count Unselected
  if($Global:isES2010){
		$databases | ForEach-Object{
			$NewObject=New-Object PSObject -Property @{
                    Archive = (get-mailbox -database $_.name -Archive -ResultSize unlimited | Select DisplayName,Database,Identity,WindowsEmailAddress,IsMailboxEnabled,RecipientType,WhenChanged, WhenCreated)
                    Arbitration= (get-mailbox -database $_.name -Arbitration -ResultSize unlimited | Select DisplayName,Database,Identity,WindowsEmailAddress,IsMailboxEnabled,RecipientType,WhenChanged, WhenCreated)
                    UsersMailBox = (get-mailbox -database $_.name -ResultSize unlimited | Select DisplayName,Database,Identity,WindowsEmailAddress,IsMailboxEnabled,RecipientType,WhenChanged, WhenCreated)
                    }
            $Global:usersByDatabase+=$NewObject
        }
	}
    
	if($Global:isES2013){
		$databases | ForEach-Object{
			$NewObject=New-Object PSObject -Property @{
                    Archive = (get-mailbox -database $_.name -Archive -ResultSize unlimited | Select DisplayName,Database,Identity,WindowsEmailAddress,IsMailboxEnabled,RecipientType,WhenChanged, WhenCreated)
                    Arbitration= (get-mailbox -database $_.name -Arbitration -ResultSize unlimited | Select DisplayName,Database,Identity,WindowsEmailAddress,IsMailboxEnabled,RecipientType,WhenChanged, WhenCreated)
                    PublicFolder = (get-mailbox -database $_.name -PublicFolder -ResultSize unlimited | Select DisplayName,Database,Identity,WindowsEmailAddress,IsMailboxEnabled,RecipientType,WhenChanged, WhenCreated)
                    RemoteArchive= (get-mailbox -database $_.name -RemoteArchive -ResultSize unlimited | Select DisplayName,Database,Identity,WindowsEmailAddress,IsMailboxEnabled,RecipientType,WhenChanged, WhenCreated)
                    Monitor = (get-mailbox -database $_.name -Monitor -ResultSize unlimited | Select DisplayName,Database,Identity,WindowsEmailAddress,IsMailboxEnabled,RecipientType,WhenChanged, WhenCreated)
                    UsersMailBox = (get-mailbox -database $_.name -ResultSize unlimited | Select DisplayName,Database,Identity,WindowsEmailAddress,IsMailboxEnabled,RecipientType,WhenChanged, WhenCreated)
                    }
            $Global:usersByDatabase+=$NewObject
		}
	}

	if($Global:isES2016){
		$databases | ForEach-Object{
			$NewObject=New-Object PSObject -Property @{
                    Archive = (get-mailbox -database $_.name -Archive -ResultSize unlimited | Select DisplayName,Database,Identity,WindowsEmailAddress,IsMailboxEnabled,RecipientType,WhenChanged, WhenCreated)
                    Arbitration= (get-mailbox -database $_.name -Arbitration -ResultSize unlimited | Select DisplayName,Database,Identity,WindowsEmailAddress,IsMailboxEnabled,RecipientType,WhenChanged, WhenCreated)
                    PublicFolder = (get-mailbox -database $_.name -PublicFolder -ResultSize unlimited | Select DisplayName,Database,Identity,WindowsEmailAddress,IsMailboxEnabled,RecipientType,WhenChanged, WhenCreated)
                    RemoteArchive= (get-mailbox -database $_.name -RemoteArchive -ResultSize unlimited | Select DisplayName,Database,Identity,WindowsEmailAddress,IsMailboxEnabled,RecipientType,WhenChanged, WhenCreated)
                    Monitor = (get-mailbox -database $_.name -Monitor -ResultSize unlimited | Select DisplayName,Database,Identity,WindowsEmailAddress,IsMailboxEnabled,RecipientType,WhenChanged, WhenCreated)
                    UsersMailBox = (get-mailbox -database $_.name -ResultSize unlimited | Select DisplayName,Database,Identity,WindowsEmailAddress,IsMailboxEnabled,RecipientType,WhenChanged, WhenCreated)
                    AuditLog = (get-mailbox -database $_.name -Auditlog -ResultSize unlimited | Select DisplayName,Database,Identity,WindowsEmailAddress,IsMailboxEnabled,RecipientType,WhenChanged, WhenCreated)
                    }
            $Global:usersByDatabase+=$NewObject
		}
	}

   #$UsersDatabaseProperties=  $usersByDatabase | Get-Member | where{$_.MemberType -eq "NoteProperty"} |select Name
	$PropertyNames= $Global:usersByDatabase | Get-Member -type NoteProperty | where{$_.Name -ne "DBName"} |Select Name
	$CleanUpVar+="PropertyNames"
	$Global:UsersByDatabaseInfo=@()
	$CleanUpGlobal+="UsersByDatabaseInfo"

    
	ForEach( $Property in  ($PropertyNames | Select -expandProperty "Name" )){
		$Global:usersByDatabase | select  -ExpandProperty "$Property"  | ForEach-Object{
			#If identity is not null or empty
			if( -not ( isNullorEmpty($_.Identity) )   ){
				$tempName= $_.DisplayName
				
			    Write-Log -Level Info "Getting Information of the account of $tempName"
				$StadististObject = Get-MailboxStatistics -Identity $_.Identity | select ItemCount,TotalItemSize,TotalDeletedItemSize,LastLogonTime,LastLogoffTime 
				
                $NewObject=New-Object PSObject -Property @{
                    DisplayName= $_.DisplayName
                    Identity= $_.Identity
                    WindowsEmailAddress = $_.WindowsEmailAddress
                    Database = $_.Database
                    IsMailboxEnabled=$_.IsMailboxEnabled
                    RecipientType=$_.RecipientType
                    ItemCount=$StadististObject.ItemCount
                    TotalItemSize=$StadististObject.TotalItemSize
                    TotalDeletedItemSize=$StadististObject.TotalDeletedItemSize
                    LastLogonTime=$StadististObject.LastLogonTime
                    LastLogoffTime=$StadististObject.LastLogoffTime
                    WhenCreated=$_.WhenCreated
                    WhenChanged=$_.WhenChanged
                }
				$Global:UsersByDatabaseInfo+=$NewObject
            }
            else{
                Write-Log -Level Warn "The identity for this object is null and it won't be added to the output, object: $_"
            }
		}
	}
    $CleanUpVar+="tempName"
    $CleanUpVar+="StadististObject"
}

$CleanUpVar+="NewObject"

PrintOrExport -Count $Count -html $html


#end time of the script
$TimeEnd=Get-Date

ShowTimeMS $TimeStart $TimeEnd
		
#Clean Up


Write-Log -Level Info "Cleaning up variables"

$CleanUpVar| ForEach-Object{
	Remove-Variable $_
	}
$CleanUpGlobal | ForEach-Object{
	Remove-Variable -Scope global $_
}
Remove-Variable CleanUpGlobal,CleanUpVar
