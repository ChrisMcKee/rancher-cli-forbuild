#!/bin/sh

mkdir -p /home/rancher-cli/.rancher

echo Writing rancher CLI2 file ...

tee ~/.rancher/cli2.json > /dev/null <<EOF
{
  "Servers":
  {
    "rancherDefault":
    {
      "accessKey":"$RANCHER_ACCESS_KEY",
      "secretKey":"$RANCHER_SECRET_KEY",
      "tokenKey":"$RANCHER_ACCESS_KEY:RANCHER_SECRET_KEY",
      "url":"$RANCHER_URL",
      "project":"$RANCHER_ENVIRONMENT",
      "cacert":"$RANCHER_CACERT"
    }
  },
  "CurrentServer":"rancherDefault"
}
EOF

exec "$@"