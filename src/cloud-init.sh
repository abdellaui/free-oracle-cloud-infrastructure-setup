#!/usr/bin/env bash

export PROJECT_NAME="demo-service"

echo "cloud-init.sh runs with passed arguments:"
for arg in "$@"; do
    echo "Argument: ${arg}"
done

if [ "$1" == "noop" ]; then

  TRANSFER_ENV_FILE="${PWD}/${PROJECT_NAME}/transfer.env"
  if [ -f "$TRANSFER_ENV_FILE" ]; then
    # shellcheck disable=SC1090
    source "${TRANSFER_ENV_FILE}"
    echo "source ${TRANSFER_ENV_FILE}"
  else
      echo "WARNING: ${TRANSFER_ENV_FILE} does not exist."
  fi
else
  if [ -z "$APP_THIS_ENV_CONSUMED" ] && [ -n "$APP_SRC_PATH" ]; then
      ENV_FILE_FOUND="{$APP_SRC_PATH}/.env"

      # shellcheck disable=SC1090
      source "${ENV_FILE_FOUND}"
      echo "source ${ENV_FILE_FOUND}"
  fi
fi


set -euxo pipefail

TEMP_GIT_REPO="${HOME_PATH}/${PROJECT_NAME}"

sudo apt-get update -y

sudo apt-get install -y udisks2-lvm2 network-manager build-essential libsystemd-dev python3 python3-pip python3-venv curl git cockpit cockpit-pcp cockpit-podman nginx tree

if [[ ! -e "/usr/local/bin/oauth2-proxy" ]]; then
  # Install OAuth2 Proxy 
  echo "Installing OAuth2 Proxy..."
  wget "https://github.com/oauth2-proxy/oauth2-proxy/releases/download/${OAUTH2_PROXY_VERSION}/oauth2-proxy-${OAUTH2_PROXY_VERSION}.${OS_ARCH_NAME}.tar.gz"
  tar -xvf "oauth2-proxy-${OAUTH2_PROXY_VERSION}.${OS_ARCH_NAME}.tar.gz"
  sudo cp "oauth2-proxy-${OAUTH2_PROXY_VERSION}.${OS_ARCH_NAME}/oauth2-proxy" /usr/local/bin/
  sudo rm -rf oauth2-proxy-*
fi

echo "############################################"
echo "############################################"
echo "########    END INSTALLATION    ############"
echo "############################################"
echo "############################################"

# Check if the argument wants to quit
if [ "$1" == "install" ]; then
    echo "Quitting duo to argument '$1'."
    exit 0
fi

CURRENT_PUBLIC_IP=$(curl -s ifconfig.me/ip)
UPDATE_CLOUDFLARE_TIMESTAMP=$(date +"%d.%m.%Y - %H:%M:%S")

# Record the new public IP address on Cloudflare using API v4
CLOUDFLARE_RECORD=$(cat <<EOF
{ "type": "A",
  "name": "@",
  "content": "${CURRENT_PUBLIC_IP}",
  "ttl": 1,
  "comment": "cloud-init @ ${UPDATE_CLOUDFLARE_TIMESTAMP}",
  "proxied": true }
EOF
)

curl "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records/${CLOUDFLARE_RECORD_ID}" \
     -X PUT \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer ${CLOUDFLARE_API_KEY}" \
     -d "${CLOUDFLARE_RECORD}"

echo "############################################"
echo "############################################"
echo "######## END CLOUDFLARE UPDATE  ############"
echo "############################################"
echo "############################################"

# Check if the argument wants to quit
if [ "$1" == "cloudflare" ]; then
    echo "Quitting duo to argument '$1'."
    exit 0
fi

# Create the directory if it does not exist
if [ ! -d "${APP_FULL_PATH}" ]; then
  echo "Creating directory: ${APP_FULL_PATH}"
  sudo mkdir -p "${APP_FULL_PATH}"
else
  echo "Directory already exists: ${APP_FULL_PATH}"
fi

# Check if the device is already formatted
if ! sudo blkid "${BLOCK_STORAGE_DEVICE}" > /dev/null 2>&1; then
  echo "Formatting device: ${BLOCK_STORAGE_DEVICE}"
  sudo mkfs.ext4 "${BLOCK_STORAGE_DEVICE}"
else
  echo "Device is already formatted: ${BLOCK_STORAGE_DEVICE}"
fi

# Check if the device is already mounted
if ! mount | grep -q "${BLOCK_STORAGE_DEVICE}"; then
  echo "Mounting device: ${BLOCK_STORAGE_DEVICE} to ${APP_FULL_PATH}"
  sudo mount "${BLOCK_STORAGE_DEVICE}" "${APP_FULL_PATH}"
else
  echo "Device is already mounted: ${BLOCK_STORAGE_DEVICE}"
