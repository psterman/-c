; SearchCenterWebLlmSites.ahk — 联网搜索内嵌 AI 站点 catalog（白名单）
#Requires AutoHotkey v2.0

ScWebLlm_SiteCatalog() {
    return [
        Map("id", "deepseek", "label", "DeepSeek", "homeUrl", "https://chat.deepseek.com/", "enabled", true),
        Map("id", "doubao", "label", "豆包", "homeUrl", "https://www.doubao.com/chat/", "enabled", true),
        Map("id", "gemini", "label", "Gemini", "homeUrl", "https://gemini.google.com/app", "enabled", true),
        Map("id", "grok", "label", "Grok", "homeUrl", "https://grok.com/", "enabled", true),
        Map("id", "perplexity", "label", "Perplexity", "homeUrl", "https://www.perplexity.ai/", "enabled", true),
    ]
}

ScWebLlm_NormalizeSiteId(siteId) {
    id := StrLower(Trim(String(siteId)))
    if (id = "")
        return ""
    for site in ScWebLlm_SiteCatalog() {
        if (site["id"] = id)
            return id
    }
    return ""
}

ScWebLlm_FindSite(siteId) {
    id := ScWebLlm_NormalizeSiteId(siteId)
    if (id = "")
        return 0
    for site in ScWebLlm_SiteCatalog() {
        if (site["id"] = id)
            return site
    }
    return 0
}

ScWebLlm_IsSiteEnabled(siteId) {
    site := ScWebLlm_FindSite(siteId)
    if !(site is Map)
        return false
    return !!site.Get("enabled", false)
}

ScWebLlm_EngineToSiteId(engine) {
    eng := StrLower(Trim(String(engine)))
    if (eng = "")
        return ""
    site := ScWebLlm_FindSite(eng)
    if !(site is Map) || !site.Get("enabled", false)
        return ""
    return site["id"]
}

ScWebLlm_IsEmbedEngine(engine) {
    return (ScWebLlm_EngineToSiteId(engine) != "")
}

ScWebLlm_DefaultSiteId() {
    for site in ScWebLlm_SiteCatalog() {
        if site.Get("enabled", false)
            return site["id"]
    }
    return "deepseek"
}

ScWebLlm_EnabledSites() {
    out := []
    for site in ScWebLlm_SiteCatalog() {
        if site.Get("enabled", false)
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
    if IsObject(engines) {
        for eng in engines {
            sid := ScWebLlm_EngineToSiteId(eng)
            if (sid != "")
                return sid
        }
    }
    return ScWebLlm_DefaultSiteId()
}
