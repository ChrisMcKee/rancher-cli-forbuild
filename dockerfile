FROM alpine:3

# Define rancher version
ENV RANCHER_CLI_VERSION=v2.10.1 \
  RANCHER_URL= \
  RANCHER_ACCESS_KEY= \
  RANCHER_SECRET_KEY= \
  RANCHER_ENVIRONMENT= \
  RANCHER_CACERT=

#https://storage.googleapis.com/kubernetes-release/release/stable.txt
ENV HELM_VERSION=v3.17.0

COPY --chmod=755 docker-entrypoint.sh /
COPY --chmod=755 kubesubst.sh /usr/local/bin/kubesubst
COPY --chmod=755 deploy.sh /usr/local/bin/deploy
COPY --chmod=755 smoke.sh /usr/local/bin/smoke

# Install dependencies and rancher
RUN cd /tmp && apk update && \
  apk upgrade && \
  apk add --update --quiet --no-cache ca-certificates openssh-client iputils iproute2 curl bash gettext tar gzip envsubst bash jq yq ncurses coreutils unzip && \
  apk add --update --quiet --no-cache --virtual build-dependencies && \
  cd /tmp && curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
  unzip awscliv2.zip && \
  ./aws/install
  curl -L https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz | tar xz && mv linux-amd64/helm /bin/helm && rm -rf linux-amd64 && \
  curl -sSL "https://github.com/rancher/cli/releases/download/${RANCHER_CLI_VERSION}/rancher-linux-amd64-${RANCHER_CLI_VERSION}.tar.gz" | tar -xz -C /usr/local/bin/ --strip-components=2 && \
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && mv kubectl /usr/local/bin/kubectl && \
  chmod +x /usr/local/bin/rancher && \
  chmod +x /usr/local/bin/kubectl && \
  curl -L -o /usr/local/bin/canary-checker https://github.com/flanksource/canary-checker/releases/latest/download/canary-checker_linux_amd64 && \
  chmod +x /usr/local/bin/canary-checker && \
  apk del build-dependencies && \
  rm -rf /var/cache/apk/* && rm -rf /tmp/*

ENTRYPOINT ["/docker-entrypoint.sh"] 

SHELL [ "/bin/bash" ]

# Set working directory
WORKDIR /home/rancher-cli

# Executing defaults
CMD ["/bin/bash"]

LABEL maintainer="Chris McKee <pcdevils+ranchercli@gmail.com>"
