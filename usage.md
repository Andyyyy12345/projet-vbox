# SAÉ 51 — Automatisation de la création de machines virtuelles VirtualBox

- **Auteurs :** Andy XIONG & Tom PAQUET
- **Date de fin :** 21 septembre 2026
- **Établissement :** IUT de Rouen Site d'Elbeuf - Réseaux & Télécoms (BUT3)

## Résumé
Ce document présente le fonctionnement d'une suite de scripts Batch Windows (de `genmv_1.bat` à `genmv_5.bat`) conçus pour automatiser la gestion de machines virtuelles sous VirtualBox via `VBoxManage`. Il détaille la syntaxe des commandes, l'évolution de la structure globale du projet, les métadonnées injectées et le paramétrage du boot réseau PXE (que nous n'avons malheuresement pas réussi à réaliser). Une section dédiée analyse l'architecture mise en place, les contraintes techniques liées à l'environnement hôte Windows ainsi que les évolutions possibles pour la maquette.

---

## Structure du dépôt

```text
projet-vbox/
├── script/
│   ├── genmv_1.bat
│   ├── genmv_2.bat
│   ├── genmv_3.bat
│   ├── genmv_4.bat
│   └── genmv_5.bat
└── usage.md
```

## Manuel d'utilisation :

Les scripts doivent être exécutés depuis l'invite de commandes Windows (cmd.exe) ou depuis Git Bash (en utilisant le préfixe cmd //c ...) à la racine du dossier script/.

Syntaxe générale (à partir de la v3)
genmv_5.bat [ACTION] [NOM_MACHINE]

### Actions disponibles :

L : Liste l'ensemble des machines virtuelles enregistrées sur l'hôte et affiche leurs métadonnées associées.

N [nom] : Crée une nouvelle VM (4 Go RAM, 64 Go disque SATA, carte NAT, métadonnées et boot réseau PXE).

S [nom] : Supprime la machine virtuelle ainsi que tous ses fichiers disques virtuels (.vdi).

D [nom] : Démarre la machine virtuelle.

A [nom] : Arrête immédiatement la machine virtuelle (poweroff).

### Exemples d'utilisation :
```
# Lister les machines et leurs métadonnées
cmd //c genmv_5.bat L

# Créer une VM nommée "Debian1"
cmd //c genmv_5.bat N Debian1

# Démarrer la VM
cmd //c genmv_5.bat D Debian1

# Arrêter puis supprimer la VM
cmd //c genmv_5.bat A Debian1
cmd //c genmv_5.bat S Debian1
```
## Choix d'implémentation et évolutions des scripts

**genmv_1.bat :** Implémentation du socle de base (création, allocation de 4 Go RAM, création et attachement d'un disque SATA de 64 Go). Une pause finale permet de vérifier l'ajout dans l'interface graphique VirtualBox.

**genmv_2.bat :** Ajout d'un contrôle d'existence préalable via la commande VBoxManage showvminfo %NOM_VM% et le test de %ERRORLEVEL% afin d'éviter d'écraser une VM existante.

**genmv_3.bat :** Passage à une architecture non-interactive basée sur des arguments positionnels (L, N, S, D, A). Centralisation de la mémoire vive (RAM=4096) et de la taille disque (DISK=65536) sous forme de variables d'en-tête.

**genmv_4.bat :** Injection de métadonnées personnalisées lors de la création (CreationDate et Creator) via setextradata. Parsing de la liste des VM à l'aide d'un fichier texte temporaire (liste_temp.txt) parcouru par une boucle FOR /F pour afficher les métadonnées de chaque machine.

**genmv_5.bat :** Configuration du démarrage réseau PXE en priorité 1 via l'option modifyvm %NOM_VM% --boot1 net.

## Problèmes rencontrés, limites & Astuces techniques

### 1. Prise en compte du binaire VBoxManage sous Windows
L'outil VBoxManage.exe n'étant pas toujours inscrit dans la variable d'environnement PATH du système hôte, la ligne suivante a été ajoutée au sommet de chaque script afin d'en garantir l'exécution :

```cmd
set "PATH=%PATH%;C:\Program Files\Oracle\VirtualBox"
```
### 2. Implémentation du boot réseau PXE et limites du serveur TFTP interne
Pour l'étape 5, le script configure la VM afin qu'elle consulte le réseau en priorité au démarrage (`--boot1 net`). La présence de cette priorité est directement vérifiable dans la GUI VirtualBox (**Configuration > Système > Ordre d'amorçage**).

**Du côté du serveur TFTP interne de VirtualBox (associé à l'interface NAT) :**

- **Démarche théorique :** Les fichiers d'amorçage réseau (`pxelinux.0`, `vmlinuz` et `initrd.gz`) extraits de l'ISO Debian netinst ainsi que le dossier de configuration `pxelinux.cfg/default` ont été positionnés dans le répertoire par défaut du profil utilisateur `%USERPROFILE%\.VirtualBox\TFTP\`. Le script pointe dynamiquement sur ce dossier via la directive `nattftpprefix1`.

- **Limite technique identifiée :** Sous environnement hôte Windows, le moteur C++ interne du service TFTP NAT de VirtualBox présente des instabilités majeures et échoue à initialiser la distribution des fichiers d'amorçage. Malgré la configuration explicite des directives `nattftpprefix1`, `nattftpfile1` et `nattftpbootdrive1 1`, le sous-système VirtualBox renvoie systématiquement la valeur `EnableTFTP = 0x0` dans ses journaux d'exécution (`VBox.log`), provoquant l'échec `Nothing to boot` côté iPXE (voir capture d'écran).

    <img width="551" height="90" alt="image" src="https://github.com/user-attachments/assets/984d1f19-f552-4f75-8f1a-d60460654c9e" />


- **Piste de résolution / Alternative :** Dans un environnement de production ou lors d'un déploiement sous Windows, l'attachement direct de l'ISO sur le contrôleur DVD virtuel (`--boot1 dvd`) ou le déploiement d'un serveur TFTP/DHCP tiers sur un réseau interne dédié (`Intnet`) constituent les alternatives préconisées.

## Fonctionnalités supplémentaires (Partie optionnelle)
### 1. Login automatique (Auto-logon)
L'auto-login permet d'exécuter automatiquement des tâches ou des services sur la machine dès son démarrage. Sous VirtualBox, cette fonctionnalité s'appuie sur l'installation préalable des Guest Additions au sein de la machine invitée et peut être pilotée depuis l'hôte via :

```
VBoxManage controlvm "Nom_VM" setcredentials "utilisateur" "mot_de_passe" ""
```

### 2. Installation automatisée via fichier "pre-seed"
Pour supprimer les interactions manuelles lors de l'installation de Debian, un fichier de réponses pré-enregistrées (preseed.cfg) hébergé sur un serveur HTTP local peut être transmis au noyau. Il suffit d'ajouter la directive suivante dans la configuration du menu PXE (pxelinux.cfg/default) :
```
append auto=true priority=critical preseed/url=http://<IP_HOTE>/preseed.cfg
```

### 3. Proposition d'amélioration : Clonage de machines virtuelles
Afin de contourner la durée d'installation d'un système d'exploitation à partir du réseau, une évolution pertinente du script consisterait à ajouter une option C (Clonage). Le script utiliserait une VM "modèle" (Template) pré-configurée et exécuterait :
```
VBoxManage clonevm Modele_Debian --name %NOM_VM% --register
```
Cela permettrait le déploiement d'une machine opérationnelle en quelques secondes.
