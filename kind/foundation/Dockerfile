FROM mcr.microsoft.com/cbl-mariner/base/core:2.0

SHELL [ "/usr/bin/bash", "-cex" ]

RUN tdnf distro-sync -y; \
    tdnf install -y \
        ca-certificates \
        git \
        golang \
        glibc-devel \
        gawk \
        moby-cli \
        jq \
        kubernetes-client \
        binutils \
        helm \
        sudo \
        kernel-headers \
        procps-ng \
        kubevirt-virtctl \
        diffutils ;\
    tdnf autoremove; \
    tdnf clean all

RUN curl -Lo /usr/local/bin/kind https://kind.sigs.k8s.io/dl/v0.24.0/kind-linux-amd64 ;\
    chmod +x /usr/local/bin/kind
RUN mkdir -p /usr/libexec/docker/cli-plugins ;\
    curl -Lo /usr/libexec/docker/cli-plugins/docker-buildx https://github.com/docker/buildx/releases/download/v0.16.2/buildx-v0.16.2.linux-amd64 ;\
    chmod +x /usr/libexec/docker/cli-plugins/docker-buildx

RUN python3 -m venv /var/lib/py-venv ;\
    source /var/lib/py-venv/bin/activate ;\
    pip install --upgrade pip ;\
    pip install --upgrade wheel ;\
    pip install --upgrade setuptools

ENV PATH="/var/lib/py-venv/bin:${PATH}"

RUN pip install \
        jinjanator[yaml] \
        j2cli


RUN go install github.com/securego/gosec/v2/cmd/gosec@latest
ENV PATH="${PATH}:/root/go/bin"
RUN curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $(go env GOPATH)/bin v1.60.3

WORKDIR /opt

RUN git clone https://github.com/kubeovn/kube-ovn.git; \
    cd kube-ovn; \
    git checkout master

WORKDIR /opt/kube-ovn
RUN bash ./dist/images/install-cilium-cli.sh

RUN curl -Lo /usr/local/bin/kubectl-ko  https://raw.githubusercontent.com/kubeovn/kube-ovn/release-1.12/dist/images/kubectl-ko ;\
    chmod +x /usr/local/bin/kubectl-ko

RUN export VERSION=$(curl https://storage.googleapis.com/kubevirt-prow/release/kubevirt/kubevirt/stable.txt) ;\
    curl -Lo /usr/local/bin/virtctl https://github.com/kubevirt/kubevirt/releases/download/${VERSION}/virtctl-${VERSION}-linux-amd64 ;\
    chmod +x /usr/local/bin/virtctl

ADD exec-kind.sh /usr/local/bin/exec-kind.sh

CMD [ "/usr/local/bin/exec-kind.sh" ]