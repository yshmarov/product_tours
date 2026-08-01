/* product_tours widget: delegated modal tutorials, no framework or build step. */
(function () {
  "use strict";

  if (window.__productToursLoaded) return;
  window.__productToursLoaded = true;

  var config = readConfig();
  var overlay = null;
  var session = null;
  var lastFocused = null;
  var savedOverflow = null;
  var viewportHandler = null;

  document.addEventListener("click", handleTrigger, true);
  document.addEventListener("keydown", handleKeydown);
  document.addEventListener("turbo:load", function () { config = readConfig() || config; });
  document.addEventListener("turbo:before-render", function () { close(false); });

  function readConfig() {
    var node = document.querySelector("script[data-product-tours-config]");
    if (!node) return null;
    try { return JSON.parse(node.textContent); } catch (_error) { return null; }
  }

  function handleTrigger(event) {
    var trigger = event.target && event.target.closest
      ? event.target.closest("[data-product-tour]")
      : null;
    if (!trigger) return;

    config = readConfig() || config;
    if (!config || !config.endpoint) return;
    event.preventDefault();
    event.stopPropagation();
    resolve(trigger.getAttribute("data-product-tour"), trigger);
  }

  function resolve(key, trigger) {
    if (!key || overlay) return;
    var url = config.endpoint + "/post?" + params({ key: key, page_url: window.location.href });
    fetch(url, { headers: { Accept: "application/json" }, credentials: "same-origin" })
      .then(function (response) {
        if (!response.ok) throw new Error("Product tour " + JSON.stringify(key) + " could not be resolved (HTTP " + response.status + ")");
        return response.json();
      })
      .then(function (post) { open(post, trigger); })
      .catch(function (error) {
        if (window.console && console.error) console.error("product_tours:", error.message);
      });
  }

  function open(post, trigger) {
    if (overlay) return;
    injectStyles();
    lastFocused = trigger || document.activeElement;
    session = { key: post.key, completed: false, viewed: false };

    overlay = element("div", "pt-overlay");
    overlay.id = "product-tours-overlay";
    overlay.addEventListener("mousedown", function (event) {
      if (event.target === overlay) close(true);
    });
    overlay.addEventListener("keydown", trapFocus);

    var dialog = element("section", "pt-dialog");
    dialog.setAttribute("role", "dialog");
    dialog.setAttribute("aria-modal", "true");
    dialog.setAttribute("aria-labelledby", "product-tours-title");
    dialog.setAttribute("aria-label", config.labels.dialog);
    dialog.tabIndex = -1;
    if (config.rtl) dialog.setAttribute("dir", "rtl");

    var closeButton = element("button", "pt-close", "\u00d7");
    closeButton.type = "button";
    closeButton.setAttribute("aria-label", config.labels.close);
    closeButton.addEventListener("click", function () { close(true); });
    dialog.appendChild(closeButton);

    var content = element("div", "pt-content");
    content.appendChild(element("h2", "pt-title", post.title));
    content.lastChild.id = "product-tours-title";

    if (post.video && post.video.url) content.appendChild(videoNode(post.video, post.title));

    if (post.descriptionHtml) {
      var description = element("div", "pt-description");
      description.innerHTML = post.descriptionHtml;
      content.appendChild(description);
    }

    var actions = element("div", "pt-actions");
    var action = element("button", "pt-primary", (post.action && post.action.label) || config.labels.done);
    action.type = "button";
    action.addEventListener("click", function () {
      session.completed = true;
      sendSignal("completed", "action");
      var target = post.action && post.action.url;
      close(false);
      if (target) window.location.assign(target);
    });
    actions.appendChild(action);
    content.appendChild(actions);
    dialog.appendChild(content);
    overlay.appendChild(dialog);
    document.body.appendChild(overlay);
    lockScroll();
    startViewportTracking();

    window.requestAnimationFrame(function () {
      if (!overlay || !dialog.getClientRects().length) return;
      closeButton.focus();
      if (document.activeElement && overlay.contains(document.activeElement)) {
        session.viewed = true;
        sendSignal("viewed", "modal");
      }
    });
  }

  function videoNode(video, title) {
    var frame = element("div", "pt-video");
    if (video.kind === "iframe") {
      var iframe = document.createElement("iframe");
      iframe.src = video.url;
      iframe.title = title || config.labels.video;
      iframe.loading = "eager";
      iframe.allow = "accelerometer; autoplay; clipboard-write; encrypted-media; fullscreen; gyroscope; picture-in-picture";
      iframe.setAttribute("allowfullscreen", "");
      iframe.referrerPolicy = "strict-origin-when-cross-origin";
      frame.appendChild(iframe);
    } else {
      var player = document.createElement("video");
      player.src = video.url;
      player.controls = true;
      player.playsInline = true;
      player.preload = "metadata";
      player.addEventListener("ended", function () {
        if (!session || session.completed) return;
        session.completed = true;
        sendSignal("completed", "video_ended", { duration: player.duration });
      });
      frame.appendChild(player);
    }
    return frame;
  }

  function handleKeydown(event) {
    if (event.key === "Escape" && overlay) close(true);
  }

  function trapFocus(event) {
    if (event.key !== "Tab" || !overlay) return;
    var focusable = overlay.querySelectorAll("button, a[href], video[controls], [tabindex]:not([tabindex='-1'])");
    if (!focusable.length) return;
    var first = focusable[0];
    var last = focusable[focusable.length - 1];
    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault();
      last.focus();
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault();
      first.focus();
    }
  }

  function close(reportDismissal) {
    if (!overlay) return;
    if (reportDismissal && session && session.viewed && !session.completed) sendSignal("dismissed", "modal");
    stopViewportTracking();
    overlay.remove();
    overlay = null;
    session = null;
    unlockScroll();
    if (lastFocused && lastFocused.focus) lastFocused.focus();
    lastFocused = null;
  }

  function sendSignal(action, source, metadata) {
    if (!session || !config) return;
    var body = {
      key: session.key,
      event_action: action,
      source: source,
      metadata: metadata || {},
      page_url: window.location.href
    };
    fetch(config.endpoint + "/signal", {
      method: "POST",
      credentials: "same-origin",
      keepalive: true,
      headers: { "Content-Type": "application/json", "X-CSRF-Token": csrfToken(), Accept: "application/json" },
      body: JSON.stringify(body)
    }).catch(function () {});
  }

  function csrfToken() {
    var meta = document.querySelector("meta[name='csrf-token']");
    return meta ? meta.content : "";
  }

  function params(values) {
    return Object.keys(values).map(function (key) {
      return encodeURIComponent(key) + "=" + encodeURIComponent(values[key] || "");
    }).join("&");
  }

  function element(tag, className, text) {
    var node = document.createElement(tag);
    node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
  }

  function lockScroll() {
    if (savedOverflow === null) savedOverflow = document.documentElement.style.overflow;
    document.documentElement.style.overflow = "hidden";
  }

  function unlockScroll() {
    if (savedOverflow === null) return;
    document.documentElement.style.overflow = savedOverflow;
    savedOverflow = null;
  }

  function applyViewport() {
    if (!overlay) return;
    var viewport = window.visualViewport;
    var dialog = overlay.querySelector(".pt-dialog");
    if (viewport && window.matchMedia("(max-width: 480px)").matches) {
      overlay.style.top = viewport.offsetTop + "px";
      overlay.style.height = viewport.height + "px";
      overlay.style.bottom = "auto";
      if (dialog) dialog.style.height = viewport.height + "px";
    } else {
      overlay.style.top = "";
      overlay.style.height = "";
      overlay.style.bottom = "";
      if (dialog) dialog.style.height = "";
    }
  }

  function startViewportTracking() {
    if (!window.visualViewport) return;
    viewportHandler = applyViewport;
    window.visualViewport.addEventListener("resize", viewportHandler);
    window.visualViewport.addEventListener("scroll", viewportHandler);
    applyViewport();
  }

  function stopViewportTracking() {
    if (viewportHandler && window.visualViewport) {
      window.visualViewport.removeEventListener("resize", viewportHandler);
      window.visualViewport.removeEventListener("scroll", viewportHandler);
    }
    viewportHandler = null;
  }

  function injectStyles() {
    if (document.getElementById("product-tours-styles")) return;
    var style = document.createElement("style");
    style.id = "product-tours-styles";
    style.textContent = [
      ".pt-overlay{position:fixed;inset:0;z-index:2147482000;display:flex;align-items:center;justify-content:center;padding:24px;background:rgba(15,23,42,.58);font-family:ui-sans-serif,system-ui,-apple-system,BlinkMacSystemFont,\"Segoe UI\",sans-serif;letter-spacing:0}",
      ".pt-overlay,.pt-overlay *{box-sizing:border-box}",
      ".pt-dialog{position:relative;width:min(680px,100%);max-height:min(760px,calc(100dvh - 48px));overflow:hidden;background:#fff;color:#17202a;border:1px solid rgba(15,23,42,.15);border-radius:8px;box-shadow:0 24px 70px rgba(15,23,42,.28);outline:none}",
      ".pt-content{max-height:min(760px,calc(100dvh - 48px));overflow-y:auto;overscroll-behavior:contain;padding:28px}",
      ".pt-close{position:absolute;top:10px;right:10px;z-index:2;width:36px;height:36px;border:0;border-radius:50%;background:rgba(255,255,255,.94);color:#17202a;font:28px/32px Arial,sans-serif;cursor:pointer;box-shadow:0 1px 4px rgba(15,23,42,.2)}",
      ".pt-close:hover{background:#f1f5f9}.pt-close:focus-visible,.pt-primary:focus-visible{outline:3px solid #0f766e;outline-offset:2px}",
      ".pt-title{margin:0 44px 18px 0;font-size:24px;line-height:1.25;font-weight:700;letter-spacing:0;overflow-wrap:anywhere}",
      ".pt-video{position:relative;width:100%;aspect-ratio:16/9;margin:0 0 20px;overflow:hidden;border-radius:6px;background:#05070a}",
      ".pt-video iframe,.pt-video video{display:block;width:100%;height:100%;border:0;object-fit:contain}",
      ".pt-description{font-size:16px;line-height:1.6;color:#334155;overflow-wrap:anywhere}.pt-description>*:first-child{margin-top:0}.pt-description>*:last-child{margin-bottom:0}.pt-description a{color:#0f766e}",
      ".pt-actions{display:flex;justify-content:flex-end;margin-top:24px}.pt-primary{min-height:44px;padding:10px 18px;border:1px solid #115e59;border-radius:6px;background:#0f766e;color:#fff;font:600 15px/1.4 inherit;cursor:pointer;letter-spacing:0}.pt-primary:hover{background:#115e59}",
      "[dir='rtl'] .pt-close{right:auto;left:10px}[dir='rtl'] .pt-title{margin-right:0;margin-left:44px}[dir='rtl'] .pt-actions{justify-content:flex-start}",
      "@media (prefers-color-scheme:dark){.pt-dialog{background:#111827;color:#f8fafc;border-color:#334155}.pt-close{background:rgba(17,24,39,.94);color:#f8fafc}.pt-close:hover{background:#263244}.pt-description{color:#cbd5e1}}",
      "@media (prefers-reduced-motion:no-preference){.pt-dialog{animation:pt-enter .16s ease-out}@keyframes pt-enter{from{opacity:0;transform:translateY(8px)}to{opacity:1;transform:none}}}",
      "@media (max-width:480px){.pt-overlay{align-items:stretch;padding:0;background:#fff}.pt-dialog{width:100%;height:100dvh;max-height:none;border:0;border-radius:0;box-shadow:none}.pt-content{height:100%;max-height:none;padding:calc(22px + env(safe-area-inset-top)) 18px calc(20px + env(safe-area-inset-bottom));overflow-y:auto}.pt-close{top:calc(8px + env(safe-area-inset-top));right:10px}.pt-title{font-size:21px;margin-top:5px}.pt-actions{position:sticky;bottom:0;padding-top:14px;padding-bottom:env(safe-area-inset-bottom);background:inherit}.pt-primary{width:100%;font-size:16px}}",
      "@media (max-width:480px) and (prefers-color-scheme:dark){.pt-overlay{background:#111827}}"
    ].join("");
    document.head.appendChild(style);
  }
})();
