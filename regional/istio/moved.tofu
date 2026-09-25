# Moved Blocks
# https://opentofu.org/docs/language/moved

# The istio ConfigMap's mesh key is now rendered entirely through istiod's Helm values
# (mesh_config_extension_providers / mesh_config_service_settings module arguments).
# Forget the out-of-band overwrite without destroying it so the live mesh config is never
# deleted — the Helm release rewrites it authoritatively on the next apply.
removed {
  from = kubernetes_config_map_v1_data.istio_mesh_config

  lifecycle {
    destroy = false
  }
}
