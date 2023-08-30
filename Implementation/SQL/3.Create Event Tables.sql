DECLARE @Message AS NVARCHAR(50) = ' Event Table successfully created'

CREATE TABLE [dbo].[ResourceConsumption] (
    [ID]                   UNIQUEIDENTIFIER CONSTRAINT [DEFAULT_ResourceConsumption_ID] DEFAULT (newsequentialid()) NOT NULL,
    [TimeStamp]            DATETIME         NULL,
    [DNSHostName]          NVARCHAR (50)    NULL,
    [CPU_Load_Percentage]  FLOAT (53)       NULL,
    [RAM_Usage_Percentage] FLOAT (53)       NULL,
    [Disk_Time_Percentage] FLOAT (53)       NULL,
    [Disk_Read_MBps]       FLOAT (53)       NULL,
    [Disk_Write_MBps]      FLOAT (53)       NULL,
    [NIC_Sent_Mbps]        FLOAT (53)       NULL,
    [NIC_Received_MBps]    FLOAT (53)       NULL,
    CONSTRAINT [PK_ResourceConsumption] PRIMARY KEY CLUSTERED ([ID] ASC)
);
PRINT CONCAT('ResourceConsumption', @Message)

CREATE TABLE [dbo].[PowerAndTemperature] (
    [ID]                       UNIQUEIDENTIFIER CONSTRAINT [DEFAULT_PowerAndTemperature_ID] DEFAULT (newsequentialid()) NOT NULL,
    [TimeStamp]                DATETIME         NULL,
    [DNSHostName]              NVARCHAR (50)    NULL,
    [CPU_Temperature_Current]  FLOAT (53)       NULL,
    [CPU_Temperature_Min]      FLOAT (53)       NULL,
    [CPU_Temperature_Max]      FLOAT (53)       NULL,
    [PowerConsumption_Current] FLOAT (53)       NULL,
    [PowerConsumption_Min]     FLOAT (53)       NULL,
    [PowerConsumption_Max]     FLOAT (53)       NULL,
    [GPU_Temperature_Current]  FLOAT (53)       NULL,
    [GPU_Temperature_Min]      FLOAT (53)       NULL,
    [GPU_Temperature_Max]      FLOAT (53)       NULL,
    CONSTRAINT [PK_PowerAndTemperature] PRIMARY KEY CLUSTERED ([ID] ASC)
);
PRINT CONCAT('PowerAndTemperature', @Message)