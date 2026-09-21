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

:: ==========================================
:: AUTOMATISATION DU TELECHARGEMENT TFTP/PXE
:: ==========================================
set "TFTPDIR=%USERPROFILE%\.VirtualBox\TFTP"
set "DEBIAN_BASE=https://deb.debian.org/debian/dists/stable/main/installer-amd64/current/images/netboot/debian-installer/amd64"

echo Preparation du dossier TFTP dans %TFTPDIR%...
if not exist "%TFTPDIR%" mkdir "%TFTPDIR%"
if not exist "%TFTPDIR%\pxelinux.cfg" mkdir "%TFTPDIR%\pxelinux.cfg"

echo Telechargement des fichiers PXE requis (patientez)...
:: Le "if not exist" permet de ne pas retélécharger si le fichier est déjà là
if not exist "%TFTPDIR%\pxelinux.0" curl -# -L -o "%TFTPDIR%\pxelinux.0" "%DEBIAN_BASE%/pxelinux.0"
if not exist "%TFTPDIR%\ldlinux.c32" curl -# -L -o "%TFTPDIR%\ldlinux.c32" "%DEBIAN_BASE%/boot-screens/ldlinux.c32"
if not exist "%TFTPDIR%\vmlinuz" curl -# -L -o "%TFTPDIR%\vmlinuz" "%DEBIAN_BASE%/linux"
if not exist "%TFTPDIR%\initrd.gz" curl -# -L -o "%TFTPDIR%\initrd.gz" "%DEBIAN_BASE%/initrd.gz"

echo Creation du fichier pxelinux.cfg\default...
(
    echo DEFAULT debian
    echo PROMPT 1
    echo TIMEOUT 50
    echo.
    echo LABEL debian
    echo     MENU LABEL Installer Debian PXE
    echo     KERNEL vmlinuz
    echo     APPEND initrd=initrd.gz
) > "%TFTPDIR%\pxelinux.cfg\default"
:: ==========================================

echo Creation de la VM %NOM_VM%...
VBoxManage createvm --name %NOM_VM% --ostype Debian_64 --register
VBoxManage modifyvm %NOM_VM% --memory %RAM% --nic1 nat
VBoxManage createmedium disk --filename "%NOM_VM%.vdi" --size %DISK%
VBoxManage storagectl %NOM_VM% --name "SATA" --add sata --controller IntelAhci
VBoxManage storageattach %NOM_VM% --storagectl "SATA" --port 0 --device 0 --type hdd --medium "%NOM_VM%.vdi"

:: Métadonnées (V4)
VBoxManage setextradata %NOM_VM% "CreationDate" "%DATE% %TIME%"
VBoxManage setextradata %NOM_VM% "Creator" "%USERNAME%"

:: Configuration TFTP PXE (V5) pour VirtualBox 7+
VBoxManage modifyvm %NOM_VM% --boot1 net
VBoxManage modifyvm %NOM_VM% --nat-tftp-prefix1 "%USERPROFILE%\.VirtualBox\TFTP"
VBoxManage modifyvm %NOM_VM% --nat-tftp-file1 pxelinux.0
VBoxManage modifyvm %NOM_VM% --nat-tftp-server1 10.0.2.2
VBoxManage modifyvm %NOM_VM% --nat-enable-tftp1 on

echo VM %NOM_VM% creee avec succes et prete pour le boot reseau !
goto :eof

:demarrer
echo Demarrage de la VM %NOM_VM%...
VBoxManage startvm %NOM_VM%
goto :eof

:supprimer
echo Suppression de la VM %NOM_VM%...
VBoxManage unregistervm %NOM_VM% --delete
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