fi

# Add the device to /etc/fstab for permanent mounting
# Check if the device is already in /etc/fstab
if ! grep -q "${BLOCK_STORAGE_DEVICE}" /etc/fstab; then
  echo "Adding ${BLOCK_STORAGE_DEVICE} to /etc/fstab for permanent mounting"
  echo "${BLOCK_STORAGE_DEVICE} ${APP_FULL_PATH} ext4 defaults 0 0" | sudo tee -a /etc/fstab > /dev/null
else
  echo "Device is already in /etc/fstab"
fi

ls -ld "${APP_FULL_PATH}"

# Create the directory if it does not exist
if [ ! -d "${APP_SRC_PATH}" ]; then
  echo "Creating directory: ${APP_SRC_PATH}"
  sudo mkdir -p "${APP_SRC_PATH}"
else
  echo "Directory already exists: ${APP_SRC_PATH}"
fi


# Create the directory if it does not exist
if [ ! -d "${APP_FULL_PATH}/logs" ]; then
  echo "Creating directory: ${APP_FULL_PATH}/logs"
  sudo mkdir -p "${APP_FULL_PATH}/logs"
else
  echo "Directory already exists: ${APP_FULL_PATH}/logs"
fi


# Create the directory if it does not exist
if [ ! -d "${APP_FULL_PATH}/records" ]; then
  echo "Creating directory: ${APP_FULL_PATH}/records"
  sudo mkdir -p "${APP_FULL_PATH}/records"
else
  echo "Directory already exists: ${APP_FULL_PATH}/records"
fi


# Create the directory if it does not exist
if [ ! -d "${APP_FULL_PATH}/configs" ]; then
  echo "Creating directory: ${APP_FULL_PATH}/configs"
  sudo mkdir -p "${APP_FULL_PATH}/configs"
else
  echo "Directory already exists: ${APP_FULL_PATH}/configs"
fi

sudo chown -R "${USER_NAME}:${USER_NAME}" "${APP_FULL_PATH}"
sudo chmod -R 755 "${APP_FULL_PATH}"

# move the .env file to the app directory
TRANSFER_ENV_FILE="${TEMP_GIT_REPO}/transfer.env"
if [ -f "$TRANSFER_ENV_FILE" ]; then
  mv "${TRANSFER_ENV_FILE}" "${APP_SRC_PATH}/.env"
  echo "moved ${TRANSFER_ENV_FILE} to ${APP_SRC_PATH}/.env"
else
    echo "WARNING: ${TRANSFER_ENV_FILE} does not exist."
fi

ls -ld "${APP_FULL_PATH}"

echo "############################################"
echo "############################################"
echo "########    END SETUP & MOUNT   ############"
echo "############################################"
echo "############################################"

# Check if the argument wants to quit
if [ "$1" == "setup" ]; then
    echo "Quitting duo to argument '$1'."
    exit 0
fi


rm -rf "${TEMP_GIT_REPO}"
git clone --branch main "https://${GITHUB_USER}:${GITHUB_TOKEN}@github.com/${GITHUB_USER}/${PROJECT_NAME}.git" "${TEMP_GIT_REPO}"

# Ensure source directory is not empty
if [ -d "${TEMP_GIT_REPO}" ] && [ "$(ls -A "${TEMP_GIT_REPO}")" ]; then
  echo "Moving files from ${TEMP_GIT_REPO} to ${APP_FULL_PATH}"
  rsync -av \
    --include "requirements.txt" \
    --include "src/***" \
    --exclude "*" \
    --inplace \
    "${TEMP_GIT_REPO}"/ \
    "${APP_FULL_PATH}/"
else
  echo "No files to move from ${TEMP_GIT_REPO} to ${APP_FULL_PATH} or directory does not exist."
fi

rm -rf "${TEMP_GIT_REPO}"

python3 -m venv "${HOME_PATH}/python3.venv"

# shellcheck disable=SC1091
source "${HOME_PATH}/python3.venv/bin/activate"
echo "source ${HOME_PATH}/python3.venv/bin/activate"


pip install --no-cache-dir -r "${APP_FULL_PATH}/requirements.txt"

deactivate

# UPDATE:END


echo "############################################"
echo "############################################"
echo "########       END UPDATE       ############"
echo "############################################"
echo "############################################"


# Check if the argument wants to quit
if [ "$1" == "update" ]; then
    echo "Quitting duo to argument '$1'."
    exit 0
fi


public_tcp_ports=("80")
for tcp_port in "${public_tcp_ports[@]}"; do
  # Define the rule to check and add
  current_rule="-m state --state NEW -p tcp --dport ${tcp_port} -j ACCEPT"

  # Check if the rule already exists
  # shellcheck disable=SC2086
  if ! sudo iptables -C INPUT ${current_rule} 2>/dev/null; then
    echo "Adding rule: INPUT 6 ${current_rule}"
    
    # Add the rule using the variable
    # shellcheck disable=SC2086
    sudo iptables -I INPUT 6 ${current_rule}

  else
    echo "Rule 'INPUT 6 ${current_rule}' already exists, skipping."
  fi

