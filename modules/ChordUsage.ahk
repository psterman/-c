; ChordUsage.ahk — CapsLock 和弦命令使用频次（ChordPad 排序）

ChordUsage_Path(*) {
    if FuncExists("Nmer_DataStatePath")
        return Nmer_DataStatePath("chord_usage.json")
    return A_ScriptDir . "\Data\state\chord_usage.json"
}

ChordUsage_Load(*) {
    path := ChordUsage_Path()
    if !FileExist(path)
        return Map()
    try {
        raw := FileRead(path, "UTF-8")
        if (raw = "")
            return Map()
        doc := Jxon_Load(raw)
        return (doc is Map) ? doc : Map()
    } catch {
        return Map()
    }
}

ChordUsage_Save(doc) {
    if !(doc is Map)
        return false
    path := ChordUsage_Path()
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

ChordUsage_Record(cmdId) {
    cmdId := Trim(String(cmdId))
    if (cmdId = "")
        return
    doc := ChordUsage_Load()
    entry := doc.Has(cmdId) && doc[cmdId] is Map ? doc[cmdId] : Map("count", 0, "lastAt", "")
    entry["count"] := Number(entry.Get("count", 0)) + 1
    entry["lastAt"] := A_Now
    doc[cmdId] := entry
    ChordUsage_Save(doc)
}

ChordUsage_GetScore(cmdId) {
    cmdId := Trim(String(cmdId))
    doc := ChordUsage_Load()
    if !doc.Has(cmdId) || !(doc[cmdId] is Map)
        return 0.0
    ent := doc[cmdId]
    cnt := Number(ent.Get("count", 0))
    lastAt := Trim(String(ent.Get("lastAt", "")))
    recency := 0.0
    if (lastAt != "") {
        try {
            lastTick := DateDiff(lastAt, A_Now, "Hours")
            if (lastTick <= 24)
                recency := 1.0
            else if (lastTick <= 168)
                recency := 0.5
            else
                recency := 0.15
        } catch {
            recency := 0.0
        }
    }
    return cnt * 0.7 + recency * 30.0 * 0.3
}

ChordUsage_TierForScore(score, rank) {
    if (rank <= 3 && score > 0)
        return "hot"
    if (score > 5)
        return "warm"
    return "normal"
}

ChordUsage_SortSlots(slots) {
    if (!(slots is Array) || slots.Length = 0)
        return slots
    sorted := []
    for s in slots
        sorted.Push(s)
    ; 简单按 score 降序
    loop sorted.Length - 1 {
        swapped := false
        loop sorted.Length - A_Index {
            i := A_Index
            a := sorted[i]
            b := sorted[i + 1]
            sa := Number(a.Get("score", 0))
            sb := Number(b.Get("score", 0))
            if (sb > sa) {
                sorted[i] := b
                sorted[i + 1] := a
                swapped := true
            }
        }
        if !swapped
            break
    }
    out := []
    rank := 0
    for s in sorted {
        rank += 1
        sc := Number(s.Get("score", 0))
        s["tier"] := ChordUsage_TierForScore(sc, rank)
        s["rank"] := rank
        out.Push(s)
    }
    return out
}
