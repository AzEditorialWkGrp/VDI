# Copyright (c) 2019 Teradici Corporation
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

#!/bin/bash

AD_SERVICE_ACCOUNT_PASSWORD=${ad_service_account_password}
CAC_TOKEN=${cac_token}
CAC_BIN_PATH="/usr/sbin/cloud-access-connector"
PCOIP_REGISTRATION_CODE=${pcoip_registration_code}
INSTALL_DIR="/root"
INSTALL_LOG="/root/cac-install.log"
sudo touch $INSTALL_LOG
sudo chmod +644 "$INSTALL_LOG"
sudo cd $INSTALL_DIR

log() {
    local message="$1"
    echo "[$(date)] $${message}" | tee -a "$INSTALL_LOG"
}

exit_and_restart()
{
    log "--> Rebooting"
    (sleep 1; reboot -p) &
    exit
}

log "Starting the logging document..."
log "$PCOIP_REGISTRATION_CODE | $AD_SERVICE_ACCOUNT_PASSWORD | $CAC_TOKEN"

if [[ -f "$INSTALL_DIR/cloud-access-connector" ]]; then
    log "Connector already installed. Skipping startup script."
    exit 0
fi

get_access_token() {
    accessToken=`curl -X POST -d "grant_type=client_credentials&client_id=$1&client_secret=$2&resource=https%3A%2F%2Fvault.azure.net" https://login.microsoftonline.com/$3/oauth2/token`
    token=$(echo $accessToken | jq ".access_token" -r)
    log "Access Token: $token"
    output=`curl -X GET -H "Authorization: Bearer $token" -H "Content-Type: application/json" --url "$4?api-version=2016-10-01"`
    log "Output: $output"
    output=$(echo $output | jq '.value')
    output=$(echo $output | sed 's/"//g')
    log "Output: $output"
    echo "Output: $output"
}

get_credentials() {
    # Check if we need to get secrets from Azure Key Vault
    if [[ -z "$1" && -z "$2" && -z "$3" && -z "$4" && -z "$5" ]]; then
        log "Not getting secrets from Azure Key Vault. Exiting get_credentials..."
    else
        log "Getting secrets from Azure Key Vault. Using the following passed variables: $2, $1, $3, $4, $5, $6"
        get_access_token $2 $1 $3 $4
        PCOIP_REGISTRATION_CODE=$output
        log "Registration Code: $PCOIP_REGISTRATION_CODE"
        get_access_token $2 $1 $3 $5
        AD_SERVICE_ACCOUNT_PASSWORD=$output
        log "Active Directory Password: $AD_SERVICE_ACCOUNT_PASSWORD"
        get_access_token $2 $1 $3 $6
        CAC_TOKEN=$output
        log "Cloud Access Token: $CAC_TOKEN"
    fi
}

sudo apt-get -y update

sudo apt-get install -y wget

sudo apt-get install -y jq

get_credentials ${aad_client_secret} ${application_id} ${tenant_id} ${pcoip_secret_key} ${ad_pass_secret_key} ${cac_token_secret_key}

# Network tuning
PCOIP_NETWORK_CONF_FILE="/etc/sysctl.d/01-pcoip-cac-network.conf"

log "Running the configuration of the network..."

if [ ! -f $PCOIP_NETWORK_CONF_FILE ]; then
    # Note the indented HEREDOC lines must be preceded by tabs, not spaces
    cat <<- EOF > $PCOIP_NETWORK_CONF_FILE
	# System Control network settings for CAC
	net.core.rmem_max=160000000
	net.core.rmem_default=160000000
	net.core.wmem_max=160000000
	net.core.wmem_default=160000000
	net.ipv4.udp_mem=120000 240000 600000
	net.core.netdev_max_backlog=2000
	EOF

    sysctl -p $PCOIP_NETWORK_CONF_FILE
fi

log "Downloading the CAC Installer..."

# download CAC installer
sudo curl -L ${cac_installer_url} -o $INSTALL_DIR/cloud-access-connector.tar.gz
sudo tar xzvf $INSTALL_DIR/cloud-access-connector.tar.gz --no-same-owner -C /


# Wait for service account to be added
# do this last because it takes a while for new AD user to be added in a
# new Domain Controller
# Note: using the domain controller IP instead of the domain name for the
#       host is more resilient
log '### Installing ldap-utils ###'
RETRIES=5
while true; do
    sudo apt-get -qq update
    sudo apt-get -qq install ldap-utils
    RC=$?
    if [ $RC -eq 0 ] || [ $RETRIES -eq 0 ]; then
        break
    fi

    log "Error installing ldap-utils. $RETRIES retries remaining..."
    RETRIES=$((RETRIES-1))
    sleep 5
