# SQLPowershellDashboard
The objective of this application is to create a dashboard to display live monitoring data from a SQL Server instance, record history of that data, and alert the user when the metrics breach a predefined threshold.
# Prerequisites
1. Install the sqlps and PSSlack modules in PowerShell
2. Create a database on the SQL Server you would like to monitor 
3. Run the CreateTables.sql file to create the tables and add the base statistics
5. Run the GatherMetrics.sql file to create the main stored procedure
6. Create a user with the following privledges: grant view server state, database owner on new database, execute GatherMetrics
7. Set up a Slack workspace and two channels (dba and sysadmin)
8. Retrieve the app access token from slack and insert it into the DataDashboard.ps1 file
# Running
To start the application, run the DataDashboard.ps1 file using PowerShell. This will pop up a PowerShell window and begin showing the live data. It will also display the last time that the specific metric was in violation of its predefined threshold. Upon breaching the threshold, a message will be sent to Slack (in the appropriate channel), and the text will change to red. 
# Possible Improvements
1. User interface could be improved to not use command line output
2. Use more stored procedures instead of ad-hoc querying through PowerShell
3. Graphically display the history data to find 
4. Supress the noise on slack once the error has cleared
5. More robust history display (data is there, visualization is not)
