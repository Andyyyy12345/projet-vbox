@echo off
set "PATH=%PATH%;C:\Program Files\Oracle\VirtualBox"
set NOM_VM=Debian1

:: 1. VÉRIFICATION ET SUPPRESSION PRÉALABLE (Script de l'étape 2)
VBoxManage showvminfo %NOM_VM% >nul 2>&1
if %ERRORLEVEL% == 0 (
    echo La machine %NOM_VM% existe deja. Suppression en cours...
    VBoxManage unregistervm %NOM_VM% --delete
)

:: 2. CRÉATION DE LA MACHINE (Script de l'étape 1)
echo Creation de la VM %NOM_VM%...
VBoxManage createvm --name %NOM_VM% --ostype Debian_64 --register
VBoxManage modifyvm %NOM_VM% --memory 4096 --nic1 nat
VBoxManage createmedium disk --filename "%NOM_VM%.vdi" --size 65536
VBoxManage storagectl %NOM_VM% --name "SATA" --add sata --controller IntelAhci
VBoxManage storageattach %NOM_VM% --storagectl "SATA" --port 0 --device 0 --type hdd --medium "%NOM_VM%.vdi"

echo Machine creee avec succes.