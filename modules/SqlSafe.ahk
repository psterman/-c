#Requires AutoHotkey v2.0

; =============================================================================
; SqlSafe — parameterized SQL helpers for SQLiteDB
;
; SqlSafe_Exec(db, sql, params*)      — INSERT/UPDATE/DELETE via Prepare+Bind
; SqlSafe_GetTable(db, &table, sql, params*) — SELECT with safe param expansion
; SqlSafe_Fts5Escape(keyword)         — escape user input for FTS5 MATCH syntax
; =============================================================================

; ——— Internal: bind positional ? params to a prepared statement ———
_SqlSafe_BindParams(ST, params) {
    paramCount := ObjOwnProps(params)
    Loop paramCount {
        val := params[A_Index]
        if (val is Integer)
            ST.Bind(A_Index, "Int", val)
        else if (val is Float)
            ST.Bind(A_Index, "Double", val)
        else if (val is String)
            ST.Bind(A_Index, "Text", val)
        else
            ST.Bind(A_Index, "Text", String(val))
    }
}

; ——— Internal: expand ? placeholders into safely-escaped SQL literals ———
_SqlSafe_Expand(sql, params) {
    paramCount := ObjOwnProps(params)
    parts := StrSplit(sql, "?")
    ; Every ? consumes one param; there should be paramCount ? marks
    result := parts[1]
    Loop paramCount {
        val := params[A_Index]
        if (val is Integer)
            result .= val
        else if (val is Float)
            result .= val
        else if (val is String) {
            escaped := StrReplace(val, "'", "''")
            result .= "'" . escaped . "'"
        } else {
            escaped := StrReplace(String(val), "'", "''")
            result .= "'" . escaped . "'"
        }
        if (A_Index + 1 <= parts.Length)
            result .= parts[A_Index + 1]
    }
    ; Append any trailing SQL beyond the last placeholder
    if (paramCount + 1 < parts.Length) {
        Loop parts.Length - paramCount - 1 {
            result .= parts[paramCount + 1 + A_Index]
        }
    }
    return result
}

; ——— Execute non-query SQL (INSERT/UPDATE/DELETE/ALTER/PRAGMA) ———
; Returns: true on success, false on failure (error logged via NMER_Log)
SqlSafe_Exec(db, sql, params*) {
    try {
        if (params.Length = 0)
            return db.Exec(sql)

        ST := 0
        if (!db.Prepare(sql, &ST)) {
            try NmerCatch("SqlSafe", Error("prepare_failed"), sql)
            return false
        }
        _SqlSafe_BindParams(ST, params)
        ST.Step()
        ST.Finalize()
        return true
    } catch as _e {
        try NmerCatch("SqlSafe", _e, sql)
        return false
    }
}

; ——— Execute SELECT and return results via output table reference ———
; table.HasRows / table.Rows[n][col] compatible with SQLiteDB.GetTable
SqlSafe_GetTable(db, &table, sql, params*) {
    try {
        safeSql := (params.Length > 0) ? _SqlSafe_Expand(sql, params) : sql
        return db.GetTable(safeSql, &table)
    } catch as _e {
        try NmerCatch("SqlSafe", _e, sql)
        table := {HasRows: false, Rows: []}
        return false
    }
}

; ——— Escape user keyword for FTS5 MATCH syntax ———
; FTS5 cannot use parameterised queries for MATCH. This function applies
; proper escaping: wraps in double-quotes to treat the input as a phrase,
; and escapes any embedded double-quote by doubling it.
;
; Returns an FTS5-safe string suitable for:  ... WHERE fts MATCH '" . SqlSafe_Fts5Escape(kw) . "'
SqlSafe_Fts5Escape(keyword) {
    kw := Trim(String(keyword))
    if (kw = "")
        return ""
    ; Double any embedded double-quotes (FTS5 escape)
    kw := StrReplace(kw, '"', '""')
    ; Wrap in double-quotes so FTS5 treats it as a phrase
    return '"' . kw . '"'
}
