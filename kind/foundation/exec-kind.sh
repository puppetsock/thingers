#!/bin/bash
set -ex

make image-kube-ovn
make kind-init-cilium-chaining-ha
make kind-install-multus
make kind-install-cilium-chaining

helm upgrade cilium cilium/cilium --version 1.15.8 \
   --namespace kube-system \
   --reuse-values \
   --set hubble.relay.enabled=true \
   --set hubble.ui.enabled=true

make kind-install-kubevirt

kubectl apply -f - <<EOF
apiVersion: "k8s.cni.cncf.io/v1"
kind: NetworkAttachmentDefinition
metadata:
  name: migration
  namespace: kubevirt
spec:
  config: '{
      "cniVersion": "0.3.0",
      "type": "kube-ovn",
      "server_socket": "/run/openvswitch/kube-ovn-daemon.sock",
      "provider": "migration.default.ovn"
    }'
---
apiVersion: kubeovn.io/v1
kind: Subnet
metadata:
  name: migration
spec:
  protocol: IPv4
  provider: migration.default.ovn
  cidrBlock: 10.100.10.0/24
  gateway: 10.100.10.1
  excludeIps:
  - 10.100.10.0..10.100.10.10
EOF

kubectl -n kubevirt patch kubevirt kubevirt --type=merge --patch \
    '{"spec":{"configuration":{"developerConfiguration":{"useEmulation":false},"migrations":{"network":"default/migration"}},"infra":{"replicas":1}}}'

exec bash