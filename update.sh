#!/bin/bash

# Vérifie si le script est lancé avec les permissions administrateurs
echo "Vérification des permissions administrateurs..."
if [ $EUID -ne 0 ]; then
    echo "Vous devez lancer ce script avec les permissions administrateurs"
    exit 1
    else echo "Vous avez les permissions administrateurs"
fi

echo "Début de l'opération de mise à niveau de netbox"

# Vérifie les mises à jours et les installes
echo "Recherche et mise à jour du système et des paquets"
apt update && apt upgrade -y

# Indiquer version actuelle

echo "Veuillez indiquer la version actuellement installé :"
read OLDVER

repository="netbox-community/netbox"

# Get the latest release information
release_data=$(curl -sSL "https://api.github.com/repos/$repository/releases/latest")

# Extract the tag name (latest release version)
latest_release=$(echo $release_data | jq -r '.tag_name')
version_number=${latest_release#v}

echo "La dernière version de NetBox sur le dépôt GitHub est : $latest_release. Celle-ci va être mis à jour à cette dernière version."

# Installation de la nouvelle version :
NEWVER=$version_number
wget https://github.com/netbox-community/netbox/archive/v$NEWVER.tar.gz
tar -xzf v$NEWVER.tar.gz -C /opt
ln -sfn /opt/netbox-$NEWVER/ /opt/netbox

# Déplacement des anciens fichiers vers le nouveau :

fichier_source="/opt/netbox-$OLDVER/local_requirements.txt"
fichier_destination="/opt/netbox/local_requirements.txt"

if [ -f "$fichier_source" ]; then
  # Le fichier existe, on le copie
  cp "$fichier_source" "$fichier_destination"
  echo "Fichier copié avec succès !"
else
  # Le fichier n'existe pas, on affiche un message
  echo "Le fichier $fichier_source n'existe pas."
fi

fichier_source="/opt/netbox-$OLDVER/netbox/netbox/ldap_config.py"
fichier_destination="/opt/netbox/netbox/netbox/ldap_config.py"

if [ -f "$fichier_source" ]; then
  # Le fichier existe, on le copie
  cp "$fichier_source" "$fichier_destination"
  echo "Fichier copié avec succès !"
else
  # Le fichier n'existe pas, on affiche un message
  echo "Le fichier $fichier_source n'existe pas."
fi

cp /opt/netbox-$OLDVER/netbox/netbox/configuration.py /opt/netbox/netbox/netbox/
cp -pr /opt/netbox-$OLDVER/netbox/media/ /opt/netbox/netbox/
cp -r /opt/netbox-$OLDVER/netbox/scripts /opt/netbox/netbox/
cp -r /opt/netbox-$OLDVER/netbox/reports /opt/netbox/netbox/
cp /opt/netbox-$OLDVER/gunicorn.py /opt/netbox/

cd /opt/netbox/
./upgrade.sh

systemctl restart netbox netbox-rq

ln -s /opt/netbox/contrib/netbox-housekeeping.sh /etc/cron.daily/netbox-housekeeping

echo "Suppression de l'ancienne version..."

rm -R /opt/netbox-$OLDVER/

echo "La mise à niveau est terminé !"