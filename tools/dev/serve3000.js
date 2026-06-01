const http = require("http");
const fs = require("fs");
const path = require("path");

const root = process.cwd();
const port = 3000;
const niumaHistoryDir = path.join(root, "Data", "niuma-chat");
const niumaHistoryFile = path.join(niumaHistoryDir, "history.json");
const niumaAuditFile = path.join(niumaHistoryDir, "niuma_audit.json");
const niumaUploadDir = path.join(niumaHistoryDir, "uploads");
const niumaAttachMetaFile = path.join(niumaHistoryDir, "attachments.json");

const mime = {
  ".html": "text/html; charset=utf-8",
  ".js": "application/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".svg": "image/svg+xml",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".gif": "image/gif",
  ".ico": "image/x-icon",
  ".txt": "text/plain; charset=utf-8"
};

function safePath(urlPath) {
  const raw = decodeURIComponent((urlPath || "/").split("?")[0].split("#")[0]);
  const normalized = raw === "/" ? "/openclaw2.html" : raw;
  const abs = path.resolve(root, "." + normalized);
  if (!abs.startsWith(root)) return null;
  return abs;
}

function sendJson(res, status, body) {
  res.writeHead(status, { "Content-Type": "application/json; charset=utf-8" });
  res.end(JSON.stringify(body));
}

function readNiumaHistory(cb) {
  fs.readFile(niumaHistoryFile, "utf8", (err, text) => {
    if (err) {
      if (err.code === "ENOENT") {
        cb(null, { version: 1, sessions: {}, updatedAt: null });
        return;
      }
      cb(err);
      return;
    }
    try {
      const parsed = JSON.parse(text);
      if (!parsed || typeof parsed !== "object") throw new Error("Invalid history payload");
      cb(null, parsed);
    } catch (parseErr) {
      cb(parseErr);
    }
  });
}

function writeNiumaHistory(payload, cb) {
  const normalized = payload && typeof payload === "object" ? payload : {};
  const doc = {
    version: 1,
    sessions: normalized.sessions && typeof normalized.sessions === "object" ? normalized.sessions : {},
    updatedAt: new Date().toISOString()
  };
  fs.mkdir(niumaHistoryDir, { recursive: true }, (mkErr) => {
    if (mkErr) {
      cb(mkErr);
      return;
    }
    fs.writeFile(niumaHistoryFile, JSON.stringify(doc, null, 2), "utf8", cb);
  });
}

function readNiumaAudit(cb) {
  fs.readFile(niumaAuditFile, "utf8", (err, text) => {
    if (err) {
      if (err.code === "ENOENT") {
        cb(null, { version: 1, entries: [], updatedAt: null });
        return;
      }
      cb(err);
      return;
    }
    try {
      const parsed = JSON.parse(text);
      if (!parsed || typeof parsed !== "object") throw new Error("Invalid audit payload");
      cb(null, parsed);
    } catch (parseErr) {
      cb(parseErr);
    }
  });
}

function writeNiumaAudit(payload, cb) {
  const normalized = payload && typeof payload === "object" ? payload : {};
  const doc = {
    version: 1,
    entries: Array.isArray(normalized.entries) ? normalized.entries.slice(-200) : [],
    updatedAt: new Date().toISOString()
  };
  fs.mkdir(niumaHistoryDir, { recursive: true }, (mkErr) => {
    if (mkErr) {
      cb(mkErr);
      return;
    }
    fs.writeFile(niumaAuditFile, JSON.stringify(doc, null, 2), "utf8", cb);
  });
}

function parseJsonBody(req, cb) {
  let raw = "";
  req.on("data", (chunk) => {
    raw += String(chunk);
    if (raw.length > 2 * 1024 * 1024) {
      cb(new Error("Body too large"));
      req.destroy();
    }
  });
  req.on("end", () => {
    if (!raw.trim()) {
      cb(null, {});
      return;
    }
    try {
      cb(null, JSON.parse(raw));
    } catch (err) {
      cb(err);
    }
  });
  req.on("error", cb);
}

