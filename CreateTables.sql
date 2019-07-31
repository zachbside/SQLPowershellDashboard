create table Contacts (
	ContactID int NOT NULL Primary Key,
	ContactName varchar(50)
)

create table Metrics (
	MetricID int NOT NULL Primary Key,
	MetricName varchar(50) NOT NULL,
	ContactID int NOT NULL,
	Threshold int NOT NULL
	FOREIGN KEY (ContactID) REFERENCES Contacts(ContactID)
)

create table Metrics_Repo (
	MetricID int NOT NULL,
	Value int NOT NULL,
	Date datetime NOT NULL
	FOREIGN KEY (MetricID) REFERENCES Metrics(MetricID)
)

CREATE TABLE [dbo].[Violations](
	[MetricID] int NOT NULL PRIMARY KEY,
	[Value] [int] NOT NULL,
	[Date] [datetime] NOT NULL
	FOREIGN KEY (MetricID) REFERENCES Metrics(MetricID)
)

CREATE TABLE dbo.CurrentMetric (
	[MetricID] int NOT NULL PRIMARY KEY,
	[VALUE] int NOT NULL,
	ViolationBit bit NOT NULL
	FOREIGN KEY (MetricID) REFERENCES Metrics(MetricID)
)
  --insert base contacts
  insert into contacts values (1, 'dba')
  insert into contacts values (2, 'sysadmin')
  
  --insert base metrics
  insert into metrics values (1,'CPU',2, 50)
  insert into metrics values (2,'Memory',1, 85)
  insert into metrics values (3,'UserConnections',1,15)
  
use [master]
  --allow user to view the dmvs
  grant view server state to tester
