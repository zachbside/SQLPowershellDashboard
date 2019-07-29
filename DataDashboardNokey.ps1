function messageSlack ($channel,$metric,$value) {
    $percentOrValue = '%'
    if ($metric -eq 'BatchesPerSec')
        {$percentOrValue = ''}
    $token=''
    Send-SlackMessage -Token $token -Channel "$channel" -Text "The $metric is over the threshold. It is currently at $value$percentOrValue. Please resolve."
}

function loadCPUData ($dbname, $serverName, $instanceName, $user, $password) {
    $CpuLoad = (Get-WmiObject win32_processor | Measure-Object -property LoadPercentage -Average | Select Average ).Average
    $violationBit=0
    if ($CpuLoad -gt 50) {$violationBit=1}
    Invoke-Sqlcmd -Query "insert into $dbname.dbo.CurrentMetric values (1,$CpuLoad,$violationBit)" -ServerInstance "$serverName\$instanceName" -Username $user -Password $password
}

function gatherDisplayData ($metricID, $serverName, $instanceName, $userName, $password) {
    $Results = Invoke-Sqlcmd -Query "select CM.Value, CM.ViolationBit,  M.MetricName, C.ContactName from dbo.CurrentMetric CM inner join Metrics M on M.MetricID=CM.MetricId inner join Contacts C on M.ContactID=C.ContactID where CM.MetricID=$metricID"  -ServerInstance "$serverName\$instanceName" -Username $userName -Password $password 
    $Metric = $Results[2]
    $Value = $Results[0]
    echo "-$Metric-"
    echo "$Value/n"
    #if the violation detection bit is set to true, message the sysadmin channel on slack
    if ($Results[1] -eq 1) {
        messageSlack -channel $Results[3] -metric $Results[2] -value $Results[0] > $null
        }
}

function displayData ($dbname, $serverName, $instanceName, $user, $password) {
    #run stored procedure that gathers all of the statistics for memory and batches
    Invoke-Sqlcmd -Query "exec $dbname.[dbo].[GatherMetrics]" -ServerInstance "$serverName\$instanceName" -Username $user -Password $password
    #clear the shell to make the dashboard appear to refresh instantly
    #clear
    $numOfMetrics = Invoke-Sqlcmd -Query "select count(*) from dbo.CurrentMetric" -ServerInstance "$serverName\$instanceName" -Username $user -Password $password
    $numOfMetricsCounter = [int]$numOfMetrics[0]
    while ($numOfMetricsCounter -gt 0)
        { 
            gatherDisplayData $numOfMetricsCounter $serverName $instanceName -userName $user $password
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