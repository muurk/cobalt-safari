#!/bin/bash

IP_FILE="ranges"
SESSION_UUID=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

if [ -z ${BASE_DIR+abc} ]; then
  BASE_DIR=$HOME/.scandata
fi

if [ -z ${MASSCAN_RATE+abc} ]; then
  MASSCAN_RATE="1000"
fi

mkdir -p ${BASE_DIR}

#BASE_DIR=$ENV{'BASE_DIR'}
RANGES=`cat "${IP_FILE}" | tr "\n" " "`
OUT_DIR="${BASE_DIR}/${SESSION_UUID}"

MASSCAN_OUT="${OUT_DIR}/masscan_output"
MASSCAN_RATE="100"
MASSCAN_PORT="50050"

START_FILE="${OUT_DIR}/start"
END_FILE="${OUT_DIR}/end"

CERT_OUT="${OUT_DIR}/certs"
CERT_JOB="${OUT_DIR}/cert_parallel"
CERT_STDOUT="${CERT_OUT}/stdout"
CERTS_SERVICES="${CERT_OUT}/services"

CS_OUT="${OUT_DIR}/cs_nodes"
S_PASSWORD="password"
CS_USER="orange"
CS_BRUTE_OUT="${OUT_DIR}/cs_brute"
CS_BRUTE_PARALLEL="${OUT_DIR}/cs_brute_parallel"

NMAP_TOP_PORTS="3000"
NMAP_OUT_DIR="${OUT_DIR}/nmap"
NMAP_TOP_SCAN="${NMAP_OUT_DIR}/top_${NMAP_TOP_PORTS}"

AMAP_OUT="${NMAP_TOP_SCAN}.amap"

EYEWITNESS_DIR="/opt/EyeWitness/"
EYEWITNESS_BIN="/opt/EyeWitness/EyeWitness.py"
EYEWITNESS_OUT_DIR="${OUT_DIR}/eyewitness"

mkdir -p "${OUT_DIR}" "${CERT_OUT}" "${NMAP_OUT_DIR}" "${CERTS_SERVICES}"

date +%s > "${START_FILE}"

masscan -p"${MASSCAN_PORT}" -oG "${MASSCAN_OUT}" --rate="${MASSCAN_RATE}" ${RANGES}
for HOST in `grep -E "^Host: " "${MASSCAN_OUT}" | awk '{print $2}'`;
do
  echo "echo x | timeout 10 openssl s_client -showcerts -connect ${HOST}:${MASSCAN_PORT} </dev/null > \"${CERT_OUT}/${HOST}.cert\"" >> "${CERT_JOB}"
done
#echo "Enumerating Certs"
parallel --bar  --jobs 50 < "${CERT_JOB}" 2>&1 > "${CERT_STDOUT}"
grep -lH "OU=AdvancedPenTesting/CN=Major Cobalt Strike" "${CERT_OUT}"/*.cert | sort -u | xargs -L1 basename | sed 's/.cert$//g' > "${CS_OUT}"
#echo "Written `wc -l ${CS_OUT}` Cobalt Strike Servers to ${CS_OUT}. Enjoy"

# We don't really want to brute force the team server... do we ?
#for node in `cat "${CS_OUT}"`;
#do
#  echo "echo Host: \"${node}\" Password: \"${CS_PASSWORD}\" && echo x | timeout 15 proxychains java -XX:+UseParallelGC -classpath ./cobaltstrike.jar aggressor.headless.Start \"${node}\" 50050 \"${CS_USER}\" \"${CS_PASSWORD}\"" | shuf >> "${CS_BRUTE_PARALLEL}"
#done

nmap -sS -Pn -i "${CS_OUT}" --top-ports="${NMAP_TOP_PORTS}" -oA "${NMAP_TOP_SCAN}" -n -v --stats-every=10s

#PTRs
#cat cs_nodes | xargs -L1 dig +noall +answer -x

amap -A -o "${AMAP_OUT}" -m -i ${NMAP_TOP_SCAN}.gnmap

for SERVICE in `grep -i "tcp:open::ssl" "${AMAP_OUT}" | awk -F: '{print $1 ":" $2 }'`;
do
  SERVICE_BASE="${CERTS_SERVICES}/${SERVICE}"
  SERVICE_CERT="${SERVICE_BASE}/${SERVICE}.txt"
  SERVICE_DOMAINS="${SERVICE_BASE}/domains.txt"
  mkdir -p "${SERVICE_BASE}"
  echo x|openssl s_client -connect ${SERVICE} 2>&1| openssl x509 -noout -text > "${SERVICE_CERT}"
  grep -E "Subject: CN =|DNS:" "${SERVICE_CERT}"|sed 's/Subject: CN = /DNS:/g'|tr ', ' '\n'|grep -vi "^$"|awk -F: '{print $2}'|sort -u > "${SERVICE_DOMAINS}"

done

date +%s > "${END_FILE}"

exit

(cd ${EYEWITNESS_DIR} && "${EYEWITNESS_BIN}"	--headless \
						-x "${NMAP_TOP_SCAN}.xml" \
						--threads=30 \
						-d "${EYEWITNESS_OUT_DIR}" \
						--no-prompt
)
