#!/bin/bash

# this script made for phase 1 of lab
# it will check for dependencies, create structure, and configure config file


# check for sudo permissions
if ! sudo -n true 2>/dev/null; then
	echo "[sudocheck] please run with sudo permissions"
	exit 1
fi


# check for dep.
depchecker() {
	local pkg="$1"
	if ! dpkg -s "$pkg" &> /dev/null; then
		echo "[depcheck] $pkg installing"
		if ! sudo apt install -y "$pkg"; then
			echo "[depcheck] failed to install $pkg"
			exit 2
		fi
	fi
}

deplist=("openssl")

for dep in "${deplist[@]}"; do
	depchecker "$dep"
done



#dir
dir="/home/user-openssl/rootCA"

# building structure
mkdir ${dir}
mkdir ${dir}/certs
mkdir ${dir}/crl
mkdir ${dir}/newcerts
mkdir ${dir}/private
mkdir ${dir}/requests

touch ${dir}/crlnumber
touch ${dir}/index.txt

# copying and modifying openssl config
cp /etc/ssl/openssl.cnf ${dir}/openssl.cnf

##configuring dir
sed -i 's|^dir[[:space:]]*=.*|dir = .|' ${dir}/openssl.cnf

##selecting ip
mapfile -t ip_list < <(ip -4 addr show | awk '/inet / && $2 !~ /^127/ {print $2}' | cut -d/ -f1)

if [ ${#ip_list[@]} -eq 0 ]; then
    echo "[ipcheck] no ip found. selecting 127.0.0.1"
    ip="127.0.0.1"
else
    echo "[ipcheck] select IP:"
    select ip in "${ip_list[@]}"; do
        if [[ -n "$ip" ]]; then
            break
        else
            echo "[ipcheck] try again"
        fi
    done
fi

##configuring headers
sed -i "/^\\[ *usr_cert *\\]/a authorityInfoAccess=OCSP;URI:http://${ip}\nextendedKeyUsage=critical,clientAuth\nkeyUsage=critical,nonRepudiation,digitalSignature,keyEncipherment" ${dir}/openssl.cnf

##uncomment copy_extensions
sed -i 's/^[[:space:]]*#[[:space:]]*\(copy_extensions[[:space:]]*=\)/\1/' ${dir}/openssl.cnf

##changing key size
sed -i 's|^default_bits[[:space:]]*=.*|default_bits = 4096|' ${dir}/openssl.cnf

##configuring keyusage for v3_ca
sed -i '/^\[ *v3_ca *\]/,/^\[.*\]/ {s/^[[:space:]]*#*[[:space:]]*keyUsage[[:space:]]*=.*/keyUsage = critical,cRLSign,keyCertSign/}' ${dir}/openssl.cnf

##configuring server_cert
server_cert_payload="""

[ server_cert ]
basicConstraints=CA:FALSE
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer
authorityInfoAccess=OCSP;URI:http://${ip}
extendedKeyUsage=critical,serverAuth
keyUsage=critical,nonRepudiation,digitalSignature,keyEncipherment
"""
echo "${server_cert_payload}" >> ${dir}/openssl.cnf

##configuring ocsp_responder_cert
ocsp_responder_cert_payload="""

[ ocsp_responder_cert ]
basicConstraints=CA:FALSE
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer
extendedKeyUsage=critical,OCSPSigning
keyUsage=critical,digitalSignature
"""

echo "${ocsp_responder_cert_payload}" >> ${dir}/openssl.cnf
