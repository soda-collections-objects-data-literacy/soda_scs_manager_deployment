/**
 * Header auth status for hosted docs (oauth2-proxy on /oauth2/*).
 * Shows Login when anonymous; username + Logout when the session cookie is valid.
 */
(function () {
  const LABELS = {
    en: { login: "Log in", logout: "Log out", loading: "…" },
    de: { login: "Anmelden", logout: "Abmelden", loading: "…" },
  };

  function lang() {
    const htmlLang = (document.documentElement.lang || "").toLowerCase();
    if (htmlLang.startsWith("de")) return "de";
    if (location.pathname.startsWith("/de/")) return "de";
    return "en";
  }

  function labels() {
    return LABELS[lang()] || LABELS.en;
  }

  function ensureWidget() {
    let el = document.getElementById("scs-docs-auth");
    if (el) return el;

    const headerInner = document.querySelector(".md-header__inner");
    if (!headerInner) return null;

    el = document.createElement("div");
    el.id = "scs-docs-auth";
    el.className = "scs-docs-auth";
    el.setAttribute("hidden", "");
    el.setAttribute("aria-live", "polite");

    // Far right of the header (after language switcher / search).
    headerInner.appendChild(el);
    return el;
  }

  function currentReturnPath() {
    return location.pathname + location.search + location.hash;
  }

  function renderLoggedOut(el) {
    const t = labels();
    const start =
      "/oauth2/start?rd=" + encodeURIComponent(currentReturnPath());
    el.removeAttribute("hidden");
    el.innerHTML =
      '<a class="scs-docs-auth__login" href="' +
      start +
      '">' +
      t.login +
      "</a>";
  }

  function displayName(info) {
    return (
      info.preferredUsername ||
      info.user ||
      info.email ||
      info.preferred_username ||
      ""
    );
  }

  function renderLoggedIn(el, info) {
    const t = labels();
    const name = displayName(info) || "user";
    const signOut =
      "/oauth2/sign_out?rd=" + encodeURIComponent(currentReturnPath());
    el.removeAttribute("hidden");
    el.innerHTML =
      '<span class="scs-docs-auth__user" title="' +
      name.replace(/"/g, "&quot;") +
      '">' +
      name.replace(/</g, "&lt;") +
      '</span><a class="scs-docs-auth__logout" href="' +
      signOut +
      '">' +
      t.logout +
      "</a>";
  }

  function refreshAuthStatus() {
    const el = ensureWidget();
    if (!el) return;

    const t = labels();
    el.removeAttribute("hidden");
    el.textContent = t.loading;

    fetch("/oauth2/userinfo", {
      credentials: "same-origin",
      headers: { Accept: "application/json" },
    })
      .then(function (res) {
        if (res.status === 401 || res.status === 403) {
          renderLoggedOut(el);
          return null;
        }
        if (!res.ok) {
          renderLoggedOut(el);
          return null;
        }
        return res.json();
      })
      .then(function (info) {
        if (!info) return;
        renderLoggedIn(el, info);
      })
      .catch(function () {
        renderLoggedOut(el);
      });
  }

  function boot() {
    refreshAuthStatus();
  }

  if (typeof document$ !== "undefined" && document$.subscribe) {
    document$.subscribe(boot);
  } else if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot);
  } else {
    boot();
  }
})();
