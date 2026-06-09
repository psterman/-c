/**
 * PaletteComparisonTableMarkdown — Markdown table parsing and legacy HTML fallback.
 */
(function (root) {
  function escapeHtml(value) {
    return String(value || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  function splitRow(line) {
    var text = String(line || "").trim();
    if (text.indexOf("|") < 0) return [];
    if (text.charAt(0) === "|") text = text.slice(1);
    if (text.charAt(text.length - 1) === "|") text = text.slice(0, -1);
    return text.split("|").map(function (cell) {
      return cell.trim();
    });
  }

  function isSeparatorRow(cells) {
    if (!cells || !cells.length) return false;
    return cells.every(function (cell) {
      return /^:?-{2,}:?$/.test(String(cell || "").trim());
    });
  }

  function extract(markdown) {
    var lines = String(markdown || "").split(/\r?\n/);
    var tables = [];
    var index = 0;
    while (index < lines.length - 1) {
      var columns = splitRow(lines[index]);
      var separator = splitRow(lines[index + 1]);
      if (columns.length >= 2 && isSeparatorRow(separator)) {
        var rows = [];
        index += 2;
        while (index < lines.length) {
          var row = splitRow(lines[index]);
          if (row.length < 2) break;
          rows.push(row);
          index++;
        }
        tables.push({ columns: columns, rows: rows });
        continue;
      }
      index++;
    }
    return tables;
  }

  function strip(markdown) {
    var lines = String(markdown || "").split(/\r?\n/);
    var output = [];
    var index = 0;
    while (index < lines.length) {
      var columns = splitRow(lines[index]);
      var separator = index + 1 < lines.length ? splitRow(lines[index + 1]) : [];
      if (columns.length >= 2 && isSeparatorRow(separator)) {
        index += 2;
        while (index < lines.length) {
          var row = splitRow(lines[index]);
          if (row.length < 2) break;
          index++;
        }
        if (output.length && String(output[output.length - 1]).trim() !== "") output.push("");
        continue;
      }
      output.push(lines[index]);
      index++;
    }
    return output
      .join("\n")
      .replace(/\n{3,}/g, "\n\n")
      .trim();
  }

  function parseSegments(markdown) {
    var lines = String(markdown || "").split(/\r?\n/);
    var segments = [];
    var textLines = [];

    function flushText() {
      if (textLines.length) segments.push({ type: "text", lines: textLines.slice() });
      textLines = [];
    }

    var index = 0;
    while (index < lines.length) {
      var columns = splitRow(lines[index]);
      var separator = index + 1 < lines.length ? splitRow(lines[index + 1]) : [];
      if (columns.length >= 2 && isSeparatorRow(separator)) {
        flushText();
        var rows = [];
        index += 2;
        while (index < lines.length) {
          var row = splitRow(lines[index]);
          if (row.length < 2) break;
          rows.push(row);
          index++;
        }
        segments.push({ type: "table", columns: columns, rows: rows });
        continue;
      }
      textLines.push(lines[index]);
      index++;
    }
    flushText();
    return segments;
  }

  function stripInlineCell(text) {
    return String(text || "")
      .replace(/\*\*/g, "")
      .replace(/^✅\s*|^❌\s*|^⚠️?\s*/g, "")
      .trim();
  }

  function renderHtml(columns, rows, escape) {
    var esc = typeof escape === "function" ? escape : escapeHtml;
    var html = '<div class="a2ui-comparison"><table class="a2ui-table md-table"><thead><tr>';
    for (var columnIndex = 0; columnIndex < columns.length; columnIndex++) {
      html += "<th>" + esc(stripInlineCell(columns[columnIndex])) + "</th>";
    }
    html += "</tr></thead><tbody>";
    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      html += "<tr>";
      for (var cellIndex = 0; cellIndex < columns.length; cellIndex++) {
        html +=
          "<td>" +
          esc(stripInlineCell(rows[rowIndex][cellIndex] != null ? rows[rowIndex][cellIndex] : "")) +
          "</td>";
      }
      html += "</tr>";
    }
    return html + "</tbody></table></div>";
  }

  root.PaletteComparisonTableMarkdown = {
    splitRow: splitRow,
    isSeparatorRow: isSeparatorRow,
    extract: extract,
    strip: strip,
    parseSegments: parseSegments,
    stripInlineCell: stripInlineCell,
    renderHtml: renderHtml
  };
})(typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : this);
