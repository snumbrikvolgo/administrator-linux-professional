$ErrorActionPreference = "Stop"

$VBoxManage = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
$VmName = "task-20-pxeclient"

& $VBoxManage startvm $VmName --type gui
