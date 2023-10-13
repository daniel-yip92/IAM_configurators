#!/bin/bash
# This script creates the AZ AD application that manages the users and permissions

echo "What is your Azure organisation name?"
read az_org

# Create new app:
az ad app create --display-name iambic --sign-in-audience AzureADMyOrg

# Add permissions for MS graph
# Variable for MS graph:
graphId=$(az ad sp list --query "[?appDisplayName=='Microsoft Graph'].appId | [0]" | tr -d '"')

# echo $graphId

# Variable for permissions:
userReadWrite=$(az ad sp show --id $graphId --query "appRoles[?value=='User.ReadWrite.All'].id | [0]" | tr -d '"')

groupReadWrite=$(az ad sp show --id $graphId --query "appRoles[?value=='Group.ReadWrite.All'].id | [0]" | tr -d '"')

directoryReadWrite=$(az ad sp show --id $graphId --query "appRoles[?value=='Directory.ReadWrite.All'].id | [0]" | tr -d '"')

approleassignmentReadWrite=$(az ad sp show --id $graphId --query "appRoles[?value=='AppRoleAssignment.ReadWrite.All'].id | [0]" | tr -d '"')

applicationReadWrite=$(az ad sp show --id $graphId --query "appRoles[?value=='Application.ReadWrite.All'].id | [0]" | tr -d '"')

# Get app Id:
appId=$(az ad app list | grep -oP '(?<="appId": ")[^"]*')

echo $appId

# Create service principal for granting app permissions
az ad sp create --id $appId
spId=$(az ad sp show --id $appId --query "id" --output tsv)
graphSpId=$(az ad sp show --id $graphId --query "id" --output tsv)

# Add list of permissions:
az ad app permission add \
  --id $appId \
  --api $graphId \
  --api-permissions \
	$applicationReadWrite=Role \
	$approleassignmentReadWrite=Role \
	$directoryReadWrite=Role \
	$groupReadWrite=Role \
	$userReadWrite=Role

echo "Granting permissions"
az ad app permission list --id $appId

# Grant admin-consent:
az rest --method POST --uri https://graph.microsoft.com/v1.0/servicePrincipals/$spId/appRoleAssignments --body "{ \"principalId\": \"$spId\", \"resourceId\": \"$graphSpId\", \"appRoleId\": \"$applicationReadWrite\" }"
az rest --method POST --uri https://graph.microsoft.com/v1.0/servicePrincipals/$spId/appRoleAssignments --body "{ \"principalId\": \"$spId\", \"resourceId\": \"$graphSpId\", \"appRoleId\": \"$approleassignmentReadWrite\" }"
az rest --method POST --uri https://graph.microsoft.com/v1.0/servicePrincipals/$spId/appRoleAssignments --body "{ \"principalId\": \"$spId\", \"resourceId\": \"$graphSpId\", \"appRoleId\": \"$directoryReadWrite\" }"
az rest --method POST --uri https://graph.microsoft.com/v1.0/servicePrincipals/$spId/appRoleAssignments --body "{ \"principalId\": \"$spId\", \"resourceId\": \"$graphSpId\", \"appRoleId\": \"$groupReadWrite\" }"
az rest --method POST --uri https://graph.microsoft.com/v1.0/servicePrincipals/$spId/appRoleAssignments --body "{ \"principalId\": \"$spId\", \"resourceId\": \"$graphSpId\", \"appRoleId\": \"$userReadWrite\" }"

sleep 30
echo "Done"

# Get tenant Id:
tenantId=$(az account list | grep -oP '(?<="tenantId": ")[^"]*')

# Get Email:
userEmail=$(az account list | grep -oP '(?<="name": ")[^"]*' | grep $".com")

# Create Secret:
password=$(az ad app credential reset --id $appId | grep -oP '(?<="password": ")[^"]*')

# Create environment variables:
export AZURE_IDP_NAME=$az_org
export AZURE_TENANT_ID=$tenantId
export AZURE_CLIENT_ID=$appId
export AZURE_CLIENT_SECRET=$password
export AZURE_TEST_USER_EMAIL=$userEmail

echo "Creating app secret file"

# Create Secrets file:
cat <<EOF > secrets.yaml
secrets:
  azure_ad:
    organizations:
      - idp_name: $AZURE_IDP_NAME
        tenant_id: $AZURE_TENANT_ID
        client_id: $AZURE_CLIENT_ID
        client_secret: $AZURE_CLIENT_SECRET
EOF

# Append Azure Secrets ref to iambic config.
cat <<EOF >> iambic_config.yaml
extends:
  - key: LOCAL_FILE
    value: secrets.yaml
EOF

sleep 10
echo "Done"

# Imports the Azure resources into the Iambic template directory
python venv/lib/python3.10/site-packages/iambic/main.py import
