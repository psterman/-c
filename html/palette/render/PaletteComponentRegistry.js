/**
 * PaletteComponentRegistry — lightweight component definition registry.
 *
 * Definitions describe tag/mount/props wiring only. Component templates stay in
 * their own modules; optional load() supports future lazy registration.
 */
(function (root) {
  var definitions = {};
  var componentIds = {};

  function normalizeName(name) {
    return String(name || "").trim();
  }

  function register(name, definition) {
    var key = normalizeName(name);
    if (!key || !definition || typeof definition !== "object") return false;
    definitions[key] = definition;
    if (definition.componentId) componentIds[String(definition.componentId)] = key;
    return true;
  }

  function unregister(name) {
    var key = normalizeName(name);
    var def = definitions[key];
    if (!def) return false;
    if (def.componentId && componentIds[String(def.componentId)] === key) {
      delete componentIds[String(def.componentId)];
    }
    delete definitions[key];
    return true;
  }

  function get(name) {
    return definitions[normalizeName(name)] || null;
  }

  function getById(componentId) {
    var id = String(componentId || "");
    var key = componentIds[id];
    return key ? definitions[key] || null : null;
  }

  function resolve(descriptor) {
    descriptor = descriptor || {};
    return getById(descriptor.component) || get(descriptor.component) || null;
  }

  function ensureLoaded(name) {
    var def = get(name);
    if (!def || typeof def.load !== "function") return Promise.resolve(def);
    if (def._loadPromise) return def._loadPromise;
    def._loadPromise = Promise.resolve()
      .then(function () {
        return def.load();
      })
      .then(function () {
        return get(name) || def;
      });
    return def._loadPromise;
  }

  function list() {
    return Object.keys(definitions);
  }

  function resetForTest() {
    definitions = {};
    componentIds = {};
  }

  root.PaletteComponentRegistry = {
    register: register,
    unregister: unregister,
    get: get,
    getById: getById,
    resolve: resolve,
    ensureLoaded: ensureLoaded,
    list: list,
    _resetForTest: resetForTest
  };
})(typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : this);
