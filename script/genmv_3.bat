@echo off
set "PATH=%PATH%;C:\Program Files\Oracle\VirtualBox"

:: Variable concernant la RAM et le DD
set RAM=4096
set DISK=65536

:: Vérification qu'au moins un argument a été fourni
if "%1"=="" goto usage

set ACTION=%1
set NOM_VM=%2

:: Les options posibles à faire
if "%ACTION%"=="L" goto lister
if "%NOM_VM%"=="" goto erreur_nom
if "%ACTION%"=="N" goto nouveau
if "%ACTION%"=="S" goto supprimer
if "%ACTION%"=="D" goto demarrer
if "%ACTION%"=="A" goto arreter

goto usage

:lister
echo Liste des machines enregistrees dans VirtualBox :
VBoxManage list vms
goto :eof

:nouveau
:: Vérification issue de l'Etape 2 : existence préalable de la VM
VBoxManage showvminfo %NOM_VM% >nul 2>&1
if %ERRORLEVEL% == 0 (
    echo Echec de la creation : La VM %NOM_VM% existe deja.
    exit /B 1
)
echo Creation de la VM %NOM_VM%...
VBoxManage createvm --name %NOM_VM% --ostype Debian_64 --register
VBoxManage modifyvm %NOM_VM% --memory %RAM% --nic1 nat
VBoxManage createmedium disk --filename "%NOM_VM%.vdi" --size %DISK%
VBoxManage storagectl %NOM_VM% --name "SATA" --add sata --controller IntelAhci
VBoxManage storageattach %NOM_VM% --storagectl "SATA" --port 0 --device 0 --type hdd --medium "%NOM_VM%.vdi"
echo VM %NOM_VM% creee avec succes.
goto :eof

:supprimer
echo Suppression de la VM %NOM_VM%...
VBoxManage unregistervm %NOM_VM% --delete
if ERRORLEVEL 1 (
    echo Echec de la suppression de la VM %NOM_VM%.
    exit /B 1
)
goto :eof

:demarrer
echo Demarrage de la VM %NOM_VM%...
VBoxManage startvm %NOM_VM%
if ERRORLEVEL 1 (
    echo Echec du demarrage de la VM %NOM_VM%.
    exit /B 2
)
goto :eof

:arreter
echo Arret de la VM %NOM_VM%...
VBoxManage controlvm %NOM_VM% poweroff
goto :eof

:erreur_nom
echo Erreur : Il faut un nom pour pouvoir creer une VM.
goto :eof

:usage
echo Utilisation : %0 [L|N|S|D|A] [nom_machine]
goto :eof