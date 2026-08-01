/* product_tours dashboard helpers: strict-CSP-safe confirmations and fields. */
(function () {
  "use strict";

  document.addEventListener("click", function (event) {
    var control = event.target.closest && event.target.closest("[data-confirm]");
    if (control && !window.confirm(control.getAttribute("data-confirm"))) event.preventDefault();
  });

  document.addEventListener("change", function (event) {
    if (event.target.matches("[data-autosubmit]")) event.target.form.requestSubmit();
  });

  document.addEventListener("input", function (event) {
    if (event.target.matches("[data-product-tour-key]")) {
      var valid = /^[a-z0-9]+(?:[._-][a-z0-9]+)*$/.test(event.target.value);
      event.target.setCustomValidity(valid || !event.target.value ? "" : "Use lowercase letters and numbers separated by ., _, or -.");
    }
    if (event.target.matches("[data-rich-content]")) syncRichEditor(event.target.closest("[data-rich-editor]"));
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
})();
