<#
    Version 6.2 Corrected to send emails from the current day and not all html in folder.
    Version 6.0
	* Added cleaning up of variables.
	* New Look and feel for the web using JCS colors.
	
    * Added Optional Parameters Days and Computer,
        - Days: It's a integer that goes from 1 to 1865 (from 1 day to 5 years behind in time to look into the logs), the default value is 3 days (if days parameter is not given)
        - Computer: In case you want to check another's computer registry.
    * The script requires that you run it in a elevated powershell console (since you're accessing the registries: security,application and system).
    * Added Log and notifications progress
    * No more infinite HTML files with the same error:
        - Added Frequency field, this is the number of repetitions of this error during the days.
        - Added FirstTime field, this is the date when the error was recorded the firsttime, during the days of query
        - Added LastTime field, ths is the date when the error was logged last time.


    How to use this script:
    EXAMPLES

    #Find all the events (Warnings and errors) for the local computer the last 3 days  (Only application and system logs)
     .\GetEventErrorsAAS.ps1

    #Find all the events (Warnings and errors) for the local computer the last 7 days (Only application and system logs)
     .\GetEventErrorsAAS.ps1 -Days 7

    #Find all events (Warnings, Errors and Information) for local computer the last 15 days (Only application and system logs)
     .\GetEventErrorsAAS.ps1 -Days 7 -AddInformation


    #Query All logs (application,system and security) for local computer in the last 3 days, will increase the time for running the script time considerably.
     .\GetEventErrorsAAS.ps1 -Days 7 -AddSecurity


     #Query all logs (application,system and security) for a remote computer 'TheRemoteServer' in the last 4 days, with informational and security info, and send the report for local email (smtp.domain.com)
     .\GetEventErrorsAAS.ps1 -Days 4 -Addinformation -AddSecurity -SendEmail -ComputersFile .\item.txt -SendEmail -computer TheRemoteServer
     

    #Added functionality in version 6
    Attach a computer's file in txt, each computer in a new line.
    computers.txt example:
   'dc01
    ex01
    ex02
    rmte'
    
    Save the file with the name of the computers with the name "computers.txt"
     .\GetEventErrorsAAS.ps1 -ComputersFile .\computers.txt
     
     you will get 3 files in the same running script path., if you want that to be sent everyday configure a task and add the  switch -SendEmail
     SendEmail is valid for all the cases above (local or remote).
       
      .\GetEventErrorsAAS.ps1 -ComputersFile .\computers.txt -SendEmail


#>

[CmdletBinding(DefaultParameterSetName=”Computer”)]
param(
     [Parameter(Mandatory=$false, ValueFromPipeline=$True,position=0, ParameterSetName="Computer")][Parameter(ParameterSetName='File', Position=0)]    [ValidateRange(1,1825)][int]$Days=3,
     [Parameter(Mandatory=$false, ValueFromPipeline=$True,position=1, ParameterSetName="Computer")][ValidateLength(1,60)][string]$computer=".",
     [Parameter(Mandatory=$false, ValueFromPipeline=$True,position=2, ParameterSetName="Computer")][Parameter(ParameterSetName='File',Position=1)][Switch]$AddInformation,
     [Parameter(Mandatory=$false, ValueFromPipeline=$True,position=3, ParameterSetName="Computer")][Parameter(ParameterSetName='File',position=2)][Switch]$AddSecurity,
     [Parameter(Mandatory=$false, ValueFromPipeline=$True,position=4, ParameterSetName="Computer")][Parameter(ParameterSetName='File',position=3)][switch]$SendEmail,
     [Parameter(Mandatory=$false, ValueFromPipeline=$True,position=5, ParameterSetName="Computer")][Parameter(ParameterSetName='File',Position=4)][string]$SMTPServer="mail.domain.com",
     [Parameter(Mandatory=$false, ValueFromPipeline=$True,position=5, ParameterSetName="File" )][string]$ComputersFile
)



#Clean Up VariableS
$CleanUpVar=@()
$CleanUpGlobal=@()

#Get start time
$TimeStart=Get-Date
$CleanUpVar+="TimeStart"

#Mail loval variables:
$mailto="joseo@lifford.com" #person or persons the would received
$mailfrom = "Reports@lifford.com" #Received from
$CleanUpVar+="mailto"
$CleanUpVar+="mailfrom"

#GLOBALs 
$global:ScriptLocation = $(get-location).Path
$global:DefaultLog = "$global:ScriptLocation\GetEventErrorsAAS.log"
$CleanUpGlobal+="ScriptLocation"
$CleanUpGlobal+="DefaultLog"

######################################################
###############       FUNCTIONS
               ####################################JCS
#ScriptLogFunction
function Write-Log{
    [CmdletBinding()]
    #[Alias('wl')]
    [OutputType([int])]
    Param(
            # The string to be written to the log.
            [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, Position=0)] [ValidateNotNullOrEmpty()] [Alias("LogContent")] [string]$Message,
            # The path to the log file.
            [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true,Position=1)] [Alias('LogPath')] [string]$Path=$global:DefaultLog,
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
function CheckExists{
	param(
		[Parameter(mandatory=$true,position=0)]$itemtocheck,
		[Parameter(mandatory=$true,position=1)]$colection
	)
	BEGIN{
		$item=$null
		$exist=$false
	}
	PROCESS{
		foreach($item in $colection){
			if($item.EventID -eq $itemtocheck){
				$exist=$true
				break;
			}
		}

	}
	END{
		return $exist
	}

}
function CheckCount{
	param(
		[Parameter(mandatory=$true,position=0)]$itemtocheck,
		[Parameter(mandatory=$true,position=1)]$colection
	)
	BEGIN{
		$item=$null
		$count=0
	}
	PROCESS{
		foreach($item in $colection){
			
			if($item.EventID -eq $itemtocheck){
				$count++
			}
		}

	}
	END{
		return $count
	}

}
function Get-Times{
	param(
		[Parameter(mandatory=$true,position=0)]$colection,
		[Parameter(mandatory=$true,position=1)]$EventID

	)
	BEGIN{
		$filterCollection= $colection | Where-Object{ $_.EventID -eq $EventID}
	}
	PROCESS{
		$previous = $filterCollection[0].TimeWritten
		$last = $filterCollection[0].TimeWritten
		foreach($item in $filterCollection){
			if($item.TimeWritten -lt $previous){
				$previous =$item.TimeWritten
			}
			if($item.TimeWritten -gt $last){
				$last = $item.TimeWritten
			}

		}

	}
	END{
		$output = New-Object psobject -Property @{
			first= $previous
			last= $last
		}
		return $output
	}

}
function Get-EventSubscriber{
         [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true,  ValueFromPipeline=$True,position=0)] [int]$Days,
        [Parameter(Mandatory=$true,  ValueFromPipeline=$True,position=1)] [ValidateSet("System","Security","Application")][ValidateNotNullOrEmpty()] [String]$LogName,
        [Parameter(Mandatory=$false, ValueFromPipeline=$True,position=2)] [String]$computer = ".",  #dot for localhost it can be changed to get any computer in the domain (server or client)
        [Parameter(Mandatory=$false, ValueFromPipeline=$True,position=3)] [Switch]$IncludeInfo
    )
    BEGIN{
        if($LogName -ne "Security"){
            Write-Log -Level Execute -Message "Getting $LogName Events"
        }
        else{
            Write-Log -Level Execute -Message "Getting $LogName Events. This can take a while"
        }
        #In case log is already there remove it.

    }
    
    PROCESS{
    if($LogName -ne "Security"){
        if($IncludeInfo){
            $Log=Get-EventLog -Computername $computer -LogName "$LogName" -EntryType "Information","Error","Warning" -After (Get-Date).Adddays(-$Days) | select *
        }
        else{
            $Log=Get-EventLog -Computername $computer -LogName "$LogName" -EntryType "Error","Warning" -After (Get-Date).Adddays(-$Days) | select *
        }
    }
    else{
            $Log=Get-EventLog -Computername $computer -LogName "$LogName" -EntryType FailureAudit,SuccessAudit -After (Get-Date).Adddays(-$Days) | select *
    }

    $Count = if($Log.Count){ $log.Count }else{ 1 }
   #
   # if($log.EventId -ne $null){
   #     $Count++;
   # }
   # else{
   #      
   # }

     Write-Log -Level Execute -Message "Attaching new properties to $LogName Events. Total Number of items in Log: $Count"       
     $return=@()
     $Log| foreach{$temp=$_.EventID; $valor = CheckCount -itemtocheck $temp -colection $Log;  $Dates = Get-Times -colection $Log -EventID $temp;  
        $_ |  Add-Member -Name "Frequency" -Value $valor -MemberType NoteProperty; 
        $_ |  Add-Member -Name "LastTime"  -Value $Dates.Last -MemberType NoteProperty;
        $_ |  Add-Member -Name "FirstTime" -Value $Dates.first -MemberType NoteProperty;
        $i++; $progress = ($i*100)/$Count;  
          if($progress -lt 100){Write-Progress -Activity "Attaching new properties to $LogName Events" -PercentComplete $progress; }
          else{Write-Progress -Activity "Attaching new properties to $LogName Events" -PercentComplete $progress -Complete }
          if(-not (CheckExists $temp $return)){$return+=$_ }}
        
    }
    END{
        return $return | Sort-Object Frequency -Descending
    }
}
function ObjectsToHtml5{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$True,position=0)][String]$Computer,
        [Parameter(mandatory=$false,position=1)]$systemObjs,
        [Parameter(mandatory=$false,position=2)]$AppObjs,
        [Parameter(mandatory=$false,position=3)]$SecObjs
    )
    BEGIN{
        write-verbose "Setting Actual Date"
	    $fecha=get-date -UFormat "%Y%m%d"
	    $dia=get-date -UFormat "%A"
        
        $Fn= "$fecha$Filename"
        
        $HtmlFileName = "$global:ScriptLocation\$Filename.html"
        $title = "Event Logs $fecha/$computer"
    }
    PROCESS{
    $html= '<!DOCTYPE HTML>
<html lang="en-US">
<head>
	<meta charset="UTF-8">
	<title>'
    $html+=$title
    $html+="</title>
	<style type=""text/css"">{margin:0;padding:0}@import url(https://fonts.googleapis.com/css?family=Indie+Flower|Josefin+Sans|Orbitron:500|Yrsa);body{text-align:center;font-family:14px/1.4 'Indie Flower','Josefin Sans',Orbitron,sans-serif;font-family:'Indie Flower',cursive;font-family:'Josefin Sans',sans-serif;font-family:Orbitron,sans-serif}#page-wrap{margin:50px}tr:nth-of-type(odd){background:#eee}th{background:#EF5525;color:#fff;font-family:Orbitron,sans-serif}td,th{padding:6px;border:1px solid #ccc;text-align:center;font-size:large}table{width:90%;border-collapse:collapse;margin-left:auto;margin-right:auto;font-family:Yrsa,serif}</style>
</head>
<body>
	<h1>Event Logs Report for $computer on $dia - $fecha
</h1>
<h2> System Information </h2>
<table>
<tr>
<th>MachineName</th><th>Index</th><th>TimeGenerated</th><th>EntryType</th><th>Source</th><th>InstanceID</th><th>FirstTime</th><th>LastTime</th><th>EventID</th><th>Frequency</th><th>Message</th>
</tr>
"
foreach($item in $systemObjs){
    $machine =$item.MachineName
    $index=$item.Index
    $timeGenerated = $item.TimeGenerated
    $entrytipe =$item.EntryType
    $Source=$item.Source
    $instanceid = $item.InstanceID
    $Ft = $item.FirstTime
    $Lt = $item.LastTime
    $Eventid = $item.EventID
    $frequency = $item.Frequency
    $mensaje = $item.Message
   $html+="<tr> <td> $machine</td> <td>$index</td> <td>$timeGenerated</td> <td> $entrytipe </td> <td>$Source</td> <td>$instanceid </td><td>$Ft</td> <td>$Lt</td> <td>$Eventid</td> <td>$frequency </td> <td>$mensaje</td> </tr>"
}

$html+="
</table>
<h2> Application Information </h2>
<table>
<tr>
<th>MachineName</th><th>Index</th><th>TimeGenerated</th><th>EntryType</th><th>Source</th><th>InstanceID</th><th>FirstTime</th><th>LastTime</th><th>EventID</th><th>Frequency</th><th>Message</th>
</tr>"

foreach($item in $AppObjs){
   $machine =$item.MachineName
    $index=$item.Index
    $timeGenerated = $item.TimeGenerated
    $entrytipe =$item.EntryType
    $Source=$item.Source
    $instanceid = $item.InstanceID
    $Ft = $item.FirstTime
    $Lt = $item.LastTime
    $Eventid = $item.EventID
    $frequency = $item.Frequency
    $mensaje = $item.Message
    $html+="<tr> <td> $machine</td> <td>$index</td> <td>$timeGenerated</td> <td> $entrytipe </td> <td>$Source</td> <td>$instanceid </td><td>$Ft</td> <td>$Lt</td> <td>$Eventid</td> <td>$frequency </td> <td>$mensaje</td> </tr>"
}

$html+="
</table>
<h2> Security Information </h2>"

if($SecObjs.Count -gt 0){

$html+="
<table>
<tr>
<th>MachineName</th><th>Index</th><th>TimeGenerated</th><th>EntryType</th><th>Source</th><th>InstanceID</th><th>FirstTime</th><th>LastTime</th><th>EventID</th><th>Frequency</th><th>Message</th>
</tr>"

foreach($item in $SecObjs){
    $machine =$item.MachineName
    $index=$item.Index
    $timeGenerated = $item.TimeGenerated
    $entrytipe =$item.EntryType
    $Source=$item.Source
    $instanceid = $item.InstanceID
    $Ft = $item.FirstTime
    $Lt = $item.LastTime
    $Eventid = $item.EventID
    $frequency = $item.Frequency
    $mensaje = $item.Message
    $html+="<tr> <td> $machine</td> <td>$index</td> <td>$timeGenerated</td> <td> $entrytipe </td> <td>$Source</td> <td>$instanceid </td><td>$Ft</td> <td>$Lt</td> <td>$Eventid</td> <td>$frequency </td> <td>$mensaje</td> </tr>"

}
$html+="</table>"

}
else{

$html+="<p> Security objects not selected in the query. If you want this information please re-run the script with the option '-AddSecurity' <br> Also remeber that you can also add the information information with the switch '-Addinformation'</p>"
}


$html+="
	<footer>
	<a href=""https://www.j0rt3g4.com"" target=""_blank"">
	2017 - J0rt3g4 Consulting Services </a> | - &#9400; All rigths reserved.
	</footer>
</body>
</html>"

    
    }
    END{
        $html | Out-File "$global:ScriptLocation\$fecha-$dia-$computername.html" 
    
    }
}
#Get warnings and info on each event viewer log.
function GetEventErrors{
<#
  .SYNOPSIS
    Get Warning and Errors from event viewer logs in local computer for the last 3 days (by default) it can be extended to any amount of days.
  .DESCRIPTION
  .EXAMPLE
  GetLogHTML ScriptPathVariable NDays
  .PARAMETERS 
  #>
  [CmdletBinding()]
   param
  (
    [Parameter(Mandatory=$true,  ValueFromPipeline=$True,position=0)] [String]$ScriptPath=".",
	[Parameter(Mandatory=$true,  ValueFromPipeline=$True,position=1)] [int]$Days=$global:DefaultNumberOfDays, #Day(s) behind for the checking of the logs (default 3) set in line 50
	[Parameter(Mandatory=$false, ValueFromPipeline=$True,position=2)] [String]$computer = ".",  #dot for localhost it can be changed to get any computer in the domain (server or client)
    [Parameter(Mandatory=$false, ValueFromPipeline=$True,position=3)] [Switch]$AddInfo=$false, #Add Information Events
    [Parameter(Mandatory=$false, ValueFromPipeline=$True,position=4)] [Switch]$AddSecu=$false  #add security Log
  )

  BEGIN{
	write-Verbose "Preparing script's Variables"
	#SimpleLogname
	$SystemLogName = "System" #other options are: security, application, forwarded events
	$AppLogname= "Application"
	$SecurityLogName= "Security"    
	#set html header in a variable CSS3
	#$header= "<style type=""text/css"">body,html{height:100%}a,abbr,acronym,address,applet,b,big,blockquote,body,caption,center,cite,code,dd,del,dfn,div,dl,dt,em,fieldset,font,form,html,i,iframe,img,ins,kbd,label,legend,li,object,ol,p,pre,q,s,samp,small,span,strike,strong,sub,sup,table,tbody,td,tfoot,th,thead,tr,tt,u,ul,var{margin:0;padding:0;border:0;outline:0;font-size:100%;vertical-align:baseline;background:0 0}body{line-height:1}ol,ul{list-style:none}blockquote,q{quotes:none}blockquote:after,blockquote:before,q:after,q:before{content:'';content:none}:focus{outline:0}del{text-decoration:line-through}table{border-spacing:0;margin: 50px 0px 50px 10px;}body{font-family:Arial,Helvetica,sans-serif;margin:0 15px;width:520px}a:link,a:visited{color:#666;font-weight:700;text-decoration:none}a:active,a:hover{color:#bd5a35;text-decoration:underline}table a:link{color:#666;font-weight:700;text-decoration:none}table a:visited{color:#999;font-weight:700;text-decoration:none}table a:active,table a:hover{color:#bd5a35;text-decoration:underline}table{font-family:Arial,Helvetica,sans-serif;color:#666;font-size:12px;text-shadow:1px 1px 0 #fff;background:#eaebec;border:1px solid #ccc;-moz-border-radius:3px;-webkit-border-radius:3px;border-radius:3px;-moz-box-shadow:0 1px 2px #d1d1d1;-webkit-box-shadow:0 1px 2px #d1d1d1;box-shadow:0 1px 2px #d1d1d1}table th{padding:21px 25px 22px;border-top:1px solid #fafafa;border-bottom:1px solid #e0e0e0;background:#ededed;background:-webkit-gradient(linear,left top,left bottom,from(#ededed),to(#ebebeb));background:-moz-linear-gradient(top,#ededed,#ebebeb)}table th:first-child{text-align:left;padding-left:20px}table tr:first-child th:first-child{-moz-border-radius-topleft:3px;-webkit-border-top-left-radius:3px;border-top-left-radius:3px}table tr:first-child th:last-child{-moz-border-radius-topright:3px;-webkit-border-top-right-radius:3px;border-top-right-radius:3px}table tr{text-align:center;padding-left:20px}table tr td:first-child{text-align:left;padding-left:20px;border-left:0}table tr td{padding:18px;border-top:1px solid #fff;border-bottom:1px solid #e0e0e0;border-left:1px solid #e0e0e0;background:#fafafa;background:-webkit-gradient(linear,left top,left bottom,from(#fbfbfb),to(#fafafa));background:-moz-linear-gradient(top,#fbfbfb,#fafafa)}table tr.even td{background:#f6f6f6;background:-webkit-gradient(linear,left top,left bottom,from(#f8f8f8),to(#f6f6f6));background:-moz-linear-gradient(top,#f8f8f8,#f6f6f6)}table tr:last-child td{border-bottom:0}table tr:last-child td:first-child{-moz-border-radius-bottomleft:3px;-webkit-border-bottom-left-radius:3px;border-bottom-left-radius:3px}table tr:last-child td:last-child{-moz-border-radius-bottomright:3px;-webkit-border-bottom-right-radius:3px;border-bottom-right-radius:3px}table tr:hover td{background:#f2f2f2;background:-webkit-gradient(linear,left top,left bottom,from(#f2f2f2),to(#f0f0f0));background:-moz-linear-gradient(top,#f2f2f2,#f0f0f0);div{font-size:20px;}}</style>";
	#$header= "<style type=""text/css"">{margin:0;padding:0}body{font:14px/1.4 Georgia,Serif}#page-wrap{margin:50px}p{margin:20px 0}table{width:100%;border-collapse:collapse}tr:nth-of-type(odd){background:#eee}th{background:#333;color:#fff;font-weight:700}td,th{padding:6px;border:1px solid #ccc;text-align:left}</style>";
	$header= "<style type=""text/css"">{margin:0;padding:0}@import url(https://fonts.googleapis.com/css?family=Indie+Flower|Josefin+Sans|Orbitron:500|Yrsa);body{font-family:14px/1.4 'Indie Flower','Josefin Sans',Orbitron,sans-serif;font-family:'Indie Flower',cursive;font-family:'Josefin Sans',sans-serif;font-family:Orbitron,sans-serif}#page-wrap{margin:50px}tr:nth-of-type(odd){background:#eee}th{background:#EF5525;color:#fff;font-family:Orbitron,sans-serif}td,th{padding:6px;border:1px solid #ccc;text-align:center;font-size:large}table{width:90%;border-collapse:collapse;margin-left:auto;margin-right:auto;font-family:Yrsa,serif}</style>";
  }
  PROCESS{
	#GET ALL ITEMS in Event Viewer with the selected options
	if(-not $AddSecu -and -not $AddInfo){
        Write-Log -Level Load -Message "Querying Logs in System and Application Logs without informational items (just Warnings and errors)"
        $system= Get-EventSubscriber -Days $Days -LogName "$SystemLogName" -computer $computerName 
        $appl= Get-EventSubscriber -Days $Days -LogName "$AppLogname" -computer $computerName
    }
    elseif($AddSecu -and -not $AddInfo){
        Write-Log -Level Load -Message "Querying Logs in System, Application and security Logs without informational items (just Warnings and errors)"
        $system= Get-EventSubscriber -Days $Days -LogName "$SystemLogName" -computer $computerName 
        $appl= Get-EventSubscriber -Days $Days -LogName "$AppLogname" -computer $computerName
        $security= Get-EventSubscriber -Days $Days -LogName "$SecurityLogName" -computer $computerName
    }
    elseif(-not $AddSecu -and $AddInfo){
        Write-Log -Level Load -Message "Querying Logs in System and Application Logs WITH informational items"
        $system= Get-EventSubscriber -Days $Days -LogName "$SystemLogName" -computer $computerName -IncludeInfo
        $appl= Get-EventSubscriber -Days $Days -LogName "$AppLogname" -computer $computerName -IncludeInfo
    }
    else{
        Write-Log -Level Load -Message "Querying Logs in System, Application and security Logs WITH informational items (just in system and application, security doesn't have informational items)"
        $system= Get-EventSubscriber -Days $Days -LogName "$SystemLogName" -computer $computerName -IncludeInfo
        $appl= Get-EventSubscriber -Days $Days -LogName "$AppLogname" -computer $computerName -IncludeInfo
        $security= Get-EventSubscriber -Days $Days -LogName "$SecurityLogName" -computer $computerName
    }

     if($AddSecu){
        ObjectsToHtml5 -Computer $computerName -systemObjs $system -AppObjs $appl -SecObj $security
     }
     else{
        ObjectsToHtml5 -Computer $computerName -systemObjs $system -AppObjs $appl
     }
  }
  END{
    write-verbose "Done Exporting"
  }
 }
