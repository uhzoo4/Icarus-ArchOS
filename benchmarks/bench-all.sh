#!/bin/bash
echo "=== Icarus Benchmark $(date) ==="
echo "Boot time: (measured elsewhere)"
echo "Memory bandwidth:"
dd if=/dev/zero of=/dev/null bs=1M count=1024 2>&1 | grep copied
echo "Python NumPy matmul:"
python -c "import numpy; a=numpy.random.randn(1024,1024); b=numpy.random.randn(1024,1024); %timeit a@b" 2>&1