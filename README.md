
![build.yml](https://github.com/melvin-suter/grafana-pusher/actions/workflows/build.yml/badge.svg)


# Setup

- Create PV if needed (if not dynamically created/allocated)
- Run Deployer to create "infra" pods

```bash
./deployer.sh --create-infra --namespace grafana-pusher --pv pv-grafpush-mysql
```
