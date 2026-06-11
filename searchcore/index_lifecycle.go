//go:build windows

package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

const fullTextSchemaVersion = 3

type IndexCutoverState string

const (
	CutoverIdle       IndexCutoverState = "idle"
	CutoverBuilding   IndexCutoverState = "building"
	CutoverReady      IndexCutoverState = "ready"
	CutoverDone       IndexCutoverState = "cutover_done"
)

type IndexRole string

const (
	IndexRoleActive         IndexRole = "active"
	IndexRoleLegacyReadonly IndexRole = "legacy_readonly"
	IndexRoleBuilding       IndexRole = "building"
	IndexRoleRetired        IndexRole = "retired"
)

type indexManifest struct {
	SchemaVersion        int               `json:"schemaVersion"`
	ConfigFingerprint    string            `json:"configFingerprint"`
	ActiveDir            string            `json:"activeDir"`
	LegacyDir            string            `json:"legacyDir,omitempty"`
	BuildingDir          string            `json:"buildingDir,omitempty"`
	CutoverState         IndexCutoverState `json:"cutoverState"`
	LegacyRetentionUntil string            `json:"legacyRetentionUntil,omitempty"`
	IndexVersion         string            `json:"indexVersion,omitempty"`
}

type indexLifecycleSnapshot struct {
	Role              IndexRole         `json:"role"`
	CutoverState      IndexCutoverState `json:"cutoverState"`
	ConfigFingerprint string            `json:"configFingerprint"`
	SchemaVersion     int               `json:"schemaVersion"`
	ActiveDir         string            `json:"activeDir"`
	LegacyDir         string            `json:"legacyDir,omitempty"`
	BuildingDir       string            `json:"buildingDir,omitempty"`
	LegacyReadonly    bool              `json:"legacyReadonly"`
}

type indexLifecycleManager struct {
	baseIndexDir string
	manifestPath string
	manifest     indexManifest
	mu           sync.Mutex
}

func newIndexLifecycleManager(indexDir string, cfg fullTextConfig) (*indexLifecycleManager, error) {
	mgr := &indexLifecycleManager{
		baseIndexDir: filepath.Clean(indexDir),
		manifestPath: filepath.Join(indexDir, "manifest.json"),
	}
	fp := computeConfigFingerprint(cfg.BaseDir, cfg)
	if err := mgr.loadOrInit(fp); err != nil {
		return nil, err
	}
	if err := mgr.reconcile(cfg, fp); err != nil {
		return nil, err
	}
	return mgr, nil
}

func (m *indexLifecycleManager) activeIndexDir() string {
	if m == nil {
		return ""
	}
	return filepath.Join(m.baseIndexDir, m.manifest.ActiveDir)
}

func (m *indexLifecycleManager) legacyIndexDir() string {
	if m == nil || strings.TrimSpace(m.manifest.LegacyDir) == "" {
		return ""
	}
	return filepath.Join(m.baseIndexDir, m.manifest.LegacyDir)
}

func (m *indexLifecycleManager) buildingIndexDir() string {
	if m == nil || strings.TrimSpace(m.manifest.BuildingDir) == "" {
		return ""
	}
	return filepath.Join(m.baseIndexDir, m.manifest.BuildingDir)
}

// writerIndexDir returns the directory the bluge writer should use.
func (m *indexLifecycleManager) writerIndexDir() string {
	if m == nil {
		return ""
	}
	m.mu.Lock()
	state := m.manifest.CutoverState
	buildName := strings.TrimSpace(m.manifest.BuildingDir)
	activeName := strings.TrimSpace(m.manifest.ActiveDir)
	m.mu.Unlock()
	if activeName == "" {
		activeName = "active"
	}
	if state == CutoverBuilding || state == CutoverReady {
		if buildName == "" {
			buildName = "building"
		}
		return filepath.Join(m.baseIndexDir, buildName)
	}
	return filepath.Join(m.baseIndexDir, activeName)
}

// queryIndexDir returns the directory searches should read during cutover.
func (m *indexLifecycleManager) queryIndexDir() string {
	if m == nil {
		return ""
	}
	m.mu.Lock()
	state := m.manifest.CutoverState
	activeName := strings.TrimSpace(m.manifest.ActiveDir)
	legacyName := strings.TrimSpace(m.manifest.LegacyDir)
	m.mu.Unlock()
	if activeName == "" {
		activeName = "active"
	}
	if state == CutoverBuilding || state == CutoverReady {
		if legacyName != "" {
			return filepath.Join(m.baseIndexDir, legacyName)
		}
		return filepath.Join(m.baseIndexDir, activeName)
	}
	return filepath.Join(m.baseIndexDir, activeName)
}

