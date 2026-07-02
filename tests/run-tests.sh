#!/bin/bash
# ------------------------------------------------------------------
# Icarus Test Suite Runner
# Executes all available tests and reports status.
# ------------------------------------------------------------------
set -euo pipefail

PASS=0
FAIL=0
log_pass() { echo "[PASS] $*"; PASS=$((PASS+1)); }
log_fail() { echo "[FAIL] $*"; FAIL=$((FAIL+1)); }

# Test 1: RAM-root integrity (if ram-root is active, verify / is tmpfs)
if mount | grep -q 'on / type tmpfs'; then
    log_pass "RAM-root active: / is tmpfs"
else
    log_fail "RAM-root not active"
fi

# Test 2: Vulkan UMA buffer creation
python3 -c "
from icarus_vulkan_engine import IcarusVulkanBackend, UMATensor
import numpy as np
back = IcarusVulkanBackend()
t = UMATensor(back, (1024,), np.float32)
t.array[:] = np.arange(1024, dtype=np.float32)
assert np.allclose(t.array, np.arange(1024))
t.free()
back.cleanup()
" 2>/dev/null && log_pass "Vulkan UMA buffer test" || log_fail "Vulkan UMA buffer test"

# Test 3: Thermal throttling simulation (run sentinel briefly)
sudo /usr/local/bin/icarus-sentinel.sh &
SENTINEL_PID=$!
sleep 5
if kill -0 $SENTINEL_PID 2>/dev/null; then
    kill $SENTINEL_PID
    log_pass "Sentinel daemon runs"
else
    log_fail "Sentinel daemon died"
fi

# Test 4: zram swap active
if swapon --show | grep -q zram0; then
    log_pass "zram swap active"
else
    log_fail "zram swap not active"
fi

# Test 5: Stealth TTY script syntax
bash -n /usr/local/bin/icarus-stealth.sh && log_pass "Stealth TTY script valid" || log_fail "Stealth TTY script syntax error"

echo "----------------------------------------"
echo "Results: $PASS passed, $FAIL failed"