/* product_tours widget: delegated modal tutorials, no framework or build step. */
(function () {
  "use strict";

  if (window.__productToursLoaded) return;
  window.__productToursLoaded = true;

  var config = readConfig();
  var overlay = null;
  var dialog = null;
  var closeButton = null;
  var session = null;
  var currentPost = null;
  var history = [];
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
    fetchPost(key, config.locale)
      .then(function (post) { open(post, trigger); })
      .catch(reportError);
  }

  function fetchPost(key, locale) {
    var url = config.endpoint + "/post?" + params({ key: key, locale: locale, page_url: window.location.href });
    return fetch(url, { headers: { Accept: "application/json" }, credentials: "same-origin" })
      .then(function (response) {
        if (!response.ok) throw new Error("Product tour " + JSON.stringify(key) + " could not be resolved (HTTP " + response.status + ")");
        return response.json();
      });
  }

  function reportError(error) {
    if (window.console && console.error) console.error("product_tours:", error.message);
  }

  function open(post, trigger) {
    if (overlay) return;
    injectStyles();
    lastFocused = trigger || document.activeElement;
    history = [];

    overlay = element("div", "pt-overlay");
    overlay.id = "product-tours-overlay";
    overlay.addEventListener("mousedown", function (event) {
      if (event.target === overlay) close(true);
    });
    overlay.addEventListener("keydown", trapFocus);

    dialog = element("div", "pt-dialog");
    dialog.setAttribute("role", "dialog");
    dialog.setAttribute("aria-modal", "true");
    dialog.setAttribute("aria-labelledby", "product-tours-title");
    dialog.setAttribute("aria-label", config.labels.dialog);
    dialog.tabIndex = -1;
    if (config.rtl) dialog.setAttribute("dir", "rtl");

    overlay.appendChild(dialog);
    document.body.appendChild(overlay);
    lockScroll();
    startViewportTracking();
    renderPost(post, "modal");
  }

  function renderPost(post, source) {
    if (!dialog) return;
    var existing = dialog.querySelector(".pt-content");
    if (existing) existing.remove();
    currentPost = post;
    session = { key: post.key, locale: post.locale, completed: false, viewed: false };

    var content = element("div", "pt-content");
    var head = element("div", "pt-head");
    var title = element("h2", "pt-title", post.title);
    title.id = "product-tours-title";
    head.appendChild(title);

    closeButton = element("button", "pt-close", "\u00d7");
    closeButton.type = "button";
    closeButton.setAttribute("aria-label", config.labels.close);
    closeButton.addEventListener("click", function () { close(true); });
    head.appendChild(closeButton);
    content.appendChild(head);

    if (post.video && post.video.url) content.appendChild(videoNode(post.video, post.title));

    if (post.descriptionHtml) {
      var description = element("div", "pt-description");
      description.innerHTML = post.descriptionHtml;
      content.appendChild(description);
    }

    var error = element("p", "pt-error");
    error.setAttribute("role", "alert");
    error.hidden = true;
    content.appendChild(error);

    var actions = element("div", "pt-actions");
    if (history.length) {
      var back = element("button", "pt-back", config.labels.back);
      back.type = "button";
      back.addEventListener("click", function () {
        renderPost(history.pop(), "back");
      });
      actions.appendChild(back);
    }

    var action = element("button", "pt-primary", (post.action && post.action.label) || config.labels.done);
    action.type = "button";
    action.addEventListener("click", function () {
      var nextKey = post.action && post.action.postKey;
      if (nextKey) {
        action.disabled = true;
        action.setAttribute("aria-busy", "true");
        fetchPost(nextKey, post.locale).then(function (nextPost) {
          var repeated = currentPost && currentPost.key === nextPost.key;
          repeated = repeated || history.some(function (visited) { return visited.key === nextPost.key; });
          if (repeated) throw new Error("Product tour link would create a navigation cycle");
          complete("linked_post");
          history.push(post);
          renderPost(nextPost, "linked_post");
        }).catch(function (fetchError) {
          reportError(fetchError);
          error.textContent = config.labels.unavailable;
          error.hidden = false;
          action.disabled = false;
          action.removeAttribute("aria-busy");
        });
        return;
      }

      complete("action");
      var target = post.action && post.action.url;
      close(false);
      if (target) window.location.assign(target);
    });
    actions.appendChild(action);
    content.appendChild(actions);
    dialog.appendChild(content);

    window.requestAnimationFrame(function () {
      if (!overlay || !dialog.getClientRects().length) return;
      closeButton.focus();
      if (document.activeElement && overlay.contains(document.activeElement)) {
        session.viewed = true;
        sendSignal("viewed", source || "modal");
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
      showFirstVideoFrame(player);
      frame.appendChild(player);
    }
    return frame;
  }

  function showFirstVideoFrame(player) {
    function seek() {
      if (!Number.isFinite(player.duration) || player.duration <= 0 || player.currentTime > 0) return;
      try { player.currentTime = Math.min(0.1, player.duration / 2); } catch (_error) {}
    }
    player.addEventListener("loadedmetadata", seek, { once: true });
    if (player.readyState >= 1) seek();
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
    dialog = null;
    closeButton = null;
    session = null;
    currentPost = null;
    history = [];
    unlockScroll();
    if (lastFocused && lastFocused.focus) lastFocused.focus();
    lastFocused = null;
  }

  function sendSignal(action, source) {
    if (!session || !config) return;
    var body = {
      key: session.key,
      locale: session.locale,
      event_action: action,
      source: source,
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

  function complete(source) {
    if (!session || session.completed) return;
    session.completed = true;
    sendSignal("completed", source);
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
    var css = [
      ".pt-overlay{position:fixed;inset:0;z-index:2147482000;background:rgba(0,0,0,.45);display:flex;align-items:center;justify-content:center;padding:16px}",
      ".pt-overlay,.pt-overlay *{box-sizing:border-box}",
      ".pt-dialog{width:100%;max-width:440px;max-height:92vh;overflow:auto;overscroll-behavior:contain;background:#fff;color:#1c2024;border-radius:14px;padding:20px;font:14px/1.5 system-ui,-apple-system,sans-serif;box-shadow:0 20px 60px rgba(0,0,0,.35);outline:none}",
      ".pt-head{display:flex;align-items:flex-start;justify-content:space-between;gap:8px;margin:0 0 12px}",
      ".pt-title{margin:0;font-size:17px;line-height:1.5;font-weight:700;overflow-wrap:anywhere}",
      ".pt-close{border:0;background:none;font-size:22px;line-height:1;cursor:pointer;color:inherit;padding:2px 6px}",
      ".pt-close:focus-visible,.pt-primary:focus-visible,.pt-back:focus-visible{outline:2px solid #2563eb;outline-offset:2px}",
      ".pt-video{position:relative;width:100%;aspect-ratio:16/9;margin:0 0 12px;overflow:hidden;border-radius:10px;background:#000}",
      ".pt-video iframe,.pt-video video{display:block;width:100%;height:100%;border:0;object-fit:contain}",
      ".pt-description{color:inherit;overflow-wrap:anywhere}.pt-description>*:first-child{margin-top:0}.pt-description>*:last-child{margin-bottom:0}.pt-description a{color:#2563eb}",
      ".pt-error{color:#dc2626;margin:0 0 12px}.pt-error[hidden]{display:none}",
      ".pt-actions{display:flex;align-items:center;justify-content:flex-end;gap:8px;flex-wrap:wrap;margin-top:12px}",
      ".pt-primary,.pt-back{padding:8px 14px;border-radius:8px;cursor:pointer;font:inherit}",
      ".pt-primary{border:0;background:#2563eb;color:#fff;font-weight:600}.pt-primary:hover{background:#1d4ed8}.pt-primary:disabled{opacity:.6;cursor:default}",
      ".pt-back{margin-inline-end:auto;border:1px solid #d1d5db;background:none;color:inherit}.pt-back:hover{background:rgba(37,99,235,.07)}",
      "@media (prefers-color-scheme:dark){.pt-dialog{background:#1a1f26;color:#e6e8ea}.pt-back{border-color:#2a313a}.pt-description{color:#e6e8ea}}",
      "@media (max-width:480px){.pt-overlay{padding:0;align-items:stretch;justify-content:stretch}.pt-dialog{left:0;right:0;top:0;bottom:0;width:100%;max-width:none;height:100vh;height:100dvh;max-height:100dvh;border-radius:0;margin:0}.pt-actions{padding-bottom:calc(0px + env(safe-area-inset-bottom))}.pt-primary,.pt-back{font-size:16px}}"
    ].join("");
    var existing = document.getElementById("product-tours-styles");
    if (existing && existing.textContent === css) return;
    if (existing) existing.remove();

    var style = document.createElement("style");
    style.id = "product-tours-styles";
    style.textContent = css;
    document.head.appendChild(style);
  }
})();
