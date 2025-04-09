#!/bin/bash

set -euo pipefail

if ! id bhos-openssl &>/dev/null; then
  echo "[phase2] ERROR: User '$OCSP_USER' does not exist. Please create it before running this script."
  exit 1
fi

dir="/home/user-openssl/rootCA"

echo "[phase2] Using directory: $dir"

# Check if directory exists
if [ ! -d "$dir" ]; then
  echo "[phase2] ERROR: Directory $dir does not exist."
  exit 1
fi

sudo chown -R user-openssl:user-openssl /home/user-openssl/rootCA
sudo chmod u+w /home/user-openssl/rootCA

cd "${dir}"

#!/bin/bash

echo "Enter the Common Name for CA (CN):"
read CN_CA
echo "Enter the Common Name for OCSP (CN):"
read CN_OCSP
echo "Enter the passphrase for the private key of CA:"
read -s PASS_CA
echo "Enter the passphrase for the private key of OCSP:"
read -s PASS_OCSP

# Creating CA request
echo "[phase2] Creating CA request..."
openssl req -config "${dir}/openssl.cnf" \
  -new -keyout "${dir}/private/cakey.pem" \
  -out "${dir}/requests/careq.pem" \
  -subj "/C=AZ/ST=Baku/L=Baku/O=ORG/OU=AZ/CN=$CN_CA/emailAddress=mail@org.local" \
  -passout pass:$PASS_CA || { echo "[phase2] ERROR: Failed to create CA request."; exit 1; }

# Self-signing CA certificate
echo "[phase2] Creating self-signed CA certificate..."
openssl ca -config "${dir}/openssl.cnf" \
  -extensions v3_ca -days 365 -create_serial -selfsign \
  -in "${dir}/requests/careq.pem" -out "${dir}/cacert.pem" \
  -passin pass:$PASS_CA || { echo "[phase2] ERROR: Failed to create CA certificate."; exit 1; }

# Show current CA database state
echo "[phase2] Printing serial and index..."
cat "${dir}/serial" || echo "[phase2] WARN: serial file missing"
cat "${dir}/index.txt" || echo "[phase2] WARN: index.txt file missing"
ls -liah "${dir}"

# Creating OCSP responder key and request
echo "[phase2] Creating OCSP responder request..."
openssl req -config "${dir}/openssl.cnf" \
  -new -keyout "${dir}/private/ocspresponder.key.pem" \
  -out "${dir}/requests/ocspresponder.csr.pem" \
  -subj "/C=AZ/ST=Baku/L=Baku/O=ORG/OU=AZ/CN=$CN_OCSP/emailAddress=mail@org.local" \
  -passout pass:$PASS_OCSP || { echo "[phase2] ERROR: Failed to create OCSP request."; exit 1; }

# Signing OCSP responder cert
echo "[phase2] Signing OCSP responder certificate..."
openssl ca -config "${dir}/openssl.cnf" \
  -extensions ocsp_responder_cert \
  -in "${dir}/requests/ocspresponder.csr.pem" \
  -out "${dir}/certs/ocspresponder.crt.pem" \
  -passin pass:$PASS_CA || { echo "[phase2] ERROR: Failed to sign OCSP responder certificate."; exit 1; }

# Create systemd service
echo "[phase2] Creating systemd service..."

service_payload="""[Unit]
Description=OpenSSL OCSP Responder - BHOS
After=network.target

[Service]
Environment=OCSP_PASS=${PASS_OCSP}
Environment=CA_PASS=${PASS_CA}
ExecStart=/usr/bin/openssl ocsp -port 80 -text \\
  -index ${dir}/index.txt \\
  -CA ${dir}/cacert.pem \\
  -rkey ${dir}/private/ocspresponder.key.pem \\
  -rsigner ${dir}/certs/ocspresponder.crt.pem \\
  -passin env:CA_PASS
WorkingDirectory=${dir}
Restart=always
User=user-openssl
Group=user-openssl

[Install]
WantedBy=multi-user.target
"""

echo "${service_payload}" | sudo tee /etc/systemd/system/user-openssl-responder.service > /dev/null || { echo "[phase2] ERROR: Failed to write service file."; exit 1; }

# Reload and restart service
echo "[phase2] Reloading and starting systemd service..."
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable user-openssl-responder
sudo systemctl restart user-openssl-responder || { echo "[phase2] ERROR: Failed to start OCSP service."; exit 1; }

# Show service status
echo "[phase2] Service status:"
sudo systemctl status user-openssl-responder --no-pager || echo "[phase2] WARNING: Could not retrieve service status"