function ShowTimeMS{
  [CmdletBinding()]
  param(
    [Parameter(ValueFromPipeline=$True,position=0,mandatory=$true)]	[datetime]$timeStart,
	[Parameter(ValueFromPipeline=$True,position=1,mandatory=$true)]	[datetime]$timeEnd
  )
  BEGIN {}
  PROCESS{
	write-Verbose "Stamping time"
	$diff=New-TimeSpan $TimeStart $TimeEnd
	Write-verbose "Timediff= $diff"
    
    if($diff.TotalMinutes -gt 60){
        #hours
        $hours = $diff.TotalHours
        Write-Log -Level Info -Message "End Script in $hours hour(s)"
    }
    elseif($diff.TotalSeconds -gt 60){
        #minutes
        $minutes = $diff.TotalMinutes
        Write-Log -Level Info -Message "End Script in $minutes minute(s)"
    }
    elseif($diff.TotalMilliseconds -gt 100){
        #seconds
        $seconds = $diff.TotalSeconds
        Write-Log -Level Info -Message "End Script in $seconds seconds"
    }
    else{
        #ms
        $miliseconds = $diff.TotalMilliseconds
        Write-Log -Level Info -Message "End Script in $miliseconds miliseconds"
    }
  }
  END{}
}
#get script directory
Write-Log -Level Info -Message "*******************************     Start Script     ******************************"


