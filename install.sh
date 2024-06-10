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

if [ $major_version -ge 15 ]; then
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

# Vérifie la connexion de redis-server
redis_response=$(redis-cli ping)

if [ "$redis_response" = "PONG" ]; then
  echo "Connexion Redis établie avec succès."
else
  echo "Erreur : Connexion Redis impossible. Réponse : $redis_response"
  exit 1
fi

# Installation de Netbox
echo "Installation de Netbox"
apt install -y python3 python3-pip python3-venv python3-dev build-essential libxml2-dev libxslt1-dev libffi-dev libpq-dev libssl-dev zlib1g-dev jq

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

echo "Souhaitez vous que le script installe la dernière version de Netbox ? (y/n)"
read install_newver

if [ $install_newver = "y" ]; then
	repository="netbox-community/netbox"

	# Get the latest release information
	release_data=$(curl -sSL "https://api.github.com/repos/$repository/releases/latest")

	# Extract the tag name (latest release version)
	latest_release=$(echo $release_data | jq -r '.tag_name')

	echo "La dernière version de NetBox sur le dépôt GitHub est : $latest_release"

	wget https://github.com/netbox-community/netbox/archive/refs/tags/$latest_release.tar.gz
	tar -xzf $latest_release.tar.gz -C /opt
	# Extract the version number without 'v' prefix
	version_number=${latest_release#v}
	ln -s /opt/netbox-$version_number/ /opt/netbox

else 
	echo "Indiquez la version que vous souhaitez installer :"
	read netbox_ver
	echo "Vous avez choisis d'installer la version v$netbox_ver de Netbox."
fi

# Création de l'utilisateur Netbox système
echo "Création de l'utilisateur système \"netbox\""
sudo adduser --system --group netbox
sudo chown --recursive netbox /opt/netbox/netbox/media/
sudo chown --recursive netbox /opt/netbox/netbox/reports/
sudo chown --recursive netbox /opt/netbox/netbox/scripts/

# Création du fichier de configuration
echo "Création du fichier de configuration"
cd /opt/netbox/netbox/netbox/
sudo cp configuration_example.py configuration.py
echo "information : Vous allez devoir modifier le fichier de configuration dans 20 secondes. Prenez le temps de noter le secret généré juste en dessous :"
python3 ../generate_secret_key.py
sleep 20
vim configuration.py

cd /opt/netbox
./upgrade.sh
pip install -r requirement.txt
systemctl restart netbox netbox-rq


# Création du super utilisateur
echo "Création du super utilisateur"
source /opt/netbox/venv/bin/activate
cd /opt/netbox/netbox
python3 manage.py createsuperuser

ln -s /opt/netbox/contrib/netbox-housekeeping.sh /etc/cron.daily/netbox-housekeeping

# Test de l'environnement de développement
echo "LANCEMENT DU TEST DE L'ENVIRONNEMENT DE DEVELOPPEMENT !!!"
sleep 2
echo "LANCEMENT DU TEST DE L'ENVIRONNEMENT DE DEVELOPPEMENT !!!"
sleep 2
echo "LANCEMENT DU TEST DE L'ENVIRONNEMENT DE DEVELOPPEMENT !!!"
sleep 2
python3 manage.py runserver 0.0.0.0:8000 --insecure

# Configuration de Gunicorn
echo "Configuration de Gunicorn"
cp /opt/netbox/contrib/gunicorn.py /opt/netbox/gunicorn.py

# Configuration de Systemd
echo "Configuration de Systemd"
cp -v /opt/netbox/contrib/*.service /etc/systemd/system/
systemctl daemon-reload
systemctl start netbox netbox-rq
systemctl enable netbox netbox-rq
echo ""
systemctl status netbox.service
sleep 5

deactivate

# Installation du serveur WEB
echo "Installation du serveur web..."
echo "Un certificat autosigné va être installé."

sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
-keyout /etc/ssl/private/netbox.key \
-out /etc/ssl/certs/netbox.crt

echo "Souhaitez vous utiliser un serveur nginx ou apache ? (nginx/apache)"
read web_server

if [ $web_server = "nginx" ]; then
	apt install -y nginx
	cp /opt/netbox/contrib/nginx.conf /etc/nginx/sites-available/netbox
	rm /etc/nginx/sites-enabled/default
	ln -s /etc/nginx/sites-available/netbox /etc/nginx/sites-enabled/netbox


	# Get the new server name from the user
	read -p "Enter the new server name (e.g., yourdomain.com): " new_server_name

	# Escape any special characters in the user input (optional, but recommended for security)
	new_server_name_escaped=$(echo "$new_server_name" | sed 's/[\]\/\*\.&$/\\&/g')
	echo "Nom de domaine échappé: $new_server_name_escaped"


	# Backup the original file (optional, but recommended)
	cp /etc/nginx/sites-available/netbox /etc/nginx/sites-available/netbox.bak

	# Modify the line using sed
	sed -i "s/server_name netbox.example.com;/server_name $new_server_name_escaped;/" /etc/nginx/sites-available/netbox

	# Check for errors
	if [ $? -eq 0 ]; then
	  echo "Configuration file modified successfully."
	else
	  echo "Error: Failed to modify the configuration file."
	  # Restore the backup if modification failed (optional)
	  # cp /etc/nginx/sites-available/netbox.bak /etc/nginx/sites-available/netbox
	fi

	# Vérifier la configuration Nginx
	nginx_config_test=$(nginx -t 2>&1)

	# Vérifier le code de retour de la commande
	if [ $? -eq 0 ]; then
	  echo "La configuration Nginx est valide."
	  systemctl restart nginx
	else
	  echo "La configuration Nginx est invalide."
	  echo "Détails de l'erreur :"
	  echo "$nginx_config_test"
	  exit 1
	fi
fi
if [ $web_server = "apache" ]; then
	apt install -y apache2
	cp /opt/netbox/contrib/apache.conf /etc/apache2/sites-available/netbox.conf

	# Get the new server name from the user
	read -p "Enter the new server name (e.g., yourdomain.com): " new_server_name

	# Escape any special characters in the user input (optional, but recommended for security)
	new_server_name_escaped=$(echo "$new_server_name" | sed 's/[\]\/\*\.&$/\\&/g')
	echo "Nom de domaine échappé: $new_server_name_escaped"

	# Backup the original file (optional, but recommended)
	cp /etc/apache2/sites-available/netbox.conf /etc/apache2/sites-available/netbox.conf.bak

	# Modify the line using sed
	sed -i "s/ServerName netbox.example.com;/ServerName $new_server_name_escaped;/" /etc/nginx/sites-available/netbox

	# Check for errors
	if [ $? -eq 0 ]; then
	  echo "Configuration file modified successfully."
	else
	  echo "Error: Failed to modify the configuration file."
	  # Restore the backup if modification failed (optional)
	  cp /etc/apache2/sites-available/netbox.conf.bak /etc/apache2/sites-available/netbox.conf
	fi

	a2enmod ssl proxy proxy_http headers rewrite
	a2ensite netbox
	systemctl restart apache2
fi	

echo "Vous pouvez vérifier la connexion de l'utilisateur de base de donnée avec la commande :"
echo "\"sudo -u postgres psql --username netbox --password --host localhost netbox\""
echo "Puis en renseignant la commande \"\\conninfo\"."