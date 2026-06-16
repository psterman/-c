; OnboardingHotkeys.ahk — ChordPad 渐进式快捷键解锁

OnboardingHotkeys_Path(*) {
    if FuncExists("Nmer_DataStatePath")
        return Nmer_DataStatePath("onboarding_hotkeys.json")
    return A_ScriptDir . "\Data\state\onboarding_hotkeys.json"
}

OnboardingHotkeys_DefaultDoc() {
    return Map(
        "version", 1,
        "tier", 1,
        "launchCount", 0,
        "revealedSlots", ["C", "V", "S"],
        "dismissedTips", [],
        "forceRevealAll", false
    )
}

OnboardingHotkeys_NormalizeDoc(doc) {
    def := OnboardingHotkeys_DefaultDoc()
    if !(doc is Map)
        doc := Map()
    out := Map()
    out["version"] := 1
    tier := Integer(doc.Get("tier", def["tier"]))
    if (tier < 1)
        tier := 1
    else if (tier > 3)
        tier := 3
    out["tier"] := tier
    lc := Integer(doc.Get("launchCount", 0))
    if (lc < 0)
        lc := 0
    out["launchCount"] := lc
    out["forceRevealAll"] := doc.Get("forceRevealAll", false) ? true : false
    rev := []
    rawRev := doc.Get("revealedSlots", def["revealedSlots"])
    if rawRev is Array {
        for a in rawRev {
            s := StrUpper(Trim(String(a)))
            if (s != "")
                rev.Push(s)
        }
    }
    if (rev.Length = 0)
        rev := ["C", "V", "S"]
    out["revealedSlots"] := rev
    dismissed := []
    rawDismiss := doc.Get("dismissedTips", [])
    if rawDismiss is Array {
        for t in rawDismiss {
            s := Trim(String(t))
            if (s != "")
                dismissed.Push(s)
        }
    }
    out["dismissedTips"] := dismissed
    return out
}

OnboardingHotkeys_Load(*) {
    path := OnboardingHotkeys_Path()
    if !FileExist(path)
        return OnboardingHotkeys_DefaultDoc()
    try {
        raw := FileRead(path, "UTF-8")
        if (raw = "")
            return OnboardingHotkeys_DefaultDoc()
        doc := Jxon_Load(raw)
        return OnboardingHotkeys_NormalizeDoc(doc)
    } catch {
        return OnboardingHotkeys_DefaultDoc()
    }
}

OnboardingHotkeys_Save(doc) {
    doc := OnboardingHotkeys_NormalizeDoc(doc)
    path := OnboardingHotkeys_Path()
    try {
        parent := ""
        SplitPath(path, , &parent)
        if (parent != "" && !DirExist(parent))
            DirCreate(parent)
        FileDelete(path)
        f := FileOpen(path, "w", "UTF-8")
        if !IsObject(f)
            return false
        f.Write(Jxon_Dump(doc))
        f.Close()
        return true
    } catch as e {
        if FuncExists("NmerCatch")
            NmerCatch(A_ThisFunc, e)
        return false
    }
}

OnboardingHotkeys_TierRevealedActions(tier) {
    tier := Integer(tier)
    if (tier <= 1)
        return ["C", "V", "S"]
    if (tier = 2)
        return ["C", "V", "S", "X", "E"]
    return [] ; tier 3 = all
}

OnboardingHotkeys_RecomputeTier(doc) {
    doc := OnboardingHotkeys_NormalizeDoc(doc)
    if doc["forceRevealAll"]
        return 3
    lc := Integer(doc["launchCount"])
    if (lc >= 10)
        return 3
    if (lc >= 3)
        return 2
    return 1
}

OnboardingHotkeys_GetTier(*) {
    doc := OnboardingHotkeys_Load()
    return OnboardingHotkeys_RecomputeTier(doc)
}

OnboardingHotkeys_GetRevealedActions(scenarioId := "") {
    doc := OnboardingHotkeys_Load()
    tier := OnboardingHotkeys_RecomputeTier(doc)
    if (tier >= 3)
        return [] ; empty = all revealed
    return OnboardingHotkeys_TierRevealedActions(tier)
}

OnboardingHotkeys_IsActionRevealed(action, scenarioId := "") {
    action := StrUpper(Trim(String(action)))
    if (action = "")
        return true
    doc := OnboardingHotkeys_Load()
    tier := OnboardingHotkeys_RecomputeTier(doc)
    if (tier >= 3)
        return true
    for a in OnboardingHotkeys_TierRevealedActions(tier) {
        if (a = action)
            return true
    }
    return false
}

OnboardingHotkeys_UnlockHintText(*) {
    tier := OnboardingHotkeys_GetTier()
    if (tier <= 1)
        return "使用 3 次后解锁"
    if (tier = 2)
        return "累计 10 次后解锁"
    return ""
}

OnboardingHotkeys_SetForceRevealAll(enable) {
    doc := OnboardingHotkeys_Load()
    doc["forceRevealAll"] := enable ? true : false
    if enable {
        doc["tier"] := 3
        doc["revealedSlots"] := ["C", "V", "S", "X", "E", "Q", "F", "R", "O"]
    }
    OnboardingHotkeys_Save(doc)
}

OnboardingHotkeys_GetForceRevealAll(*) {
    doc := OnboardingHotkeys_Load()
    return !!doc.Get("forceRevealAll", false)
}

OnboardingHotkeys_RecordSummon() {
    doc := OnboardingHotkeys_Load()
    prevTier := OnboardingHotkeys_RecomputeTier(doc)
    doc["launchCount"] := Integer(doc.Get("launchCount", 0)) + 1
    newTier := OnboardingHotkeys_RecomputeTier(doc)
    doc["tier"] := newTier
    if (newTier >= 2)
        doc["revealedSlots"] := OnboardingHotkeys_TierRevealedActions(newTier)
    if (newTier >= 3)
        doc["revealedSlots"] := ["C", "V", "S", "X", "E", "Q", "F", "R", "O"]
    OnboardingHotkeys_Save(doc)
    upgraded := (prevTier < newTier)
    return Map("prevTier", prevTier, "newTier", newTier, "launchCount", doc["launchCount"], "upgraded", upgraded)
}

OnboardingHotkeys_PayloadForWeb(*) {
    doc := OnboardingHotkeys_Load()
    tier := OnboardingHotkeys_RecomputeTier(doc)
    rev := OnboardingHotkeys_GetRevealedActions()
    if (tier >= 3)
        rev := ["C", "V", "S", "X", "E", "Q", "F", "R", "O"]
    return Map(
        "onboardingTier", tier,
        "launchCount", Integer(doc.Get("launchCount", 0)),
        "revealedSlots", rev,
        "forceRevealAll", !!doc.Get("forceRevealAll", false),
        "unlockHint", OnboardingHotkeys_UnlockHintText()
    )
}
