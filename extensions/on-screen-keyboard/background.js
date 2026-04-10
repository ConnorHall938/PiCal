chrome.runtime.onInstalled.addListener(() => {
  console.log("Kiosk Keyboard installed.");
});

chrome.runtime.onMessage.addListener((msg, sender) => {
  if (msg.cmd === 'injectPageScript' && sender.tab?.id) {
    chrome.scripting.executeScript({
      target: { tabId: sender.tab.id, allFrames: true },
      files: ['inject.js'],
      world: 'MAIN'
    });
  }
});

