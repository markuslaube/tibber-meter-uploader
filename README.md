# Tibber Meter Uploader

Dieses Tool verwendet die Tibber-API, welcher unter https://app.tibber.com/v4/gql verfügbar ist, um tägliche Zählerstände automatisiert hochzuladen.

Es kann als Alternative zur manuellen monatlichen Eingabe von Zählerständen verwendet werden und ist nicht als Ersatz für den "Tibber Pulse" gedacht, welcher stündliche Werte übermittelt.

Das ganze hier ist ein Fork von https://github.com/micw/tibber-meter-uploader Ursprünglich "nur" um Doker Container für Raspberrys zu erstellen, für die kein openjdk:17-alpine verfügbar ist (war). Das ganze wurde dann auf genau (m)einen Anwendungsfall optimiert:

- Ferraris-Zähler (https://de.wikipedia.org/wiki/Ferraris-Zähler)
- Tibber Stromvertrag (https://developer.tibber.com) -> Werbecode nicht enthalten, gern per Mail.
- AI on the Edge zur Zählerstandsermittlung (https://github.com/jomjol/AI-on-the-edge-device)
- Home Assistant (https://www.home-assistant.io)
- InfluxDB2 (https://github.com/influxdata/influxdb)

Der Container ist so optimiert, das er in einer Docker (Swarm) Umgebung Stateless, sprich ohne eigenes Volume, autark laufen kann und die Zählerdaten an Tibber überträg.

Diese Version ist eine Testversion mit Alpine Linux und entsprechenden Security-Optimierungen innerhalb der Maven Build Umgebung.

## Ausführen (docker)

```
docker run -it --rm \
  -e "READINGS_SOURCE_CLASS=ScriptedRestApiMeterReadingSource" \
  -e "READINGS_SCRIPT_COMMAND=echo test; exit 1" \
  -e TIBBER_LOGIN=me@example.com \
  -e TIBBER_PASSWORD=mysecretpassword \
  -e DRY_RUN=false' \
  -e TIBBER_METER_REGISTER_ID=1-1:1.8.0 \
  -e SCHEDULING_ENABLED=true" \
  -e READINGS_SOURCE_CLASS=ScriptedRestApiMeterReadingSource"
  -e READINGS_SCRIPT_COMMAND=/read_AIotE_from_influxd2.sh"
  -e INFLUXDB2_IP=<<ip of influxdb>>"
  -e INFLUXDB2_PORT=<<port of influxdb>>"
  -e INFLUXDB2_ORG=################"
  -e INFLUXDB2_TOKEN=#################################################_####################################=="
  -e TZ=Europe/Berlin"
  laubi/tibber-meter-uploader:latest
```

## Code für Stack im Portainer

```
version: "3.9"
services:
  tibber-meter-uploader:
    user: 1000:1000
    environment:
     - "TIBBER_LOGIN=me@example.com"
     - "TIBBER_PASSWORD=mysecretpassword"
     - "DRY_RUN=false"
     - "TIBBER_METER_REGISTER_ID=1-1:1.8.0"
     - "SCHEDULING_ENABLED=true"
     - "READINGS_SOURCE_CLASS=ScriptedRestApiMeterReadingSource"
     - "READINGS_SCRIPT_COMMAND=/read_AIotE_from_influxd2.sh"
     - "INFLUXDB2_IP=<<ip of influxdb>>"
     - "INFLUXDB2_PORT=<<port of influxdb>>"
     - "INFLUXDB2_ORG=################"
     - "INFLUXDB2_TOKEN=#################################################_####################################=="
     - "TZ=Europe/Berlin"
    image: "laubi/tibber-meter-uploader:latest"
```

## Konfiguration

Die Konfiguration erfolgt über Umgebungsvariablen.

* `TIBBER_LOGIN` (benötigt): E-Mail-Adresse eines Tibber-Accounts
* `TIBBER_PASSWORD` (benötigt): Passwort eines Tibber-Accounts
* `READINGS_SOURCE_CLASS` (benötigt): `ScriptedRestApiMeterReadingSource` - Implementierungsklasse der Quelle für Zählerstände (siehe unten)
* `INFLUXDB2_IP` (benötigt): <<ip of influxdb>>"
* `INFLUXDB2_PORT` (benötigt): <<port of influxdb>>"
* `INFLUXDB2_ORG` (benötigt): ORG ID der Daten in der InfluxDB
* `INFLUXDB2_TOKEN` (benötigt): Influx DB2 User Token
* `SCHEDULING_ENABLED` (default: `true`): Wenn der Parameter auf `false` gesetzt wird, terminiert der Prozess nach einem einmaligen Durchlauf
* `SCHEDULING_CRON` (default: `0 0 * * * *` = jede volle Stunde): Ermöglicht, den Ausführungszeitpunkt der regelmäßigen Durchläufe zu verändern
* `DRY_RUN` (default: `false`): Wenn der Parameter auf `true` gesetzt wird, werden die an an Tibber zu übermittelnden Zählerstände nur angezeigt, aber nicht übertragen. Nützlich, um Quellen und die Konfiguration zu testen.


### Meter Register ID

In einigen Fällen ist bei Tibber nicht der Standard-OBIS-Code `1-1:1.8.0` für den Gesamt-Strombezug hinterlegt sondern `1-1:1.8.0`. In dem Fall erscheint beim Start eine Fehlermeldung ähnlich dieser:

	Meter 149d2526-6c26-4435-9b2b-0dbfd3251bcd has no register with id '1-0:1.8.0'. Available registers are: 1-1:1.8.0

Über den Konfigurtationsparameter `TIBBER_METER_REGISTER_ID = 1-1:1.8.0` kann die Anwendung so konfiguriert werden, dass Zählerstände für diesen OBIS-Code an Tibber übergeben werden.

Eine Liste gängiger OBIS-Codes und deren Bedeutung kann unter https://de.wikipedia.org/wiki/OBIS-Kennzahlen gefunden werden.

## Programmablauf

* Beim Start sowie einmal pro volle Stunde versucht sich der Client an der Tibber-API anzumelden und das Benutzerprofil incl. der zuletzt gemeldeten Zählerstände abzurufen
* Es wird derzeit nur ein Zuhause mit einem Zähler unterstützt
* Sind für ein oder mehrere Tage in der Vergangenheit (maximal 30 Tage zurück) noch keine Zählerstände vorhanden, wird die konfigurierte Quelle nach Zählerständen in diesem Zeitraum befragt
* fehlende Zählerstände werden nachgetragen

## Quellen

Um flexibel zu sein, unterstützt das Tool konfigurierbare Quellen für die Zählerstände.

### ScriptedRestApiMeterReadingSource

Diese Quelle führt ein Shell-Script aus, um Zählerstände zu beziehen. Als Ergebnis wird eine Liste mit je einem Datum + Zählerstand in kWh pro Zeile erwartet (getrennt mit Leerzeichen, Semikolon oder Komma).

Beispiel:

```
2023-01-19 10003
2023-01-20 10114
2023-01-21 10234
2023-01-22 10521
```

Die folgenden Konfigurationsparameter sind für die Quelle verfügbar:

* `READINGS_SOURCE_CLASS` (benötigt): `ScriptedRestApiMeterReadingSource` für diese Quelle
* `READINGS_SCRIPT_COMMAND` (benötigt): Auszuführender Befehl oder Shell-Script. Der Befehl wird an eine Shell mittels `sh -c ${READINGS_SCRIPT_COMMAND}` übergeben
* `READINGS_METER`(optional): Wenn angegeben, prüft die Quelle, dass die von der Tibber-Api gelieferte Zählernummer dieser Zählernummer entspricht.

Innerhalb des Shell-Scriptes stehen die folgenden Umgebnugsvariablen zur Verfügung:

* `FIRST_DAY` - Der erste Tag, für den der Zählerstand benötigt wird. Format: `2023-01-19`
* `LAST_DAY` - Der letzte Tag, für den der Zählerstand benötigt wird. Format: `2023-01-22`
* `METER` - Die abgefragte Zähelernummer. Format: `1EBZ0123456789`
* `FIRST_DAY_START_ISO_TZ` - Die Startzeit des ersten Tages, Format: `2023-01-19T00:00:00+01:00[Europe/Berlin]`
* `LAST_DAY_END_ISO_TZ` - Die Startzeit des Folgetages des letzten Tages. Format: `2023-01-23T00:00:00+01:00[Europe/Berlin]`


### CommandLineMeterReadingSource

Diese Quelle ließt Zählerstände von der Kommandozeile. Es können mehrere Zählerstände im Format datum=zählerstand übergeben werden. Statt des Datums kann auch das Schlüsselwort `today` verwendet werden, um den aktuellen Tag zu übergeben.

Beispiel:

```
java -jar tibber-uploader.jar 2023-01-19=10003 2023-01-20=10114 2023-01-21=10234 today=10521
```

Die folgenden Konfigurationsparameter sind für die Quelle verfügbar:

* `READINGS_SOURCE_CLASS` (benötigt): `CommandLineMeterReadingSource` für diese Quelle
* `READINGS_METER`(optional): Wenn angegeben, prüft die Quelle, dass die von der Tibber-Api gelieferte Zählernummer dieser Zählernummer entspricht.

Es ist sinnvoll, diese Quelle zusammen mit dem Konfigurationsparameter `SCHEDULING_ENABLED=false` zu verwenden, um das Programm nach dem Upload der Werte zu beenden.

### DummyMeterReadingSource

Diese Quelle stellt ein einzelnes statisches Reading zum Testen zur Verfügung.

Die folgenden Konfigurationsparameter sind für die Quelle verfügbar:

* `READINGS_SOURCE_CLASS` (benötigt): `DummyMeterReadingSource` für diese Quelle
* `READINGS_METER`(optional): Wenn angegeben, prüft die Quelle, dass die von der Tibber-Api gelieferte Zählernummer dieser Zählernummer entspricht.
* `DUMMY_READING_DATE`(benötigt): Datum des Dummy-Readings, z.b. 2023-01-19
* `DUMMY_READING_VALUE`(benötigt): Wert des Dummy-Readings, z.b. 10003
