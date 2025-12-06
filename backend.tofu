# Backend Configuration
# https://opentofu.org/docs/language/settings/backends/gcs

# pt-pneuma uses state storage infrastructure created by pt-corpus.
# The bucket pt-pneuma-state-{env} is created in the pt-corpus project.

terraform {
  backend "gcs" {
    bucket = "pt-pneuma-state-prod"
    prefix = "pt-pneuma"
  }
}
