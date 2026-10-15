// Easy Pay, Safe Pay: screens, state and the bridge to Android.
// window.AndroidBridge exists inside the app; in a desktop browser the app falls back to practice-friendly stand-ins.

const NB = window.AndroidBridge || null;

// Practice data (no real UPI connection)
const DEMO_SAVED = [
  { id: 'raju.kirana@okaxis', name: 'Raju Kirana Store', usual: 500, ico: 'shop' },
  { id: 'meena.r@oksbi', name: 'Meena Rao (daughter)', usual: 2000, ico: 'person' },
  { id: 'bescom.bill@ybl', name: 'BESCOM Electricity', usual: 1500, ico: 'bolt' }
];
const DEMO_DIR = {
  'sharma.tailor@okicici': 'Sharma Tailors',
  'sbi.kyc.help@ybl': 'Rahul Traders',
  'lottery.kbc@paytm': 'Prize Desk Services'
};
const DEMO_QR = 'upi://pay?pa=raju.kirana@okaxis&pn=Raju%20Kirana%20Store&mc=5411';
const SCAM_REQ = { id: 'sbi.kyc.help@ybl', shown: 'SBI Refund Desk', name: 'Rahul Traders', amount: 15000,
  note: 'KYC refund approved. Enter UPI PIN to RECEIVE ₹15,000. Do it in 10 minutes or account will be blocked.' };
const QUESTIONS = ['caller', 'urgency', 'prize', 'remote'];
const UPI_MAX = 100000;

const ICONS = {
  qr: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 4h6v6H4zM14 4h6v6h-6zM4 14h6v6H4zM14 14h2v2h-2zM18 18h2v2h-2zM14 18h2M18 14h2"/></svg>',
  send: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12h14M13 6l6 6-6 6"/></svg>',
  inbox: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 4v10M7 9l5 5 5-5M4 18h16"/></svg>',
  msg: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 5h16v11H9l-5 4z"/><path d="M12 8v3M12 13.5h.01"/></svg>',
  shield: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z"/><path d="M12 8v5M12 16h.01"/></svg>',
  people: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="9" cy="8" r="3.5"/><path d="M2.5 20c.8-3.5 3.4-5.5 6.5-5.5s5.7 2 6.5 5.5"/><path d="M16 4.5a3.5 3.5 0 0 1 0 7M18 14.8c1.8.8 3 2.6 3.5 5.2"/></svg>',
  gear: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="3"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3M4.9 4.9l2.1 2.1M17 17l2.1 2.1M4.9 19.1L7 17M17 7l2.1-2.1"/></svg>',
  shop: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 9l1.5-5h13L20 9M4 9h16v11H4zM9 20v-6h6v6"/></svg>',
  person: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="8" r="4"/><path d="M4 21c1-4 4.2-6 8-6s7 2 8 6"/></svg>',
  bolt: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M13 2L4 14h7l-1 8 9-12h-7z"/></svg>',
  plus: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M12 5v14M5 12h14"/></svg>',
  play: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M7 5l12 7-12 7z"/></svg>',
  ok: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><path d="M7.5 12.5l3 3 6-6.5"/></svg>',
  warn: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3l10 18H2z"/><path d="M12 10v4M12 17.5h.01"/></svg>',
  stop: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M8 2h8l6 6v8l-6 6H8l-6-6V8z"/><path d="M8 12h8"/></svg>',
  clock: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/></svg>'
};

// ---- state ----
const DEFAULTS = { lang: 'en', voice: false, mode: 'practice', size: 'normal', contact: { name: 'Meena', phone: '9876543210', limit: 5000 }, payees: [] };
let S = (() => {
  try { const v = JSON.parse(localStorage.getItem('easypay') || 'null'); return v ? Object.assign({}, JSON.parse(JSON.stringify(DEFAULTS)), v) : JSON.parse(JSON.stringify(DEFAULTS)); }
  catch (e) { return JSON.parse(JSON.stringify(DEFAULTS)); }
})();
function persist() { try { localStorage.setItem('easypay', JSON.stringify(S)); } catch (e) {} }
let F = {};            // the payment in progress
let stack = ['home'];
let timer = null;
let flash = '';
let listening = false;
const real = () => S.mode === 'real';
const savedList = () => real() ? S.payees : DEMO_SAVED;

