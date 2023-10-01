# Multi Environment Control

This Repo defines the automation to deploy the branch environments CICD pipeline.

This repo will create deployment environment specific objects including Service Principals and Azure resource groups for managing terraform state and deployment of resources.

A Github access token will be used by a workflow in this environment, to create deployment secrets in an environment in the project gtihub repo.

1. Create an access token from a Github account.

```
gh workflow run application.yml -R "robinmordasiewicz/multi-environment-controller" -f "application=cm9iaW5tb3JkYXNpZXdpY3ovZm9ydGluZXQtc2VjdXJlLWNsb3VkLWJsdWVwcmludC10ZXJyYWZvcm0="
```
