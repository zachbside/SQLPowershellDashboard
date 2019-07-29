
create table Contacts (
	ContactID int NOT NULL Primary Key,
	ContactName varchar(50)
	)

create table Metrics (
	MetricID int NOT NULL Primary Key,
	MetricName varchar(50) NOT NULL,
	ContactID int NOT NULL
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
	[VALUE] int NOT NULL
	ViolationBit bit NOT NULL
	FOREIGN KEY (MetricID) REFERENCES Metrics(MetricID)
	)
