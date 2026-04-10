document.addEventListener("DOMContentLoaded", () => {

  const themeSelect      = document.getElementById("themeSelect");
  const langSelect       = document.getElementById("langSelect");
  const visibilitySelect = document.getElementById("visibilitySelect");
  const positionSelect   = document.getElementById("positionSelect");
  const layoutSelect     = document.getElementById("layoutSelect");

  const languagesDefault = [
    { code: "de", name: "Deutsch" },
    { code: "en", name: "English" },
    { code: "fr", name: "Français" },
    { code: "ru", name: "Русский" },
    { code: "ar", name: "العربية" }
  ];

  const languagesNumpad = [
    { code: "numpad", name: "Numpad" }
  ];

  // version for popup
  const el = document.getElementById("version");
  if (!el) return;

  const v = chrome.runtime.getManifest().version; 
  el.textContent = `Version ${v}`;


  function populateLanguages(list, selected) {
    langSelect.innerHTML = "";

    list.forEach(({ code, name }) => {
      const opt = document.createElement("option");
      opt.value = code;
      opt.textContent = name;
      langSelect.appendChild(opt);
    });

    langSelect.value = selected || list[0].code;
  }

  chrome.storage.local.get(
    ["oskTheme", "oskLayout", "oskLang", "oskVisibility", "oskPosition"],
    res => {

      // Theme
      const theme = res.oskTheme || "light";
      themeSelect.value = theme;
      applyPopupTheme(theme);
      chrome.storage.local.set({ oskTheme: theme });

      // Layout
      const layout = res.oskLayout || "default";
      layoutSelect.value = layout;
      chrome.storage.local.set({ oskLayout: layout });

      // Language abhängig vom Layout
      if (layout === "numpad") {
        populateLanguages(languagesNumpad, "numpad");
        chrome.storage.local.set({ oskLang: "numpad" });
      } else {
        populateLanguages(languagesDefault, res.oskLang);
        chrome.storage.local.set({ oskLang: langSelect.value });
      }

      // Visibility
      visibilitySelect.value = res.oskVisibility || "alwayson";
      chrome.storage.local.set({ oskVisibility: visibilitySelect.value });

      // Position
      positionSelect.value = res.oskPosition || "bottom-center";
      chrome.storage.local.set({ oskPosition: positionSelect.value });
    }
  );

  themeSelect.addEventListener("change", () => {
    const t = themeSelect.value;
    chrome.storage.local.set({ oskTheme: t });
    applyPopupTheme(t);
  });

  layoutSelect.addEventListener("change", () => {
    const layout = layoutSelect.value;
    chrome.storage.local.set({ oskLayout: layout });

    if (layout === "numpad") {
      populateLanguages(languagesNumpad, "numpad");
      chrome.storage.local.set({ oskLang: "numpad" });
    } else {
      populateLanguages(languagesDefault);
      chrome.storage.local.set({ oskLang: langSelect.value });
    }
  });

  langSelect.addEventListener("change", () => {
    chrome.storage.local.set({ oskLang: langSelect.value });
  });

  visibilitySelect.addEventListener("change", () => {
    chrome.storage.local.set({ oskVisibility: visibilitySelect.value });
  });

  positionSelect.addEventListener("change", () => {
    chrome.storage.local.set({ oskPosition: positionSelect.value });
  });
});

function applyPopupTheme(theme) {
  if (theme === "dark") {
    document.body.classList.add("dark-mode");
  } else {
    document.body.classList.remove("dark-mode");
  }
}
