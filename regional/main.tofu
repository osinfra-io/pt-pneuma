# Google Kubernetes Engine Module (osinfra.io)
# https://github.com/osinfra-io/opentofu-google-kubernetes-engine

module "kubernetes_engine_regional" {
  for_each = local.gke_clusters
  source   = "github.com/osinfra-io/opentofu-google-kubernetes-engine//regional?ref=f56d2d830d0cc4f690c1791de46bc683fe2fa2b6" # v0.2.7

  cluster_prefix             = module.helpers.team
  enable_deletion_protection = false
  enable_gke_hub_host        = lookup(each.value, "enable_gke_hub_host", false)
  gke_hub_memberships        = lookup(each.value, "gke_hub_memberships", {})
  labels                     = module.helpers.labels
  master_ipv4_cidr_block     = var.kubernetes_engine_master_ipv4_cidr_block
  node_pools                 = lookup(each.value, "node_pools", {})
  project                    = local.main.project_id
  resource_labels            = module.helpers.labels
  subnet                     = local.subnet
  vpc_host_project_id        = local.main.shared_vpc_host_project_id
}

# Google Artifact Registry Repository
# https://search.opentofu.org/provider/hashicorp/google/latest/docs/resources/artifact_registry_repository

resource "google_artifact_registry_repository" "docker_standard" {
  for_each = local.docker_repositories

  description   = "Registry for multi-region - US Standard : ${module.helpers.team}"
  format        = "DOCKER"
  labels        = module.helpers.labels
  location      = "us"
  project       = local.main.project_id
  repository_id = "${each.key}-standard"
}

resource "google_artifact_registry_repository" "docker_remote" {
  lifecycle {
    enabled = var.enable_google_artifact_registries
  }

  description = "Registry for multi-region - US Docker Hub"
  format      = "DOCKER"
  labels      = module.helpers.labels
  location    = "us"
  mode        = "REMOTE_REPOSITORY"
  project     = local.main.project_id

  remote_repository_config {
    description = "docker hub"
    docker_repository {
      public_repository = "DOCKER_HUB"
    }
  }

  repository_id = "docker-remote"
}

resource "google_artifact_registry_repository" "docker_virtual" {
  for_each = local.docker_repositories

  description   = "Registry for multi-region - US Virtual : ${module.helpers.team}"
  format        = "DOCKER"
  labels        = module.helpers.labels
  location      = "us"
  mode          = "VIRTUAL_REPOSITORY"
  project       = local.main.project_id
  repository_id = "${each.key}-virtual"

  virtual_repository_config {
    upstream_policies {
      id         = each.key
      priority   = 20
      repository = google_artifact_registry_repository.docker_standard[each.key].id
    }

    upstream_policies {
      id         = "docker"
      priority   = 10
      repository = google_artifact_registry_repository.docker_remote.id
    }
  }
}

# Google Artifact Registry IAM Binding
# https://search.opentofu.org/provider/hashicorp/google/latest/docs/resources/artifact_registry_repository_iam

resource "google_artifact_registry_repository_iam_binding" "docker_virtual_readers" {
  for_each = local.docker_repositories

  location   = "us"
  members    = each.value.registry_readers
  project    = local.main.project_id
  repository = google_artifact_registry_repository.docker_virtual[each.key].id
  role       = "roles/artifactregistry.reader"
}

resource "google_artifact_registry_repository_iam_binding" "docker_standard_writers" {
  for_each = local.docker_repositories

  location   = "us"
  members    = each.value.registry_writers
  project    = local.main.project_id
  repository = google_artifact_registry_repository.docker_standard[each.key].id
  role       = "roles/artifactregistry.writer"
}
