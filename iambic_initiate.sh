#!/bin/bash
# This script creates the working directory for the iambic project
# and installs the necessary packages to use iambic

# Create base directory for Iambic templates
n=""
mkdir iambic_templates$n

status=$?

if [ "$status" != 0 ]
then
        while [ "$status" != 0 ]
                do
                        n=$((n + 1))
                        mkdir iambic_templates$n
                        status=$?
                        
                done
fi

filename=$(find "iambic_templates$n")

cd $filename

# Activate virtual environment
python3 -m venv venv
source venv/bin/activate

# Install required packages
# Iambic
pip install iambic-core
# AZ CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
# AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
# Azure DevOps
az extension add --name azure-devops
