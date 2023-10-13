#!/bin/bash
# This script is used for creating new users in configured AWS or Azure accounts.
# The script will generate the user YAML file in the respective directory
# then the change will be made by running iambic apply.

# User input for initialisation
echo "Set up New User for AWS(1), Azure(2), or both(3)?"
read init

echo -e "What is the username of the new user?\n
        Valid characters are: A-Z a-z 0-9 . - _ "
read username
        if [ -z "$username" ]
        then
                echo "Please provide a username."
                exit
        fi
        
# Define user create functions
AWS_User_Create () {
	echo "this is function number $init, AWS Create"
	echo "username will be $username"

# AWS User Template
cat<<EOF > resources/aws/iam/user/$aws_account/$username.yaml
template_type: NOQ::AWS::IAM::User
template_schema_url: https://docs.iambic.org/reference/schemas/aws_iam_user_template
included_accounts:
  - $aws_account
identifier: $username
properties:
  credentials:
    access_keys: []
    password:
      enabled: false
      last_used: Never
  user_name: $username
EOF

}

AZURE_User_Create () {
	echo "this is function number $init, Azure Create"
	echo "username will be $username"
	
# Azure User Template
cat <<EOF > resources/azure_ad/user/$az_account/$username@$domain.yaml
template_type: NOQ::AzureAD::User
template_schema_url: https://docs.iambic.org/reference/schemas/azure_active_directory_user_template
idp_name: $az_account
properties:
  display_name: $username
  given_name: $username
  username: $username@$domain
EOF

}

# Expire function to set access expiry. Inserts expiry property in the user YAML file.
Expire_Func () {
        echo -e "When will the user access expire? (Date and time the resource will be deleted./n
                Example: 'in 3 days', '2023-10-16', '2023-08-31T12:00:00')"
        read expiry_time        
        if [ $# -eq 2 ]
        then
                sed -i "1s/^/expires_at: $expiry_time\n/" $1
                sed -i "1s/^/expires_at: $expiry_time\n/" $2
        else
                sed -i "1s/^/expires_at: $expiry_time\n/" $1
        fi
}

# Call functions
if [ $init -eq 1 ]
then
        echo "What is the AWS account name?"
        read aws_account
        
        AWS_User_Create
        # Store new user file path as variables
        awsNewFile=resources/aws/iam/user/$aws_account/$username.yaml
        
        echo "Set expiry for $username? Y/N"
        read expiry_choice        
                if [ $expiry_choice = "y" ] || [ $expiry_choice = "Y" ]
                then
                        Expire_Func $awsNewFile
                fi
        
        python venv/lib/python3.10/site-packages/iambic/main.py apply $awsNewFile
else
	if [ $init -eq 2 ]
	then
	echo "What is the Azure account name?"
        read az_account
        
        # Set UserPrincipalName as the domain for creating users:
        domain=$(az rest --method get --url 'https://graph.microsoft.com/v1.0/domains?$select=id' | grep -oP '(?<="id": ")[^"]*')

        
	AZURE_User_Create
	
        # Store new user file path as variables
        azNewFile=resources/azure_ad/user/$az_account/$username@$domain.yaml
        
        echo "Set expiry for $username? Y/N"
        read expiry_choice        
                if [ $expiry_choice = "y" ] || [ $expiry_choice = "Y" ]
                then
                        Expire_Func $azNewFile
                fi                
                
        python venv/lib/python3.10/site-packages/iambic/main.py apply $azNewFile	
else
	if [ $init -eq 3 ]
	then
	
	echo "What is the Azure account name?"
        read az_account
        
        # Set UserPrincipalName as the domain for creating users:
        domain=$(az rest --method get --url 'https://graph.microsoft.com/v1.0/domains?$select=id' | grep -oP '(?<="id": ")[^"]*')
        
        AZURE_User_Create
	
        # Store new user file path as variables
        azNewFile=resources/azure_ad/user/$az_account/$username@$domain.yaml
        
        echo "What is the AWS account name?"
        read aws_account
        
        AWS_User_Create
        # Store new user file path as variables
        awsNewFile=resources/aws/iam/user/$aws_account/$username.yaml
        
        echo "Set expiry for $username? Y/N"
        read expiry_choice        
                if [ $expiry_choice = "y" -o $expiry_choice = "Y" ]
                then
                        Expire_Func $azNewFile $awsNewFile
                fi
        	        
        python venv/lib/python3.10/site-packages/iambic/main.py apply $azNewFile $awsNewFile
	        
	        else
# Input other than 1 or 2 or 3
		echo "Please enter a value of either 1/2/3"
	        
	        fi
        fi
fi

exit
