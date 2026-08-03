/* product_tours dashboard helpers: strict-CSP-safe confirmations and fields. */
(function () {
  "use strict";

  document.addEventListener("click", function (event) {
    var control = event.target.closest && event.target.closest("[data-confirm]");
    if (control && !window.confirm(control.getAttribute("data-confirm"))) event.preventDefault();
  });

  document.addEventListener("change", function (event) {
    if (event.target.matches("[data-autosubmit]")) event.target.form.requestSubmit();
    if (event.target.matches("[data-action-target]")) syncActionPicker(event.target.closest("[data-action-picker]") || event.target.form);
    if (event.target.matches("[data-video-source]")) syncVideoSourcePicker(event.target.closest("[data-video-source-picker]"));
    if (event.target.matches("[name='post[locale]']")) refreshPostOptions(event.target.form);
    if (event.target.matches("[data-action-post-select]")) event.target.dataset.selectedKey = event.target.value;
    if (event.target.matches("[data-product-tour-key]")) normalizeKey(event.target, true);
    if (event.target.matches("[data-video-preview-input]")) scheduleVideoPreview(event.target, 0);
  });

  document.addEventListener("input", function (event) {
    if (event.target.matches("[data-product-tour-key]")) {
      normalizeKey(event.target, false);
      var valid = /^[a-z0-9]+(?:[._-][a-z0-9]+)*$/.test(event.target.value);
      event.target.setCustomValidity(valid || !event.target.value ? "" : "Use lowercase letters and numbers separated by ., _, or -.");
    }
    if (event.target.matches("[data-video-preview-input]")) scheduleVideoPreview(event.target, 400);
    if (event.target.matches("[data-rich-content]")) syncRichEditor(event.target.closest("[data-rich-editor]"));
  });

  document.addEventListener("focusout", function (event) {
    if (!event.target.matches("[data-product-tour-key]")) return;
    normalizeKey(event.target, true);
    event.target.setCustomValidity("");
  });

  document.addEventListener("click", function (event) {
    var button = event.target.closest && event.target.closest("[data-rich-command]");
    if (!button) return;
    var editor = button.closest("[data-rich-editor]");
    var content = editor && editor.querySelector("[data-rich-content]");
    if (!content) return;

    event.preventDefault();
    content.focus();
    var command = button.getAttribute("data-rich-command");
    var value = null;
    if (command === "createLink") {
      value = window.prompt("Link URL", "https://");
      if (!value) return;
    }
    document.execCommand(command, false, value);
    syncRichEditor(editor);
  });

  document.addEventListener("submit", function (event) {
    var editors = event.target.querySelectorAll && event.target.querySelectorAll("[data-rich-editor]");
    if (editors) editors.forEach(syncRichEditor);
  });

  function syncRichEditor(editor) {
    if (!editor) return;
    var input = editor.querySelector("[data-rich-input]");
    var content = editor.querySelector("[data-rich-content]");
    if (input && content) input.value = content.innerHTML;
  }

  function normalizeKey(input, final) {
    var value = input.value.toLowerCase()
      .replace(/[^a-z0-9._-]+/g, "_")
      .replace(/([._-])[._-]+/g, "$1")
      .replace(/^[._-]+/, "");
    if (final) value = value.replace(/[._-]+$/, "");
    input.value = value;
  }

  function showFirstVideoFrame(video) {
    function seek() {
      if (!Number.isFinite(video.duration) || video.duration <= 0 || video.currentTime > 0) return;
      try { video.currentTime = Math.min(0.1, video.duration / 2); } catch (_error) {}
    }
    video.addEventListener("loadedmetadata", seek, { once: true });
    if (video.readyState >= 1) seek();
  }

  function scheduleVideoPreview(input, delay) {
    if (input.disabled) return;
    window.clearTimeout(input._productToursPreviewTimer);
    input._productToursPreviewTimer = window.setTimeout(function () { loadVideoPreview(input); }, delay);
  }

  function loadVideoPreview(input) {
    var form = input.closest("form");
    var preview = form && form.querySelector("[data-video-preview]");
    if (!preview) return;

    var frame = preview.querySelector("[data-video-preview-frame]");
    var status = preview.querySelector("[data-video-preview-status]");
    var value = input.value.trim();
    var requestId = String(Date.now()) + Math.random();
    preview.dataset.requestId = requestId;
    frame.replaceChildren();
    status.textContent = "";
    preview.hidden = !value;
    if (!value) return;

    status.textContent = preview.dataset.loading;
    var endpoint = new URL(preview.dataset.endpoint, window.location.origin);
    endpoint.searchParams.set("url", value);
    fetch(endpoint.toString(), { credentials: "same-origin", headers: { Accept: "application/json" } })
      .then(function (response) {
        return response.json().catch(function () { return {}; }).then(function (payload) {
          if (!response.ok) throw new Error(payload.error || preview.dataset.error);
          return payload;
        });
      })
      .then(function (video) {
        if (preview.dataset.requestId !== requestId) return;
        renderVideoPreview(frame, video, form);
        status.textContent = "";
      })
      .catch(function (error) {
        if (preview.dataset.requestId !== requestId) return;
        status.textContent = error.message || preview.dataset.error;
      });
  }

  function renderVideoPreview(frame, video, form) {
    var player;
    if (video.kind === "iframe") {
      player = document.createElement("iframe");
      player.src = video.url;
      player.title = video.title || "Video preview";
      player.allow = "autoplay; fullscreen; picture-in-picture";
      player.setAttribute("allowfullscreen", "");
      player.referrerPolicy = "strict-origin-when-cross-origin";
    } else {
      player = document.createElement("video");
      player.src = video.url;
      player.controls = true;
      player.playsInline = true;
      player.preload = "metadata";
      if (video.thumbnail_url) player.poster = video.thumbnail_url;
      showFirstVideoFrame(player);
    }
    frame.appendChild(player);

    var title = form.querySelector("[name='post[title]']");
    if (title && !title.value.trim() && video.title) title.value = video.title;
  }

  function syncActionPicker(scope) {
    if (!scope) return;
    var picker = scope.matches && scope.matches("[data-action-picker]") ? scope : scope.querySelector("[data-action-picker]");
    if (!picker) return;
    var selected = picker.querySelector("[data-action-target]:checked");
    var target = selected ? selected.value : "close";
    picker.querySelectorAll(".action-choice").forEach(function (choice) {
      choice.classList.toggle("selected", choice.contains(selected));
    });

    picker.parentElement.querySelectorAll("[data-action-fields]").forEach(function (fields) {
      var active = fields.getAttribute("data-action-fields") === target;
      fields.hidden = !active;
      fields.querySelectorAll("input, select, textarea").forEach(function (input) { input.disabled = !active; });
    });

    var label = picker.parentElement.querySelector("[data-action-label]");
    if (label) label.placeholder = target === "post" ? "Next" : "Done";
  }

  function syncVideoSourcePicker(picker) {
    if (!picker) return;
    var selected = picker.querySelector("[data-video-source]:checked");
    var source = selected ? selected.value : "url";
    picker.querySelectorAll(".action-choice").forEach(function (choice) {
      choice.classList.toggle("selected", choice.contains(selected));
    });

    var section = picker.parentElement;
    section.querySelectorAll("[data-video-source-fields]").forEach(function (fields) {
      var active = fields.getAttribute("data-video-source-fields") === source;
      fields.hidden = !active;
      fields.querySelectorAll("input, select, textarea").forEach(function (input) {
        input.disabled = !active;
        if (input.type === "file") input.required = active && picker.dataset.hasUpload !== "true";
      });
    });

    var urlInput = section.querySelector("[data-video-preview-input]");
    if (source === "url" && urlInput && urlInput.value.trim()) scheduleVideoPreview(urlInput, 0);
  }

  function refreshPostOptions(form) {
    if (!form) return;
    var select = form.querySelector("[data-action-post-select]");
    var data = form.querySelector("[data-action-post-options]");
    var locale = form.querySelector("[name='post[locale]']");
    if (!select || !data || !locale) return;

    var posts;
    try { posts = JSON.parse(data.textContent); } catch (_error) { return; }
    var selectedKey = select.dataset.selectedKey || select.value;
    var currentPostId = select.dataset.currentPostId;
    var placeholder = select.options.length ? select.options[0].textContent : "Select the next post…";
    select.replaceChildren(new Option(placeholder, ""));

    posts.forEach(function (post) {
      if (post.locale !== locale.value || String(post.id) === currentPostId) return;
      select.add(new Option(post.label, post.key));
    });
    select.value = selectedKey;
  }

  function initializeDashboard() {
    document.querySelectorAll("[data-video-source-picker]").forEach(syncVideoSourcePicker);
    document.querySelectorAll("[data-action-picker]").forEach(function (picker) {
      var form = picker.closest("form");
      refreshPostOptions(form);
      syncActionPicker(form);
    });
    document.querySelectorAll("[data-video-first-frame]").forEach(showFirstVideoFrame);
    document.querySelectorAll("[data-video-preview-input]").forEach(function (input) {
      if (!input.disabled && input.value.trim()) scheduleVideoPreview(input, 0);
    });
  }

  document.addEventListener("turbo:load", initializeDashboard);
  initializeDashboard();
})();
