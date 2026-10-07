/**
 * Mermaid fullscreen + render recovery for Zensical/Material.
 * If Material leaves empty .mermaid nodes, re-render from page HTML.
 */
(function () {
  const LABELS = {
    en: { enter: "Fullscreen", exit: "Exit fullscreen" },
    de: { enter: "Vollbild", exit: "Vollbild beenden" },
  };

  let pageSources = null;
  let renderInFlight = false;

  function lang() {
    const htmlLang = (document.documentElement.lang || "").toLowerCase();
    if (htmlLang.startsWith("de")) return "de";
    if (location.pathname.startsWith("/de/")) return "de";
    return "en";
  }

  function labels() {
    return LABELS[lang()] || LABELS.en;
  }

  function setButtonState(btn, isFullscreen) {
    const t = labels();
    btn.textContent = isFullscreen ? t.exit : t.enter;
    btn.setAttribute("aria-pressed", isFullscreen ? "true" : "false");
    btn.title = btn.textContent;
  }

  function exitFullscreen(shell) {
    if (!shell || !shell.classList.contains("is-fullscreen")) return;
    shell.classList.remove("is-fullscreen");
    document.documentElement.classList.remove("scs-mermaid-fullscreen-open");
    const btn = shell.querySelector(".scs-mermaid__btn");
    if (btn) setButtonState(btn, false);
  }

  function enterFullscreen(shell) {
    document
      .querySelectorAll(".scs-mermaid.is-fullscreen")
      .forEach((other) => exitFullscreen(other));
    shell.classList.add("is-fullscreen");
    document.documentElement.classList.add("scs-mermaid-fullscreen-open");
    const btn = shell.querySelector(".scs-mermaid__btn");
    if (btn) {
      setButtonState(btn, true);
      btn.focus();
    }
  }

  function enhanceDiagram(el) {
    if (!(el instanceof Element)) return;
    if (!el.classList.contains("mermaid")) return;
    if (el.closest(".scs-mermaid")) return;
    if (!el.querySelector("svg")) return;

    const shell = document.createElement("div");
    shell.className = "scs-mermaid";

    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "scs-mermaid__btn";
    setButtonState(btn, false);
    btn.addEventListener("click", function () {
      if (shell.classList.contains("is-fullscreen")) exitFullscreen(shell);
      else enterFullscreen(shell);
    });

    el.parentNode.insertBefore(shell, el);
    shell.appendChild(btn);
    shell.appendChild(el);
  }

  function enhanceAll(root) {
    (root || document).querySelectorAll(".mermaid").forEach(enhanceDiagram);
  }

  function decodeHtml(encoded) {
    const ta = document.createElement("textarea");
    ta.innerHTML = encoded;
    return ta.value;
  }

  function extractMermaidSources(html) {
    const sources = [];
    const needle = '<pre class="mermaid"><code>';
    let from = 0;
    while (true) {
      const start = html.indexOf(needle, from);
      if (start < 0) break;
      const contentStart = start + needle.length;
      const end = html.indexOf("</code></pre>", contentStart);
      if (end < 0) break;
      sources.push(decodeHtml(html.slice(contentStart, end)));
      from = end + "</code></pre>".length;
    }
    return sources;
  }

  async function loadSources() {
    if (pageSources) return pageSources;
    const html = await fetch(location.pathname + location.search, {
      credentials: "same-origin",
      cache: "no-store",
    }).then(function (r) {
      return r.text();
    });
    pageSources = extractMermaidSources(html);
    return pageSources;
  }

  function emptyDiagrams() {
    return [...document.querySelectorAll(".mermaid")].filter(function (el) {
      return !el.querySelector("svg") && !(el.textContent || "").trim();
    });
  }

  async function recoverEmptyDiagrams() {
    const empties = emptyDiagrams();
    if (!empties.length || renderInFlight) return;
    if (typeof window.mermaid === "undefined" || !window.mermaid.render) return;

    renderInFlight = true;
    try {
      const sources = await loadSources();
      for (let i = 0; i < empties.length; i++) {
        const src = sources[i];
        if (!src) continue;
        const id = "scs-mermaid-" + Date.now() + "-" + i;
        try {
          const out = await window.mermaid.render(id, src);
          empties[i].innerHTML = out.svg;
          if (typeof out.bindFunctions === "function") {
            out.bindFunctions(empties[i]);
          }
          enhanceDiagram(empties[i]);
        } catch (err) {
          console.error("SCS Mermaid render failed", err);
        }
      }
    } finally {
      renderInFlight = false;
    }
  }

  document.addEventListener("keydown", function (event) {
    if (event.key !== "Escape") return;
    const open = document.querySelector(".scs-mermaid.is-fullscreen");
    if (open) {
      event.preventDefault();
      exitFullscreen(open);
    }
  });

  enhanceAll(document);

  const observer = new MutationObserver(function (mutations) {
    for (const mutation of mutations) {
      for (const node of mutation.addedNodes) {
        if (!(node instanceof Element)) continue;
        const diagram = node.classList.contains("mermaid")
          ? node
          : node.closest && node.closest(".mermaid");
        if (diagram) enhanceDiagram(diagram);
        else enhanceAll(node);
      }
    }
    if (emptyDiagrams().length) {
      recoverEmptyDiagrams();
    }
  });

  if (document.body) {
    observer.observe(document.body, { childList: true, subtree: true });
  }

  if (typeof document$ !== "undefined" && document$.subscribe) {
    document$.subscribe(function () {
      pageSources = null;
      enhanceAll(document);
      window.setTimeout(recoverEmptyDiagrams, 300);
    });
  }

  window.setTimeout(recoverEmptyDiagrams, 400);
  window.setTimeout(recoverEmptyDiagrams, 1500);
})();
