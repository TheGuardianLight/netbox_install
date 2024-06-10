#!/bin/bash

# Vérifie si le script est lancé avec les permissions administrateurs
echo "Vérification des permissions administrateurs..."
if [ $EUID -ne 0 ]; then
    echo "Vous devez lancer ce script avec les permissions administrateurs"
    exit 1
    else echo "Vous avez les permissions administrateurs"
fi

# Vérifie les mises à jours et les installes
echo "Recherche et mise à jour du système et des paquets"
apt update && apt upgrade -y