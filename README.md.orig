# Control repository for deployment environments.

Service Pricipals are used to authenticate this workflow

[![Launch Cloud Shell](/azure/cloud-shell/media/embed-cloud-shell/launch-cloud-shell-1.png)](https://shell.azure.com)

https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/guides/service_principal_configuration#creating-a-service-principal

https://learn.microsoft.com/en-us/azure/active-directory/roles/custom-available-permissions

https://learn.microsoft.com/en-us/azure/developer/github/connect-from-azure?tabs=azure-cli%2Cwindows

Check Azure CLI login status.

```
az ad signed-in-user show --query 'id' -o tsv
```

If there is no output, then log in using
```
az login -o none
```

Check the default subscription.
```
az account show --query '[id,name]'
```

Use a different subscription.
```
az account set -s <yoursubscription>
```

Authenticate command line to github
```
gh auth login
```

Show Subscription Id.
```
az account show --query id -o tsv
```

Show Tenant ID.
```
az account show --query tenantId -o tsv
```

Check if an app with the same name exists, if so use it, if not create one
```
az ad app list --filter "displayName eq '$APP_NAME'" --query [].appId -o tsv
```

Create the app if it does not exist.
```
az ad app create --display-name ${APP_NAME} --query appId -o tsv
```

Check if the Service Principal already exists.
```
az ad sp list --filter "displayName eq '$APP_ID'" --query [].id -o tsv
```

Create service principal.
```
az ad sp create --id $APP_ID --query id -o tsv
```

Create role assignment.
```
az role assignment create --role contributor --subscription $SUB_ID --assignee-object-id $SP_ID --assignee-principal-type ServicePrincipal
```

https://www.youtube.com/watch?v=lsWOx9bzAwY

