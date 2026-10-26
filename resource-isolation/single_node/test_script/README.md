# Single-node Resource Isolation Test

Scripts to start and stop the pullpiri + TIMPANI based resource-isolation
scenario on a single PC. pullpiri, nodeagent, TIMPANI, monitoring and the
containers all run locally (no SSH, no guest node).

## Layout

```
test_script/
├── config.env                        # settings (edit here only)
├── run_resource_isolation_flow.sh    # start
├── stop_resource_isolation_flow.sh   # stop
├── preflight/prepare.sh              # one-time: build images + upload Arduino
├── lib/utils.sh                      # shared functions
├── pullpiri/                         # pullpiri install/uninstall scripts, node config
└── timpani/                          # timpani-o/-n install/uninstall scripts, node config
```

## Prerequisites

- `docker`, `podman`, `arduino-cli` installed on this PC
- Local `sudo` access (set `SUDO_PASS` in config.env for non-interactive runs)

## config.env

Edit only the **USER SETTINGS** section at the top. Defaults cover the rest.

| Variable | Description | Default |
|----------|-------------|---------|
| `NODE_NAME` | This machine's node name. Must match the pullpiri nodeagent registration name and the `node:` field in the workload YAML | `hostname` |
| `NODE_IP` | Local IP used by pullpiri apiserver/nodeagent. Empty = auto-detect first non-loopback IP | (auto) |
| `BASE_DIR` | Path to the `single_node` directory | repo path |
| `SUDO_PASS` | Local sudo password. Empty = interactive prompt | (empty) |

> **kuksa-bridge address**: leave `KUKSA_HOST` in
> [../kuksa-bridge/.env](../kuksa-bridge/.env) empty. `prepare.sh` fills it with
> this host's IP right before building the image.

## Scripts

| Script | Role |
|--------|------|
| `preflight/prepare.sh` | Apply udev rules, compile/upload Arduino, build container images (one-time) |
| `run_resource_isolation_flow.sh` | Start serial-bridge -> install pullpiri -> restart nodeagent -> start monitoring -> run timpani-o container -> wait for databroker log -> install & start timpani-n package |
| `stop_resource_isolation_flow.sh` | compose down, stop monitoring, remove timpani-o container, uninstall timpani-n package, uninstall pullpiri, clean up containers |

## Test Procedure

### 1. Prepare (one-time)

```bash
cd single_node/test_script
./preflight/prepare.sh
```

Builds images and uploads the Arduino sketches (includes `KUKSA_HOST` auto-setup).

### 2. Start

```bash
./run_resource_isolation_flow.sh
```

The script runs automatically and waits for Arduino input at **Step 6**.

- **Turn the rotary** -> launch workload containers (serial-bridge POSTs the YAML to pullpiri)
- Once the script detects the databroker log (`api/artifact ... status=200`), it proceeds to **Step 7** (timpani-n) automatically

### 3. Observe

- **Press the joystick button** to toggle the CPU load (stress-ng)
- Compare the two LED periods in Grafana (`http://<node-ip>:3000`)
  - TIMPANI LED: stays ~500ms regardless of load
  - Normal LED: delayed beyond 500ms under load

### 4. Stop

```bash
./stop_resource_isolation_flow.sh
```

## Notes

- **timpani-o** runs as a Podman container (image pulled from
  `ghcr.io/mco-piccolo/timpani-o:latest` and launched by
  `timpani/scripts/install-timpani-o.sh`; logs via
  `sudo podman logs -f timpani-o`)
- **timpani-n** is installed from a prebuilt native package (`.deb`/`.rpm`) in
  the [../../artifacts](../../artifacts) directory by
  `timpani/scripts/install-timpani-n.sh` and runs as the `timpani-n` systemd
  service (logs via `sudo journalctl -u timpani-n -f`)
- Detailed values such as paths and image versions can be overridden in the **ADVANCED SETTINGS** section of config.env
- Scripts work regardless of the current working directory (paths are resolved relative to their own location)
