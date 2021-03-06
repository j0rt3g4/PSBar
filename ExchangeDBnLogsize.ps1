<#
    Created by : Jose Ortega (jortega928@yahoo.com/j0rt3g4@j0rt3g4.com)
    Version 1: 03/18/2015
    Version 2: 08/23/2017 Added Decimals as parameter. Transformed into Advanced Functions and Parameters use
    https://www.j0rt3g4.com
#>

[Cmdletbinding()]
param(
    [Parameter(Position=0,Mandatory=$false,valuefrompipeline=$true)]$Decimals=5,
    [Parameter(Position=0,Mandatory=$false,valuefrompipeline=$true)][switch]$ft
)
function Get-ExchangeDBPath{
    [Cmdletbinding()]
    param()
    BEGIN{}
    PROCESS{
        $AllDbsPath=@()
        Get-MailboxDatabase | SELECT name,EdbFilePath,logfolderpath,LogFileSize | foreach-object{ 
            $prop =@{ 
                LogPath= $_.LogFolderPath  
                Name= $_.Name 
                EdbPath = $_.EdbFilePath
                EdbSizeGB =$null
                LogSizeGB =$null
                LogFileSize= $_.LogFileSize
            }
        $path = new-Object PSOBject  -property $prop;      
        $AllDbsPath+=$path
        }
    }
    END{
        return $AllDbsPath;
    }
}
function ExchangeDBnLogSize{
    [Cmdletbinding()]
    param(
        [Parameter(Position=0,Mandatory=$false,valuefrompipeline=$true)][switch]$ft
    )
    BEGIN{
        $getPaths = Get-ExchangeDBPath
    }
    PROCESS{
        foreach ($obj in $getPaths){
            $EdbFile= $obj.EdbPath
            $size =  [math]::Round( (Get-Item "$EdbFile").length/ 1Gb, $Decimals)  #Gbs
            $obj.EdbSizeGB=$size;
            $LogFiles = $obj.LogPath
            
            $SumItems = Get-ChildItem "$LogFiles" -recurse | Measure-Object -property length -sum
            $obj.LogSizeGB = [math]::Round($SumItems.sum/1GB,$decimals)
        }
    }
    END{
        if($ft){
            $getPaths | Select  Name,EdbSizeGB,LogSizeGB,LogPath,EdbPath | ft
        }
        else{
            $getPaths | Select  Name,EdbSizeGB,LogSizeGB,LogPath,EdbPath
        }
    }
}

#Start Script
Write-Output "Checking if the Exchange PS Snap in is present"
if ( (Get-PSSnapin -Name Microsoft.Exchange.Management.PowerShell.E2010 -ErrorAction SilentlyContinue) -eq $null ){
	Write-Output -Level Load "Loading Exchange PS Snap in"
    Add-PSSnapin Microsoft.Exchange.Management.PowerShell.E2010
}
else{
    Write-Output "Exchange PS Snapin is already loaded" 
}


ExchangeDBnLogSize $ft