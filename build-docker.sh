#!/usr/bin/env bash
set -e -o pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

CONTAINER_NAME=${CONTAINER_NAME:-trezor-firmware-env.nix}
ALPINE_CDN=${ALPINE_CDN:-http://dl-cdn.alpinelinux.org/alpine}
ALPINE_RELEASE=${ALPINE_RELEASE:-3.12}
ALPINE_ARCH=${ALPINE_ARCH:-x86_64}
ALPINE_VERSION=${ALPINE_VERSION:-3.12.3}
CONTAINER_FS_URL=${CONTAINER_FS_URL:-"$ALPINE_CDN/v$ALPINE_RELEASE/releases/$ALPINE_ARCH/alpine-minirootfs-$ALPINE_VERSION-$ALPINE_ARCH.tar.gz"}

TAG=${1:-master}
REPOSITORY=${2:-/local}
PRODUCTION=${PRODUCTION:-1}
MEMORY_PROTECT=${MEMORY_PROTECT:-1}

wget --no-config -nc -P ci/ "$CONTAINER_FS_URL"
docker build --platform "linux/$ALPINE_ARCH" --build-arg ALPINE_VERSION="$ALPINE_VERSION" --build-arg ALPINE_ARCH="$ALPINE_ARCH" -t "$CONTAINER_NAME" ci/

# stat under macOS has slightly different cli interface
USER=$(stat -c "%u" . 2>/dev/null || stat -f "%u" .)
GROUP=$(stat -c "%g" . 2>/dev/null || stat -f "%g" .)

mkdir -p build/core build/legacy
mkdir -p build/core-bitcoinonly build/legacy-bitcoinonly

DIR=$(pwd)

# build core

for BITCOIN_ONLY in 0 1; do

  DIRSUFFIX=${BITCOIN_ONLY/1/-bitcoinonly}
  DIRSUFFIX=${DIRSUFFIX/0/}

  SCRIPT_NAME=".build_core_$BITCOIN_ONLY.sh"
  cat <<EOF > "build/$SCRIPT_NAME"
    # DO NOT MODIFY!
    # this file was generated by ${BASH_SOURCE[0]}
    # variant: core build BITCOIN_ONLY=$BITCOIN_ONLY
    set -e -o pipefail
    cd /tmp
    git clone "$REPOSITORY" trezor-firmware
    cd trezor-firmware/core
    ln -s /build build
    git checkout "$TAG"
    git submodule update --init --recursive
    poetry install
    poetry run make clean vendor build_firmware
    poetry run ../python/tools/firmware-fingerprint.py \
               -o build/firmware/firmware.bin.fingerprint \
               build/firmware/firmware.bin
    chown -R $USER:$GROUP /build
EOF

  docker run --platform "linux/$ALPINE_ARCH" -it --rm \
    -v "$DIR:/local" \
    -v "$DIR/build/core$DIRSUFFIX":/build:z \
    --env BITCOIN_ONLY="$BITCOIN_ONLY" \
    --env PRODUCTION="$PRODUCTION" \
    --init \
    "$CONTAINER_NAME" \
    /nix/var/nix/profiles/default/bin/nix-shell --run "bash /local/build/$SCRIPT_NAME"
done

# build legacy

for BITCOIN_ONLY in 0 1; do

  DIRSUFFIX=${BITCOIN_ONLY/1/-bitcoinonly}
  DIRSUFFIX=${DIRSUFFIX/0/}

  SCRIPT_NAME=".build_legacy_$BITCOIN_ONLY.sh"
  cat <<EOF > "build/$SCRIPT_NAME"
    # DO NOT MODIFY!
    # this file was generated by ${BASH_SOURCE[0]}
    # variant: legacy build BITCOIN_ONLY=$BITCOIN_ONLY
    set -e -o pipefail
    cd /tmp
    git clone "$REPOSITORY" trezor-firmware
    cd trezor-firmware/legacy
    ln -s /build build
    git checkout "$TAG"
    git submodule update --init --recursive
    poetry install
    poetry run script/cibuild
    mkdir -p build/firmware
    cp firmware/trezor.bin build/firmware/firmware.bin
    cp firmware/trezor.elf build/firmware/firmware.elf
    poetry run ../python/tools/firmware-fingerprint.py \
               -o build/firmware/firmware.bin.fingerprint \
               build/firmware/firmware.bin
    chown -R $USER:$GROUP /build
EOF

  docker run --platform "linux/$ALPINE_ARCH" -it --rm \
    -v "$DIR:/local" \
    -v "$DIR/build/legacy$DIRSUFFIX":/build:z \
    --env BITCOIN_ONLY="$BITCOIN_ONLY" \
    --env MEMORY_PROTECT="$MEMORY_PROTECT" \
    --init \
    "$CONTAINER_NAME" \
    /nix/var/nix/profiles/default/bin/nix-shell --run "bash /local/build/$SCRIPT_NAME"

done

# all built, show fingerprints

echo "Fingerprints:"
for VARIANT in core legacy; do
  for BITCOIN_ONLY in 0 1; do

    DIRSUFFIX=${BITCOIN_ONLY/1/-bitcoinonly}
    DIRSUFFIX=${DIRSUFFIX/0/}

    FWPATH=build/${VARIANT}${DIRSUFFIX}/firmware/firmware.bin
    FINGERPRINT=$(tr -d '\n' < $FWPATH.fingerprint)
    echo "$FINGERPRINT $FWPATH"
  done
done
