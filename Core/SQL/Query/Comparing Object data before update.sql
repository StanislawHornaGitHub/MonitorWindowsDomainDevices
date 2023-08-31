SELECT TOP(0) *
INTO #Temp_DNSHostName FROM OperatingSystem

INSERT INTO #Temp_DNSHostName (DNSHostName, CurrentlyLoggedOn, Error, isLicenseActivated, LastUpdate, OS_Architecture, OS_build, OS_Display_Version, OS_Version)     
VALUES ('Lian6700.Horna.local', 'HORNA\wojtek', '', 'True', '2023-08-30 13:34', '64-bit', '10.0.23531.1001', '22H2', 'Microsoft Windows 11 Pro Insider Preview')

SELECT COUNT(*) 
FROM (SELECT 
DNSHostName,
CurrentlyLoggedOn,
OS_Version,
OS_Display_Version,
OS_build,
OS_Architecture,
isLicenseActivated,
LastUpdate
FROM #Temp_DNSHostName

UNION

SELECT 
DNSHostName,
CurrentlyLoggedOn,
OS_Version,
OS_Display_Version,
OS_build,
OS_Architecture,
isLicenseActivated,
LastUpdate
FROM OperatingSystem
WHERE DNSHostName = 'Lian6700.Horna.local') a


DROP TABLE #Temp_DNSHostName
