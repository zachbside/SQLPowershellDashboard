USE [test]
GO

/****** Object:  StoredProcedure [dbo].[GatherMetrics]    Script Date: 7/29/2019 12:19:45 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



-- ============================================= 
-- Author:    Zach Burnside 
-- Create date: 7/25/2019 
-- Description:  Stored procedure used to gather metrics on the local SQL server 
-- ============================================= 
CREATE PROCEDURE [dbo].[GatherMetrics] 
AS 
  BEGIN 
      SET nocount ON; 
	  
      DECLARE @CurrentMemory float 
	  DECLARE @MaxMemory float
      DECLARE @BatchesPerSec INT 
      DECLARE @AVG INT 
      DECLARE @ViolationBit BIT = 0 
      --Get the current memory as a percentage. current memory / max server memory allocated
      SET @CurrentMemory=(SELECT ( physical_memory_in_use_kb / 1024 ) AS 
                                 Memory_GB 
                          FROM   sys.dm_os_process_memory) 
      SET @MaxMemory = convert(float,(SELECT value
					   FROM sys.configurations  
                       WHERE [name] = 'max server memory (MB)'))
      SET @CurrentMemory = (@CurrentMemory/@MaxMemory)*100

      --if memory used is above 85% send an alert 
      IF @CurrentMemory > 85 
		BEGIN
        SET @ViolationBit=1 
		END
      
      --insert the date, metric name(Memory), metric value(Memory % used), and the violation bit 
      INSERT INTO  test.dbo.CurrentMetric 
      VALUES      ( 2, 
                    @CurrentMemory, 
                    @ViolationBit ) 

      --check the number of batches per second 
      SET @BatchesPerSec = (SELECT cntr_value 
                            FROM   sys.dm_os_performance_counters 
                            WHERE  counter_name LIKE 'Batch Requests/sec%') 
							
      --reset violation bit 
      SET @ViolationBit = 0 

      --check if the number of batches per second is higher than 8000 
      IF @BatchesPerSec > 8000
        SET @ViolationBit=1 

      --insert the date, metric name(batches per second), metric value(batches per second), and the violation bit
      INSERT INTO  test.dbo.CurrentMetric 
      VALUES      ( 3, 
                    @BatchesPerSec, 
                    @ViolationBit )

	  insert into dbo.Metrics_Repo 
		select MetricID, Value, getdate() from test.dbo.CurrentMetric
    
	  
  END 

GO


