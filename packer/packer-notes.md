
Create the resource group:

    az group create --location <LOCATION> --name <NAME>

Create the service principal

    az ad sp create-for-rbac --name <NAME>

Outputs:

    {
    "appId": "<CLIENT-ID>",
    "displayName": "<NAME>",
    "name": "http://<NAME>",
    "password": "<CLIENT-SECRET>",
    "tenant": "<TENANT-ID>"
    }
