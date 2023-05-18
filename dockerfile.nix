FROM nixos/nix:2.15.0
RUN nix-channel --update
RUN nix-env -i bash curl git gnused
RUN nix-env -iA nixpkgs.rancher nixpkgs.kubectl nixpkgs.kubernetes-helm nixpkgs.iputils nixpkgs.iproute2 nixpkgs.envsubst nixpkgs.gzip nixpkgs.cacert nixpkgs.coreutils

# Define rancher version
ENV RANCHER_CLI_VERSION=v2.7.0 \
  RANCHER_URL= \
  RANCHER_ACCESS_KEY= \
  RANCHER_SECRET_KEY= \
  RANCHER_ENVIRONMENT= \
  RANCHER_CACERT=

#https://storage.googleapis.com/kubernetes-release/release/stable.txt
ENV HELM_VERSION=v3.12.0

RUN ls / -lsa && ls /bin/ -lsa

COPY --chmod=755 docker-entrypoint.sh /
COPY --chmod=755 kubesubst.sh /bin/

ENTRYPOINT ["/docker-entrypoint.sh"] 

# Set working directory
WORKDIR /home/rancher-cli

# Executing defaults
CMD ["/bin/bash"]

LABEL maintainer="Chris McKee <pcdevils+ranchercli@gmail.com>"