function parseRawBody(req, maxBytes, cb) {
  const chunks = [];
  let total = 0;
  req.on("data", (chunk) => {
    total += chunk.length;
    if (total > maxBytes) {
      cb(new Error("Body too large"));
      req.destroy();
      return;
    }
    chunks.push(chunk);
  });
  req.on("end", () => cb(null, Buffer.concat(chunks)));
  req.on("error", cb);
}

function parseMultipartFormData(bodyBuf, contentType) {
  const ct = String(contentType || "");
  const m = ct.match(/boundary=(?:"([^"]+)"|([^;]+))/i);
  if (!m) throw new Error("Missing multipart boundary");
  const boundary = "--" + (m[1] || m[2]);
  const body = bodyBuf.toString("binary");
  const parts = body.split(boundary).slice(1, -1);
  const fields = {};
  let file = null;
  for (const rawPart of parts) {
    let p = rawPart;
    if (p.startsWith("\r\n")) p = p.slice(2);
    if (p.endsWith("\r\n")) p = p.slice(0, -2);
    const headerEnd = p.indexOf("\r\n\r\n");
    if (headerEnd < 0) continue;
    const headerText = p.slice(0, headerEnd);
    const contentBin = p.slice(headerEnd + 4);
    const headers = {};
    headerText.split("\r\n").forEach((line) => {
      const idx = line.indexOf(":");
      if (idx > 0) headers[line.slice(0, idx).trim().toLowerCase()] = line.slice(idx + 1).trim();
    });
    const cd = headers["content-disposition"] || "";
    const nameMatch = cd.match(/name="([^"]+)"/i);
    if (!nameMatch) continue;
    const fieldName = nameMatch[1];
    const fileNameMatch = cd.match(/filename="([^"]*)"/i);
    if (fileNameMatch) {
      const contentTypePart = headers["content-type"] || "application/octet-stream";
      const fileBuf = Buffer.from(contentBin, "binary");
      file = {
        fieldName,
        filename: fileNameMatch[1] || "file",
        mimeType: contentTypePart,
        buffer: fileBuf
      };
    } else {
      fields[fieldName] = Buffer.from(contentBin, "binary").toString("utf8");
    }
  }
  return { fields, file };
}

function readAttachmentMeta(cb) {
  fs.readFile(niumaAttachMetaFile, "utf8", (err, text) => {
    if (err) {
      if (err.code === "ENOENT") {
        cb(null, { version: 1, files: {}, updatedAt: null });
        return;
      }
      cb(err);
      return;
    }
    try {
      const cleaned = String(text || "").replace(/^\uFEFF/, "").trim();
      if (!cleaned) {
        cb(null, { version: 1, files: {}, updatedAt: null });
        return;
      }
      const parsed = JSON.parse(cleaned);
      if (!parsed || typeof parsed !== "object") throw new Error("Invalid attachment metadata");
      cb(null, parsed);
    } catch (parseErr) {
      cb(null, { version: 1, files: {}, updatedAt: null });
    }
  });
}

function writeAttachmentMeta(payload, cb) {
  const normalized = payload && typeof payload === "object" ? payload : {};
  const doc = {
    version: 1,
    files: normalized.files && typeof normalized.files === "object" ? normalized.files : {},
    updatedAt: new Date().toISOString()
  };
  fs.mkdir(niumaHistoryDir, { recursive: true }, (mkErr) => {
    if (mkErr) return cb(mkErr);
    fs.writeFile(niumaAttachMetaFile, JSON.stringify(doc, null, 2), "utf8", cb);
  });
}

function safeBaseName(name) {
  return String(name || "file").replace(/[^\w.\-()/\\\s]/g, "_").slice(0, 180) || "file";
}

function createFileId() {
  return "att_" + Date.now().toString(36) + "_" + Math.random().toString(36).slice(2, 10);
}

function extOf(name) {
  const s = String(name || "");
  const idx = s.lastIndexOf(".");
  return idx >= 0 ? s.slice(idx + 1).toLowerCase() : "";
}

function shouldExtractText(name, mimeType) {
  const mt = String(mimeType || "").toLowerCase();
  if (mt.startsWith("text/")) return true;
  return /^(md|txt|json|csv|log|xml|yml|yaml|ini|cfg|js|ts|py|java|go|rs|html|css|sql|bat|cmd|ps1|psm1|sh|toml|env)$/i.test(extOf(name));
}

