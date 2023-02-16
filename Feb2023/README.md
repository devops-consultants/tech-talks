# Links from the Slide Decks

## Automating the Boring Stuff

* [github.com/devops-consultants/tech-talks](https://github.com/devops-consultants/tech-talks)
* [cert-manager.io/docs](https://cert-manager.io/docs)
* [github.com/kubernetes-sigs/external-dns](https://github.com/kubernetes-sigs/external-dns)

---

## Authenticating without Passwords

* [github.com/devops-consultants/tech-talks](https://github.com/devops-consultants/tech-talks)
* [goteleport.com/](https://goteleport.com/)
* [docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
* [docs.gitlab.com/ee/ci/cloud_services/aws/](https://docs.gitlab.com/ee/ci/cloud_services/aws/)
* <https://youtu.be/M5hJwl2ewTk>

---

## Teleport Demo Infrastructure

The `terraform` folder contains the infrastructure definition used for both demos. Applying the terraform
will create the following:

* VPC with Public, Private and Database subnets across 3 availability zones
* Internet Gateway and NAT gateway and associated route tables
* Aurora RDS MySQL database in the database subnets
* EKS cluster in the private subnets
* S3 bucket and DynamoDB to support the Teleport deployment
* Various IAM policies & Roles used by the k8s service accounts for accessing the aws resources
* Kubernetes deployments for Cluster Autoscaler, Node Termination Handler, External-DNS, Cert-Manager, Nginx Ingress Controller, Podman and Teleport

---

## GitHub Actions Pipeline

The pipeline used to demo the passwordless `bot` connectivity through Teleport can be found in the `.github/workflows/techtalks.yml` file
in the top level directory of this repository.
