netsh advfirewall firewall set rule group="Network Discovery" new enable=Yes
netsh advfirewall firewall set rule group="File and Printer Sharing" new enable=yes
Enable-PSRemoting -Force -SkipNetworkProfileCheck -ErrorAction Stop
set-item wsman:\localhost\client\trustedhosts -Concatenate -value 'Server-Automation.Horna.local'
netsh advfirewall firewall add rule name="Allow ICMPv4" protocol=icmpv4:8,any dir=in action=allow