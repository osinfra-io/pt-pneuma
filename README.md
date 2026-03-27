# Pneuma

[![Dependabot](https://img.shields.io/github/actions/workflow/status/osinfra-io/pt-pneuma/dependabot.yml?style=for-the-badge&logo=github&color=2088FF&label=Dependabot)](https://github.com/osinfra-io/pt-pneuma/actions/workflows/dependabot.yml) [![Datadog Security Enabled](https://img.shields.io/badge/Datadog%20Security-Enabled-632CA6?style=for-the-badge&logo=datadog)](https://app.datadoghq.com/security/code-security/repositories?repository_id=pt-pneuma)

## 📄 Repository Description

This repository contains the Infrastructure as Code (IaC) that shapes the Pneuma domain — the breathing, dynamic layer of the platform where structure comes alive. In the wider hierarchy of the Platform Team, Pneuma serves as the stratum where Corpus projects and networking become animated workload environments capable of receiving and running application teams.

Here, Kubernetes clusters are called into being across multiple zones; certificate management, service mesh, and policy enforcement are woven into each cluster; and Datadog observability extends its reach into the runtime so the platform can perceive and regulate itself at the application layer.

The Pneuma layer is where infrastructure breathes — where the static order established by Logos and the tangible form given by Corpus are joined by living workloads, dynamic routing, and continuous delivery. It is the atmosphere within which application teams move, build, and ship.

The infrastructure automates the creation of:

- **GKE Clusters** deployed across multiple zones for high availability and geographic redundancy
- **Certificate Management** with cert-manager and Istio CSR for mTLS and workload identity
- **Service Mesh** with Istio for traffic management, observability, and secure service-to-service communication
- **Datadog Integration** with cluster-level monitoring, APM, and infrastructure visibility
- **Policy Enforcement** with OPA Gatekeeper for admission control and governance
- **Namespace Onboarding** with workload identity setup for application teams

This establishes the Kubernetes runtime layer, providing a consistent, secure, and observable environment for all application workloads running on the platform.

## 🏭 Platform Information

- Documentation: [docs.osinfra.io](https://docs.osinfra.io/product-guides/google-cloud-platform/pneuma)
- Service Interfaces: [github.com](https://github.com/osinfra-io/pt-pneuma/issues/new/choose)

## <img align="left" width="35" height="35" src="https://github.com/user-attachments/assets/eb98a3be-2ffe-4c05-91a4-072fe795a167"> Development

Our focus is on the core fundamental practice of platform engineering, Infrastructure as Code.

>Open Source Infrastructure (as Code) is a development model for infrastructure that focuses on open collaboration and applying relative lessons learned from software development practices that organizations can use internally at scale. - [Open Source Infrastructure (as Code)](https://www.osinfra.io)

To avoid slowing down stream-aligned teams, we want to open up the possibility for contributions. The Open Source Infrastructure (as Code) model allows team members external to the platform team to contribute with only a slight increase in cognitive load. This section is for developers who want to contribute to this repository, describing the tools used, the skills, and the knowledge required, along with OpenTofu documentation.

See the [documentation](https://docs.osinfra.io/fundamentals/development-setup) for setting up a development environment.

### 🛠️ Tools

- [pre-commit](https://github.com/pre-commit/pre-commit)
- [osinfra-pre-commit-hooks](https://github.com/osinfra-io/pt-techne-pre-commit-hooks)

### 📋 Skills and Knowledge

Links to documentation and other resources required to develop and iterate in this repository successfully.

- [cert-manager](https://cert-manager.io/docs/)
- [datadog kubernetes monitoring](https://docs.datadoghq.com/containers/kubernetes/)
- [google kubernetes engine](https://cloud.google.com/kubernetes-engine/docs)
- [istio service mesh](https://istio.io/latest/docs/)
- [kubernetes](https://kubernetes.io/docs/home/)
- [opa gatekeeper](https://open-policy-agent.github.io/gatekeeper/website/docs/)
