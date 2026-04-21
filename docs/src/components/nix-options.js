/**
 * nix-options.js — Client-side NixOS option card renderer (Option 2).
 *
 * Finds every <div class="nix-options-widget"> element on the page and
 * fetches a pre-generated options JSON blob from the co-deployed search
 * directory, then renders interactive option cards inline.
 *
 * Widget HTML (placed in Markdown as raw HTML):
 *
 *   <div class="nix-options-widget"
 *        data-module="tailscale"
 *        data-prefix="services.tailscale">
 *     Loading options…
 *   </div>
 *
 *   data-module  – filename stem under search/module-options/<module>.json
 *   data-prefix  – optional; filters options to those starting with this prefix
 */
(() => {
  /**
   * Return the absolute URL to the search directory, derived from the
   * <base href="…"> tag that mdbook injects based on site-url.
   */
  function getSearchBase() {
    const base = document.querySelector("base");
    if (base?.href) {
      return `${base.href.replace(/\/?$/, "/")}search/`;
    }
    return "/search/";
  }

  /** Escape text so it can be safely embedded in HTML attribute strings. */
  function escAttr(s) {
    return String(s)
      .replace(/&/g, "&amp;")
      .replace(/"/g, "&quot;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;");
  }

  /** Render a single option object as a DOM element. */
  function renderOption(opt) {
    const card = document.createElement("div");
    card.className = "nix-option-card";

    let html = `<h4 class="nix-option-name"><code>${escAttr(opt.name)}</code></h4>`;

    html += '<table class="nix-option-meta"><tbody>';
    html += `<tr><td><strong>Type</strong></td><td><code>${escAttr(opt.type || "—")}</code></td></tr>`;

    if (opt.default !== null && opt.default !== undefined) {
      html += `<tr><td><strong>Default</strong></td><td><code>${escAttr(opt.default)}</code></td></tr>`;
    }
    if (opt.example !== null && opt.example !== undefined) {
      html += `<tr><td><strong>Example</strong></td><td><code>${escAttr(opt.example)}</code></td></tr>`;
    }
    if (opt.readOnly) {
      html += "<tr><td><strong>Read-only</strong></td><td>yes</td></tr>";
    }
    html += "</tbody></table>";

    if (opt.description) {
      // Descriptions from nixosOptionsDoc may contain HTML; set via innerHTML.
      card.innerHTML = html;
      const desc = document.createElement("div");
      desc.className = "nix-option-description";
      desc.innerHTML = opt.description;
      card.appendChild(desc);
    } else {
      card.innerHTML = html;
    }

    if (opt.declarations?.length) {
      const decl = document.createElement("p");
      decl.className = "nix-option-declarations";
      decl.innerHTML = `<em>Declared in: ${opt.declarations.map((d) => `<code>${escAttr(d)}</code>`).join(", ")}</em>`;
      card.appendChild(decl);
    }

    return card;
  }

  /** Initialise every widget found on the page. */
  function initWidgets() {
    const widgets = document.querySelectorAll(
      ".nix-options-widget[data-module]",
    );
    if (!widgets.length) return;

    const searchBase = getSearchBase();

    for (const widget of widgets) {
      const moduleName = widget.dataset.module;
      const prefix = widget.dataset.prefix ?? "";
      const url = `${searchBase}module-options/${encodeURIComponent(moduleName)}.json`;

      widget.innerHTML =
        '<span class="nix-options-loading">Loading options\u2026</span>';

      fetch(url)
        .then((r) => {
          if (!r.ok) throw new Error(`HTTP ${r.status} fetching ${url}`);
          return r.json();
        })
        .then((options) => {
          const filtered = prefix
            ? options.filter((o) => o.name.startsWith(prefix))
            : options;

          widget.innerHTML = "";

          if (!filtered.length) {
            widget.innerHTML = `<p><em>No options found for prefix <code>${escAttr(prefix)}</code>.</em></p>`;
            return;
          }

          filtered.forEach((opt, idx) => {
            widget.appendChild(renderOption(opt));
            if (idx < filtered.length - 1) {
              widget.appendChild(document.createElement("hr"));
            }
          });
        })
        .catch((err) => {
          widget.innerHTML = `<p class="nix-options-error"><em>Could not load options: ${escAttr(err.message)}</em></p>`;
          console.warn("[nix-options]", err);
        });
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initWidgets);
  } else {
    initWidgets();
  }
})();
