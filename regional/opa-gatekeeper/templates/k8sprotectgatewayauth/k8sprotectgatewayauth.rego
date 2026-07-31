package k8sprotectgatewayauth

allowed_platform_principal if {
	input.review.userInfo.username in object.get(input.parameters, "allowedUsers", [])
}

allowed_platform_principal if {
	group := input.review.userInfo.groups[_]
	group in object.get(input.parameters, "allowedGroups", [])
}

protected_istio_kind if {
	protected_kind := object.get(input.parameters, "protectedKinds", [])[_]
	input.review.kind.group == protected_kind.apiGroup
	input.review.kind.kind == protected_kind.kind
}

protected_namespace if {
	input.review.kind.group == ""
	input.review.kind.kind == "Namespace"
	review_object.metadata.name in object.get(input.parameters, "protectedNamespaces", [])
}

protected_secret if {
	input.review.kind.group == ""
	input.review.kind.kind == "Secret"
	object.get(review_object.metadata, "namespace", "") in object.get(input.parameters, "protectedNamespaces", [])
}

review_object := obj if {
	obj := object.get(input.review, "object", null)
	obj != null
}

review_object := object.get(input.review, "oldObject", {}) if {
	object.get(input.review, "object", null) == null
}

violation contains {"msg": msg} if {
	not allowed_platform_principal
	protected_istio_kind
	msg := sprintf("gateway authn/authz resource %s/%s is platform-managed and may only be changed by platform principals", [input.review.kind.group, input.review.kind.kind])
}

violation contains {"msg": msg} if {
	not allowed_platform_principal
	protected_namespace
	msg := sprintf("namespace %q is platform-managed and may only be changed by platform principals", [review_object.metadata.name])
}

violation contains {"msg": msg} if {
	not allowed_platform_principal
	protected_secret
	msg := sprintf("secrets in platform-managed namespace %q may only be changed by platform principals", [object.get(review_object.metadata, "namespace", "")])
}
