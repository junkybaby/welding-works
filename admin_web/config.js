function resolveApiBase() {
  const defaultApiBase = "";
  const params = new URLSearchParams(window.location.search);
  const queryOverride = (params.get("api_base") || "").trim();
  if (queryOverride) {
    return queryOverride.replace(/\/+$/, "");
  }

  const storedOverride = (localStorage.getItem("admin_api_base") || "").trim();
  if (storedOverride) {
    return storedOverride.replace(/\/+$/, "");
  }

  const runtimeOverride = typeof window.__ADMIN_API_BASE__ === "string"
    ? window.__ADMIN_API_BASE__.trim()
    : "";
  if (runtimeOverride) {
    return runtimeOverride.replace(/\/+$/, "");
  }

  const origin = window.location.origin && window.location.origin !== "null"
    ? window.location.origin
    : defaultApiBase;
  const currentPath = window.location.pathname || "/";
  const normalizedPath = currentPath.endsWith("/")
    ? currentPath.slice(0, -1)
    : currentPath.replace(/\/[^/]*$/, "");

  if (normalizedPath.endsWith("/admin_web")) {
    return `${origin}${normalizedPath.replace(/\/admin_web$/, "/welding_api")}`;
  }

  return defaultApiBase;
}

const API_BASE = resolveApiBase();
