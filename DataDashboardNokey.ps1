function messageSlack ($channel,$metric,$value) {
    $percentOrValue = '%'
    if ($metric -eq 'UserConnections')
        {$percentOrValue = ''}
    $token='x8'
    Send-SlackMessage -Token $token -Channel "$channel" -Text "The $metric is over the threshold. It is currently at $value$percentOrValue. Please resolve."
}

function loadCPUData ($dbname, $serverName, $instanceName, $user, $password) {
    $CpuLoad = (Get-WmiObject win32_processor | Measure-Object -property LoadPercentage -Average | Select Average ).Average
    $violationBit=0
    $Threshold = Invoke-Sqlcmd -Query "select Threshold from $dbname.dbo.Metrics where MetricID = 1" -ServerInstance "$serverName\$instanceName" -Username $user -Password $password
    if ($CpuLoad -gt $Threshold[0]) {$violationBit=1}
    Invoke-Sqlcmd -Query "insert into $dbname.dbo.CurrentMetric values (1,$CpuLoad,$violationBit)" -ServerInstance "$serverName\$instanceName" -Username $user -Password $password
}

function gatherDisplayData ($metricID, $dbname, $serverName, $instanceName, $userName, $password) {
    $Results = Invoke-Sqlcmd -Query "select CM.Value, CM.ViolationBit,  M.MetricName, C.ContactName 
                                     from $dbname.dbo.CurrentMetric CM 
                                     inner join $dbname.dbo.Metrics M on M.MetricID=CM.MetricId 
                                     inner join $dbname.dbo.Contacts C on M.ContactID=C.ContactID 
                                     where CM.MetricID=$metricID"  -ServerInstance "$serverName\$instanceName" -Username $userName -Password $password 
    $Metric = $Results[2]
    $Value = $Results[0]
    #if the violation detection bit is set to true, message the sysadmin channel on slack
    if ($Results[1] -eq 1) {
        messageSlack -channel $Results[3] -metric $Results[2] -value $Results[0] > $null
        $ErrorDate = Invoke-Sqlcmd -Query "select Date from $dbname.dbo.Violations where MetricID=$metricID" -ServerInstance "$serverName\$instanceName" -Username $user -Password $password
        $ErrorDate=$ErrorDate[0]
        Write-Host -ForegroundColor Red "- $Metric - Currently in violation beginning at $ErrorDate"
        echo "$Value`n"
        }
    else {
        echo "- $Metric -"
        echo "$Value`n"
    }
}

function gatherLatestViolation ($metricID, $dbname, $serverName, $instanceName, $userName, $password) {
    $Results = Invoke-Sqlcmd -Query "select TOP 1 MR.Date, M.MetricName 
                                    from $dbname.dbo.Metrics_Repo MR
                                    inner join $dbname.dbo.Metrics M on M.MetricID = MR.MetricID
                                    where MR.MetricID=$metricID 
                                    and value > M.Threshold 
                                    order by MR.Date desc" -ServerInstance "$serverName\$instanceName" -Username $userName -Password $password
    if ($Results) {
    $DateOfViolation = $Results[0]
    echo "Last violation occured on $DateOfViolation"
    }
}

function displayData ($dbname, $serverName, $instanceName, $user, $password) {
    #run stored procedure that gathers all of the statistics for memory and batches
    Invoke-Sqlcmd -Query "exec $dbname.[dbo].[GatherMetrics]" -ServerInstance "$serverName\$instanceName" -Username $user -Password $password
    #clear the shell to make the dashboard appear to refresh instantly
    clear
    $numOfMetrics = Invoke-Sqlcmd -Query "select count(*) from $dbname.dbo.CurrentMetric" -ServerInstance "$serverName\$instanceName" -Username $user -Password $password
    $numOfMetricsCounter = [int]$numOfMetrics[0]
    while ($numOfMetricsCounter -gt 0)
        { 
            gatherDisplayData $numOfMetricsCounter $dbname $serverName $instanceName -userName $user $password
            gatherLatestViolation $numOfMetricsCounter $dbname $serverName $instanceName -userName $user $password
            echo "-------------------------"
            $numOfMetricsCounter-- 
        }
    
    #truncate the current data table to make room for the next batch of data
    Invoke-Sqlcmd -Query "truncate table $dbname.dbo.CurrentMetric" -ServerInstance "$serverName\$instanceName" -Username $user -Password $password
}



#prompt the user for information about the database they are connecting to and querying
$dbInput = Read-Host -Prompt "Database Name: "
$serverInput = Read-Host -Prompt "Server Name: "
$instanceInput = Read-Host -Prompt "Instance Name: "
$userInput = Read-Host -Prompt "Username: "

#hide the password from the console
$passwordInput = Read-Host -Prompt "Password: " -asSecureString         
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($passwordInput)            
$passwordPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

#continue to run the command, refreshing the data and alerting the user, sleeping for 10 seconds, and then refreshing
while (1 -eq 1) {
    loadCPUData -dbname $dbInput -servername $serverInput -instanceName $instanceInput -user $userInput -password $passwordPlain
    displayData -dbname $dbInput -servername $serverInput -instanceName $instanceInput -user $userInput -password $passwordPlain
    Start-Sleep -Seconds 5
    }
