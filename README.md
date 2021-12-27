
![build.yml](https://github.com/melvin-suter/grafana-pusher/actions/workflows/build.yml/badge.svg)

This kubernetes "system" is designed to give the simple ability, to add key-value to a database, so grafana can read it.
It is easy to use (with a single http call) and is based on a mysql database.

You can store data simple as a key-value pair, or as a time-based key-value pair, where the key doesn't have to be unique.


# Setup

- Create PV if needed (if not dynamically created/allocated)
- Run Deployer to create "infra" pods

```bash
$ ./deployer.sh --create-infra --namespace=grafapush --base-url=grafapush.kub.example.com --pv=pv-grafapush-mysql

Generating keys...
Generating templates...
Saving vars...
Creating infra...
* namespace
* pvc
* mysql config
* mysql deployment
* mysql service
* phpmyadmin deployment
* phpmyadmin service
* phpmyadmin ingress
waiting for mysql pod to be running...
** waiting 15 seconds for mysql to be up
deploying mysql config...
* tables.sql
* create_keybased.sql
* create_timebased.sql
* delete_table.sql


Done
PHPMyAdmin URL:                 management.grafapush.kub.example.com
MariaDB root password:          3dceededc5c4055459fb851dc70e78bf
MariaDB grafanapusher password: 0256b433cde71f7abc2e81dfd06d24dd
```

# Deploy a new api-endpoint

For a time-based table:

```bash
$ ./deployer.sh --create-timebased --table=tempsensor
checking on folder
generating template
creating pod
running mysql procedure


Done
Table Name:        tempsensor
API Endpoint:      api-tempsensor.grafapush.kub.example.com
Authorization Key: 9obcesfj4putaspycmrq1q8qmqgvnbg1
```

For a key (value) based table:

```bash
$ ./deployer.sh --create-keybased --table=lightstate
checking on folder
generating template
creating pod
running mysql procedure


Done
Table Name:        lightstate
API Endpoint:      api-lightstate.grafapush.kub.example.com
Authorization Key: 3gno37f8n918oh2ouz10lrosqzg0fsgm
```

# Write a script

Here is a simple example, which will just push a number to the `lightstate` table in the example above:

```bash
curl --insecure -XPOST -H "AUTH: 3gno37f8n918oh2ouz10lrosqzg0fsgm" -F "key=light1" -F "value=1" https://api-lightstate.grafapush.kub.example.com
```

```powershell
Invoke-WebRequest  -Method Post -Body @{"key" = "light"; "value" = "1"} -Headers @{"AUTH" = "3gno37f8n918oh2ouz10lrosqzg0fsgm"}  -ContentType "application/x-www-form-urlencoded" -Uri https://api-lightstate.grafapush.kub.example.com
```

## Powershell SSL

If you have trouble with the ssl cert, add this before the powershell script toi disable ssl-check:

```powershell
add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
```