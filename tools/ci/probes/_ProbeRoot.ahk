; Shared by SearchCore CI probes — resolve repo root from tools/ci/probes
Probe_ResolveProjectRoot() {
    root := A_ScriptDir
    Loop 3 {
        SplitPath root, , &root
    }
    return root
}