done

sudo iptables -L -v -n


echo "############################################"
echo "############################################"
echo "########      END IP SETUP      ############"
echo "############################################"
echo "############################################"


# Check if the argument wants to quit
if [ "$1" == "ipsetup" ]; then
    echo "Quitting duo to argument '$1'."
    exit 0
fi

TEMPLATES_DIR="${APP_SRC_PATH}/templates"

# Create Cockpit configuration file
echo "Creating Cockpit configuration file..."
sudo mkdir -p /etc/cockpit

OUTPUT_COCKPIT_CONF="/etc/cockpit/cockpit.conf"
# shellcheck disable=SC2002,SC2016
cat "${TEMPLATES_DIR}/cockpit.conf.template" | envsubst '$TLD_HOSTNAME' | sudo tee "${OUTPUT_COCKPIT_CONF}" > /dev/null

# shellcheck disable=SC2002,SC2016
echo "Configuring Nginx as a reverse proxy for all webservices..."

sudo mkdir -p /var/cache/nginx/landing
sudo mkdir -p /var/cache/nginx/status

OUTPUT_NGINX_CONF="/etc/nginx/conf.d/http.conf"
# shellcheck disable=SC2002,SC2016
cat "${TEMPLATES_DIR}/nginx.conf.template" | envsubst '$TLD_HOSTNAME' | sudo tee "${OUTPUT_NGINX_CONF}" > /dev/null

sudo rm -rf /etc/nginx/sites-enabled/default || true
sudo rm -rf /etc/nginx/sites-available/default || true

OUTPUT_NGINX_WEBSERVICES_CONF="/etc/nginx/sites-available/webservices"
# shellcheck disable=SC2002,SC2016
cat "${TEMPLATES_DIR}/nginx-webservices.conf.template" | envsubst '$TLD_HOSTNAME' | sudo tee "${OUTPUT_NGINX_WEBSERVICES_CONF}" > /dev/null

OUTPUT_ENABLED_NGINX_CONF="/etc/nginx/sites-enabled/webservices"
sudo rm -rf "${OUTPUT_ENABLED_NGINX_CONF}" || true 
sudo ln -s "${OUTPUT_NGINX_WEBSERVICES_CONF}" "${OUTPUT_ENABLED_NGINX_CONF}"
sudo nginx -t || true # Test the configuration


# Create OAuth2 Proxy configuration
echo "Creating OAuth2 Proxy configuration..."
sudo mkdir -p /etc/oauth2-proxy
sudo chown -R "${USER_NAME}:${USER_NAME}" /etc/oauth2-proxy

OUTPUT_OAUTH2_PROXY_CONF="/etc/oauth2-proxy/oauth2-proxy.cfg"
# shellcheck disable=SC2002,SC2016
cat "${TEMPLATES_DIR}/oauth2-proxy.cfg.template" | envsubst '$USER_NAME $GITHUB_CLIENT_ID $GITHUB_CLIENT_SECRET $GITHUB_COOKIE_SECRET $MY_OAUTH_EMAIL_HOST $TLD_HOSTNAME' | sudo tee "${OUTPUT_OAUTH2_PROXY_CONF}" > /dev/null


# Creating service files
SERVICE_DIR_PATH="/usr/lib/systemd/system"

OUTPUT_OAUTH2_PROXY_SERVICE_CONF="${SERVICE_DIR_PATH}/oauth2-proxy.service"
# shellcheck disable=SC2002,SC2016
cat "${TEMPLATES_DIR}/oauth2-proxy.service.template" | envsubst '$USER_NAME' | sudo tee "${OUTPUT_OAUTH2_PROXY_SERVICE_CONF}" > /dev/null

OUTPUT_CLOUDFLARE_UPDATE_SERVICE_CONF="${SERVICE_DIR_PATH}/cloudflare-update.service"
# shellcheck disable=SC2002,SC2016
cat "${TEMPLATES_DIR}/cloudflare-update.service.template" | envsubst '$USER_NAME $APP_SRC_PATH' | sudo tee "${OUTPUT_CLOUDFLARE_UPDATE_SERVICE_CONF}" > /dev/null



export APPLICATION_TIER="status"
export APPLICATION_SCRIPT="web"
export APPLICATION_WAIT="0"
echo "service file for APPLICATION_SCRIPT: ${APPLICATION_SCRIPT}, APPLICATION_TIER: ${APPLICATION_TIER}, APPLICATION_WAIT: ${APPLICATION_WAIT}"

