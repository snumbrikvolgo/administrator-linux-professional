$ErrorActionPreference = "Stop"

$VBoxManage = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
$VmName = "task-20-pxeclient"
$VmDir = Join-Path $env:USERPROFILE "VirtualBox VMs\$VmName"
$DiskPath = Join-Path $VmDir "$VmName.vdi"

if (-not (Test-Path $VBoxManage)) {
    throw "VBoxManage.exe not found at $VBoxManage"
}

$existing = & $VBoxManage list vms | Select-String -SimpleMatch "`"$VmName`""
if ($existing) {
    $ErrorActionPreference = "Continue"
    & $VBoxManage controlvm $VmName poweroff 2>$null | Out-Null
    $ErrorActionPreference = "Stop"
    & $VBoxManage unregistervm $VmName --delete | Out-Null
}

& $VBoxManage createvm --name $VmName --ostype Debian_64 --register | Out-Null
New-Item -ItemType Directory -Force -Path $VmDir | Out-Null
& $VBoxManage createmedium disk --filename $DiskPath --size 20480 --format VDI | Out-Null
& $VBoxManage storagectl $VmName --name "SATA" --add sata --controller IntelAhci --bootable on | Out-Null
& $VBoxManage storageattach $VmName --storagectl "SATA" --port 0 --device 0 --type hdd --medium $DiskPath | Out-Null
& $VBoxManage modifyvm $VmName `
    --firmware efi `
    --memory 4096 `
    --cpus 2 `
    --boot1 net `
    --boot2 disk `
    --boot3 none `
    --boot4 none `
    --nic1 intnet `
    --intnet1 pxenet `
    --nictype1 virtio `
    --cableconnected1 on `
    --nicbootprio1 1 `
    --nic2 nat `
    --nictype2 virtio `
    --cableconnected2 on `
    --graphicscontroller vmsvga `
    --vram 32

& $VBoxManage setextradata $VmName VBoxInternal2/EfiBootArgs " "
& $VBoxManage showvminfo $VmName --machinereadable |
    Select-String -Pattern "firmware|boot|nic1|nic2|intnet|cableconnected|nicbootprio"

Write-Host ""
Write-Host "PXE client VM created with a blank 20G disk. Start it with:"
Write-Host "  & '$VBoxManage' startvm $VmName --type gui"
