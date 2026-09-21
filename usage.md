# SAÉ 51 — Automatisation de la création de machines virtuelles VirtualBox

- **Auteurs :** Andy XIONG & Tom PAQUET
- **Date de fin :** 21 septembre 2026
- **Établissement :** IUT de Rouen Site d'Elbeuf - Réseaux & Télécoms (BUT3)

## Résumé
Ce document présente le fonctionnement d'une suite de scripts Batch Windows (de `genmv_1.bat` à `genmv_5.bat`) conçus pour automatiser la gestion de machines virtuelles sous VirtualBox via `VBoxManage`. Il détaille la syntaxe des commandes, l'évolution de la structure globale du projet, les métadonnées injectées et le paramétrage du boot réseau PXE. Une section dédiée analyse l'architecture mise en place, les contraintes techniques liées à l'environnement hôte Windows ainsi que les évolutions possibles pour la maquette.

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
### 2. Implémentation du boot réseau PXE et résolution des instabilités TFTP
Pour l'Étape 5, le script configure avec succès la VM afin qu'elle consulte le réseau en priorité au démarrage (`--boot1 net`). La machine virtuelle démarre effectivement sur l'installateur réseau de Debian via le PXE.

Cependant, la mise en place du serveur TFTP interne de VirtualBox (associé à l'interface NAT) a nécessité le diagnostic et le contournement de plusieurs obstacles techniques :

- **Évolution de la syntaxe VirtualBox 7+ :** Le CLI ayant été mis à jour par Oracle, il a fallu appliquer la nouvelle nomenclature stricte comportant des tirets (ex: `--nat-enable-tftp1` au lieu des anciennes commandes) pour éviter les erreurs `Unknown option`. La VM ne pouvait donc tout simplement pas trouver le dossier TFTP pour boot.

  <img width="1109" height="613" alt="Capture d&#39;écran 2026-09-21 133259" src="https://github.com/user-attachments/assets/96a258ee-7928-4203-8197-b301d24ec8ca" />

  
- **Routage du serveur TFTP :** Par défaut, le firmware iPXE tentait de joindre le réseau *Host-Only* (`192.168.56.1`), ce qui provoquait une expiration du délai de connexion (`Connection timed out`). Il a été nécessaire de forcer l'adresse de la passerelle NAT via la directive `--nat-tftp-server1 10.0.2.2`.

  <img width="1197" height="596" alt="21ac56e6-b2c6-4175-94b5-4f3126688d95" src="https://github.com/user-attachments/assets/d0b6c2e9-fdd8-4682-89b3-75cc9c25408a" />

  
- **Sensibilité du parsing de l'antislash final :** L'ajout d'un antislash à la fin du chemin du préfixe TFTP (`--nat-tftp-prefix1`) générait un double slash interne corrompant l'accès aux fichiers. La valeur a dû être formatée sans slash terminal (ex: `%USERPROFILE%\.VirtualBox\TFTP`).
  
- **Dépendances de l'amorceur réseau (Syslinux) :** Le protocole TFTP ne permet pas d'amorcer directement un fichier `.iso`. Après l'obtention du premier fichier (`pxelinux.0`), l'amorceur bloquait sur l'absence du module `ldlinux.c32`. Il a fallu déployer l'arborescence *Netboot* complète de Debian (`pxelinux.0`, `ldlinux.c32`, le noyau `vmlinuz`, l'image `initrd.gz` ainsi que le dossier de configuration `pxelinux.cfg`) pour permettre le chargement de l'installateur.

  <img width="1123" height="561" alt="a7a1c654-a36a-4c5f-95c3-01db514a28e3" src="https://github.com/user-attachments/assets/a24d2f18-f5a1-4c81-86f1-097c8c10ede2" />


  

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
