; SearchCenterWebLlm 宿主符号声明（仅 LSP / IntelliSense，不参与运行）

ScWebLlm_NormalizeSiteId(siteId) {
}

ScWebLlm_SiteCatalog() {
}

WebView2_EnsureScWebLlmSiteDataDir(siteId, outMeta := 0) {
}

WebView2_CreateWithSiteDataDirAsync(hostHwnd, siteId, callback, reason := "") {
}

Nmer_ScWebLlmStatePath() {
}

NmerCatch(funcName, err) {
}

Nmer_Telemetry_Record(scope, action, ok := true, meta := 0) {
}

Nmer_DebugPath(fileName) {
}

Jxon_Load(src, args*) {
}

Jxon_Dump(obj, args*) {
}

ScWebLlm_ValidateSiteCatalog() {
}

ScWebLlm_SiteEmbedEnabled(site) {
}

ScWebLlm_SiteCapability(siteId, key, default := "") {
}

ScWebLlm_SiteQueryMode(siteId := "") {
}

ScWebLlm_SiteUaMode(siteId := "") {
}

ScWebLlm_SiteProfileMode(siteId := "") {
}

ScWebLlm_DefaultOpenSiteIds() {
}

ScWebLlm_ApplySiteIdAlias(rawId) {
}

ScWebLlm_MakeSite(id, label, homeUrl, opts := "") {
}

ScWebLlm_FindSite(siteId) {
}

ScWebLlm_IsSiteEnabled(siteId) {
}

ScWebLlm_NormalizeBroadcastSiteIds(rawIds) {
}

ScWebLlm_MaxBroadcastColumns() {
}

ScWebLlm_DefaultSiteId() {
}

ScWebLlm_SiteHomeUrl(siteId) {
}

ScWebLlm_EngineToSiteId(engine) {
}

ScWebLlm_IsEmbedEngine(engine) {
}

ScWebLlm_PickSiteFromEngines(engines) {
}

SearchCenterWebLlm_NavigateEngine(engine, keyword := "") {
}

SearchCenterWebLlm_Show(parentHwnd) {
}

SearchCenterWebLlm_MarkEmbedRequested() {
}

SearchCenterWebLlm_StartEmbedWatchdog() {
}

SearchCenterWebLlm_EnsureEmbedSitesLoaded(forceNavigateHome := false, parentHwnd := 0) {
}

ScWebLlm_GetEmbedParentHwnd() {
}

ScWebLlm_ResolveEmbedHostHwnd() {
}

ScWebLlm_ScheduleEmbedBootstrap() {
}

SearchCenterWebLlm_CanBootstrapEmbed() {
}

SearchCenterWebLlm_Hide() {
}

SearchCenterWebLlm_TeardownEmbed(preservePrefs := true) {
}

SearchCenterWebLlm_Dispose() {
}

SearchCenterWebLlm_ApplyBounds(parentHwnd := 0) {
}

SearchCenterWebLlm_SetContentRect(rect) {
}

SearchCenterWebLlm_SelectSite(siteId) {
}

SearchCenterWebLlm_FocusSite(siteId) {
}

ScWebLlm_ResolveTargetSites(engines := 0) {
}

SearchCenterWebLlm_BroadcastSearch(keyword, engines := 0) {
}

SearchCenterWebLlm_ReloadSites(engines := 0) {
}

SearchCenterWebLlm_HandleNav(action) {
}

SearchCenterWebLlm_BuildDebugSnapshot(clientMeta := 0) {
}

SCWV_PostJson(jsonStr) {
}

SearchCenterWebLlm_PrepareForScriptReload() {
}