func (m *indexLifecycleManager) snapshot() indexLifecycleSnapshot {
	if m == nil {
		return indexLifecycleSnapshot{}
	}
	m.mu.Lock()
	defer m.mu.Unlock()
	role := IndexRoleActive
	legacyRO := false
	if m.manifest.CutoverState == CutoverBuilding || m.manifest.CutoverState == CutoverReady {
		role = IndexRoleBuilding
	}
	if strings.TrimSpace(m.manifest.LegacyDir) != "" {
		legacyRO = true
	}
	return indexLifecycleSnapshot{
		Role:              role,
		CutoverState:      m.manifest.CutoverState,
		ConfigFingerprint: m.manifest.ConfigFingerprint,
		SchemaVersion:     m.manifest.SchemaVersion,
		ActiveDir:         m.manifest.ActiveDir,
		LegacyDir:         m.manifest.LegacyDir,
		BuildingDir:       m.manifest.BuildingDir,
		LegacyReadonly:    legacyRO,
	}
}

func loadIndexLifecycleSnapshot(baseDir string) (indexLifecycleSnapshot, error) {
	cfg := loadFullTextConfig(baseDir)
	mgr, err := newIndexLifecycleManager(cfg.IndexDir, cfg)
	if err != nil {
		return indexLifecycleSnapshot{}, err
	}
	return mgr.snapshot(), nil
}

func (m *indexLifecycleManager) loadOrInit(fp string) error {
	if err := os.MkdirAll(m.baseIndexDir, 0o755); err != nil {
		return err
	}
	if buf, err := os.ReadFile(m.manifestPath); err == nil {
		var loaded indexManifest
		if json.Unmarshal(buf, &loaded) == nil && loaded.SchemaVersion > 0 {
			m.manifest = loaded
			return nil
		}
	}
	legacyDir := m.baseIndexDir
	entries, readErr := os.ReadDir(legacyDir)
	hasLegacy := false
	if readErr == nil {
		for _, e := range entries {
			if e.Name() == "manifest.json" {
				continue
			}
			hasLegacy = true
			break
		}
	}
	activeDirName := "active"
	if hasLegacy && readErr == nil {
		if err := os.MkdirAll(filepath.Join(m.baseIndexDir, activeDirName), 0o755); err != nil {
			return err
		}
		// migrate flat legacy layout into active/
		for _, e := range entries {
			if e.Name() == activeDirName || e.Name() == "legacy_readonly" || e.Name() == "building" || e.Name() == "manifest.json" {
				continue
			}
			src := filepath.Join(legacyDir, e.Name())
			dst := filepath.Join(legacyDir, activeDirName, e.Name())
			_ = os.Rename(src, dst)
		}
	}
	m.manifest = indexManifest{
		SchemaVersion:     fullTextSchemaVersion,
		ConfigFingerprint: fp,
		ActiveDir:         activeDirName,
		CutoverState:      CutoverIdle,
		IndexVersion:      fullTextIndexVersion,
	}
	return m.save()
}

func (m *indexLifecycleManager) reconcile(cfg fullTextConfig, fp string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if m.manifest.SchemaVersion != fullTextSchemaVersion {
		if err := m.beginSchemaMigrationLocked(); err != nil {
			return err
		}
	}
	if m.manifest.ConfigFingerprint != fp {
		if err := m.onFingerprintChangeLocked(fp); err != nil {
			return err
		}
	}
	return m.saveLocked()
}

func (m *indexLifecycleManager) onFingerprintChangeLocked(newFP string) error {
	oldFP := m.manifest.ConfigFingerprint
	m.manifest.ConfigFingerprint = newFP
	if oldFP == "" {
		return nil
	}
	if m.manifest.CutoverState == CutoverBuilding {
		return nil
	}
	// roots-only shrink handled by doc pruning; schema/tier changes spawn building index
	if m.manifest.SchemaVersion == fullTextSchemaVersion {
		return m.beginBuildingLocked()
	}
	return nil
}

