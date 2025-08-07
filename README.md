# 🐧 Pelican-Autoinstaller

Script d'installation automatique pour le panel Pelican !

Vous pouvez installer soit le **panel**, soit **Wings**, soit les deux sur la même machine !

## 🚀 Installation rapide

**⚠️ Prérequis : Vous devez être connecté en tant que root !**

### Étape 1 : Mettre à jour le système
```bash
apt update
```

### Étape 2 : Installer curl
```bash
apt install curl -y
```

### Étape 3 : Lancer le script d'installation
```bash
bash <(curl -s https://raw.githubusercontent.com/TheOrion-OVH/Pelican-Autoinstaller/refs/heads/main/installer.sh)
```

## 📋 Installation en une seule commande

Si vous préférez, vous pouvez exécuter toutes les commandes d'un coup :

```bash
apt update && apt install curl -y && bash <(curl -s https://raw.githubusercontent.com/TheOrion-OVH/Pelican-Autoinstaller/refs/heads/main/installer.sh)
```

## 🛠️ Options d'installation

Le script vous permettra de choisir entre :
- ✅ **Panel Pelican uniquement**
- ✅ **Wings uniquement** 
- ✅ **Panel + Wings** (installation complète)
