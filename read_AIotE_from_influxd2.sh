#!/bin/bash
# Nachfolgende Variablen müssen als Umgebungsvrariablen in der Docker-Umgebung gesetzt werden 
# AGODAYS=1...9999 -> wir wollen das mit der vom Java angebotenen FIRST_DAY Variable ersetzen ... coming soon
# INFLUXDB2_IP=192.168.0.1
# INFLUXDB2_PORT=8087
# INFLUXDB2_ORG="xxxxxxxxxxxxxxxx"
# INFLUXDB2_TOKEN="#####################################################################################=="

# We need the variables from the Docker system. Thanks to Java, which is trying to withhold them from me. Fortunately, they are always available in process "1".
cat /proc/1/environ | tr '\0' '\n' > /tmp/envimport
. /tmp/envimport

alldata=$(
for days in `seq ${AGODAYS} -1 0` ; do

        DAY=$(date +%F -d "$days days ago")

        data=$( curl -XPOST ${INFLUXDB2_IP}:${INFLUXDB2_PORT}/api/v2/query?org=${INFLUXDB2_ORG} \
                -H "Authorization: Token ${INFLUXDB2_TOKEN}" \
                -H "Accept:application/csv" \
                -H "Content-type:application/vnd.flux" \
                -d "from(bucket:\"home_assistant\")
                        |> range(start:${DAY}T00:00:00.000000000Z, stop:${DAY}T23:59:59.000000000Z)
                        |> filter(fn: (r) => r[\"_measurement\"] == \"kWh\")
                        |> filter(fn: (r) => r[\"_field\"] == \"value\")
                        |> filter(fn: (r) => r[\"domain\"] == \"sensor\")
                        |> filter(fn: (r) => r[\"entity_id\"] == \"powermeter_value\")
                        |> filter(fn: (r) => r[\"source\"] == \"HA\")" 2> /dev/null )

        output=$(echo "$data" | head -n 2 | tail -n 1 | awk -F, '{print$6,$7}' | sed 's/T.*Z//g' | sed 's/\.[0-9]*$//g' )
        echo $output
done | grep -v ^\s*$ )

LINES=$( echo "$alldata" | wc -l )
ASKDAYS=$((${AGODAYS}+1))
if [[ ${ASKDAYS} == ${LINES} ]] ; then
        ERR=0
        echo "$alldata"
else
        ERR=$((${ASKDAYS}-${LINES}))
        echo "Fehler gefunden, es sind statt erwarteten ${ASKDAYS} Datensaetze nur ${LINES} Datensätze gefunden wurden"
        echo "Es fehlen daher $ERR Datensätze, Ich übertrage zur Sicherheit keine Daten"
fi

exit $ERR
