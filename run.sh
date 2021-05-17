#!/usr/bin/env bash

[[ -n ${DEBUG} ]] && set -x

# Expected Files
# /certs/tls.pem - Server cert - if missing create
# /certs/tls-key.pem - Server key - if missing create
# /etc/ssl/certs/chain-ca.pem - CA Cert (or intermediate CA)
# /etc/ssl/certs/ca-bundle.crt - CA Bundle

CERTIFICATE_FILE="${CERTIFICATE_FILE:-/certs/tls.crt}"
PRIVATE_KEY_FILE="${PRIVATE_KEY_FILE:-/certs/tls.key}"
CA_CERT_DIR="${CA_CERT_DIR:-/cacerts}"
CA_CERT_FILE="${CA_CERT_FILE:-/certs/ca.crt}"
IMPORT_SYSTEM_TRUSTSTORE="${IMPORT_SYSTEM_TRUSTSTORE:-true}"
JAVA_CACERTS="${JAVA_CACERTS:-/opt/java/openjdk/lib/security/cacerts}"
KEYSTORE_RUNTIME="${KEYSTORE_RUNTIME:-/etc/keystore}"
KEYSTORE_FILE="${KEYSTORE_FILE:-${KEYSTORE_RUNTIME}/keystore.p12}"
TRUSTSTORE_FILE="${TRUSTSTORE_FILE:-${KEYSTORE_RUNTIME}/cacerts}"

announce() {
  [ -n "$@" ] && echo "[v] --> $@"
}

failed() {
  echo "[failed] $@" && exit 1
}

create_truststore() {
  announce "Creating a JAVA truststore as ${TRUSTSTORE_FILE}"
  if [[ -d "${CA_CERT_DIR}" ]]
  then
    find ${CA_CERT_DIR} \( -name '*.crt' -o  -name '*.pem' \) -type f -exec basename {} >> /tmp/certs_list \;
    for CA in `cat /tmp/certs_list`
    do
      announce "Importing ${CA} into JAVA truststore"
      keytool -import -alias ${CA%%.*} -file ${CA_CERT_DIR}/${CA} -keystore ${TRUSTSTORE_FILE} -noprompt -storepass changeit -trustcacerts
    done
  fi

  if [[ ${IMPORT_SYSTEM_TRUSTSTORE} == 'true' ]]; then
    announce "Importing ${JAVA_CACERTS} into ${TRUSTSTORE_FILE}."
    keytool -importkeystore -destkeystore ${TRUSTSTORE_FILE} \
      -srckeystore ${JAVA_CACERTS} -srcstorepass changeit \
      -noprompt -storepass changeit &> /dev/null
  fi

  if [[ -f "${CA_CERT_FILE}" ]]; then
    announce "Importing InternalCA into JAVA truststore"
    keytool -import -alias InternalCA -file ${CA_CERT_FILE} -keystore ${TRUSTSTORE_FILE} -noprompt -storepass changeit -trustcacerts
  fi
}

create_keystore() {
  announce "Importing certificate and key into pkcs12 keystore."
  openssl pkcs12 -export -name cert -in ${CERTIFICATE_FILE} -inkey ${PRIVATE_KEY_FILE} -nodes \
    -CAfile ${CA_CERT_FILE} -out ${KEYSTORE_FILE} \
    -passout pass:'changeit' || failed "unable to convert certificates pkcs12 format"

}


# step: at the very least we must have cert and private key
if [[ -f "${CERTIFICATE_FILE}" ]] && [[ -f "${PRIVATE_KEY_FILE}" ]]
then
  sleep 10
  create_truststore
  create_keystore
else
  create_truststore
fi

/opt/java/openjdk/bin/java $@
