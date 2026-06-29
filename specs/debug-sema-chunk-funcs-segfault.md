# Debug Session: semaChunkFuncs Segmentation Fault

**Status**: [OPEN]
**Session ID**: sema-chunk-funcs-segfault
**Created**: 2026-06-28

## Symptom
- Command: `zig build behavior-test -Doptimize=Debug`
- Crash: Segmentation fault at address 0x32cca0000
- Last successful output: `semaChunkFuncs: i=260 func=from_znode_auto, isMethod=false`
- Crash location: In or after processing function i=260 in `semaChunkFuncs`

## Environment
- OS: macOS
- Zig version: 0.16
- Build mode: Debug
- Project: doe language (migrated from cyber)

## Hypotheses
1. **H1**: Function pointer at i=261 is invalid (null, freed, or corrupted memory)
   - Observation: Check if `c.funcs.items[261]` points to valid memory
   - Test: Add null check and memory validation before accessing func

2. **H2**: ArrayList reallocation during i=260 processing invalidated cached pointer
   - Observation: Check if `c.funcs.items.ptr` changed after processing i=260
   - Test: Print pointer address before and after each iteration

3. **H3**: Stack overflow from deep recursion in `semaFuncBody`
   - Observation: Check call stack depth
   - Test: Add recursion depth counter

4. **H4**: Memory corruption from previous operation manifests at i=261
   - Observation: Check memory state around the crash address
   - Test: Add memory validation checks throughout the loop

5. **H5**: `from_znode_auto` function (i=260) has semantic analysis issue that corrupts state
   - Observation: Check if crash happens during or after processing i=260
   - Test: Add detailed logging around i=260 processing

## Evidence Collection
- (pending instrumentation)

## Analysis
- (pending evidence)

## Fix
- (pending analysis)
