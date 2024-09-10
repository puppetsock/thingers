kubectl apply -f - <<EOF
apiVersion: "k8s.cni.cncf.io/v1"
kind: NetworkAttachmentDefinition
metadata:
  name: attachnet
  namespace: default
spec:
  config: '{
      "cniVersion": "0.3.0",
      "type": "kube-ovn",
      "server_socket": "/run/openvswitch/kube-ovn-daemon.sock",
      "provider": "attachnet.default.ovn"
    }'
---
apiVersion: kubeovn.io/v1
kind: Subnet
metadata:
  name: attachnet
spec:
  protocol: IPv4
  provider: attachnet.default.ovn
  cidrBlock: 10.10.10.0/24
  gateway: 10.10.10.1
  excludeIps:
  - 10.10.10.0..10.10.10.10
EOF

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jumppod
spec:
  selector:
    matchLabels:
      app: jumppod
  replicas: 1
  template:
    metadata:
      labels:
        app: jumppod
      annotations:
        k8s.v1.cni.cncf.io/networks: attachnet
    spec:
      containers:
      - name: jumppod
        image: ubuntu:20.04
        command:
          - bash
          - "-cex"
          - |
            apt-get update
            apt-get install -y openssh-client iputils-ping iproute2
            exec tail -f /dev/null
EOF

docker pull quay.io/port/kubevirt-images:ubuntu-focal
kind load docker-image --name kube-ovn quay.io/port/kubevirt-images:ubuntu-focal

kubectl create -f - <<EOF
apiVersion: kubevirt.io/v1
kind: VirtualMachine
metadata:
  name: ubuntu
spec:
  runStrategy: Always
  template:
    metadata:
      annotations:
        # Allow KubeVirt VMs with bridge binding to be migratable
        # also ovn-k will not configure network at pod, delegate it to DHCP
        kubevirt.io/allow-pod-bridge-network-live-migration: ""
    spec:
      domain:
        cpu:
          model: host-passthrough
          sockets: 1
          cores: 1
          threads: 1
        devices:
          disks:
            - disk:
                bus: virtio
              name: containerdisk
            - disk:
                bus: virtio
              name: cloudinit
          rng: {}
          interfaces:
            # - name: default
            #   bridge: {}
            #   ports:
            #     - name: ssh
            #       port: 22
            - name: test1
              bridge: {}
        features:
          acpi: {}
          smm:
            enabled: true
        firmware:
          bootloader:
            efi:
              secureBoot: true
        resources:
          requests:
            memory: 1Gi
      terminationGracePeriodSeconds: 180
      networks:
        # - name: default
        #   pod: {}
        - name: test1
          multus:
            networkName: attachnet
      volumes:
        - containerDisk:
            image: quay.io/port/kubevirt-images:ubuntu-focal
          name: containerdisk
        - cloudInitNoCloud:
            networkData: |
              version: 2
              ethernets:
                enp1s0:
                  dhcp4: true
                enp2s0:
                  dhcp4: true
            userData: |-
              #cloud-config
              # The default username is: ubuntu
              password: ubuntu
              chpasswd: { expire: False }
              runcmd:
                - sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
                - systemctl restart sshd
          name: cloudinit
EOF