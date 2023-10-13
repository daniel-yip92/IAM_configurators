#!/bin/bash
# This script is used for adding permission policies to existing AWS users in configured AWS account.
# The script will append the requested AWS services to the the user's YAML file in the respective directory
# then the change will be made by running iambic apply.

# User Input
echo "What is the AWS account name?"
read aws_account

echo "What is the username of the user to give access to?"
read username

if ! find resources/aws/iam/user/$aws_account/$username.yaml
then
        echo "Please enter a valid account or username."
        exit
fi

echo "What is the service to be granted? (s3 / iam / ec2 / cloudformation)"
read service

# Associated User YAML
filename=resources/aws/iam/user/$aws_account/$username.yaml

# Allows multi-line quote to be read by sed
# credit to mklelement0 on stackoverflow
# https://stackoverflow.com/questions/29613304/is-it-possible-to-escape-regex-metacharacters-reliably-with-sed
quoteSubst() {
  IFS= read -d '' -r < <(sed -e ':a' -e '$!{N;ba' -e '}' -e 's/[&/\]/\\&/g; s/\n/\\&/g' <<<"$1")
  printf %s "${REPLY%$'\n'}"
}

# Inline policy to be added
inline_policy="
  inline_policies:
    - policy_name: iambic_grant_$service
      statement:
        - action:
            - $service:*
          effect: Allow
          resource:
            - '*'
          sid: Statement1
      version: '2012-10-17'"

existing_policies="inline_policies"

if grep -q "$existing_policies" <<< "$filname"
then
        adding_policy=$(echo "$inline_policy" | sed 2d)
        echo "Adding to existing policies."
        
        # Appends inline policy to user YAML
        sed -i "/^ *inline_policies:/a $(quoteSubst "$adding_policy")" $filename
else

echo "No existing policies exist, adding new inline policy"

# Appends inline policy to user YAML
sed -i "/^properties:/a $(quoteSubst "$inline_policy")" $filename

fi

# Applies change through iambic apply
python venv/lib/python3.10/site-packages/iambic/main.py apply $filename