func (m *indexLifecycleManager) beginSchemaMigrationLocked() error {
	active := filepath.Join(m.baseIndexDir, m.manifest.ActiveDir)
	if st, err := os.Stat(active); err == nil && st.IsDir() {
		legacyName := "legacy_readonly"
		legacyPath := filepath.Join(m.baseIndexDir, legacyName)
		if _, lerr := os.Stat(legacyPath); lerr != nil {
			_ = os.Rename(active, legacyPath)
			m.manifest.LegacyDir = legacyName
		}
	}
	m.manifest.ActiveDir = "active"
	m.manifest.BuildingDir = "building"
	m.manifest.CutoverState = CutoverBuilding
	m.manifest.SchemaVersion = fullTextSchemaVersion
	return os.MkdirAll(filepath.Join(m.baseIndexDir, m.manifest.BuildingDir), 0o755)
}

func (m *indexLifecycleManager) beginBuildingLocked() error {
	if strings.TrimSpace(m.manifest.BuildingDir) == "" {
		m.manifest.BuildingDir = "building"
	}
	buildPath := filepath.Join(m.baseIndexDir, m.manifest.BuildingDir)
	if err := os.MkdirAll(buildPath, 0o755); err != nil {
		return err
	}
	m.manifest.CutoverState = CutoverBuilding
	return nil
}

func (m *indexLifecycleManager) markBuildingReady() error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.manifest.CutoverState != CutoverBuilding {
		return nil
	}
	m.manifest.CutoverState = CutoverReady
	return m.saveLocked()
}

func (m *indexLifecycleManager) cutoverIfReady(pendingTasks int) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.manifest.CutoverState != CutoverReady || pendingTasks > 0 {
		return nil
	}
	buildName := strings.TrimSpace(m.manifest.BuildingDir)
	if buildName == "" {
		return errors.New("building dir missing")
	}
	activeName := strings.TrimSpace(m.manifest.ActiveDir)
	if activeName == "" {
		activeName = "active"
	}
	activePath := filepath.Join(m.baseIndexDir, activeName)
	if _, err := os.Stat(activePath); err == nil {
		legacyName := "legacy_readonly"
		legacyPath := filepath.Join(m.baseIndexDir, legacyName)
		if _, lerr := os.Stat(legacyPath); lerr == nil {
			_ = os.RemoveAll(legacyPath)
		}
		_ = os.Rename(activePath, legacyPath)
		m.manifest.LegacyDir = legacyName
	}
	_ = os.Rename(filepath.Join(m.baseIndexDir, buildName), activePath)
	m.manifest.ActiveDir = activeName
	m.manifest.BuildingDir = ""
	m.manifest.CutoverState = CutoverDone
	until := time.Now().Add(7 * 24 * time.Hour).UTC().Format(time.RFC3339)
	m.manifest.LegacyRetentionUntil = until
	return m.saveLocked()
}

func (m *indexLifecycleManager) save() error {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.saveLocked()
}

func (m *indexLifecycleManager) saveLocked() error {
	out, err := json.MarshalIndent(m.manifest, "", "  ")
	if err != nil {
		return err
	}
	tmp := m.manifestPath + ".tmp"
	if err := os.WriteFile(tmp, out, 0o644); err != nil {
		return err
	}
	return os.Rename(tmp, m.manifestPath)
}

func ensureIndexDirsForLifecycle(indexDir string, cfg fullTextConfig) (writerDir, queryDir string, mgr *indexLifecycleManager, forceRebuild bool, err error) {
	mgr, err = newIndexLifecycleManager(indexDir, cfg)
	if err != nil {
		return "", "", nil, false, err
	}
	writerDir = mgr.writerIndexDir()
	queryDir = mgr.queryIndexDir()
	if err := os.MkdirAll(writerDir, 0o755); err != nil {
		return "", "", mgr, false, err
	}
	state := mgr.manifest.CutoverState
	if state == CutoverBuilding || state == CutoverReady {
		forceRebuild = true
	}
	changed, verr := ensureIndexVersion(writerDir, fullTextIndexVersion)
	if verr != nil {
		return "", "", mgr, false, fmt.Errorf("ensure index version failed: %w", verr)
	}
	if changed {
		forceRebuild = true
	}
	return writerDir, queryDir, mgr, forceRebuild, nil
}
