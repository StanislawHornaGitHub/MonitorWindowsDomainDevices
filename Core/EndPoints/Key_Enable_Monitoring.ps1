netsh advfirewall firewall set rule group="Network Discovery" new enable=Yes
netsh advfirewall firewall set rule group="File and Printer Sharing" new enable=yes
Enable-PSRemoting -Force -SkipNetworkProfileCheck -ErrorAction Stop