const esc = s => String(s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
function t(k, v) { let s = (T[S.lang] && T[S.lang][k]) || T.en[k] || k; if (v) for (const x in v) s = s.split('{' + x + '}').join(v[x]); return s; }
const rupee = n => '₹' + Number(n).toLocaleString('en-IN');
const strip = html => html.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim();
const phoneDigits = () => String(S.contact.phone || '').replace(/\D/g, '').slice(-10);

function progress(n) {
  return `<div class="step">${esc(t('step', { n, t: 4 }))}</div><div class="progress" aria-hidden="true">${[1, 2, 3, 4].map(i => `<i class="${i <= n ? 'on' : ''}"></i>`).join('')}</div>`;
}
function nav(showBack = true) {
  return `<div class="navrow">${showBack ? `<button class="btn" data-act="back">← ${esc(t('back'))}</button>` : ''}<button class="btn" data-act="home">${esc(t('home'))}</button></div>`;
}
function listenBtn() { return `<button class="chip" data-act="speak">🔊 ${esc(t('listen'))}</button>`; }
function micBtn(target) { return canListen() ? `<button class="chip ${listening ? 'listening' : ''}" data-act="mic" data-v="${target}">🎤 ${esc(listening ? t('listening') : t('speakBtn'))}</button>` : ''; }
function title(text, extra = '') { return `<div class="titlerow"><h2>${esc(text)}</h2><div class="tools">${extra}${listenBtn()}</div></div>`; }
function flashHtml(cls = 'err') { return flash ? `<p class="${cls}" role="alert">${esc(flash)}</p>` : ''; }
function payeeIcon(p) { return ICONS[p.ico] || ICONS.person; }

// ---- screens: each returns {html, say} ----
const SCREENS = {
  home() {
    return { say: t('hello') + '. ' + t('scanQr') + '. ' + t('sendMoney') + '. ' + t('gotRequest') + '. ' + t('checkMsg') + '. ' + t('report') + '.', html: `
    <div class="card">
      ${title(t('hello'))}
      <div class="stack">
        <button class="btn hero" data-act="scan"><span class="ico">${ICONS.qr}</span><span>${esc(t('scanQr'))}<small>${esc(t('scanQrSub'))}</small></span></button>
        <button class="btn" data-act="startSend" id="b-send"><span class="ico">${ICONS.send}</span><span>${esc(t('sendMoney'))}<small>${esc(t('sendMoneySub'))}</small></span></button>
        <button class="btn" data-act="startRequest" id="b-req"><span class="ico">${ICONS.inbox}</span><span>${esc(t('gotRequest'))}<small>${esc(t('gotRequestSub'))}</small></span></button>
        <button class="btn" data-act="go" data-v="message"><span class="ico">${ICONS.msg}</span><span>${esc(t('checkMsg'))}<small>${esc(t('checkMsgSub'))}</small></span></button>
        <button class="btn" data-act="go" data-v="report" id="b-report"><span class="ico bad">${ICONS.shield}</span><span>${esc(t('report'))}<small>${esc(t('reportSub'))}</small></span></button>
        <button class="btn" data-act="go" data-v="family" id="b-family"><span class="ico">${ICONS.people}</span><span>${esc(t('family'))}: ${esc(S.contact.name)}<small>${esc(t('familySub'))}</small></span></button>
        <button class="btn" data-act="go" data-v="settings"><span class="ico">${ICONS.gear}</span><span>${esc(t('settings'))}<small>${esc(t('settingsSub'))}</small></span></button>
      </div>
      ${real() ? '' : `
      <div class="section-label">${esc(t('stories'))}</div>
      <div class="stack">
        <button class="btn" data-act="story1"><span class="ico">${ICONS.play}</span><span>${esc(t('story1'))}<small>${esc(t('story1Sub'))}</small></span></button>
        <button class="btn" data-act="story2"><span class="ico bad">${ICONS.play}</span><span>${esc(t('story2'))}<small>${esc(t('story2Sub'))}</small></span></button>
      </div>`}
    </div>` };
  },
  payee() {
    const list = savedList();
    return { say: t('whoPay'), html: `
    <div class="card">${progress(1)}
      ${title(t('whoPay'))}
      <button class="btn hero" data-act="scan"><span class="ico">${ICONS.qr}</span><span>${esc(t('scanQr'))}</span></button>
      <div class="section-label">${esc(t('savedPeople'))}</div>
      <div class="stack">${list.length ? list.map((p, i) => `<button class="btn" data-act="pickSaved" data-v="${i}"><span class="ico">${payeeIcon(p)}</span><span>${esc(p.name)}<small>${esc(p.id)}</small></span></button>`).join('') : `<p class="muted">${esc(t('noSaved'))}</p>`}
        <button class="btn" data-act="go" data-v="newPayee"><span class="ico">${ICONS.plus}</span><span>${esc(t('someoneNew'))}<small>${esc(t('someoneNewSub'))}</small></span></button>
      </div>
      ${flashHtml()}
    </div>${nav()}` };
  },
  newPayee() {
    const examples = ['sharma.tailor@okicici', 'lottery.kbc@paytm'];
    return { say: t('enterUpi') + '. ' + t('upiHint'), html: `
    <div class="card">${progress(1)}
      ${title(t('enterUpi'))}
      <div><label for="upi">${esc(t('upiLabel'))}</label><input type="text" id="upi" autocomplete="off" autocapitalize="off" spellcheck="false" placeholder="name@bank" value="${esc(F.upiDraft || '')}"></div>
      <p class="muted">${esc(t('upiHint'))} ${real() ? '' : esc(t('upiHintPractice'))}</p>
      ${real() ? '' : `<div class="tools">${examples.map(e => `<button class="chip" data-act="fillUpi" data-v="${e}">${e}</button>`).join('')}</div>`}
      ${flashHtml()}
      <button class="btn primary" data-act="submitUpi">${esc(t('next'))} →</button>
    </div>${nav()}` };
  },
  nameCheck() {
    const p = F.payee;
    const known = !!p.name && p.name !== p.id;
    const label = p.fromQr ? t('qrName') : t('bankName');
    return { say: t('nameCheck') + '. ' + (known ? label + ' ' + p.name : t('noNameYet')) + (real() ? '. ' + t('realNameNote') : ''), html: `
    <div class="card">${progress(1)}
      ${title(t('nameCheck'))}
      ${known ? `<p class="muted">${esc(label)}:</p><p class="big-name">${esc(p.name)}</p>` : `<p class="muted">${esc(t('noNameYet'))}</p>`}
      <p class="muted">${esc(p.id)}</p>
      ${real() ? `<p class="msgbox">${esc(t('realNameNote'))}</p>` : ''}
      ${real() && !known ? `<div><label for="nick">${esc(t('nickLabel'))}</label><input type="text" id="nick" autocomplete="off"></div>` : ''}
      <div class="stack">
        <button class="btn primary" data-act="nameOk" data-v="1">${esc(t('yesRight'))}</button>
        <button class="btn center" data-act="nameOk" data-v="0">${esc(t('noWrong'))}</button>
      </div>
    </div>${nav()}` };
  },
  amount() {
    const a = F.amount || '';
    return { say: t('howMuch') + ' ' + t('to') + ' ' + F.payee.name, html: `
    <div class="card">${progress(2)}
      ${title(t('howMuch'), micBtn('amount'))}
      <p><span class="muted">${esc(t('to'))}:</span> <strong>${esc(F.payee.name)}</strong></p>
      <input type="tel" inputmode="numeric" id="amt" class="amount-in" placeholder="₹ 0" value="${esc(a)}" maxlength="6" aria-label="Amount in rupees">
      <p class="words" id="words">${esc(wordsFor(a))}</p>
      <div class="quick">${[100, 200, 500, 1000].map(v => `<button class="chip" data-act="quickAmt" data-v="${v}">₹${v}</button>`).join('')}</div>
      ${flashHtml()}
      <button class="btn primary" data-act="submitAmt">${esc(t('next'))} →</button>
    </div>${nav()}` };
  },
  question() {
    const i = F.qi || 0, key = QUESTIONS[i];
    return { say: t('qTitle') + '. ' + t('q_' + key), html: `
    <div class="card">${progress(3)}
      <div class="titlerow"><span class="step">${esc(t('qTitle'))} · ${i + 1} / ${QUESTIONS.length}</span><div class="tools">${micBtn('yesno')}${listenBtn()}</div></div>
      ${i === 0 ? `<p class="muted">${esc(t('qIntro'))}</p>` : ''}
      <h2>${esc(t('q_' + key))}</h2>
      <div class="yesno">
        <button class="btn" data-act="answer" data-v="1">${esc(t('yes'))}</button>
        <button class="btn" data-act="answer" data-v="0">${esc(t('no'))}</button>
      </div>
      ${flashHtml()}
    </div>${nav()}` };
  },
  result() {
    const r = F.result, lv = r.level;
    const reasons = r.reasons.slice(0, 3).map(id => t('r_' + id, { name: F.payee.name, limit: rupee(S.contact.limit) }));
    const icon = lv === 'green' ? ICONS.ok : lv === 'amber' ? ICONS.warn : ICONS.stop;
    const fam = esc(t('askFamily', { name: S.contact.name }));
    const next = F.collect && real() ? 'reqDone' : 'confirm';
    let actions;
    if (lv === 'green') actions = `<button class="btn primary" data-act="go" data-v="${next}">${esc(t('continuePay'))} →</button><button class="btn center" data-act="stop">${esc(t('cancel'))}</button>`;
    else if (lv === 'amber') actions = `<button class="btn primary" data-act="go" data-v="alert">${fam}</button><button class="btn center" data-act="go" data-v="${next}">${esc(t('continuePay'))}</button><button class="btn center" data-act="stop">${esc(t('cancel'))}</button>`;
    else actions = `<button class="btn danger" data-act="stop">${esc(t('cancel'))}</button><button class="btn center" data-act="go" data-v="alert">${fam}</button><button class="btn center" data-act="go" data-v="report">${esc(t('reportBtn'))}</button><button class="btn center" id="anyway" data-act="go" data-v="alert" disabled>${esc(t('waitSec', { s: 30 }))}</button>`;
    return { say: t('lv_' + lv) + '. ' + (reasons.length ? reasons.join(' ') : t('greenMsg')), html: `
    <div class="card">${progress(3)}
      <div class="verdict ${lv}" role="alert">
        <h2>${icon}<span>${esc(t('lv_' + lv))}</span></h2>
        ${reasons.length ? `<ul>${reasons.map(x => `<li>${esc(x)}</li>`).join('')}</ul>` : `<p style="font-weight:600">${esc(t('greenMsg'))}</p>`}
        <div>${listenBtn()}</div>
      </div>
      <dl class="summary"><dt>${esc(t('to'))}</dt><dd>${esc(F.payee.name)}</dd><dt>${esc(t('amountLabel'))}</dt><dd>${rupee(F.amount)}</dd></dl>
      <div class="stack">${actions}</div>
    </div>` };
  },
  alert() {
    const c = S.contact;
    const msg = t('alertMsg', { name: c.name, amt: rupee(F.amount), payee: F.payee.name, level: t('lv_' + F.result.level) });
    const wa = 'https://wa.me/91' + phoneDigits() + '?text=' + encodeURIComponent(msg);
    const next = F.collect && real() ? 'reqDone' : 'confirm';
    return { say: t('alertTitle', { name: c.name }) + '. ' + t('alertIntro', { name: c.name }), html: `
    <div class="card">
      ${title(t('alertTitle', { name: c.name }))}
      <p>${esc(t('alertIntro', { name: c.name }))}</p>
      <div class="msgbox" id="msgtext">${esc(msg)}</div>
      <div class="stack">
        <a class="btn primary" href="tel:${esc(phoneDigits())}">📞 ${esc(t('callName', { name: c.name }))}</a>
        <a class="btn center" href="${esc(wa)}" target="_blank" rel="noopener">${esc(t('whatsapp'))}</a>
        <button class="btn center" data-act="copy" data-v="${esc(msg)}">${esc(t('copyMsg'))}</button>
        <p class="muted">${esc(t('whatsappNote'))}</p>
        <button class="btn danger" data-act="stop">${esc(t('talkedStop'))}</button>
        <button class="btn center" data-act="go" data-v="${next}">${esc(t('talkedOk'))}</button>
      </div>
    </div>${nav()}` };
  },
  confirm() {
    const w = S.lang === 'en' ? toWordsIN(F.amount) + ' rupees' : rupee(F.amount) + ' ' + t('rupees');
    const payBtn = real()
      ? `<p class="msgbox">${esc(t('payInAppNote'))}</p><button class="btn primary" data-act="payReal">${esc(t('payInApp'))} →</button>`
      : `<button class="btn primary" data-act="go" data-v="pin">${esc(t('pay'))} →</button>`;
    return { say: t('confirmTitle') + '. ' + t('youSend') + ' ' + w + ' ' + t('to') + ' ' + F.payee.name + (real() ? '. ' + t('payInAppNote') : ''), html: `
    <div class="card">${progress(4)}
      ${title(t('confirmTitle'))}
      <p class="muted">${esc(t('youSend'))}</p>
      <p class="big-amt">${rupee(F.amount)}</p>
      <p class="words">${esc(w)}</p>
      <dl class="summary"><dt>${esc(t('to'))}</dt><dd>${esc(F.payee.name)}</dd><dt>${esc(t('upiLabel'))}</dt><dd>${esc(F.payee.id)}</dd></dl>
      ${flashHtml()}
      ${payBtn}
      <button class="btn center" data-act="stop">${esc(t('cancel'))}</button>
    </div>${nav()}` };
  },
  pin() {
    const n = (F.pin || '').length;
    return { say: t('enterPin') + '. ' + t('pinNote'), html: `
    <div class="card">${progress(4)}
      ${title(t('enterPin'))}
      <p class="muted">${esc(t('pinNote'))}</p>
      <div class="pin-dots" aria-label="${n} of 4">${[0, 1, 2, 3].map(i => `<i class="${i < n ? 'on' : ''}"></i>`).join('')}</div>
      <div class="keypad">${[1, 2, 3, 4, 5, 6, 7, 8, 9].map(d => `<button data-act="pinKey" data-v="${d}">${d}</button>`).join('')}<button data-act="pinDel" aria-label="${esc(t('del'))}" style="font-size:1rem">${esc(t('del'))}</button><button data-act="pinKey" data-v="0">0</button><span></span></div>
    </div>${nav()}` };
  },
  done() {
    const st = F.payStatus || 'success';
    const name = F.payee.name;
    const cfg = {
      success: { ico: ICONS.ok, col: 'var(--good)', h: t('paid'), m: t('paidMsg', { amt: rupee(F.amount), name }) },
      failure: { ico: ICONS.stop, col: 'var(--bad)', h: t('res_failure'), m: t('res_failureMsg', { name: S.contact.name }) },
      pending: { ico: ICONS.clock, col: 'var(--warn)', h: t('res_pending'), m: t('res_pendingMsg') },
      unknown: { ico: ICONS.warn, col: 'var(--warn)', h: t('res_unknown'), m: t('res_unknownMsg') }
    }[st];
    return { say: cfg.h + '. ' + cfg.m, html: `
    <div class="card center-text">
      <div class="big-ico" style="color:${cfg.col}">${cfg.ico}</div>
      <h2 style="color:${cfg.col}">${esc(cfg.h)}</h2>
      <p style="font-weight:600">${esc(cfg.m)}</p>
      ${F.txnId ? `<p class="muted">${esc(t('txnId'))}: <strong style="user-select:all">${esc(F.txnId)}</strong></p>` : ''}
      ${real() ? '' : `<p class="muted">${esc(t('practiceNote'))}</p>`}
      <button class="btn primary" data-act="home">${esc(t('doneHome'))}</button>
    </div>` };
  },
  stopped() {
    return { say: t('stopped') + ' ' + t('stoppedMsg'), html: `
    <div class="card center-text">
      <div class="big-ico" style="color:var(--good)">${ICONS.shield}</div>
      <h2 style="color:var(--good)">${esc(t('stopped'))}</h2>
      <p>${esc(t('stoppedMsg'))}</p>
      <button class="btn danger" data-act="go" data-v="report">${esc(t('reportBtn'))}</button>
      <button class="btn primary" data-act="home">${esc(t('doneHome'))}</button>
    </div>` };
  },
  request() {
    if (real()) {
      return { say: t('reqTitle') + '. ' + t('reqWho'), html: `
      <div class="card">${progress(2)}
        ${title(t('reqTitle'))}
        <div><label for="reqwho">${esc(t('reqWho'))}</label><input type="text" id="reqwho" value="${esc(F.reqWho || '')}"></div>
        <div><label for="reqamt">${esc(t('reqAmt'))}</label><input type="tel" inputmode="numeric" id="reqamt" class="amount-in" maxlength="6" value="${esc(F.reqAmt || '')}"></div>
        ${flashHtml()}
        <h2 style="font-size:1.3rem">${esc(t('reqQ'))}</h2>
        <div class="stack">
          <button class="btn center" data-act="reqAnswer" data-v="receive">${esc(t('reqReceive'))}</button>
          <button class="btn center" data-act="reqAnswer" data-v="pay">${esc(t('reqPay'))}</button>
        </div>
      </div>${nav()}` };
    }
    return { say: t('reqTitle') + '. ' + t('reqFrom', { name: SCAM_REQ.shown }) + ' ' + rupee(SCAM_REQ.amount) + '. ' + t('reqQ'), html: `
    <div class="card">${progress(2)}
      ${title(t('reqTitle'))}
      <div class="reqcard">
        <strong>${esc(t('reqFrom', { name: SCAM_REQ.shown }))}</strong>
        <span class="big-amt">${rupee(SCAM_REQ.amount)}</span>
        <span class="muted">${esc(SCAM_REQ.id)}</span>
        <span class="muted">${esc(t('reqNoteLabel'))}:</span>
        <span class="note">“${esc(SCAM_REQ.note)}”</span>
      </div>
      <h2 style="font-size:1.3rem">${esc(t('reqQ'))}</h2>
      <div class="stack">
        <button class="btn center" data-act="reqAnswer" data-v="receive">${esc(t('reqReceive'))}</button>
        <button class="btn center" data-act="reqAnswer" data-v="pay">${esc(t('reqPay'))}</button>
      </div>
    </div>${nav()}` };
  },
  reqDone() {
    return { say: t('reqSafe'), html: `
    <div class="card center-text">
      <div class="big-ico" style="color:var(--warn)">${ICONS.warn}</div>
      <p style="font-weight:600">${esc(t('reqSafe'))}</p>
      <dl class="summary" style="text-align:left"><dt>${esc(t('to'))}</dt><dd>${esc(F.payee.name)}</dd><dt>${esc(t('amountLabel'))}</dt><dd>${rupee(F.amount)}</dd></dl>
      <button class="btn primary" data-act="home">${esc(t('doneHome'))}</button>
    </div>` };
  },
  message() {
    const r = F.msgResult;
    let res = '';
    if (r) {
      const lv = r.level;
      const icon = lv === 'green' ? ICONS.ok : lv === 'amber' ? ICONS.warn : ICONS.stop;
      const reasons = r.reasons.slice(0, 4).map(id => t('s_' + id));
      res = `<div class="verdict ${lv}" role="alert">
        <h2>${icon}<span>${esc(t('m_' + lv))}</span></h2>
        ${reasons.length ? `<ul>${reasons.map(x => `<li>${esc(x)}</li>`).join('')}</ul><p>${esc(t('m_advice'))}</p>` : `<p style="font-weight:600">${esc(t('m_greenMsg'))}</p>`}
        <div>${listenBtn()}</div>
      </div>
      ${lv === 'red' ? `<button class="btn danger" data-act="go" data-v="report">${esc(t('reportBtn'))}</button>` : ''}`;
    }
    const say = r ? t('m_' + r.level) + '. ' + (r.reasons.length ? r.reasons.slice(0, 4).map(id => t('s_' + id)).join(' ') + ' ' + t('m_advice') : t('m_greenMsg'))
                  : t('msgTitle') + '. ' + t('msgIntro');
    return { say, html: `
    <div class="card">
      ${title(t('msgTitle'))}
      <p class="muted">${esc(t('msgIntro'))}</p>
      <button class="btn center" data-act="pasteMsg">📋 ${esc(t('msgPaste'))}</button>
      <textarea id="msgin" placeholder="${esc(t('msgPlaceholder'))}">${esc(F.msgText || '')}</textarea>
      ${flashHtml()}
      <button class="btn primary" data-act="checkMsg">${esc(t('msgCheck'))}</button>
      ${res}
    </div>${nav(false)}` };
  },
  report() {
    const l3 = '<a href="https://cybercrime.gov.in" target="_blank" rel="noopener">cybercrime.gov.in</a>';
    const l4 = '<a href="https://sancharsaathi.gov.in/sfc/" target="_blank" rel="noopener">Sanchar Saathi (Chakshu)</a>';
    const items = [esc(t('rp1')), esc(t('rp2')), esc(t('rp3')).replace('{link}', l3), esc(t('rp4')).replace('{link}', l4), esc(t('rp5'))];
    return { say: t('reportTitle') + '. ' + t('reportIntro') + ' ' + strip(items.join('. ')), html: `
    <div class="card">
      ${title(t('reportTitle'))}
      <p class="helpline">1930</p>
      <a class="btn danger" href="tel:1930">📞 ${esc(t('call1930'))}</a>
      <p style="font-weight:600">${esc(t('reportIntro'))}</p>
      <ol class="steps">${items.map(x => `<li>${x}</li>`).join('')}</ol>
      ${phoneDigits() ? `<a class="btn center" href="tel:${esc(phoneDigits())}">📞 ${esc(t('callName', { name: S.contact.name }))}</a>` : ''}
    </div>${nav()}` };
  },
  family() {
    const c = S.contact;
    return { say: t('familyTitle') + '. ' + t('familyIntro'), html: `
    <div class="card">
      ${title(t('familyTitle'))}
      <p class="muted">${esc(t('familyIntro'))}</p>
      <form id="famform" class="stack">
        <div><label for="fname">${esc(t('fName'))}</label><input type="text" id="fname" value="${esc(c.name)}" required></div>
        <div><label for="fphone">${esc(t('fPhone'))}</label><input type="tel" inputmode="numeric" id="fphone" value="${esc(c.phone)}" required></div>
        <div><label for="flimit">${esc(t('fLimit'))}</label><input type="tel" inputmode="numeric" id="flimit" value="${esc(c.limit)}"></div>
        ${flashHtml('ok-msg')}
        <button class="btn primary" type="submit">${esc(t('save'))}</button>
      </form>
      ${phoneDigits() ? `<a class="btn center" href="tel:${esc(phoneDigits())}">📞 ${esc(t('callName', { name: c.name }))}</a>` : ''}
    </div>${nav()}` };
  },
  settings() {
    const opt = (act, v, on, label) => `<button class="btn" data-act="${act}" data-v="${v}" aria-pressed="${on}"><span class="dot"></span><span>${esc(label)}</span></button>`;
    return { say: t('setTitle'), html: `
    <div class="card">
      ${title(t('setTitle'))}
      <div class="section-label">${esc(t('setMode'))}</div>
      <div class="radio">${opt('setMode', 'practice', !real(), t('modePractice'))}${opt('setMode', 'real', real(), t('modeReal'))}</div>
      <div class="section-label">${esc(t('setText'))}</div>
      <div class="radio">${opt('setSize', 'normal', S.size !== 'big', t('textNormal'))}${opt('setSize', 'big', S.size === 'big', t('textBig'))}</div>
      ${S.payees.length ? `<div class="section-label">${esc(t('setPayees'))}</div>
      <div class="stack">${S.payees.map((p, i) => `<div class="payee-row"><span>${esc(p.name)}<br><small class="muted">${esc(p.id)}</small></span><button class="chip" data-act="removePayee" data-v="${i}">${esc(t('remove'))}</button></div>`).join('')}</div>` : ''}
      <p class="muted">${esc(t('setAbout'))}</p>
    </div>${nav()}` };
  },
  realConfirm() {
    return { say: t('realWarn'), html: `
    <div class="card">
      <div class="verdict amber"><h2>${ICONS.warn}<span>${esc(t('modeReal'))}</span></h2><p style="font-weight:600">${esc(t('realWarn'))}</p></div>
      <button class="btn primary" data-act="confirmReal">${esc(t('turnOn'))}</button>
      <button class="btn center" data-act="back">${esc(t('keepPractice'))}</button>
    </div>` };
  }
};

function wordsFor(a) {
  const n = parseInt(a, 10);
  if (!(n > 0)) return '';
  return S.lang === 'en' ? toWordsIN(n) + ' rupees' : rupee(n) + ' ' + t('rupees');
}

// ---- voice out: Android TextToSpeech in the app, Web Speech in a browser ----
const LOCALE = { en: 'en-IN', hi: 'hi-IN', kn: 'kn-IN' };
let lastSay = '';
function speak(text) {
  if (NB) { try { NB.speak(text, LOCALE[S.lang]); } catch (e) {} return; }
  try {
    if (!('speechSynthesis' in window)) return;
    speechSynthesis.cancel();
    const u = new SpeechSynthesisUtterance(text);
    const code = LOCALE[S.lang];
    u.lang = code; u.rate = 0.85;
    const vs = speechSynthesis.getVoices();
    const v = vs.find(x => x.lang && x.lang.replace('_', '-') === code) || vs.find(x => x.lang && x.lang.startsWith(code.slice(0, 2)));
    if (v) u.voice = v;
    speechSynthesis.speak(u);
  } catch (e) {}
}
function stopSpeaking() { if (NB) { try { NB.stopSpeaking(); } catch (e) {} } else { try { speechSynthesis.cancel(); } catch (e) {} } }

// ---- voice in: Android speech recogniser in the app, webkitSpeechRecognition in Chrome ----
function canListen() { return NB ? NB.canListen() : !!(window.SpeechRecognition || window.webkitSpeechRecognition); }
let micTarget = null;
function startListening(target) {
  micTarget = target; listening = true; stopSpeaking(); render(true);
  if (NB) { NB.listen(LOCALE[S.lang]); return; }
  try {
    const R = new (window.SpeechRecognition || window.webkitSpeechRecognition)();
    R.lang = LOCALE[S.lang]; R.interimResults = false; R.maxAlternatives = 3;
    R.onresult = e => EP.onVoice(Array.from(e.results[0]).map(a => a.transcript).join('|'));
    R.onerror = () => EP.onVoice('');
    R.start();
  } catch (e) { EP.onVoice(''); }
}

// ---- callbacks from Android ----
window.EP = {
  onVoice(text) {
    listening = false;
    const alts = String(text || '').split('|').filter(Boolean);
    if (micTarget === 'amount') {
      const n = alts.map(parseSpokenAmount).find(x => x > 0);
      if (n) { F.amount = String(n); render(true); return; }
    } else if (micTarget === 'yesno') {
      const yn = alts.map(parseYesNo).find(x => x !== null);
      if (yn !== undefined && yn !== null) { ACT.answer(yn ? '1' : '0'); return; }
    }
    flash = t('notHeard'); render(true); if (S.voice) speak(t('notHeard'));
  },
  onQr(text) {
    if (text === '__unavailable__') { flash = t('qrUnavailable'); F = { ans: {} }; stack = ['home', 'payee']; go('newPayee'); return; }
    if (!text) return; // scanner closed
    const q = parseUpiQr(text);
    if (!q) { flash = t('qrFail'); F = F.ans ? F : { ans: {} }; if (current() !== 'payee') { stack = ['home']; go('payee'); } else render(); return; }
    F = { ans: {} };
    stack = ['home', 'payee'];
    const saved = savedList().find(p => p.id === q.pa);
    if (q.am && Number(q.am) > 0) F.amount = String(Math.round(Number(q.am)));
    if (saved) { F.payee = Object.assign({ saved: true }, saved, { mc: q.mc }); go('amount'); return; }
    const demoName = real() ? '' : DEMO_DIR[q.pa];
    F.payee = { id: q.pa, name: q.pn || demoName || q.pa, saved: false, usual: 0, fromQr: !!q.pn, mc: q.mc, tn: q.tn };
    go('nameCheck');
  },
  onUpi(resp) {
    if (!F.payee) { ACT.home(); return; }
    const r = parseUpiResponse(resp);
    F.payStatus = r.status; F.txnId = r.txnId;
    if (r.status === 'success') rememberPayee(F.payee, Number(F.amount));
    stack = ['home']; go('done');
  },
  onTtsMissing() { flash = t('noVoice'); render(true); },
  onBack() {
    if (listening) { listening = false; render(true); return true; }
    if (stack.length > 1 && !['done', 'stopped', 'reqDone'].includes(current())) { ACT.back(); return true; }
    if (stack.length > 1) { ACT.home(); return true; }
    return false;
  }
};

function rememberPayee(p, amount) {
  if (!real() || !p || !p.id) return;
  const ex = S.payees.find(x => x.id === p.id);
  if (ex) { ex.count = (ex.count || 1) + 1; ex.usual = Math.round(((ex.usual || amount) * (ex.count - 1) + amount) / ex.count); }
  else S.payees.unshift({ id: p.id, name: p.name || p.id, usual: amount, count: 1, ico: p.mc ? 'shop' : 'person' });
  S.payees = S.payees.slice(0, 12);
  persist();
}

// ---- render ----
const current = () => stack[stack.length - 1];
function render(keepScroll) {
  if (timer) { clearInterval(timer); timer = null; }
  const root = document.documentElement;
  root.lang = S.lang;
  root.dataset.size = S.size;
  document.getElementById('appname').innerHTML = `${esc(t('app1'))} <span>${esc(t('app2'))}</span>`;
  const banner = document.getElementById('banner');
  banner.textContent = real() ? t('bannerReal') : t('bannerPractice');
  banner.classList.toggle('real', real());
  const vb = document.getElementById('voiceBtn');
  vb.textContent = '🔊 ' + (S.voice ? t('voiceOn') : t('voiceOff'));
  vb.setAttribute('aria-pressed', String(S.voice));
  ['en', 'hi', 'kn'].forEach(l => document.getElementById('lang-' + l).setAttribute('aria-pressed', String(S.lang === l)));
  const name = current();
  const scr = SCREENS[name]();
  document.getElementById('screen').innerHTML = scr.html;
  const changed = lastSay !== scr.say;
  lastSay = scr.say;
  flash = '';
  if (S.voice && changed && !listening) speak(lastSay);
  if (!keepScroll) window.scrollTo(0, 0);
  if (name === 'result' && F.result.level === 'red') {
    let s = 30; const b = document.getElementById('anyway');
    timer = setInterval(() => {
      s--; if (!b.isConnected) { clearInterval(timer); return; }
      if (s <= 0) { clearInterval(timer); timer = null; b.disabled = false; b.textContent = t('payAnyway'); }
      else b.textContent = t('waitSec', { s });
    }, 1000);
  }
  const amt = document.getElementById('amt');
  if (amt) amt.addEventListener('input', () => { amt.value = amt.value.replace(/\D/g, ''); F.amount = amt.value; document.getElementById('words').textContent = wordsFor(amt.value); });
  const upi = document.getElementById('upi');
  if (upi) upi.addEventListener('input', () => { F.upiDraft = upi.value; });
  const msgin = document.getElementById('msgin');
  if (msgin) msgin.addEventListener('input', () => { F.msgText = msgin.value; });
  const reqwho = document.getElementById('reqwho'), reqamt = document.getElementById('reqamt');
  if (reqwho) reqwho.addEventListener('input', () => { F.reqWho = reqwho.value; });
  if (reqamt) reqamt.addEventListener('input', () => { reqamt.value = reqamt.value.replace(/\D/g, ''); F.reqAmt = reqamt.value; });
  const ff = document.getElementById('famform');
  if (ff) ff.addEventListener('submit', e => {
    e.preventDefault();
    S.contact = { name: document.getElementById('fname').value.trim() || 'Family', phone: document.getElementById('fphone').value.replace(/\D/g, ''), limit: parseInt(document.getElementById('flimit').value, 10) || 0 };
    persist(); flash = t('saved'); render();
  });
}
function go(name) { stack.push(name); render(); }

function runCheck() {
  const ctx = {
    isCollect: !!F.collect, thinksReceive: !!F.thinksReceive,
    calledFirst: !!F.ans.caller, urgency: !!F.ans.urgency, prizeRefund: !!F.ans.prize, remoteApp: !!F.ans.remote,
    nameMismatch: !!F.nameMismatch, newPayee: !F.payee.saved,
    amount: Number(F.amount), usual: F.payee.usual || 0, familyLimit: Number(S.contact.limit) || 0
  };
  F.result = assess(ctx);
}

const ACT = {
  home() { F = {}; stack = ['home']; render(); },
  back() { if (stack.length > 1) stack.pop(); if (current() === 'question' && F.qi > 0) F.qi--; render(); },
  go(v) { go(v); },
  lang(v) { S.lang = v; persist(); render(true); },
  voice() { S.voice = !S.voice; persist(); if (!S.voice) stopSpeaking(); else speak(lastSay); render(true); },
  speak() { speak(lastSay); },
  mic(v) { if (!listening) startListening(v); },
  startSend() { F = { ans: {} }; go('payee'); },
  startRequest() { F = { ans: {} }; go('request'); },
  scan() {
    if (NB) { NB.scanQr(); return; }
    // Browser: no camera scanner; in practice mode pretend we scanned Raju's shop
    if (!real()) EP.onQr(DEMO_QR); else EP.onQr('__unavailable__');
  },
  story1() { F = { ans: {}, payee: Object.assign({ saved: true }, DEMO_SAVED[0]), amount: '200' }; stack = ['home', 'payee']; go('amount'); },
  story2() { F = { ans: {} }; stack = ['home']; go('request'); },
  pickSaved(v) { F.payee = Object.assign({ saved: true }, savedList()[+v]); F.nameMismatch = false; go('amount'); },
  fillUpi(v) { F.upiDraft = v; render(true); },
  submitUpi() {
    const id = (document.getElementById('upi').value || '').trim().toLowerCase();
    if (!isUpiId(id)) { flash = t('upiInvalid'); render(true); return; }
    const saved = savedList().find(p => p.id === id);
    if (saved) { F.payee = Object.assign({ saved: true }, saved); F.nameMismatch = false; go('amount'); return; }
    const name = real() ? '' : (DEMO_DIR[id] || id.split('@')[0].split(/[._-]/).filter(Boolean).map(w => w[0].toUpperCase() + w.slice(1)).join(' '));
    F.payee = { id, name: name || id, saved: false, usual: 0 };
    go('nameCheck');
  },
  nameOk(v) {
    const nick = document.getElementById('nick');
    if (nick && nick.value.trim()) F.payee.name = nick.value.trim();
    F.nameMismatch = v === '0'; go('amount');
  },
  quickAmt(v) { F.amount = v; render(true); },
  submitAmt() {
    const n = parseInt(document.getElementById('amt').value, 10);
    if (!(n > 0)) { flash = t('amountZero'); render(true); return; }
    if (n > UPI_MAX) { flash = t('amountMax'); render(true); return; }
    F.amount = String(n); F.qi = 0; F.ans = {}; go('question');
  },
  answer(v) {
    F.ans[QUESTIONS[F.qi]] = v === '1';
    if (F.qi < QUESTIONS.length - 1) { F.qi++; stack.push('question'); render(); }
    else { runCheck(); go('result'); }
  },
  reqAnswer(v) {
    if (real()) {
      const who = (F.reqWho || '').trim(), n = parseInt(F.reqAmt, 10);
      if (!(n > 0)) { flash = t('amountZero'); render(true); return; }
      F.payee = { id: who || '?', name: who || '?', saved: !!savedList().find(p => who && p.name.toLowerCase() === who.toLowerCase()), usual: 0 };
      F.amount = String(n); F.nameMismatch = false;
    } else {
      F.payee = { id: SCAM_REQ.id, name: SCAM_REQ.name, saved: false, usual: 0 };
      F.amount = String(SCAM_REQ.amount); F.nameMismatch = true;
    }
    F.collect = true; F.thinksReceive = v === 'receive';
    F.qi = 0; F.ans = {}; go('question');
  },
  stop() { stack = ['home']; go('stopped'); },
  pinKey(v) { F.pin = (F.pin || '') + v; if (F.pin.length >= 4) { F.pin = ''; F.payStatus = 'success'; stack = ['home']; go('done'); } else render(true); },
  pinDel() { F.pin = (F.pin || '').slice(0, -1); render(true); },
  payReal() {
    const uri = buildUpiUri({ pa: F.payee.id, pn: F.payee.name, am: F.amount, mc: F.payee.mc, tn: F.payee.tn || 'Easy Pay' });
    const ok = NB ? NB.payUpi(uri) : false;
    if (!ok) { flash = t('noUpiApp'); render(true); }
  },
  copy(v, el) {
    const done = () => { el.textContent = '✓ ' + t('copied'); };
    if (NB) { NB.copy(v); done(); return; }
    try { navigator.clipboard.writeText(v).then(done, () => {}); } catch (e) {}
  },
  pasteMsg() {
    const set = s => { if (s) { F.msgText = s; F.msgResult = null; render(true); } };
    if (NB) { set(NB.paste()); return; }
    try { navigator.clipboard.readText().then(set, () => {}); } catch (e) {}
  },
  checkMsg() {
    const s = (document.getElementById('msgin').value || '').trim();
    F.msgText = s;
    if (!s) { F.msgResult = null; flash = t('msgEmpty'); render(true); return; }
    F.msgResult = checkMessage(s); render(true);
  },
  setMode(v) {
    if (v === S.mode) return;
    if (v === 'real') { go('realConfirm'); return; }
    S.mode = 'practice'; persist(); render(true);
  },
  confirmReal() { S.mode = 'real'; persist(); stack.pop(); render(); },
  setSize(v) { S.size = v; persist(); render(true); },
  removePayee(v) { S.payees.splice(+v, 1); persist(); render(true); }
};

document.addEventListener('click', e => {
  const el = e.target.closest('[data-act]');
  if (!el || el.disabled) return;
  const fn = ACT[el.dataset.act];
  if (fn) { e.preventDefault(); fn(el.dataset.v, el); }
});
try { if (!NB) speechSynthesis.onvoiceschanged = () => {}; } catch (e) {}
render();
