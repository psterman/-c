package poc

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
)

func TestShellFtbControlShowHide(t *testing.T) {
	dir := t.TempDir()
	htmlDir := filepath.Join(dir, "html")
	if err := os.MkdirAll(htmlDir, 0o755); err != nil {
		t.Fatal(err)
	}
	stub := filepath.Join(htmlDir, "FloatingToolbarStrip.html")
	if err := os.WriteFile(stub, []byte("<html>ftb</html>"), 0o644); err != nil {
		t.Fatal(err)
	}

	ctrl := NewShellFtbController(dir)
	ctrl.SetAddr("127.0.0.1:18791")
	mux := http.NewServeMux()
	ctrl.RegisterRoutes(mux)

	showBody, _ := json.Marshal(map[string]string{"action": "show", "entry": "test"})
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, ShellFtbControlPath, bytes.NewReader(showBody))
	mux.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("show status=%d body=%s", rec.Code, rec.Body.String())
	}
	st := ctrl.Status()
	if !st.Visible || !st.Mounted {
		t.Fatalf("expected visible mounted, got %+v", st)
	}
	if st.Phase != 2 {
		t.Fatalf("phase=%d", st.Phase)
	}

	htmlRec := httptest.NewRecorder()
	htmlReq := httptest.NewRequest(http.MethodGet, ShellFtbHtmlPrefix+"FloatingToolbarStrip.html", nil)
	mux.ServeHTTP(htmlRec, htmlReq)
	if htmlRec.Code != http.StatusOK {
		t.Fatalf("html status=%d", htmlRec.Code)
	}
}