done

log '### Ensure AD account is available ###'
TIMEOUT=1200
until ldapwhoami \
    -H ldap://${domain_controller_ip} \
    -D ${ad_service_account_username}@${domain_name} \
    -w $AD_SERVICE_ACCOUNT_PASSWORD \
    -o nettimeout=1; do
    if [ $TIMEOUT -le 0 ]; then
        break
    else
        log "Waiting for AD account ${ad_service_account_username}@${domain_name} to become available. Retrying in 10 seconds... (Timeout in $TIMEOUT seconds)"
    fi
    TIMEOUT=$((TIMEOUT-10))
    sleep 10
done

# Check that the domain name can be resolved and that the LDAP port is accepting
# connections. This could have been all done with the ldapwhoami command, but
# due to a number of occasional cac-installation issues, such as "domain
# controller unreachable" or "DNS error occurred" errors, check these explicitly
# for logging and debug purposes.

echo '### Ensure domain ${domain_name} can be resolved ###'
TIMEOUT=1200
until host ${domain_name}; do
    if [ $TIMEOUT -le 0 ]; then
        break
    else
        echo "Trying to resolve ${domain_name}. Retrying in 10 seconds... (Timeout in $TIMEOUT seconds)"
    fi
    TIMEOUT=$((TIMEOUT-10))
    sleep 10
done

echo '### Ensure domain ${domain_name} port 636 is reacheable ###'
TIMEOUT=1200
until netcat -vz ${domain_name} 636; do
    if [ $TIMEOUT -le 0 ]; then
        break
    else
        echo "Trying to contact ${domain_name}:636. Retrying in 10 seconds... (Timeout in $TIMEOUT seconds)"
    fi
    TIMEOUT=$((TIMEOUT-10))
    sleep 10
done

log '### Installing Cloud Access Connector ###'
RETRIES=3
export CAM_BASE_URI=${cam_url}

# Set pipefail option to return status of the connector install command
set -o pipefail



if [ -z "${ssl_key}" ]; then
    log "### Not installing ssl certificate ###"
    while true
    do
        $CAC_BIN_PATH install \
            -t $CAC_TOKEN \
            --accept-policies \
            --insecure \
            --sa-user ${ad_service_account_username} \
            --sa-password "$AD_SERVICE_ACCOUNT_PASSWORD" \
            --domain ${domain_name} \
            --domain-group "${domain_group}" \
            --reg-code $PCOIP_REGISTRATION_CODE \
            --sync-interval 5 \
            2>&1 | tee -a $INSTALL_LOG

        RC=$?
        if [ $RC -eq 0 ]
        then
            log "--> Successfully installed Cloud Access Connector."
            break
        fi

        if [ $RETRIES -eq 0 ]
        then
            exit 1
        fi

        log "--> ERROR: Failed to install Cloud Access Connector. $RETRIES retries remaining..."
        RETRIES=$((RETRIES-1))
        sleep 60
    done
else
    log "### Installing ssl certificate ###"
    wget ${_artifactsLocation}${ssl_key} $INSTALL_DIR
    wget ${_artifactsLocation}${ssl_cert} $INSTALL_DIR

    while true
    do
        ./cloud-access-connector install \
            -t $CAC_TOKEN \
            --accept-policies \
            --ssl-key $INSTALL_DIR/${ssl_key} \
            --ssl-cert $INSTALL_DIR/${ssl_cert} \
            --sa-user ${ad_service_account_username} \
            --sa-password "$AD_SERVICE_ACCOUNT_PASSWORD" \
            --domain ${domain_name} \
            --domain-group "${domain_group}" \
            --reg-code $PCOIP_REGISTRATION_CODE \
            --sync-interval 5 \
            2>&1 | tee -a $INSTALL_LOG

        RC=$?
        if [ $RC -eq 0 ]
        then
            log "--> Successfully installed Cloud Access Connector."
            break
        fi

        if [ $RETRIES -eq 0 ]
        then
            exit 1
        fi

        log "--> ERROR: Failed to install Cloud Access Connector. $RETRIES retries remaining..."
        RETRIES=$((RETRIES-1))
        sleep 60
    done
fi

docker service ls

log "### FINISHING INSTALLING CAC ###"