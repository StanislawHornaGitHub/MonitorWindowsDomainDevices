DECLARE @Message AS NVARCHAR(50) = ' Object Table successfully created'

CREATE TABLE [dbo].[Inventory] (
    [DNSHostName]               NVARCHAR (50)  NOT NULL,
    [IPaddress]                 NVARCHAR (50)  NULL,
    [isActiveWinRM]             BIT            NOT NULL,
    [isActiveTCP]               BIT            NOT NULL,
    [isActive]                  BIT            NOT NULL,
    [LastUpdate]                DATETIME2 (7)  NULL,
    [LastSeen]                  DATETIME2 (7)  NULL,
    [IsHardwareMonitorDeployed] BIT            NULL,
    [Error]                     NVARCHAR (MAX) NULL,
    CONSTRAINT [PK_Inventory] PRIMARY KEY CLUSTERED ([DNSHostName] ASC)
);
PRINT CONCAT('Inventory', @Message)

CREATE TABLE [dbo].[Hardware] (
    [DNSHostName]               NVARCHAR (50)  NOT NULL,
    [LastUpdate]                DATETIME2 (7)  NULL,
    [DeviceManufacturer]        NVARCHAR (50)  NULL,
    [DeviceModel]               NVARCHAR (50)  NULL,
    [NumberOfCPUs]              TINYINT        NULL,
    [CPUmodel]                  NVARCHAR (100) NULL,
    [NumberOfCores]             TINYINT        NULL,
    [NumberOfLogicalProcessors] TINYINT        NULL,
    [NumberOfRAMBanks]          TINYINT        NULL,
    [RAMCapacity_GB]            TINYINT        NULL,
    [RAMSpeed_MHz]              NVARCHAR (50)  NULL,
    [RAMmanufacturer]           NVARCHAR (50)  NULL,
    [GPU_Model]                 NVARCHAR (100) NULL,
    [DiskName]                  NVARCHAR (100) NULL,
    [StorageCapacity_GB]        SMALLINT       NULL,
    CONSTRAINT [PK_DeviceHardwareDetails] PRIMARY KEY CLUSTERED ([DNSHostName] ASC)
);
PRINT CONCAT('Hardware', @Message)

CREATE TABLE [dbo].[OperatingSystem] (
    [DNSHostName]        NVARCHAR (50) NOT NULL,
    [CurrentlyLoggedOn]  NVARCHAR (50) NULL,
    [LastUpdate]         DATETIME2 (7) NULL,
    [OS_Version]         NVARCHAR (50) NULL,
    [OS_Display_Version] NVARCHAR (50) NULL,
    [OS_build]           NVARCHAR (50) NULL,
    [OS_Architecture]    NVARCHAR (50) NULL,
    [isLicenseActivated] NVARCHAR (50) NULL,
    [Error]              NVARCHAR (1)  NULL,
    [FastStartEnabled]   BIT           NULL,
    [LastBootTime]       DATETIME2 (7) NULL,
    [LastBootType]       NVARCHAR (50) NULL,
    CONSTRAINT [PK_OperatingSystem] PRIMARY KEY CLUSTERED ([DNSHostName] ASC)
);
PRINT CONCAT('OperatingSystem', @Message)

CREATE TABLE [dbo].[Storage] (
    [DNSHostName]             NVARCHAR (50)  NOT NULL,
    [LastUpdate]              DATETIME2 (7)  NULL,
    [SystemDriveCapacity_GB]  FLOAT (53)     NULL,
    [SystemDriveFreeSpace_GB] FLOAT (53)     NULL,
    [SystemDriveUsed]         NVARCHAR (50)  NULL,
    [AllDriveCapacity_GB]     FLOAT (53)     NULL,
    [AllDriveFreeSpace_GB]    FLOAT (53)     NULL,
    [AllDriveUsed]            NVARCHAR (50)  NULL,
    [OtherDrivesDetails]      NVARCHAR (100) NULL,
    CONSTRAINT [PK_VolumeSpace] PRIMARY KEY CLUSTERED ([DNSHostName] ASC)
);
PRINT CONCAT('Storage', @Message)

CREATE TABLE [dbo].[Packages] (
    [DisplayName]          NVARCHAR (100) NULL,
    [Publisher]            NVARCHAR (100) NULL,
    [DisplayVersion]       NVARCHAR (100) NULL,
    [InstallDate]          DATETIME2 (7)  NULL,
    [InstallLocation]      NVARCHAR (250) NULL,
    [QuietUninstallString] NVARCHAR (250) NULL,
    [DNSHostName]          NVARCHAR (50)  NULL,
    [EstimatedSize_GB]     FLOAT (53)     NULL,
    [LastUpdate]           DATETIME       NULL,
    [Row_ID]               NVARCHAR (500) NOT NULL,
    CONSTRAINT [PK_Packages] PRIMARY KEY CLUSTERED ([Row_ID] ASC)
);
PRINT CONCAT('Packages', @Message)
