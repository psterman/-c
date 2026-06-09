/**
 * PaletteA2UILegacyRenderer — non-Lit fallback for canonical A2UI blocks.
 */
(function (root) {
  function escapeHtml(value) {
    return String(value || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  function renderComparisonTable(element, props) {
    var columns = (props && props.columns) || [];
    var rows = (props && props.rows) || [];
    if (!columns.length) return false;
    var html = '<div class="a2ui-comparison"><table class="a2ui-table"><thead><tr>';
    for (var columnIndex = 0; columnIndex < columns.length; columnIndex++) {
      html += "<th>" + escapeHtml(columns[columnIndex]) + "</th>";
    }
    html += "</tr></thead><tbody>";
    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      html += "<tr>";
      for (var cellIndex = 0; cellIndex < columns.length; cellIndex++) {
        html +=
          "<td>" +
          escapeHtml(rows[rowIndex][cellIndex] != null ? rows[rowIndex][cellIndex] : "") +
          "</td>";
      }
      html += "</tr>";
    }
    element.innerHTML = html + "</tbody></table></div>";
    return true;
  }

  function renderSteps(element, props) {
    var items = (props && props.items) || [];
    if (!items.length) return false;
    element.innerHTML =
      '<div class="a2ui-steps"><ol class="a2ui-steps-list">' +
      items
        .map(function (item) {
          return "<li>" + escapeHtml(item) + "</li>";
        })
        .join("") +
      "</ol></div>";
    return true;
  }

  function renderAlert(element, props) {
    var text = String((props && props.text) || "").trim();
    if (!text) return false;
    var variant = String((props && props.variant) || "info");
    element.innerHTML =
      '<div class="a2ui-alert a2ui-alert-' +
      escapeHtml(variant) +
      '">' +
      escapeHtml(text) +
      "</div>";
    return true;
  }

  function render(container, block) {
    if (!container || !block) return false;
    container.hidden = false;
    container.setAttribute("data-component", block.component || "");
    container.setAttribute("data-block-id", block.id || "");
    var component = String(block.component || "");
    var props = block.props || {};
    if (component === "ComparisonTable") return renderComparisonTable(container, props);
    if (component === "Steps") return renderSteps(container, props);
    if (component === "Alert") return renderAlert(container, props);
    container.hidden = true;
    return false;
  }

  root.PaletteA2UILegacyRenderer = {
    render: render,
    renderComparisonTable: renderComparisonTable,
    renderSteps: renderSteps,
    renderAlert: renderAlert
  };
})(typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : this);
