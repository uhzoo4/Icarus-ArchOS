#!/bin/bash
# ------------------------------------------------------------------
# Icarus Python & NumPy build with Profile-Guided Optimization
# and BOLT binary optimization.  Requires: base-devel, wget, git,
# perf, llvm-bolt.
# ------------------------------------------------------------------
set -euo pipefail

PY_VERSION="3.12.4"
NUMPY_VERSION="1.26.4"
INSTALL_PREFIX="/opt/icarus-python"
CORES=$(nproc)

log() { echo "[Build] $*"; }

# 1. Install dependencies
sudo pacman -S --needed --noconfirm base-devel wget git perf llvm llvm-libs \
    zlib bzip2 openssl libffi ncurses sqlite readline xz tk

# 2. Build Python with PGO
log "Building Python ${PY_VERSION} with PGO..."
cd /tmp
wget -q https://www.python.org/ftp/python/${PY_VERSION}/Python-${PY_VERSION}.tgz
tar xf Python-${PY_VERSION}.tgz
cd Python-${PY_VERSION}

# Step 1: produce profile
./configure --prefix="$INSTALL_PREFIX" --enable-optimizations --with-lto
make -j$CORES PROFILE_TASK="-m test.regrtest --pgo" 2>&1 | tee build.log
# Step 2: use profile to build final binary
make -j$CORES 2>&1 | tee build.log
sudo make altinstall

# 3. Build NumPy from source, linked against OpenBLAS (also compiled)
log "Building NumPy ${NUMPY_VERSION}..."
cd /tmp
git clone --recursive https://github.com/numpy/numpy.git
cd numpy
git checkout v${NUMPY_VERSION}

# Build OpenBLAS first (if not present)
if ! ldconfig -p | grep -q libopenblas; then
    cd /tmp
    git clone https://github.com/xianyi/OpenBLAS.git
    cd OpenBLAS
    make -j$CORES TARGET=HASWELL USE_OPENMP=1
    sudo make PREFIX=/usr install
fi

# Build NumPy with native flags
export CFLAGS="-O3 -march=native -flto -fopenmp"
export LDFLAGS="-fopenmp"
python3.12 -m pip install --no-cache-dir --prefix "$INSTALL_PREFIX" .

# 4. Apply BOLT optimization to the Python binary (post-link)
log "Applying BOLT optimization to Python binary..."
# Record profile of a typical workload (e.g., import numpy, some computation)
PYBIN="$INSTALL_PREFIX/bin/python3.12"
perf record -e cycles:u -j any,u -o /tmp/python.perf.data -- $PYBIN -c "import numpy; a=numpy.random.rand(1000,1000); b=numpy.random.rand(1000,1000); c=a@b"
llvm-bolt "$PYBIN" -o "$PYBIN.bolt" --data /tmp/python.perf.data --reorder-blocks=ext-tsp --reorder-functions=hfsort+ \
    --split-functions=3 --split-all-cold --dyno-stats --icf=1 --use-gnu-stack
sudo mv "$PYBIN.bolt" "$PYBIN"

log "Python and NumPy installed to $INSTALL_PREFIX"
echo "Add $INSTALL_PREFIX/bin to your PATH to use."