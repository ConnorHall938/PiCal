(function(){
  if (window !== window.top) return;

  let keyboardContainer = null;
  let keyboardFrame = null;
  let lastFocusedElement = null;
  let currentLang = "en"; // CH, used to be de
  let currentTheme = "dark"; // CH, used to be light
  let currentVisibility = "oninput"; // CH, used to be alwayson
  let currentPosition = "bottom-left";// CH, used to be bottom center
  let dragHandle = null;
  let isDragging = false;
  let dragOffset = { x: 0, y: 0 };

  chrome.storage.local.get(["oskLang","oskTheme","oskVisibility","oskPosition"], res => {
    if (res.oskLang) currentLang = res.oskLang;
    if (res.oskTheme) currentTheme = res.oskTheme;
    if (res.oskVisibility) currentVisibility = res.oskVisibility;
    if (res.oskPosition) currentPosition = res.oskPosition;
    createKeyboard();
    initListeners();
    if (currentVisibility === "alwayson") showKeyboard();
  });

  function deepTargetFromEvent(e){
    const p = e.composedPath && e.composedPath();
    return (p && p.length) ? p[0] : e.target;
  }
  function isTextLike(el){
    if (!el) return false;
    if (el.isContentEditable) return true;
    if (el.tagName === "TEXTAREA") return true;
    if (el.getAttribute && el.getAttribute("role") === "textbox") return true;
    if (el.tagName === "INPUT"){
      const t = (el.type || "text").toLowerCase();
      if (/^(text|password|search|email|tel|url|number|one-time-code|otp)$/.test(t)) return true;
      if (el.autocomplete === "one-time-code") return true;
      if (el.inputMode || el.getAttribute("inputmode")) return true;
    }
    return false;
  }

  function initListeners(){
    document.addEventListener("focusin", e => {
      const t = deepTargetFromEvent(e);
      if (isTextLike(t)) {
        lastFocusedElement = t;
        if (currentVisibility !== "alwaysoff") showKeyboard();
      }
    }, true);

    document.addEventListener("pointerdown", e => {
      const t = deepTargetFromEvent(e);
      if (isTextLike(t)) {
        lastFocusedElement = t;
        if (currentVisibility !== "alwaysoff") showKeyboard();
      }
    }, true);

const stopFocusSteal = (e) => {
  if (!keyboardFrame) return;
  const path = e.composedPath ? e.composedPath() : [e.target];
  if (path.includes(keyboardFrame)) e.preventDefault();
};
document.addEventListener("mousedown",  stopFocusSteal, true);
document.addEventListener("pointerdown", stopFocusSteal, true);

    document.addEventListener("blur", e => {
      if (e.target === lastFocusedElement) {
        setTimeout(() => {
          const a = document.activeElement;
          if (currentVisibility === "alwayson") return;
          if (a !== keyboardFrame && !(a && isTextLike(a))) hideKeyboard();
        }, 50);
      }
    }, true);

    const mo = new MutationObserver(() => {
      const a = document.activeElement;
      if (isTextLike(a) && currentVisibility !== "alwaysoff") showKeyboard();
    });
    mo.observe(document.documentElement, { subtree: true, childList: true });
  }

  function createKeyboard(){
    if (keyboardContainer) return;
    keyboardContainer = document.createElement("div");
    keyboardContainer.className = "keyboard-container";
    keyboardContainer.style.position = "fixed";
    keyboardContainer.style.zIndex = "2147483647";
    keyboardContainer.style.userSelect = "none";
    updateKeyboardPosition();
    if (currentPosition === "drag") createDragHandle();

    const htmlFile = `keyboard-${currentLang}.html`;
    keyboardFrame = document.createElement("iframe");
    keyboardFrame.src = chrome.runtime.getURL(htmlFile);
    keyboardFrame.tabIndex = -1; 
    if (currentLang === "numpad") {
      keyboardFrame.style.width = "300px";
      keyboardFrame.style.height = "300px";
    } else {
        keyboardFrame.style.width = "900px";
      keyboardFrame.style.height = "300px";
      }
    
    keyboardFrame.style.border = "0";
    keyboardFrame.style.borderRadius = "10px";
    keyboardFrame.style.overflow = "hidden";
    keyboardFrame.style.display = "none";

    keyboardFrame.addEventListener("load", () => {
      applyKeyboardTheme(currentTheme);
    });

    keyboardContainer.appendChild(keyboardFrame);
    document.documentElement.appendChild(keyboardContainer);
  }

  function updateKeyboardPosition(){
    if (!keyboardContainer) return;
    keyboardContainer.style.top = "";
    keyboardContainer.style.bottom = "";
    keyboardContainer.style.left = "";
    keyboardContainer.style.right = "";
    keyboardContainer.style.transform = "";
    if (currentPosition === "drag") {
      keyboardContainer.style.bottom = "0";
      keyboardContainer.style.left = "50%";
      keyboardContainer.style.transform = "translateX(-50%)";
      return;
    }
    removeDragHandle();
    switch (currentPosition) {
      case "top-left": keyboardContainer.style.top = "0"; keyboardContainer.style.left = "0"; break;
      case "top-center": keyboardContainer.style.top = "0"; keyboardContainer.style.left = "50%"; keyboardContainer.style.transform = "translateX(-50%)"; break;
      case "top-right": keyboardContainer.style.top = "0"; keyboardContainer.style.right = "0"; break;
      case "bottom-left": keyboardContainer.style.bottom = "0"; keyboardContainer.style.left = "0"; break;
      case "bottom-center": keyboardContainer.style.bottom = "0"; keyboardContainer.style.left = "50%"; keyboardContainer.style.transform = "translateX(-50%)"; break;
      case "bottom-right": keyboardContainer.style.bottom = "0"; keyboardContainer.style.right = "0"; break;
      default: keyboardContainer.style.bottom = "0"; keyboardContainer.style.left = "50%"; keyboardContainer.style.transform = "translateX(-50%)";
    }
  }
function updateKeyboardSize() {
  if (!keyboardFrame) return;

  if (currentLang === "numpad") {
    keyboardFrame.style.width  = "260px";
    keyboardFrame.style.height = "300px";
  } else {
    keyboardFrame.style.width  = "900px";
    keyboardFrame.style.height = "300px";
  }
}

  function createDragHandle(){
    if (dragHandle) return;
    dragHandle = document.createElement("div");
    dragHandle.className = "drag-handle";
    Object.assign(dragHandle.style, {
      position:"absolute", top:"-12px", left:"-12px", width:"32px", height:"32px",
      borderRadius:"50%", backgroundColor:"rgba(0,0,0,0.8)", cursor:"move",
      display:"flex", alignItems:"center", justifyContent:"center", zIndex:"1000000"
    });
    dragHandle.innerHTML = '<svg width="20" height="20" viewBox="0 0 24 24"><path d="M12 2 L12 22 M2 12 L22 12" stroke="white" stroke-width="2" stroke-linecap="round"/></svg>';
    dragHandle.addEventListener("mousedown", startDrag);
    keyboardContainer.appendChild(dragHandle);
  }
  function removeDragHandle(){
    if (!dragHandle) return;
    dragHandle.removeEventListener("mousedown", startDrag);
    dragHandle.remove(); dragHandle = null;
  }
  function startDrag(e){
    isDragging = true;
    const rect = keyboardContainer.getBoundingClientRect();
    dragOffset.x = e.clientX - rect.left;
    dragOffset.y = e.clientY - rect.top;
    document.addEventListener("mousemove", doDrag);
    document.addEventListener("mouseup", stopDrag);
    e.preventDefault();
  }
  function doDrag(e){
    if (!isDragging) return;
    keyboardContainer.style.top = (e.clientY - dragOffset.y) + "px";
    keyboardContainer.style.left = (e.clientX - dragOffset.x) + "px";
    keyboardContainer.style.transform = "";
  }
  function stopDrag(){
    isDragging = false;
    document.removeEventListener("mousemove", doDrag);
    document.removeEventListener("mouseup", stopDrag);
  }

  function showKeyboard(){ if (!keyboardFrame) createKeyboard(); if (shouldShowKeyboard()) keyboardFrame.style.display = "block"; }
  function hideKeyboard(){ if (keyboardFrame) keyboardFrame.style.display = "none"; }
  function shouldShowKeyboard(){ if (currentVisibility === "alwayson") return true; if (currentVisibility === "alwaysoff") return false; return true; }

  chrome.storage.onChanged.addListener((changes, area) => {
    if (area !== "local") return;
    if (changes.oskVisibility) {
      const v = changes.oskVisibility.newValue;
      if (v !== currentVisibility) { currentVisibility = v; if (v === "alwayson") showKeyboard(); else if (v === "alwaysoff") hideKeyboard(); }
    }
if (changes.oskLang) {
  const l = changes.oskLang.newValue;
  if (l !== currentLang) {
    currentLang = l;

    updateKeyboardSize(); 

  if (keyboardFrame) {
  keyboardFrame.src = chrome.runtime.getURL(`keyboard-${currentLang}.html`);
  keyboardFrame.addEventListener(
    "load",
    () => {
      updateKeyboardSize();      
      applyKeyboardTheme(currentTheme);
    },
    { once: true }
  );
}

  }
}

    if (changes.oskTheme) {
      const t = changes.oskTheme.newValue;
      if (t !== currentTheme) { currentTheme = t; applyKeyboardTheme(currentTheme); }
    }
    if (changes.oskPosition) {
      const p = changes.oskPosition.newValue;
      if (p !== currentPosition) { currentPosition = p; updateKeyboardPosition(); if (p === "drag") createDragHandle(); else removeDragHandle(); }
    }
  });

  function applyKeyboardTheme(theme){
    try { keyboardFrame?.contentWindow?.postMessage({ type: "setTheme", theme }, "*"); } catch {}
  }
})();
