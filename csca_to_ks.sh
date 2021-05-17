#!/usr/bin/env bash

[[ -n ${DEBUG} ]] && set -x

################################################################################
# Script to convert a CSCA masterlist into a Java keystore
#
# Usage: ./csca_to_ks.sh <masterlist> <ca-certificate>
#           - masterlist: the CMS message containing the masterlist
#           - ca-certificate: the CA certificate used to check the masterlist signing certificate
################################################################################

CMS_MESSAGE=$1
SIGNING_CERT=$2

if [[ -f "$CMS_MESSAGE" ]]; then
    echo "$CMS_MESSAGE exists."
else
    echo "CMS_MESSAGE missing as \$1"
    exit 1
fi

if [[ -f "$SIGNING_CERT" ]]; then
    echo "$SIGNING_CERT exists."
else
    echo "SIGNING_CERT missing as \$2"
    exit 1
fi

if [[ -d "/certs" ]]; then
  echo "Exporting to /certs"
else
  echo "Error: /certs not found attempting to create"
  mkdir /certs || exit 1
fi

openssl x509 -inform der -in $SIGNING_CERT -out /certs/signing_ca.pem

if [[ -d "/tmp/certs" ]]; then
  echo "removeing old tmp certs"
  rm -rf /tmp/certs || exit 1
fi

mkdir /tmp/certs || exit 1


# Verify ML signature and extract ML from CMS message
openssl cms -in "${CMS_MESSAGE}" -inform der -verify -out /tmp/certs/ml.der -certsout signing.pem -noverify || exit 1
openssl verify -CAfile /certs/signing_ca.pem signing.pem && rm signing.pem || exit 1

cd /tmp/certs
eval $(openssl asn1parse -in ml.der -inform der -i | \
       awk "/:d=1/{b=0}
            /:d=1.*SET/{b=1}
	        /:d=2/&&b{print}" |\
       sed 's/^ *\([0-9]*\).*hl= *\([0-9]*\).*l= *\([0-9]*\).*/ \
	     dd if=ml.der bs=1 skip=\1 count=$((\2+\3)) 2>\/dev\/null | openssl x509 -inform der -out cert.\1.pem -outform pem;/')

for cert in cert.*.pem; do
  echo "Adding: ${cert}"
	keytool -alias ${cert} -importcert -noprompt -file ${cert} -keystore /certs/masterlist.bks -storepass changeit -storetype BKS -providerClass org.bouncycastle.jce.provider.BouncyCastleProvider -providerPath /app/bcprov-jdk15on.jar && rm ${cert}
done

echo "Master list validated and keystore created"
