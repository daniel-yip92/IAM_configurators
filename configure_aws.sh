#!/bin/bash
# This script configures the initial AWS account set up in Iambic to manage AWS resources

# User input for AWS Account details

echo "What is your AWS account id?"
read aws_id

echo "What is your AWS account profile name?"
read aws_name

# Create Hub and Spoke Roles in AWS through Cloudformation that allows managing AWS resources
aws cloudformation create-stack --stack-name IambicHubRole --template-body file://IambicHubRole.yml --parameters ParameterKey=HubRoleName,ParameterValue=IambicHubRole ParameterKey=SpokeRoleName,ParameterValue=IambicSpokeRole --capabilities CAPABILITY_NAMED_IAM

cat <<EOF > Hub_trust.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Deny",
            "Principal": {
                "Service": "ec2.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        },
        {
            "Sid": "Statement1",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::$aws_id:user/$aws_name"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF

echo "Creating HubRole"
sleep 25
echo "Done"

aws iam update-assume-role-policy --role-name IambicHubRole --policy-document file://Hub_trust.json

aws cloudformation create-stack --stack-name IambicSpokeRole --template-body file://IambicSpokeRole.yml --parameters ParameterKey=SpokeRoleName,ParameterValue=IambicSpokeRole ParameterKey=HubRoleArn,ParameterValue=arn:aws:iam::$aws_id:role/IambicHubRole --capabilities CAPABILITY_NAMED_IAM

echo "Creating SpokeRole"
sleep 25
echo "Done"

# Create Iambic config file
cat <<EOF > iambic_config.yaml
template_type: NOQ::Core::Config
version: "1"
aws:
  accounts:
    - account_id: $aws_id
      account_name: $aws_name
      hub_role_arn: arn:aws:iam::$aws_id:role/IambicHubRole
      iambic_managed: read_and_write
      spoke_role_arn: arn:aws:iam::$aws_id:role/IambicSpokeRole
EOF

# Imports the AWS resources into the Iambic template directory
python venv/lib/python3.10/site-packages/iambic/main.py import

