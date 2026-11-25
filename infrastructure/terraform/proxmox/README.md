# DHCP01 - Terraform

Contenidor Debian 13, ID 201, IP 10.11.0.136/26, gateway 10.11.0.129, bridge vmbr0, 1 CPU, 512 MB RAM i 6 GB a local-lvm.

Credencials: terraform.local.tfvars, fitxer local amb permisos 600 i exclòs de Git.

Desplegament:

terraform init
terraform fmt
terraform validate
terraform plan -var-file=terraform.local.tfvars
terraform apply -var-file=terraform.local.tfvars

Comprovació: pct list, accés SSH i terraform plan sense canvis.
