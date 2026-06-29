# cd /opt/repos/doe && make clean && make build

cd /opt/repos/doe && echo "=== ReleaseSafe build ===" && make clean && make rebuild 2>&1 | tail -15 && echo -e "\n=== Debug build ===" && make clean && make debug 2>&1 | tail -10 && echo -e "\n=== Behavior test ===" && zig build behavior-test -Doptimize=Debug 2>&1

cd /opt/repos/doe && make clean && zig build behavior-test -Doptimize=Debug 2>&1 | tail -50
zig build behavior-test -Doptimize=Debug 2>&1 | grep -E "Build Summary|failure|error:|spawn" | tail -20
zig build behavior-test -
Doptimize=Debug 2>&1 | grep -A50 "panic:|Segmentation|unreleased|Retaining" | tail -80
