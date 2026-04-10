;(function(){
  if (window.__oskInjected) return; window.__oskInjected = true;

  let lastFocused = null, lastCaretPos = 0;
  let bsArmTO = null, bsInt = null, bsRepeating = false;

  function stopBS(){ bsRepeating=false; clearTimeout(bsArmTO); clearInterval(bsInt); }
  ['blur','pagehide','unload'].forEach(ev=>window.addEventListener(ev, stopBS));
  document.addEventListener('visibilitychange', ()=>{ if (document.hidden) stopBS(); });
  document.addEventListener('keydown', e=>{ if (e.key!=='Backspace') stopBS(); }, true);
function keyWithFallback(el, key, fallback) {
  const code = key === 'Enter' ? 'Enter' : key; 
  const kd = new KeyboardEvent('keydown', { key, code, keyCode: key === 'Enter' ? 13 : 8,
    which: key === 'Enter' ? 13 : 8, bubbles: true, cancelable: true, composed: true });
  const proceed = el.dispatchEvent(kd); 

  if (proceed && typeof fallback === 'function') fallback();

  const ku = new KeyboardEvent('keyup', { key, code, keyCode: kd.keyCode, which: kd.which,
    bubbles: true, cancelable: true, composed: true });
  el.dispatchEvent(ku);
}

  function deepActive(){ let a=document.activeElement; while(a&&a.shadowRoot&&a.shadowRoot.activeElement) a=a.shadowRoot.activeElement; return a; }
  function isTextLike(el){
    if(!el) return false;
    if(el.isContentEditable||el.tagName==='TEXTAREA') return true;
    if(el.getAttribute?.('role')==='textbox') return true;
    if(el.tagName==='INPUT'){
      const t=(el.type||'text').toLowerCase();
      if(/^(text|password|search|email|tel|url|number|one-time-code|otp)$/i.test(t)) return true;
      if(el.autocomplete==='one-time-code') return true;
      if(el.inputMode||el.getAttribute('inputmode')) return true;
    }
    return false;
  }

  document.addEventListener('focusin', e=>{
    const t=(e.composedPath?.()[0])||e.target;
    if(isTextLike(t)){
      stopBS();
      lastFocused=t;
      if('selectionEnd'in t&&typeof t.selectionEnd==='number') lastCaretPos=t.selectionEnd;
      else if('value'in t&&typeof t.value==='string') lastCaretPos=t.value.length;
    }
  },true);

  document.addEventListener('selectionchange', ()=>{
    const a=deepActive();
    if(a&&isTextLike(a)&&typeof a.selectionEnd==='number') lastCaretPos=a.selectionEnd;
  },true);
  const syncPos=()=>{
    const a=deepActive();
    if(a&&isTextLike(a)){
      if('selectionEnd'in a&&typeof a.selectionEnd==='number') lastCaretPos=a.selectionEnd;
      else if('value'in a&&typeof a.value==='string') lastCaretPos=a.value.length;
    }
  };
  document.addEventListener('input',syncPos,true);
  document.addEventListener('change',syncPos,true);

  function currentEl(){ const a=deepActive(); return isTextLike(a)?a:lastFocused; }

  const setInputValue=(el,val)=>{ try{
      const proto=el.tagName==='TEXTAREA'?TextAreaElement.prototype:HTMLInputElement.prototype;
      const d=Object.getOwnPropertyDescriptor(proto,'value'); d?.set? d.set.call(el,val): el.value=val;
    }catch{ el.value=val; } };
  const beforeInput=(el,type,data=null)=>{ try{ el.dispatchEvent(new InputEvent('beforeinput',{inputType:type,data,bubbles:true,cancelable:true,composed:true})); }catch{} };
  const fireInput=el=>{ el.dispatchEvent(new Event('input',{bubbles:true,cancelable:true,composed:true})); };
  const getValue=el=> el.isContentEditable? (el.textContent||'') : (el.value||'');
  const setSel=(el,pos)=>{ try{ el.setSelectionRange(pos,pos);}catch{} lastCaretPos=pos; };

  const seg=(typeof Intl!=='undefined'&&Intl.Segmenter)? new Intl.Segmenter(undefined,{granularity:'grapheme'}) : null;
  function prevGraphemeIndex(str,i){
    if(!str) return Math.max(0,i-1);
    if(seg){ let last=0; for(const s of seg.segment(str.slice(0,i))) last=s.index; return last; }
    const p=str.codePointAt(i-1); return p&&p>0xFFFF? i-2: i-1;
  }

  function fireKey(type,key,{ctrl=false,shift=false}={}){
    const keyCode=key==='Tab'?9:key==='Enter'?13:key==='Backspace'?8:key===' '?32:key.charCodeAt(0);
    const code=/^[a-zA-Z]$/.test(key)?('Key'+key.toUpperCase()):(key===' ' ? 'Space' : key);
    const evt=new KeyboardEvent(type,{key,code,keyCode,which:keyCode,ctrlKey:ctrl,shiftKey:shift,bubbles:true,cancelable:true,composed:true});
    const el=currentEl(); el&&el.dispatchEvent(evt);
  }
  const canSelect=el=> typeof el.selectionStart==='number'&&typeof el.selectionEnd==='number';

  function insertText(el,text){
    if(el.isContentEditable){ beforeInput(el,'insertText',text); document.execCommand('insertText',false,text); fireInput(el); return; }
    const v=getValue(el);
    if(canSelect(el)){ const s=el.selectionStart,e=el.selectionEnd; beforeInput(el,'insertText',text);
      setInputValue(el, v.slice(0,s)+text+v.slice(e)); setSel(el,s+text.length); fireInput(el); return; }
    beforeInput(el,'insertText',text); setInputValue(el,v+text); fireInput(el);
  }
  function backspaceText(el){
    if(el.isContentEditable){ beforeInput(el,'deleteContentBackward'); document.execCommand('delete',false,null); fireInput(el); return; }
    const v=getValue(el); if(!v){ beforeInput(el,'deleteContentBackward'); fireInput(el); return; }
    if(canSelect(el)){
      const s=el.selectionStart,e=el.selectionEnd; const from=(s===e)? prevGraphemeIndex(v,s): s;
      beforeInput(el,'deleteContentBackward'); setInputValue(el, v.slice(0,from)+v.slice(e)); setSel(el,from); fireInput(el); return;
    }
    const cut=prevGraphemeIndex(v,v.length); beforeInput(el,'deleteContentBackward'); setInputValue(el,v.slice(0,cut)); fireInput(el);
  }

  function isVisible(n){ const r=n.getBoundingClientRect(); return r.width>0&&r.height>0&&getComputedStyle(n).visibility!=='hidden'; }
  function nextFocusable(start,back=false){
    const sel='input,select,textarea,button,a[href],[tabindex]:not([tabindex="-1"])';
    const list=[...document.querySelectorAll(sel)].filter(n=>!n.disabled&&isVisible(n));
    const i=list.indexOf(start); if(i<0||!list.length) return null;
    return list[(i+(back?-1:1)+list.length)%list.length];
  }
  function clickVisible(sel,root=document){ const el=root.querySelector(sel); if(!el) return false; const r=el.getBoundingClientRect(); if(!r.width||!r.height) return false; el.click(); return true; }
  function trySubmit(el){
    const form=el.closest?.('form');
    const sub=form?.querySelector?.('button[type=submit],input[type=submit],#idSIButton9');
    if(form?.requestSubmit && sub){ form.requestSubmit(sub); return true; }
    if(sub?.click){ sub.click(); return true; }
    return clickVisible('#idSIButton9') ||
           clickVisible('button[data-report-event*="Signin_Submit"]') ||
           clickVisible('button[aria-label*="Weiter"],button[aria-label*="Next"]');
  }

  document.addEventListener('pointerdown', e=>{
    const p=e.composedPath?.()||[]; if(p.find(n=>n&&n.id==='osk-root')){ e.preventDefault(); e.stopPropagation(); currentEl()?.focus({preventScroll:true}); }
  }, true);
  document.addEventListener('mousedown', e=>{
    const p=e.composedPath?.()||[]; if(p.find(n=>n&&n.id==='osk-root')){ e.preventDefault(); e.stopPropagation(); currentEl()?.focus({preventScroll:true}); }
  }, true);

  window.addEventListener('message', e=>{
    const d=e.data; if(!d||d.type!=='keyboard-ui') return;
    const key=d.key, ctrl=!!d.ctrl, shift=!!d.shift, state=d.state;
    const el=currentEl(); if(!el) return;

    if(key!=='Backspace') stopBS();

    if(key==='Copy'){ try{ document.execCommand?.('copy'); }catch{} return; }
    if(key==='Paste'){ try{
      if(navigator.clipboard?.readText) navigator.clipboard.readText().then(t=>insertText(el,t)).catch(()=>{});
      else if(el.isContentEditable) document.execCommand?.('paste');
    }catch{} return; }

    el.focus({preventScroll:true});
    if('setSelectionRange'in el&&typeof lastCaretPos==='number'){ try{ el.setSelectionRange(lastCaretPos,lastCaretPos);}catch{} }

    if(key==='Tab'){ ['keydown','keypress','keyup'].forEach(t=>fireKey(t,'Tab',{ctrl,shift})); nextFocusable(el,shift)?.focus({preventScroll:true}); return; }

if (key === 'Enter') {
  setInputValue(el, getValue(el));
  try {
    el.dispatchEvent(new InputEvent('beforeinput', {inputType:'insertLineBreak', bubbles:true, cancelable:true, composed:true}));
  } catch {}
  el.dispatchEvent(new Event('input',  {bubbles:true, cancelable:true, composed:true}));
  el.dispatchEvent(new Event('change', {bubbles:true, cancelable:true, composed:true}));

  if (el.isContentEditable || el.tagName === 'TEXTAREA') {
    const proceed = el.dispatchEvent(new KeyboardEvent('keydown',  {key:'Enter',code:'Enter',keyCode:13,which:13,bubbles:true,cancelable:true,composed:true}));
    if (proceed) { try { document.execCommand('insertLineBreak'); } catch {} }
    el.dispatchEvent(new KeyboardEvent('keyup', {key:'Enter',code:'Enter',keyCode:13,which:13,bubbles:true,cancelable:true,composed:true}));
    return;
  }

  const kd = new KeyboardEvent('keydown',  {key:'Enter',code:'Enter',keyCode:13,which:13,bubbles:true,cancelable:true,composed:true});
  const proceed = el.dispatchEvent(kd);
  el.dispatchEvent(new KeyboardEvent('keypress',{key:'Enter',code:'Enter',keyCode:13,which:13,bubbles:true,cancelable:true,composed:true}));
  document.dispatchEvent(new KeyboardEvent('keydown',  {key:'Enter',code:'Enter',keyCode:13,which:13,bubbles:true,cancelable:true,composed:true}));
  document.dispatchEvent(new KeyboardEvent('keypress', {key:'Enter',code:'Enter',keyCode:13,which:13,bubbles:true,cancelable:true,composed:true}));
  window.dispatchEvent(new KeyboardEvent('keydown',    {key:'Enter',code:'Enter',keyCode:13,which:13,bubbles:true,cancelable:true,composed:true}));
  window.dispatchEvent(new KeyboardEvent('keypress',   {key:'Enter',code:'Enter',keyCode:13,which:13,bubbles:true,cancelable:true,composed:true}));
  el.dispatchEvent(new KeyboardEvent('keyup',          {key:'Enter',code:'Enter',keyCode:13,which:13,bubbles:true,cancelable:true,composed:true}));
  document.dispatchEvent(new KeyboardEvent('keyup',    {key:'Enter',code:'Enter',keyCode:13,which:13,bubbles:true,cancelable:true,composed:true}));
  window.dispatchEvent(new KeyboardEvent('keyup',      {key:'Enter',code:'Enter',keyCode:13,which:13,bubbles:true,cancelable:true,composed:true}));

  if (proceed) {
    const form = el.closest && el.closest('form');
    if (form && typeof form.requestSubmit === 'function') {
      const submitter = form.querySelector('button[type=submit],input[type=submit]');
      setTimeout(() => { try { form.requestSubmit(submitter || undefined); } catch {} }, 0);
      return;
    }
    const clicked =
      clickVisible('button[type=submit],input[type=submit]') ||
      clickVisible('button[aria-label*="Search"],button[title*="Search"]') ||
      clickVisible('button[class*="search"],[data-action*="search"]');
    if (clicked) return;

    el.dispatchEvent(new Event('change', {bubbles:true, cancelable:true, composed:true}));
    try { el.blur(); el.focus({preventScroll:true}); } catch {}
  }
  return;
}


  if (key === 'Backspace') {
  if (state === 'up') { stopBS(); return; }

  const deleteOnce = () => keyWithFallback(el, 'Backspace', () => backspaceText(el));

  if (state === 'down') {
    deleteOnce();
    if (!bsRepeating) {
      bsArmTO = setTimeout(() => {
        bsRepeating = true;
        bsInt = setInterval(() => {
          if (bsRepeating) deleteOnce();
        }, 50);
      }, 220);
    }
    return;
  }

  deleteOnce();
  return;
}

    if(key===' '){
      const ok=el.isContentEditable||el.tagName==='TEXTAREA'||(el.tagName==='INPUT'&&/^(text|password|search|email|tel|url)$/i.test(el.type||'text'));
      if(!ok) return;
      fireKey('keydown',' ',{}); fireKey('keypress',' ',{}); insertText(el,' '); fireKey('keyup',' ',{}); return;
    }

    if(typeof key==='string'&&key.length===1){
      fireKey('keydown',key,{ctrl,shift}); fireKey('keypress',key,{ctrl,shift}); insertText(el,key); fireKey('keyup',key,{ctrl,shift}); return;
    }

    ['keydown','keypress','keyup'].forEach(t=>fireKey(t,key,{ctrl,shift}));
  });
})();
