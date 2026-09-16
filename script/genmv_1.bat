@echo off
set "PATH=%PATH%;C:\Program Files\Oracle\VirtualBox"
set NOM_VM=Debian1

echo Creation de la VM %NOM_VM%...
VBoxManage createvm --name %NOM_VM% --ostype Debian_64 --register

VBoxManage modifyvm %NOM_VM% --memory 4096 --nic1 nat

:: On spécifie le nom du fichier VDI (VirtualBox le stockera dans le dossier de la VM)
VBoxManage createmedium disk --filename "%NOM_VM%.vdi" --size 65536

VBoxManage storagectl %NOM_VM% --name "SATA" --add sata --controller IntelAhci
VBoxManage storageattach %NOM_VM% --storagectl "SATA" --port 0 --device 0 --type hdd --medium "%NOM_VM%.vdi"

echo Machine creee avec succes dans le dossier VirtualBox par defaut.
pause

echo Suppression de la VM %NOM_VM%...
VBoxManage unregistervm %NOM_VM% --delete
echo Machine supprimee.