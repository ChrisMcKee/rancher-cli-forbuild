FROM alpine:3.8

MAINTAINER Chris McKee <pcdevils@gmail.com>

# Define rancher version
ENV RANCHER_CLI_VERSION=v2.0.5 \
    YAML_VERSION=1.6 \
    RANCHER_URL= \
    RANCHER_ACCESS_KEY= \
    RANCHER_SECRET_KEY= \
    RANCHER_ENVIRONMENT= \
    RANCHER_CACERT=

ENV KUBE_LATEST_VERSION=v1.11.0
ENV HELM_VERSION=v2.11.0
ENV HELM_FILENAME=helm-${HELM_VERSION}-linux-amd64.tar.gz

ADD docker-entrypoint.sh /
RUN chmod +x /docker-entrypoint.sh

# Install dependencies and rancher
RUN apk update && \
    apk upgrade && \
    apk add --no-cache ca-certificates && \
    apk add openssh-client && \
    apk add iputils && \
    apk add iproute2 && \
    apk add curl && \
    apk add bash && \
    apk add --update gettext tar gzip
  
RUN curl -L https://storage.googleapis.com/kubernetes-release/release/${KUBE_LATEST_VERSION}/bin/linux/amd64/kubectl -o /usr/local/bin/kubectl

RUN curl -L https://storage.googleapis.com/kubernetes-helm/${HELM_FILENAME} | tar xz && mv linux-amd64/helm /bin/helm && rm -rf linux-amd64

RUN apk add --quiet --no-cache --virtual build-dependencies curl

RUN curl -sSL "https://github.com/rancher/cli/releases/download/${RANCHER_CLI_VERSION}/rancher-linux-amd64-${RANCHER_CLI_VERSION}.tar.gz" | tar -xz -C /usr/local/bin/ --strip-components=2

RUN chmod +x /usr/local/bin/rancher && \
  chmod +x /usr/local/bin/kubectl && \
	apk del build-dependencies && \
	rm -rf /var/cache/apk/*

RUN adduser -S rancher-cli
USER rancher-cli

ENTRYPOINT ["/docker-entrypoint.sh"] 

# Set working directory
WORKDIR /home/rancher-cli

# Executing defaults
CMD ["/bin/sh"]
