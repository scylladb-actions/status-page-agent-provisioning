resource "scylladbcloud_cluster" "aws" {
  name       = "AWS-statuspage-test"
  cloud      = "AWS"
  region     = "us-east-1"
  node_count = 3
  node_type  = "t3.micro"
  cidr_block = "172.31.0.0/24"
  enable_dns = true
}

resource "scylladbcloud_cluster" "gcp" {
  name       = "GCP-statuspage-test"
  cloud      = "GCP"
  region     = "us-east1"
  node_count = 3
  node_type  = "n2-highmem-2"
  cidr_block = "172.31.1.0/24"
  enable_dns = true
}

#resource "scylladbcloud_serverless_cluster" "k8s" {
#  name = "K8S-statuspage-test"
#  units = 1
#  hours = 1
#  free_tier = true
#  enable_dns = true
#}

output "cluster_id_aws" {
  value = scylladbcloud_cluster.aws.id
}

output "cluster_id_gcp" {
  value = scylladbcloud_cluster.gcp.id
}

#output "cluster_id_k8s" {
#  value = scylladbcloud_serverless_cluster.k8s.id
#}
