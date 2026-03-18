ARG BASE_IMAGE=openhab/openhab:5.1.3-debian

# Stage 1: GraalPy-Version aus openHAB-Addons-KAR ermitteln
FROM ubuntu:24.04 AS graal-detector
ARG BASE_IMAGE

RUN apt-get update && apt-get install -y --no-install-recommends \
    wget unzip ca-certificates && rm -rf /var/lib/apt/lists/*

RUN OPENHAB_VERSION=$(echo "${BASE_IMAGE}" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+') && \
    echo "openHAB Version: $OPENHAB_VERSION" && \
    mkdir -p /tmp/addons && cd /tmp/addons && \
    wget -q "https://github.com/openhab/openhab-distro/releases/download/${OPENHAB_VERSION}/openhab-addons-${OPENHAB_VERSION}.kar" && \
    unzip -q "openhab-addons-${OPENHAB_VERSION}.kar" && \
    GRAAL_VER=$(find . -name "org.graalvm.python.python-language-*.jar" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1) && \
    echo "$GRAAL_VER" > /tmp/graal_version.txt

# Stage 2: GraalPy venv bauen (auf Base-Image damit glibc/libs übereinstimmen)
FROM ${BASE_IMAGE} AS venv-builder

# 2a: Build-Dependencies installieren (cached solange Basis-Image gleich bleibt)
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget ca-certificates \
    build-essential g++ gfortran cmake meson ninja-build pkg-config autoconf automake libtool \
    libssl-dev libffi-dev libpq-dev libxml2-dev libxslt1-dev \
    libjpeg-dev libpng-dev zlib1g-dev libbz2-dev liblzma-dev \
    libopenblas-dev liblapack-dev \
    libsqlite3-dev libreadline-dev libncurses-dev \
    libcurl4-openssl-dev libgmp-dev libmpfr-dev \
    patchelf patch libstdc++6 git \
    && rm -rf /var/lib/apt/lists/*

# 2b: GraalPy downloaden und entpacken (cached solange Version gleich bleibt)
COPY --from=graal-detector /tmp/graal_version.txt /tmp/graal_version.txt
RUN GRAAL_VER=$(cat /tmp/graal_version.txt) && \
    ARCH=$(uname -m) && \
    GRAAL_ARCH=$([ "$ARCH" = "x86_64" ] && echo "linux-amd64" || echo "linux-aarch64") && \
    GRAALPY_DIR="/openhab/python/graalpy-${GRAAL_VER}-${GRAAL_ARCH}" && \
    mkdir -p "$GRAALPY_DIR" && \
    wget -O /tmp/graalpy.tar.gz \
      "https://github.com/oracle/graalpython/releases/download/graal-${GRAAL_VER}/graalpy-community-jvm-${GRAAL_VER}-${GRAAL_ARCH}.tar.gz" && \
    tar xzf /tmp/graalpy.tar.gz -C "$GRAALPY_DIR" --strip-components=1 && \
    rm /tmp/graalpy.tar.gz

# 2c: venv erstellen (cached solange GraalPy-Version gleich bleibt)
RUN GRAAL_VER=$(cat /tmp/graal_version.txt) && \
    ARCH=$(uname -m) && \
    GRAAL_ARCH=$([ "$ARCH" = "x86_64" ] && echo "linux-amd64" || echo "linux-aarch64") && \
    GRAALPY_DIR="/openhab/python/graalpy-${GRAAL_VER}-${GRAAL_ARCH}" && \
    "$GRAALPY_DIR/bin/graalpy" -m venv /openhab/python/venv && \
    echo "$GRAAL_VER" > "/openhab/python/graalpy.version" && \
    rm /tmp/graal_version.txt

# 2d: pip install (invalidiert nur bei requirements.txt-Änderung)
COPY requirements.txt /openhab/requirements.txt
RUN /openhab/python/venv/bin/pip install -r /openhab/requirements.txt

# Stage 3: Final Image
FROM ${BASE_IMAGE}

RUN apt-get update && apt-get install -y --no-install-recommends \
    libstdc++6 libgfortran5 \
    libssl3 libffi8 \
    libpq5 \
    libxml2 libxslt1.1 \
    libjpeg62-turbo libpng16-16 zlib1g \
    libopenblas0 \
    libcurl4 \
    && rm -rf /var/lib/apt/lists/*

COPY --chown=9001:9001 --from=venv-builder /openhab/python /openhab/python
COPY --chown=9001:9001 requirements.txt /openhab/requirements.txt

RUN mkdir -p /etc/cont-init.d
COPY cont-init.d/* /etc/cont-init.d/
RUN chmod +x /etc/cont-init.d/*
