#!/bin/sh

# Vérifie les mises à jours et les installes
echo "Recherche et mise à jour du système et des paquets"
apt update && apt upgrade -y

# Installe PostgreSQL :
echo "Installation de PostgreSQL"
apt install -y postgresql

echo "Vérification de l'exigence de version de PostgreSQL"
# Obtenir la version de PostgreSQL
version=$(psql -V | awk '{print $3}')

# Extraire le numéro de version principal
major_version=${version%%.*}

# Vérifier si la version principale est supérieure ou égale à 12
if [ $major_version -ge 12 ]; then
  echo "Version de PostgreSQL requise respectée : $version"
else
  echo "Erreur : Version de PostgreSQL trop ancienne. Version minimale requise : 12. Version trouvée : $version"
  exit 1
fi

if [$major_version -ge 15]; then
	echo "Version de PostgreSQL non supporté par ce script. Version maximale accepté : 14"
	exit 1
fi

# Questions-réponses sur la bdd
echo "Veuillez indiquer le nom de votre base de donnée :"
read bdd_name
echo "Veuillez indiquer le nom de l'utilisateur propriétaire de la base de donnée $bdd_name :"
read user_name
echo "Veuillez indiquer le mot de passe de cet utilisateurs :"
read user_password

# Création BDD
echo "Création de la base de donnée et de l'utilisateur"
cd /opt
sudo -u postgres psql -c "CREATE DATABASE $bdd_name;"
sudo -u postgres psql -c "
CREATE USER $user_name WITH PASSWORD '$user_password';
ALTER DATABASE $bdd_name OWNER TO $user_name;
"

if [ $? -eq 0 ]; then
  echo "Base de données '$bdd_name' créée avec succès."
else
  echo "Erreur lors de la création de la base de données '$bdd_name'."
fi


# Installation de redis
echo "Installation de redis-server"
apt install -y redis-server

# Obtenir la version de Redis
echo "Vérification de la version de redis-server..."
redis_version=$(redis-server -v | awk '{print $2}')

# Extraire le numéro de version principal
major_redis_version=${redis_version%%.*}

# Vérifier si la version principale est supérieure ou égale à 4
if [ $major_redis_version -ge 4 ]; then
  echo "Version de Redis requise respectée : $redis_version"
else
  echo "Erreur : Version de Redis trop ancienne. Version minimale requise : 4.0. Version trouvée : $redis_version"
  exit 1
fi

# Vérifie la connexion de redis-server
redis_response=$(redis-cli ping)

if [ "$redis_response" == "PONG" ]; then
  echo "Connexion Redis établie avec succès."
else
  echo "Erreur : Connexion Redis impossible. Réponse : $redis_response"
  exit 1
fi

# Installation de Netbox
echo "Installation de Netbox"
apt install -y python3 python3-pip python3-venv python3-dev build-essential libxml2-dev libxslt1-dev libffi-dev libpq-dev libssl-dev zlib1g-dev

# Check Python version
python_version=$(python3 -V | awk '{print $2}')
version_parts=(${python_version//\./ })  # Split version into an array

major_python_version=${version_parts[0]}
minor_python_version=${version_parts[1]}
sub_minor_python_version=${version_parts[2]}  # Assuming 3-part version format

if [ $major_python_version -ge 3 ]; then
  if [ $major_python_version -eq 3 ]; then
    if [ $minor_python_version -ge 10 ]; then
      if [ $sub_minor_python_version -ge 0 ]; then  # Check for >= 0 sub-minor version
        echo "Version de Python requise respectée : $python_version"
      else
        echo "Erreur : Version de Python trop ancienne. Version minimale requise : 3.10.0. Version trouvée : $python_version"
        exit 1
      fi
    else
      echo "Erreur : Version de Python trop ancienne. Version minimale requise : 3.10.0. Version trouvée : $python_version"
      exit 1
    fi
  else
    echo "Version de Python requise respectée : $python_version"
  fi
else
  echo "Erreur : Version de Python trop ancienne. Version minimale requise : 3.10.0. Version trouvée : $python_version"
  exit 1
fi



echo "Vous pouvez vérifier la connexion de l'utilisateur de base de donnée avec la commande :"
echo "\"sudo -u postgres psql --username netbox --password --host localhost netbox\""
echo "Puis en renseignant la commande \"\\conninfo\"."