if($AddSecurity){
    Write-Log -Level Warn -Message "Using the ""AddSecurity"" switch will increase the time of execution of the script"
    $key = Read-Host "Are you sure you want to continue?(Y/N) "
    $CleanUpVar+="key"
    if($key -ne "Y" -or $key -ne "y"){
        $TimeEnd=Get-Date
		$CleanUpVar+="TimeEnd"
        #Write export total time into console
        $time=ShowTimeMS $TimeStart $TimeEnd 
        $CleanUpVar+="time"
        Write-Log -Level Info -Message "End Script in $time miliseconds"
        exit(0)
    }
}




#call the eventlog function and export the info to html (the 3 at the end is the number of days backwards where it will search, using 1 -> last 24 hours, 2 ->48 days, etc)

if($computer -eq "."){
    $computerName = $env:computername
}
else{
	$computerName = $computer
}

$CleanUpVar+="computerName"

if([string]::IsNullOrEmpty($ComputersFile) ){
    Write-Log -Level Execute -Message "Creating Html Files"
    
    if(-not $AddInformation -and -not $AddSecurity){
        GetEventErrors -ScriptPath $global:ScriptLocation -Days $Days -computer $computerName
    }
    elseif(-not $AddInformation -and $AddSecurity){
        GetEventErrors -ScriptPath $global:ScriptLocation -Days $Days -computer $computerName  -AddInfo:$false -AddSecu
    }
    elseif( $AddInformation -and -not $AddSecurity){
        GetEventErrors -ScriptPath $global:ScriptLocation -Days $Days -computer $computerName  -AddInfo
    }
    else{
        GetEventErrors -ScriptPath $global:ScriptLocation -Days $Days -computer $computerName  -AddInfo -AddSecu
    }
    
    if($SendEmail){
        $fecha=get-date -UFormat "%Y%m%d"
        $dia=get-date -UFormat "%A"
        $Subject="Report from $computer on $fecha" 
        $HtmlFileName ="$global:ScriptLocation\$fecha-$dia-$computerName.html" 

        $CleanUpVar+="fecha"
        $CleanUpVar+="dia"
        $CleanUpVar+="subject"
        $CleanUpVar+="HtmlFileName"
        Send-MailMessage -From $mailfrom -To $mailto -Subject  $Subject -Body "JCS $Subject" -Attachments "$HtmlFileName" -Priority High -dno onSuccess, onFailure -SmtpServer $SMTPServer
    }

}
else{
    $computers = Get-Content $ComputersFile

    foreach($computer in $computers){

    	if($computer -eq "."){
		    $computerName = $env:computername
	    }
	    else{
		    $computerName = $computer
	    }
	    

        Write-Log -Level Load -Message "Looking information for computer $computerName"

        if(-not $AddInformation -and -not $AddSecurity){
            GetEventErrors -ScriptPath $global:ScriptLocation -Days $Days -computer $computerName 
        }
        elseif(-not $AddInformation -and $AddSecurity){
            GetEventErrors -ScriptPath $global:ScriptLocation -Days $Days -computer $computerName -AddInfo:$false -AddSecu
        }
        elseif( $AddInformation -and -not $AddSecurity){
            GetEventErrors -ScriptPath $global:ScriptLocation -Days $Days -computer $computerName -AddInfo
        }
        else{
            GetEventErrors -ScriptPath $global:ScriptLocation -Days $Days -computer $computerName -AddInfo -AddSecu
        }
    }
    if($SendEmail){
        $fecha=get-date -UFormat "%Y%m%d"
        $dia=get-date -UFormat "%A"
        $Subject="Report from several computers on $fecha" 
        #Get all Html files inside that folder
        $files= [System.IO.Directory]::GetFiles("$global:ScriptLocation", "*.html", [System.IO.SearchOption]::AllDirectories);
        $todayFiles = files | where{ $_ -match $fecha}
        $CleanUpVar+="fecha"
        $CleanUpVar+="dia"
        $CleanUpVar+="subject"
       
        Send-MailMessage -From $mailfrom -To $mailto -Subject  $Subject -Body "JCS $Subject" -Attachments $todayFiles -Priority High -dno onSuccess, onFailure -SmtpServer $SMTPServer
     }
}


$TimeEnd=Get-Date
$time=ShowTimeMS $TimeStart $TimeEnd 
Write-Log -Level Info -Message "******************************    Finished Script     *****************************"
#get the info for finish
$CleanUpVar| ForEach-Object{
	Remove-Variable $_
}
$CleanUpGlobal | ForEach-Object{
	Remove-Variable -Scope global $_
}
Remove-Variable CleanUpGlobal,CleanUpVar