OUTPUT_APPLICATION_SERVICE_CONF="${SERVICE_DIR_PATH}/${PROJECT_NAME}-${APPLICATION_TIER}-${APPLICATION_SCRIPT}.service"
# shellcheck disable=SC2002,SC2016
cat "${TEMPLATES_DIR}/application.service.template" | envsubst '$PROJECT_NAME $HOME_PATH $APP_SRC_PATH $USER_NAME $APPLICATION_SCRIPT $APPLICATION_TIER $APPLICATION_WAIT' | sudo tee "${OUTPUT_APPLICATION_SERVICE_CONF}" > /dev/null




# TIERS_DIR="${APP_SRC_PATH}/tiers"

# # Loop through each file in the directory that matches the pattern .envs.*
# available_scripts=("watch" "convert" "share")


# OFFSET_BETWEEN_APPS=3
# index=0

# for tier_file in "${TIERS_DIR}"/*.env; do
#   if [ ! -f "$tier_file" ]; then
#     continue
#   fi
#   tier_base_name="${tier_file##*/}"
#   export APPLICATION_TIER="${tier_base_name%.env}"
  
#   for current_script in "${available_scripts[@]}"; do
#     export APPLICATION_SCRIPT=$current_script
#     export APPLICATION_WAIT=$((index * OFFSET_BETWEEN_APPS + 1))

#     echo "service file for APPLICATION_SCRIPT: ${APPLICATION_SCRIPT}, APPLICATION_TIER: ${APPLICATION_TIER}, APPLICATION_WAIT: ${APPLICATION_WAIT}"
    
#     OUTPUT_APPLICATION_SERVICE_CONF="${SERVICE_DIR_PATH}/${PROJECT_NAME}-${APPLICATION_TIER}-${APPLICATION_SCRIPT}.service"
#     # shellcheck disable=SC2002,SC2016
#     cat "${TEMPLATES_DIR}/application.service.template" | envsubst '$PROJECT_NAME $HOME_PATH $APP_SRC_PATH $USER_NAME $APPLICATION_SCRIPT $APPLICATION_TIER $APPLICATION_WAIT' | sudo tee "${OUTPUT_APPLICATION_SERVICE_CONF}" > /dev/null
#   done
#   index=$((index + 1))
# done


# sudo systemctl daemon-reload
# sudo systemctl reset-failed

# for tier_file in "${TIERS_DIR}"/*.env; do
#   if [ ! -f "$tier_file" ]; then
#     continue
#   fi
#   tier_base_name="${tier_file##*/}"
#   export APPLICATION_TIER="${tier_base_name%.env}"

#   for APPLICATION_SCRIPT in "${available_scripts[@]}"; do

#     echo "systemctl enable --now ${PROJECT_NAME}-${APPLICATION_TIER}-${APPLICATION_SCRIPT} || true"
#     sudo systemctl enable --now "${PROJECT_NAME}-${APPLICATION_TIER}-${APPLICATION_SCRIPT}" || true

#   done
# done

if [ "$1" == "cloudflare-auto" ]; then
  enable_services=("oauth2-proxy" "${PROJECT_NAME}-status-web.service" "cockpit.socket" "nginx")
else
  enable_services=("oauth2-proxy" "${PROJECT_NAME}-status-web.service" "cockpit.socket" "nginx" "cloudflare-update")
fi

for current_svc in "${enable_services[@]}"; do
  sudo systemctl restart "${current_svc}"
  sudo systemctl enable --now "${current_svc}"
done

sudo /usr/lib/systemd/systemd-sysv-install enable tor

echo "############################################"
echo "############################################"
echo "########     END SERVICE.D      ############"
echo "############################################"
echo "############################################"

# Check if the argument wants to quit
if [ "$1" == "serviced" ]; then
    echo "Quitting duo to argument '$1'."
    exit 0
fi


NETPLAN_FILE="/etc/netplan/50-cloud-init.yaml"

# Check if the renderer is already set to NetworkManager using sudo
if ! sudo grep -q "renderer: NetworkManager" "${NETPLAN_FILE}"; then
    # Add renderer: NetworkManager under the network: section
    sudo sed -i '/^network:/a \ \ renderer: NetworkManager' "${NETPLAN_FILE}"
    echo "NetworkManager renderer added to ${NETPLAN_FILE}"
    sudo netplan apply
else
    echo "Renderer is already set to NetworkManager in ${NETPLAN_FILE}"
fi


sudo rm -rf rm /etc/cockpit/disallowed-users || true
sudo touch /etc/cockpit/disallowed-users


echo "${USER_NAME}:${COCKPIT_PASSWORD}" | sudo chpasswd

echo "############################################"
echo "############################################"
echo "########    END SSHD CONFIG     ############"
echo "############################################"
echo "############################################"


