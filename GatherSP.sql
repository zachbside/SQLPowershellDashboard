/****** Object:  StoredProcedure [dbo].[GatherMetrics]    Script Date: 7/30/2019 12:12:58 PM ******/ 
SET ansi_nulls ON 

go 

SET quoted_identifier ON 

go 

-- =============================================       
-- Author:    Zach Burnside       
-- Create date: 7/25/2019       
-- Description:  Stored procedure used to gather metrics on the local SQL server       
-- =============================================       
ALTER PROCEDURE [dbo].[Gathermetrics] 
AS 
  BEGIN 
      SET nocount ON; 

      DECLARE @CurrentMemory FLOAT 
      DECLARE @MaxMemory FLOAT 
      DECLARE @UserConnections INT 
      DECLARE @ViolationBit BIT = 0 
      DECLARE @Threshold INT 
      DECLARE @NumOfMetrics INT 
      DECLARE @ValueOfMetric INT 

      --Get the current memory as a percentage. current memory / max server memory allocated    
      SET @CurrentMemory=(SELECT ( physical_memory_in_use_kb / 1024 ) AS 
                                 Memory_GB 
                          FROM   sys.dm_os_process_memory) 
      SET @MaxMemory = CONVERT(FLOAT, (SELECT value 
                                       FROM   sys.configurations 
                                       WHERE  [name] = 'max server memory (MB)') 
                       ) 
      SET @CurrentMemory = ( @CurrentMemory / @MaxMemory ) * 100 
      --set variable to the threshold that is written in the metrics table   
      SET @Threshold = (SELECT threshold 
                        FROM   dbo.metrics 
                        WHERE  metricname = 'Memory') 

      --if in violation of of the threshold, set violation bit to 1   
      IF @CurrentMemory > @Threshold 
        BEGIN 
            SET @ViolationBit=1 
        END 

      --insert the metricID, metric value(Memory % used), and the violation bit into the CurrentMetric table   
      INSERT INTO test.dbo.currentmetric 
      VALUES      ( 2, 
                    @CurrentMemory, 
                    @ViolationBit ) 

      --check the number of users connected       
      SET @UserConnections = (SELECT Count(*) 
                              FROM   sys.dm_exec_sessions 
                              WHERE  is_user_process = 1) 
      --reset violation bit       
      SET @ViolationBit = 0 
      --check if the number of user connections is over the threshold      
      SET @Threshold = (SELECT threshold 
                        FROM   dbo.metrics 
                        WHERE  metricname = 'UserConnections') 

      --if this value is above the threshold, set the violation bit   
      IF @UserConnections > @Threshold 
        SET @ViolationBit=1 

      --insert the metric name(connections), metric value(number of connections), and the violation bit into the CurrentMetric table
      INSERT INTO test.dbo.currentmetric 
      VALUES      ( 3, 
                    @UserConnections, 
                    @ViolationBit ) 

      --Log the values from CurrentMetric into the Metric_Repo history table   
      INSERT INTO dbo.metrics_repo 
      SELECT metricid, 
             value, 
             Getdate() 
      FROM   dbo.currentmetric 

      --Determine the number of metrics that need to be accounted for   
      SET @NumOfMetrics = (SELECT Count(*) 
                           FROM   dbo.currentmetric) 

      --loop through the metrics, checking for violations in CurrentMetric   
      WHILE ( @NumOfMetrics > 0 ) 
        BEGIN 
            SET @ValueOfMetric = (SELECT value 
                                  FROM   currentmetric 
                                  WHERE  metricid = @NumOfMetrics) 

            --check if the violation bit is true per metric  
            IF ( (SELECT violationbit 
                  FROM   currentmetric 
                  WHERE  metricid = @NumOfMetrics) = 1 ) 
              BEGIN 
                  --check if the metric is in the violation table 
                  IF NOT EXISTS (SELECT * 
                                 FROM   violations 
                                 WHERE  metricid = @NumOfMetrics) 
                    BEGIN 
                        --insert the violation information into the Violations table  
                        INSERT INTO dbo.violations 
                        VALUES      (@NumOfMetrics, 
                                     @ValueOfMetric, 
                                     Getdate()) 

                        RETURN 
                    END 
              END 
            ELSE 
              --if metric is not violating (or never was) remove it from the violations table   
              DELETE FROM violations 
              WHERE  metricid = @NumOfMetrics 

            --increment counter  
            SET @NumOfMetrics = @NumOfMetrics - 1 
        END 
  END 