function persistUploadAndMeta(name, relativePath, mimeType, buf, cb) {
  const fileId = createFileId();
  const storedName = fileId + "_" + safeBaseName(name);
  const absPath = path.join(niumaUploadDir, storedName);
  fs.mkdir(niumaUploadDir, { recursive: true }, (mkErr) => {
    if (mkErr) return cb(mkErr);
    fs.writeFile(absPath, buf, (writeErr) => {
      if (writeErr) return cb(writeErr);
      readAttachmentMeta((metaErr, metaDoc) => {
        if (metaErr) return cb(metaErr);
        const doc = metaDoc && typeof metaDoc === "object" ? metaDoc : { version: 1, files: {} };
        if (!doc.files || typeof doc.files !== "object") doc.files = {};
        let textExcerpt = "";
        if (shouldExtractText(name, mimeType)) textExcerpt = buf.toString("utf8").slice(0, 12000).trim();
        doc.files[fileId] = {
          id: fileId,
          name,
          relativePath,
          type: mimeType,
          size: buf.length,
          storedName,
          storedPath: absPath,
          uploadedAt: new Date().toISOString(),
          textExcerpt
        };
        writeAttachmentMeta(doc, (saveErr) => {
          if (saveErr) return cb(saveErr);
          cb(null, {
            id: fileId,
            name,
            relativePath,
            type: mimeType,
            size: buf.length,
            hasTextExcerpt: !!textExcerpt
          });
        });
      });
    });
  });
}

