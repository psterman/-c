; SearchCenterWebLlmSites.ahk — 联网搜索内嵌 AI 站点 catalog（候选池 / 默认 / 能力字段）
#Requires AutoHotkey v2.0

global g_ScWebLlm_SiteCatalogCache := 0
global g_ScWebLlm_SiteCatalogById := 0

ScWebLlm_MaxBroadcastColumns() {
    return 8
}

ScWebLlm_MakeSite(id, label, homeUrl, opts := "") {
    site := Map(
        "id", id,
        "label", label,
        "homeUrl", homeUrl,
        "embedEnabled", true,
        "defaultOpen", false,
        "iconKey", id,
        "kind", "chat",
        "queryMode", "inject",
        "uaMode", "mobile",
        "profileMode", "shared",
        "embedRisk", "untested",
        "submitDelayMs", 0
    )
    if (opts is Map) {
        for k, v in opts
            site[k] := v
    }
    return site
}

ScWebLlm_BuildSiteCatalogArray() {
    return [
        ScWebLlm_MakeSite("deepseek", "DeepSeek", "https://chat.deepseek.com/",
            Map("defaultOpen", true, "embedRisk", "none", "submitDelayMs", 550)),
        ScWebLlm_MakeSite("doubao", "豆包", "https://www.doubao.com/chat/",
            Map("defaultOpen", true, "embedRisk", "none")),
        ScWebLlm_MakeSite("gemini", "Gemini", "https://gemini.google.com/app",
            Map("defaultOpen", true, "uaMode", "desktop", "embedRisk", "login", "submitDelayMs", 550)),
        ScWebLlm_MakeSite("grok", "Grok", "https://grok.com/",
            Map("defaultOpen", true, "queryMode", "url", "uaMode", "desktop", "embedRisk", "none")),
        ScWebLlm_MakeSite("perplexity", "Perplexity", "https://www.perplexity.ai/",
            Map("defaultOpen", true, "kind", "search", "queryMode", "url", "uaMode", "desktop", "profileMode", "isolated", "embedRisk", "none")),
        ScWebLlm_MakeSite("kimi", "Kimi", "https://kimi.moonshot.cn/",
            Map("embedRisk", "none")),
        ScWebLlm_MakeSite("claude", "Claude", "https://claude.ai/",
            Map("uaMode", "desktop", "embedRisk", "login")),
        ScWebLlm_MakeSite("yuanbao", "元宝", "https://yuanbao.tencent.com/",
            Map("embedRisk", "none")),
        ScWebLlm_MakeSite("aistudio", "AI Studio", "https://aistudio.google.com/",
            Map("iconKey", "gemini", "uaMode", "desktop", "embedRisk", "login")),
        ScWebLlm_MakeSite("nami", "纳米 AI", "https://www.n.cn/",
            Map("kind", "search", "queryMode", "url", "uaMode", "desktop")),
        ScWebLlm_MakeSite("mita", "秘塔", "https://metaso.cn/",
            Map("kind", "search", "queryMode", "url", "uaMode", "desktop", "embedRisk", "none")),
        ScWebLlm_MakeSite("qianwen", "千问", "https://tongyi.aliyun.com/qianwen/",
            Map("iconKey", "qwen", "embedRisk", "none")),
        ScWebLlm_MakeSite("copilot", "Copilot", "https://copilot.microsoft.com/",
            Map("uaMode", "desktop", "embedRisk", "login")),
        ScWebLlm_MakeSite("lmarena", "LMArena", "https://lmarena.ai/",
            Map("uaMode", "desktop")),
        ScWebLlm_MakeSite("manus", "Manus", "https://manus.im/",
            Map("uaMode", "desktop")),
        ScWebLlm_MakeSite("mistral", "Mistral", "https://chat.mistral.ai/",
            Map("uaMode", "desktop")),
        ScWebLlm_MakeSite("yupp", "Yupp", "https://yupp.ai/",
            Map("uaMode", "desktop")),
        ScWebLlm_MakeSite("zai", "Z.ai", "https://z.ai/",
            Map("uaMode", "desktop")),
        ScWebLlm_MakeSite("coze", "扣子", "https://www.coze.cn/",
            Map("embedRisk", "none")),
        ScWebLlm_MakeSite("tiangong", "天工", "https://www.tiangong.cn/",
            Map("uaMode", "desktop")),
        ScWebLlm_MakeSite("wenxin", "文心一言", "https://yiyan.baidu.com/",
            Map("embedRisk", "none")),
    ]
}

ScWebLlm_EnsureSiteCatalogCache() {
    global g_ScWebLlm_SiteCatalogCache, g_ScWebLlm_SiteCatalogById
    if IsObject(g_ScWebLlm_SiteCatalogCache) && IsObject(g_ScWebLlm_SiteCatalogById)
        return
    g_ScWebLlm_SiteCatalogCache := ScWebLlm_BuildSiteCatalogArray()
    g_ScWebLlm_SiteCatalogById := Map()
    for site in g_ScWebLlm_SiteCatalogCache {
        if !(site is Map) || !site.Has("id")
            continue
        g_ScWebLlm_SiteCatalogById[site["id"]] := site
    }
}

ScWebLlm_SiteCatalog() {
    ScWebLlm_EnsureSiteCatalogCache()
    global g_ScWebLlm_SiteCatalogCache
    return g_ScWebLlm_SiteCatalogCache
}

