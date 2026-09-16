@echo off
set "PATH=%PATH%;C:\Program Files\Oracle\VirtualBox"

:: Variables d'en-tête
set RAM=4096
set DISK=65536

if "%1"=="" goto usage

set ACTION=%1
set NOM_VM=%2

if "%ACTION%"=="L" goto lister
if "%NOM_VM%"=="" goto erreur_nom
if "%ACTION%"=="N" goto nouveau
if "%ACTION%"=="S" goto supprimer
if "%ACTION%"=="D" goto demarrer
if "%ACTION%"=="A" goto arreter

goto usage

:lister
echo Liste des machines et leurs metadonnees :
VBoxManage list vms > liste_temp.txt
FOR /F %%a in (liste_temp.txt) do call :afficher_meta %%a
if exist liste_temp.txt del liste_temp.txt
goto :eof

:afficher_meta
set VM_EXT=%1
echo ----------------------------------------
echo Machine : %VM_EXT%
VBoxManage getextradata %VM_EXT% "CreationDate" 2>nul
VBoxManage getextradata %VM_EXT% "Creator" 2>nul
goto :eof

:nouveau
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

:: Métadonnées (V4)
VBoxManage setextradata %NOM_VM% "CreationDate" "%DATE% %TIME%"
VBoxManage setextradata %NOM_VM% "Creator" "%USERNAME%"

:: Configuration du boot réseau PXE en priorité 1 (Nouveauté concernant l'étape 5)
VBoxManage modifyvm %NOM_VM% --boot1 net
echo VM %NOM_VM% creee avec succes (PXE configure en boot1).
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
echo Erreur : Il faut un nom pour la VM.
goto :eof

:usage
echo Utilisation : %0 [L|N|S|D|A] [nom_machine]
goto :eof