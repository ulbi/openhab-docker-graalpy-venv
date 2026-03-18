# openhab-docker-graalpy-venv

## Description
OpenHab docker image that automatically creates a pre-built GraalPy venv ready to be used with https://www.openhab.org/addons/automation/pythonscripting/

Currently only supports OpenHAB 5.1.3

## Image details
- uses a **3-stage multi-stage build**:
  1. **graal-detector**: extracts the exact GraalPy version bundled in the openHAB addons KAR so the runtime and the scripting addon always match
  2. **venv-builder**: downloads the matching GraalPy community JVM distribution, creates a venv under `/openhab/python/venv`, and installs all packages from `requirements.txt` — compiled against the same glibc as the base image
  3. **final image**: copies only the finished venv + required runtime libs from the builder; no build toolchain ends up in the image
- keeps the GraalPy runtime and venv in `/openhab/python/`
- uses the openHAB container's **`/etc/cont-init.d/` hook mechanism** (s6-overlay): `cont-init.d/10-graalpy-venv.sh` symlinks the pre-built venv into `/openhab/userdata/cache/org.openhab.automation.pythonscripting/venv` on every container start, even when `/openhab/userdata` is a mounted host volume
- includes runtime libs such as `patchelf` needed for GraalPy native extensions

## Adding Python packages

Add the desired packages to `requirements.txt` — they get installed into the venv at image build time.

GraalPy supports only a subset of packages from PyPI. For packages with native extensions, the build can take a very long time if no pre-built wheel is available. Before adding a package, check which versions have pre-built GraalPy wheels:
https://www.graalvm.org/python/compatibility/

Prefer pinning to a version listed there as "supported" to avoid compiling from source during the Docker build.

## Building locally
```bash
docker build -t openhab-graalpy .
```
To target a different openHAB version, pass `BASE_IMAGE`:
```bash
docker build --build-arg BASE_IMAGE=openhab/openhab:5.1.3-debian -t openhab-graalpy .
```
The GraalPy version is detected automatically from the addons KAR of the chosen openHAB version — no manual version pinning needed.

## GitHub Actions / Published images

The workflow `.github/workflows/build-image.yml` runs every Sunday at 3am and can also be triggered manually via `workflow_dispatch`. It:

1. Fetches the 10 most recent `*-debian` tags from Docker Hub (`openhab/openhab`)
2. Builds each tag in a matrix job using `BASE_IMAGE=openhab/openhab:<tag>`
3. Pushes to GHCR as `ghcr.io/<owner>/openhab-docker-graalpy-venv:<tag>` and updates `:latest`

The GraalPy version is auto-detected per build from the addons KAR — no manual pinning needed when openHAB updates.

## Automated GraalPy venv smoke test

`./run-test.sh` builds the enhanced OpenHAB image, mounts the `test-config` python rules/items, waits for the REST API, and then runs `tests/check_venv.py` on the host to confirm that `SimpleItem` was updated and the `requests`-powered rule reported HTTP `200`. The script tears down the compose stack afterward and prints a concise pass/fail message.