ScWebLlm_ApplySiteIdAlias(rawId) {
    id := StrLower(Trim(String(rawId)))
    if (id = "qwen" || id = "tongyi")
        return "qianwen"
    return id
}

ScWebLlm_NormalizeSiteId(siteId) {
    id := ScWebLlm_ApplySiteIdAlias(siteId)
    if (id = "")
        return ""
    ScWebLlm_EnsureSiteCatalogCache()
    global g_ScWebLlm_SiteCatalogById
    return g_ScWebLlm_SiteCatalogById.Has(id) ? id : ""
}

ScWebLlm_FindSite(siteId) {
    id := ScWebLlm_NormalizeSiteId(siteId)
    if (id = "")
        return 0
    ScWebLlm_EnsureSiteCatalogCache()
    global g_ScWebLlm_SiteCatalogById
    return g_ScWebLlm_SiteCatalogById.Has(id) ? g_ScWebLlm_SiteCatalogById[id] : 0
}

ScWebLlm_SiteEmbedEnabled(site) {
    if !(site is Map)
        return false
    if site.Has("embedEnabled")
        return !!site["embedEnabled"]
    return !!site.Get("enabled", false)
}

ScWebLlm_IsSiteEnabled(siteId) {
    return ScWebLlm_SiteEmbedEnabled(ScWebLlm_FindSite(siteId))
}

ScWebLlm_SiteCapability(siteId, key, default := "") {
    site := ScWebLlm_FindSite(siteId)
    if !(site is Map)
        return default
    if site.Has(key)
        return site[key]
    return default
}

ScWebLlm_SiteQueryMode(siteId := "") {
    return Trim(String(ScWebLlm_SiteCapability(siteId, "queryMode", "inject")))
}

ScWebLlm_SiteUaMode(siteId := "") {
    return Trim(String(ScWebLlm_SiteCapability(siteId, "uaMode", "mobile")))
}

ScWebLlm_SiteProfileMode(siteId := "") {
    return Trim(String(ScWebLlm_SiteCapability(siteId, "profileMode", "shared")))
}

ScWebLlm_EngineToSiteId(engine) {
    eng := ScWebLlm_ApplySiteIdAlias(engine)
    if (eng = "")
        return ""
    site := ScWebLlm_FindSite(eng)
    if !(site is Map) || !ScWebLlm_SiteEmbedEnabled(site)
        return ""
    return site["id"]
}

ScWebLlm_IsEmbedEngine(engine) {
    return (ScWebLlm_EngineToSiteId(engine) != "")
}

ScWebLlm_DefaultOpenSiteIds() {
    out := []
    for site in ScWebLlm_SiteCatalog() {
        if ScWebLlm_SiteEmbedEnabled(site) && site.Get("defaultOpen", false)
            out.Push(site["id"])
    }
    if !out.Length {
        for site in ScWebLlm_SiteCatalog() {
            if ScWebLlm_SiteEmbedEnabled(site) {
                out.Push(site["id"])
                break
            }
        }
    }
    return out
}

ScWebLlm_NormalizeBroadcastSiteIds(rawIds) {
    maxCols := ScWebLlm_MaxBroadcastColumns()
    out := []
    if IsObject(rawIds) && rawIds.Length {
        for eng in rawIds {
            sid := ScWebLlm_EngineToSiteId(eng)
            if (sid = "")
                continue
            found := false
            for existing in out {
                if (existing = sid) {
                    found := true
                    break
                }
            }
            if found
                continue
            out.Push(sid)
            if (out.Length >= maxCols)
                break
        }
    }
    if !out.Length {
        for sid in ScWebLlm_DefaultOpenSiteIds()
            out.Push(sid)
    }
    return out
}

ScWebLlm_DefaultSiteId() {
    ids := ScWebLlm_DefaultOpenSiteIds()
    return ids.Length ? ids[1] : "deepseek"
}

ScWebLlm_EnabledSites() {
    out := []
    for site in ScWebLlm_SiteCatalog() {
        if ScWebLlm_SiteEmbedEnabled(site)
            out.Push(site)
    }
    return out
}

ScWebLlm_SiteHomeUrl(siteId) {
    site := ScWebLlm_FindSite(siteId)
    if !(site is Map)
        return ""
    return Trim(String(site.Get("homeUrl", "")))
}

ScWebLlm_PickSiteFromEngines(engines) {
    ids := ScWebLlm_NormalizeBroadcastSiteIds(engines)
    return ids.Length ? ids[1] : ScWebLlm_DefaultSiteId()
}

ScWebLlm_ValidateSiteCatalog() {
    catalog := ScWebLlm_SiteCatalog()
    seen := Map()
    for site in catalog {
        id := site.Has("id") ? Trim(String(site["id"])) : ""
        if (id = "") {
            try OutputDebug("[SC_WEB_EMBED] catalog entry missing id")
            catch {
            }
            continue
        }
        if seen.Has(id) {
            try OutputDebug("[SC_WEB_EMBED] duplicated site id: " id)
            catch {
            }
        }
        seen[id] := true
        if !site.Has("homeUrl") || Trim(String(site["homeUrl"])) = "" {
            try OutputDebug("[SC_WEB_EMBED] missing homeUrl: " id)
            catch {
            }
        }
        if site.Get("defaultOpen", false) && !ScWebLlm_SiteEmbedEnabled(site) {
            try OutputDebug("[SC_WEB_EMBED] defaultOpen but not embedEnabled: " id)
            catch {
            }
        }
    }
}
