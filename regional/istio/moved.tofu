# Moved Blocks
# https://opentofu.org/docs/language/moved

# The istio ConfigMap mesh key is now rendered by istiod's Helm values. Forget the old
# overwrite without deleting the live key; remove this block once applied in every environment.
removed {
  from = kubernetes_config_map_v1_data.istio_mesh_config

  lifecycle {
    destroy = false
  }
}