const server = http.createServer((req, res) => {
  const reqPath = decodeURIComponent((req.url || "/").split("?")[0].split("#")[0]);
  if (reqPath === "/api/niuma/upload") {
    if (req.method !== "POST") {
      sendJson(res, 405, { ok: false, error: "Method not allowed" });
      return;
    }
    const contentType = String(req.headers["content-type"] || "");
    if (/multipart\/form-data/i.test(contentType)) {
      parseRawBody(req, 40 * 1024 * 1024, (rawErr, rawBuf) => {
        if (rawErr) {
          sendJson(res, 413, { ok: false, error: rawErr.message || String(rawErr) });
          return;
        }
        let parsed;
        try {
          parsed = parseMultipartFormData(rawBuf, contentType);
        } catch (e) {
          sendJson(res, 400, { ok: false, error: e.message || String(e) });
          return;
        }
        const f = parsed.file;
        if (!f || !f.buffer || !f.buffer.length) {
          sendJson(res, 400, { ok: false, error: "Missing file" });
          return;
        }
        if (f.buffer.length > 20 * 1024 * 1024) {
          sendJson(res, 413, { ok: false, error: "File too large (>20MB)" });
          return;
        }
        const name = String(f.filename || "file");
        const relativePath = String((parsed.fields && parsed.fields.relativePath) || name);
        const mimeType = String(f.mimeType || "application/octet-stream");
        persistUploadAndMeta(name, relativePath, mimeType, f.buffer, (saveErr, fileInfo) => {
          if (saveErr) {
            sendJson(res, 500, { ok: false, error: saveErr.message || String(saveErr) });
            return;
          }
          sendJson(res, 200, { ok: true, file: fileInfo });
        });
      });
      return;
    }
    parseJsonBody(req, (bodyErr, body) => {
      if (bodyErr) {
        sendJson(res, 400, { ok: false, error: "Invalid JSON body" });
        return;
      }
      const name = String((body && body.name) || "file");
      const relativePath = String((body && body.relativePath) || name);
      const mimeType = String((body && body.type) || "");
      const contentBase64 = body && typeof body.contentBase64 === "string" ? body.contentBase64 : "";
      if (!contentBase64) {
        sendJson(res, 400, { ok: false, error: "Missing contentBase64" });
        return;
      }
      let buf;
      try {
        buf = Buffer.from(contentBase64, "base64");
      } catch (err) {
        sendJson(res, 400, { ok: false, error: "Invalid base64 content" });
        return;
      }
      if (!buf.length) {
        sendJson(res, 400, { ok: false, error: "Empty file" });
        return;
      }
      if (buf.length > 20 * 1024 * 1024) {
        sendJson(res, 413, { ok: false, error: "File too large (>20MB)" });
        return;
      }
      persistUploadAndMeta(name, relativePath, mimeType, buf, (saveErr, fileInfo) => {
        if (saveErr) {
          sendJson(res, 500, { ok: false, error: saveErr.message || String(saveErr) });
          return;
        }
        sendJson(res, 200, { ok: true, file: fileInfo });
      });
    });
    return;
  }
  if (reqPath === "/api/niuma/attachments/context") {
    if (req.method !== "POST") {
      sendJson(res, 405, { ok: false, error: "Method not allowed" });
      return;
    }
    parseJsonBody(req, (bodyErr, body) => {
      if (bodyErr) {
        sendJson(res, 400, { ok: false, error: "Invalid JSON body" });
        return;
      }
      const ids = Array.isArray(body && body.fileIds) ? body.fileIds : [];
      readAttachmentMeta((metaErr, metaDoc) => {
        if (metaErr) {
          sendJson(res, 500, { ok: false, error: metaErr.message || String(metaErr) });
          return;
        }
        const filesMap = (metaDoc && metaDoc.files) || {};
        const files = ids
          .map((id) => filesMap[String(id)])
          .filter(Boolean)
          .map((x) => ({
            id: x.id,
            name: x.name,
            relativePath: x.relativePath || x.name,
            type: x.type || "",
            size: Number(x.size || 0),
            uploadedAt: x.uploadedAt || null,
            textExcerpt: String(x.textExcerpt || "").slice(0, 6000)
          }));
        sendJson(res, 200, { ok: true, files });
      });
    });
    return;
  }
  if (reqPath === "/api/niuma/history") {
    if (req.method === "GET") {
      readNiumaHistory((err, data) => {
        if (err) {
          sendJson(res, 500, { ok: false, error: err.message || String(err) });
          return;
        }
        sendJson(res, 200, { ok: true, data });
      });
      return;
    }
    if (req.method === "POST") {
      parseJsonBody(req, (bodyErr, body) => {
        if (bodyErr) {
          sendJson(res, 400, { ok: false, error: "Invalid JSON body" });
          return;
        }
        const payload = body && typeof body === "object" && body.data && typeof body.data === "object"
          ? body.data
          : body;
        writeNiumaHistory(payload, (writeErr) => {
          if (writeErr) {
            sendJson(res, 500, { ok: false, error: writeErr.message || String(writeErr) });
            return;
          }
          sendJson(res, 200, { ok: true, path: niumaHistoryFile });
        });
      });
      return;
    }
    sendJson(res, 405, { ok: false, error: "Method not allowed" });
    return;
  }
  if (reqPath === "/api/niuma/audit") {
    if (req.method === "GET") {
      readNiumaAudit((err, data) => {
        if (err) {
          sendJson(res, 500, { ok: false, error: err.message || String(err) });
          return;
        }
        sendJson(res, 200, { ok: true, data });
      });
      return;
    }
    if (req.method === "POST") {
      parseJsonBody(req, (bodyErr, body) => {
        if (bodyErr) {
          sendJson(res, 400, { ok: false, error: "Invalid JSON body" });
          return;
        }
        const payload = body && typeof body === "object" && body.data && typeof body.data === "object"
          ? body.data
          : body;
        writeNiumaAudit(payload, (writeErr) => {
          if (writeErr) {
            sendJson(res, 500, { ok: false, error: writeErr.message || String(writeErr) });
            return;
          }
          sendJson(res, 200, { ok: true, path: niumaAuditFile });
        });
      });
      return;
    }
    sendJson(res, 405, { ok: false, error: "Method not allowed" });
    return;
  }

  const abs = safePath(req.url);
  if (!abs) {
    res.writeHead(400, { "Content-Type": "text/plain; charset=utf-8" });
    res.end("Bad request");
    return;
  }
  fs.stat(abs, (err, stat) => {
    if (err || !stat.isFile()) {
      res.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" });
      res.end("Not found");
      return;
    }
    const ext = path.extname(abs).toLowerCase();
    res.writeHead(200, { "Content-Type": mime[ext] || "application/octet-stream" });
    fs.createReadStream(abs).pipe(res);
  });
});

server.listen(port, () => {
  console.log(`Static server running: http://localhost:${port}/openclaw2.html`);
});
