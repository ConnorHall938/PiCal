(function () {
  let shiftActive = false;
  let capsActive = false;
  let symbolActive = false;

  const keyboardRoot = document.getElementById("keyboard");
  const layoutAlpha = document.getElementById("layout-alpha");
  const layoutSymbol = document.getElementById("layout-symbol");

  function qsa(sel, root = document) {
    return Array.from(root.querySelectorAll(sel));
  }

  function setShift(on) {
    shiftActive = !!on;
    document.body.classList.toggle("shift-on", shiftActive);
    qsa(".key[data-key='Shift'], .key.shift").forEach(k =>
      k.classList.toggle("active", shiftActive)
    );
    updateKeyLabelsAlpha();
  }

  function clearShift() {
    if (shiftActive) setShift(false);
  }

  function setCaps(on) {
    capsActive = !!on;
    document.body.classList.toggle("caps-on", capsActive);
    qsa(".key[data-key='CapsLock'], .key.caps").forEach(k =>
      k.classList.toggle("active", capsActive)
    );
    updateKeyLabelsAlpha();
  }

  function effectiveUppercase() {
    return shiftActive ? !capsActive : capsActive;
  }

  function updateKeyLabelsAlpha() {
    if (!layoutAlpha) return;
    const alphaKeys = qsa(".key", layoutAlpha);
    const upper = effectiveUppercase();

    alphaKeys.forEach(k => {
      const lowerVal = k.getAttribute("data-lower");
      if (!lowerVal) return;
      k.textContent = upper ? lowerVal.toUpperCase() : lowerVal.toLowerCase();
    });
  }

  function showAlphaLayout() {
    symbolActive = false;
    if (layoutAlpha) layoutAlpha.style.display = "block";
    if (layoutSymbol) layoutSymbol.style.display = "none";
    updateKeyLabelsAlpha();
    bindBackspaceKeys();
  }

  function showSymbolLayout() {
    symbolActive = true;
    if (layoutAlpha) layoutAlpha.style.display = "none";
    if (layoutSymbol) layoutSymbol.style.display = "block";
    bindBackspaceKeys();
  }

  function postKey(key, extra = {}) {
    parent.postMessage({ type: "keyboard-ui", key, ...extra }, "*");
  }

  function handleRegularKeyOutput(outKey) {
    if (!outKey) return;
    postKey(outKey);
    clearShift();
  }

  function normalizeOutputForAlpha(lowerVal) {
    if (!lowerVal) return "";
    return effectiveUppercase() ? lowerVal.toUpperCase() : lowerVal.toLowerCase();
  }

  function bindBackspaceKeys() {
    qsa('.key[data-key="Backspace"]').forEach(bs => {
      if (bs.dataset.oskBound === "1") return;
      bs.dataset.oskBound = "1";

      bs.addEventListener("click", e => {
        e.preventDefault();
        e.stopImmediatePropagation();
      });

      bs.addEventListener("pointerdown", e => {
        e.preventDefault();
        e.stopPropagation();
        try {
          bs.setPointerCapture(e.pointerId);
        } catch {}
        parent.postMessage({ type: "keyboard-ui", key: "Backspace", state: "down" }, "*");
      });

      const up = e => {
        if (e) {
          e.preventDefault();
          e.stopPropagation();
          try {
            bs.releasePointerCapture(e.pointerId);
          } catch {}
        }
        parent.postMessage({ type: "keyboard-ui", key: "Backspace", state: "up" }, "*");
      };

      bs.addEventListener("pointerup", up);
      bs.addEventListener("pointercancel", up);
      bs.addEventListener("pointerleave", up);
      bs.addEventListener("pointerout", up);
    });
  }

  if (keyboardRoot) {
    keyboardRoot.addEventListener(
      "pointerdown",
      e => {
        e.preventDefault();
      },
      { capture: true }
    );
    keyboardRoot.addEventListener(
      "mousedown",
      e => {
        e.preventDefault();
      },
      { capture: true }
    );
  }

  function wireKeyHandlers() {
    const allKeys = qsa(".key");

    allKeys.forEach(key => {
      key.addEventListener("pointerdown", e => {
        e.preventDefault();
        e.stopPropagation();
      });
      key.addEventListener("mousedown", e => {
        e.preventDefault();
        e.stopPropagation();
      });

      key.addEventListener("click", () => {
        const dataKey = key.getAttribute("data-key");
        const lowerVal = key.getAttribute("data-lower") || "";

        if (dataKey === "Backspace") return;

        if (dataKey === "Shift") {
          setShift(!shiftActive);
          return;
        }

        if (dataKey === "CapsLock") {
          setCaps(!capsActive);
          return;
        }

        if (dataKey === "SymbolToggle") {
          showSymbolLayout();
          return;
        }

        if (dataKey === "AlphaToggle") {
          showAlphaLayout();
          return;
        }

        if (dataKey === "Enter" || dataKey === "Tab" || dataKey === "Copy" || dataKey === "Paste") {
          postKey(dataKey);
          clearShift();
          return;
        }

        if (dataKey === " ") {
          postKey(" ");
          clearShift();
          return;
        }

        if (dataKey && dataKey.length === 1) {
          postKey(dataKey);
          clearShift();
          return;
        }

        let outKey = lowerVal;
        if (!symbolActive) {
          outKey = normalizeOutputForAlpha(lowerVal);
        }
        handleRegularKeyOutput(outKey);
      });
    });
  }

  bindBackspaceKeys();
  wireKeyHandlers();
  updateKeyLabelsAlpha();

  window.addEventListener("message", e => {
    if (!e.data || e.data.type !== "setTheme") return;
    document.body.classList.toggle("dark-mode", e.data.theme === "dark");
  });

  chrome.storage.local.get(["oskTheme"], res => {
    if (!res.oskTheme) return;
    document.body.classList.toggle("dark-mode", res.oskTheme === "dark");
  });
})();
