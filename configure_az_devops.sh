#!/bin/bash
# This script sets up the initial Azure DevOps repos

echo "Enter your Azure DevOps organisation name"
read dev_ops_name

echo "Enter your Azure DevOps Project name"
read dev_ops_project

repo_name=IAMBIC_Templates

az devops configure -d organization=https://dev.azure.com/$dev_ops_name/
az devops configure -d project=$dev_ops_project
az repos create --name $repo_name

$repo_url=$(az repos show -r $repo_name | grep -oP '(?<="webUrl": ")[^"]*')
match="https://"
insert=$dev_ops_name@

full_repo_url=$(echo $repo_url | sed "s|"$match"|&"$insert"|g")

git init
git remote add origin $full_repo_url
git push -u origin --all
