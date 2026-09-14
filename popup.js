(() => {
  // src/popup.js
  document.addEventListener("DOMContentLoaded", () => {
    const SUPABASE_URL = "https://gbsyzsckiarexxkcjszn.supabase.co";
    const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imdic3l6c2NraWFyZXh4a2Nqc3puIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI1NDI2MzksImV4cCI6MjA5ODExODYzOX0.yXNWXMpsMpCJv3pqOycTi8OFuCaipDDSQ0YM5bOI2PY";
    const GOOGLE_CLIENT_ID = "621619576044-sfj1k8q06uan9cg34tdqf9slj77orlkg.apps.googleusercontent.com";
    const PROXY_SERVER_URL = "https://syncdub-translator-backend-1-hncr.onrender.com";
    let PRICING_URL = "https://syncdub.live/pricing";
    (async function resolvePricingUrl() {
      try {
        if (!PROXY_SERVER_URL) return;
        const resp = await fetch(PROXY_SERVER_URL + "/api/config");
        if (!resp.ok) return;
        const data = await resp.json();
        if (data && typeof data.pricingUrl === "string" && data.pricingUrl) {
          PRICING_URL = data.pricingUrl;
        }
      } catch (e) {
      }
    })();
    function getEl(id) {
      return document.getElementById(id);
    }
    const inlineError = document.getElementById("inline-error");
    let inlineErrorTimeout = null;
    function showInlineError(msg) {
      if (!inlineError) return;
      inlineError.textContent = msg;
      inlineError.classList.add("visible");
      if (inlineErrorTimeout) clearTimeout(inlineErrorTimeout);
      inlineErrorTimeout = setTimeout(() => {
        inlineError.classList.remove("visible");
      }, 5e3);
    }
    const hiddenSelect = getEl("target-lang");
    const masterToggle = getEl("master-toggle");
    const masterBtn = getEl("master-btn");
    const masterBtnText = getEl("master-btn-text");
    const masterIconPlay = getEl("master-icon-play");
    const masterIconStop = getEl("master-icon-stop");
    const routingRadios = document.getElementsByName("routing-mode");
    const ytVolumeSlider = getEl("yt-volume-slider");
    const ytVolumeVal = getEl("yt-volume-val");
    const aiVolumeSlider = getEl("ai-volume-slider");
    const aiVolumeVal = getEl("ai-volume-val");
    const statusPill = getEl("status-pill");
    const statusText = getEl("status-text");
    const waveform = getEl("waveform");
    const timerDisplay = getEl("timer-value");
    const searchClearBtn = getEl("search-clear-btn");
    let latestInputRms = 0;
    let latestOutputRms = 0;
    let lastRmsTime = 0;
    let wavePhase1 = 0;
    let wavePhase2 = 0;
    let wavePhase3 = 0;
    let currentSpeed1 = 0;
    let currentSpeed2 = 0;
    let currentSpeed3 = 0;
    let currentAmp = 2;
    let targetAmp = 2;
    const langGrid = getEl("lang-grid");
    const langSearch = getEl("lang-search");
    const currentLangBadge = getEl("current-lang-badge");
    const langPinnedGrid = getEl("lang-pinned-grid");
    const langPinnedTitle = getEl("lang-pinned-title");
    const heroLangName = getEl("hero-lang-name");
    const heroPipelineStatus = getEl("hero-pipeline-state");
    const pauseBtn = getEl("pause-btn");
    const pauseBtnText = getEl("pause-btn-text");
    const pauseIconPause = getEl("pause-icon-pause");
    const pauseIconResume = getEl("pause-icon-resume");
    const accountLoggedOut = getEl("account-logged-out");
    const accountLoggedIn = getEl("account-logged-in");
    const btnLogin = getEl("btn-login");
    const btnLogout = getEl("btn-logout");
    const userEmailSpan = getEl("user-email");
    const userCreditsSpan = getEl("user-credits");
    const creditsProgressFill = getEl("credits-progress-fill");
    const accountStatusBadge = getEl("account-status-badge");
    const mainAppContent = getEl("main-app-content");
    const loginScreen = getEl("login-screen");
    const btnGoogleLogin = getEl("btn-google-login");
    const btnUpgrade = getEl("btn-upgrade");
    const linkTos = getEl("link-tos");
    const linkPrivacy = getEl("link-privacy");
    const proUpgradeBanner = getEl("pro-upgrade-banner");
    const proBannerTitle = getEl("pro-banner-title");
    const proBannerDesc = getEl("pro-banner-desc");
    let selectedLang = null;
    let sessionSeconds = 0;
    let sessionInterval = null;
    let isActive = false;
    function safeSendMessage(message, callback) {
      try {
        if (typeof chrome !== "undefined" && chrome.runtime && chrome.runtime.sendMessage) {
          if (callback) {
            chrome.runtime.sendMessage(message).then(callback).catch((err) => {
              callback(null);
            });
          } else {
            chrome.runtime.sendMessage(message).catch((err) => {
            });
          }
        }
      } catch (e) {
        if (callback) callback(null);
      }
    }
    function logDiag(message, type = "INFO") {
      try {
        const timestamp = (/* @__PURE__ */ new Date()).toLocaleTimeString();
        const logMsg = `[${timestamp}] [Popup] [${type}] ${message}`;
        if (type === "ERROR" || type === "WARN") ;
        safeSendMessage({ action: "logDiag", logMsg });
      } catch (e) {
      }
    }
    async function fetchWithTimeout(url, options = {}, timeoutMs = 1e4) {
      const controller = new AbortController();
      const { signal } = controller;
      const config = { ...options, signal };
      const timer = setTimeout(() => {
        controller.abort();
      }, timeoutMs);
      try {
        const response = await fetch(url, config);
        const contentType = response.headers.get("content-type");
        let data = null;
        if (contentType && contentType.includes("application/json")) {
          try {
            data = await response.json();
          } catch (jsonErr) {
            throw new Error(`JSON parsing failed: ${jsonErr.message}`);
          }
        } else {
          const text = await response.text();
          data = { text };
        }
        if (!response.ok) {
          throw {
            status: response.status,
            statusText: response.statusText,
            data
          };
        }
        return data;
      } catch (err) {
        if (err.name === "AbortError") {
          throw new Error(`Request timed out after ${timeoutMs}ms`);
        }
        throw err;
      } finally {
        clearTimeout(timer);
      }
    }
    function parseJwt(token) {
      try {
        const base64Url = token.split(".")[1];
        const base64 = base64Url.replace(/-/g, "+").replace(/_/g, "/");
        const jsonPayload = decodeURIComponent(atob(base64).split("").map((c) => "%" + ("00" + c.charCodeAt(0).toString(16)).slice(-2)).join(""));
        return JSON.parse(jsonPayload);
      } catch (e) {
        return null;
      }
    }
    window.onerror = (msg, src, line, col, error) => {
      logDiag(`Error: ${msg} at ${src}:${line}:${col} | ${error?.stack || ""}`, "ERROR");
      return false;
    };
    window.addEventListener("unhandledrejection", (e) => {
      e.preventDefault();
      logDiag(`Unhandled Rejection: ${e.reason} | ${e.reason?.stack || ""}`, "ERROR");
    });
    const RECENT_LANGS_KEY = "recentLangCodes";
    const MAX_RECENT = 5;
    let recentCodes = [];
    function buildLangGrid(filter = "") {
      try {
        if (!langGrid) return;
        langGrid.innerHTML = "";
        if (langPinnedGrid) langPinnedGrid.innerHTML = "";
        const q = filter.toLowerCase().trim();
        const isSearching = q.length > 0;
        const showRecent = !isSearching && recentCodes.length > 0;
        if (langPinnedTitle) langPinnedTitle.classList.toggle("hidden", !showRecent);
        if (langPinnedGrid) langPinnedGrid.classList.toggle("hidden", !showRecent);
        if (showRecent && langPinnedGrid) {
          const pinnedLangs = recentCodes.map((code) => LANGUAGES.find((l) => l.code === code)).filter(Boolean);
          pinnedLangs.forEach((lang) => {
            const tile = createLangTile(lang);
            langPinnedGrid.appendChild(tile);
          });
        }
        const filtered = LANGUAGES.filter(
          (l) => l.name.toLowerCase().includes(q) || l.code.toLowerCase().includes(q)
        );
        filtered.forEach((lang) => {
          const tile = createLangTile(lang);
          langGrid.appendChild(tile);
        });
        if (hiddenSelect) {
          hiddenSelect.innerHTML = "";
          LANGUAGES.forEach((l) => {
            const opt = document.createElement("option");
            opt.value = l.code;
            opt.textContent = l.name;
            if (l.code === selectedLang) opt.selected = true;
            hiddenSelect.appendChild(opt);
          });
        }
      } catch (err) {
      }
    }
    function formatLangLabel(lang) {
      if (!lang) return "";
      return lang.flag ? `${lang.flag} ${lang.name}` : lang.name;
    }
    function createLangTile(lang) {
      const tile = document.createElement("div");
      tile.className = "lang-tile" + (lang.code === selectedLang ? " selected" : "");
      tile.dataset.code = lang.code;
      tile.tabIndex = 0;
      const abbrSpan = document.createElement("span");
      abbrSpan.className = "lang-abbr lang-flag";
      abbrSpan.setAttribute("aria-hidden", "true");
      abbrSpan.textContent = lang.flag || lang.abbr;
      if (lang.flagDataUri) {
        const flagImg = document.createElement("img");
        flagImg.className = "lang-flag-img";
        flagImg.alt = "";
        flagImg.src = lang.flagDataUri;
        abbrSpan.textContent = "";
        abbrSpan.appendChild(flagImg);
      }
      const nameSpan = document.createElement("span");
      nameSpan.className = "lang-name";
      const q = langSearch && langSearch.value ? langSearch.value.toLowerCase().trim() : "";
      const lowerName = lang.name.toLowerCase();
      const idx = q ? lowerName.indexOf(q) : -1;
      if (idx !== -1) {
        const before = lang.name.substring(0, idx);
        const match = lang.name.substring(idx, idx + q.length);
        const after = lang.name.substring(idx + q.length);
        const beforeNode = document.createTextNode(before);
        const matchNode = document.createElement("mark");
        matchNode.className = "search-highlight";
        matchNode.textContent = match;
        const afterNode = document.createTextNode(after);
        nameSpan.appendChild(beforeNode);
        nameSpan.appendChild(matchNode);
        nameSpan.appendChild(afterNode);
      } else {
        nameSpan.textContent = lang.name;
      }
      tile.appendChild(abbrSpan);
      tile.appendChild(nameSpan);
      const onSelect = () => {
        try {
          selectLanguage(lang.code);
        } catch (e) {
        }
      };
      tile.addEventListener("click", onSelect);
      tile.addEventListener("keydown", (e) => {
        if (e.key === "Enter" || e.key === " ") {
          e.preventDefault();
          onSelect();
        }
      });
      return tile;
    }
    function selectLanguage(code) {
      try {
        selectedLang = code;
        const lang = LANGUAGES.find((l) => l.code === code);
        if (lang) {
          if (currentLangBadge) currentLangBadge.textContent = formatLangLabel(lang);
          if (heroLangName) heroLangName.textContent = formatLangLabel(lang);
        }
        const updateSelection = (container) => {
          if (container) {
            container.querySelectorAll(".lang-tile").forEach((t) => {
              t.classList.toggle("selected", t.dataset.code === code);
            });
          }
        };
        updateSelection(langGrid);
        updateSelection(langPinnedGrid);
        if (hiddenSelect) hiddenSelect.value = code;
        recentCodes = [code, ...recentCodes.filter((c) => c !== code)].slice(0, MAX_RECENT);
        chrome.storage.local.set({ [RECENT_LANGS_KEY]: recentCodes }, () => {
          if (chrome.runtime.lastError) {
          }
        });
        buildLangGrid(langSearch ? langSearch.value : "");
        chrome.storage.local.set({ targetLang: code }, () => {
          if (chrome.runtime.lastError) {
          }
        });
        safeSendMessage({ action: "updateSettings", settings: { targetLang: code } });
        logDiag(`Language \u2192 ${lang ? lang.name : code}`);
      } catch (err) {
      }
    }
    if (langSearch) {
      langSearch.addEventListener("input", () => {
        try {
          const query = langSearch.value;
          if (searchClearBtn) {
            searchClearBtn.classList.toggle("hidden", query.length === 0);
          }
          buildLangGrid(query);
        } catch (e) {
        }
      });
    }
    if (searchClearBtn) {
      searchClearBtn.addEventListener("click", () => {
        try {
          if (langSearch) langSearch.value = "";
          searchClearBtn.classList.add("hidden");
          buildLangGrid("");
          if (langSearch) langSearch.focus();
        } catch (e) {
        }
      });
    }
    try {
      chrome.storage.local.get(["authToken", "refreshToken", "tokenExpiresAt", "userId", "userEmail", "userCredits", "userPlan", "targetLang", "isEnabled", "routingMode", "ytVolume", "aiVolume", "status", "recentLangCodes"], (localAllItems) => {
        chrome.storage.session.get(["authToken", "userEmail", "userCredits", "userPlan", "tokenExpiresAt", "refreshToken", "userId"], (sessionItems) => {
          if (!sessionItems?.authToken && localAllItems?.authToken) {
            chrome.storage.session.set({ authToken: localAllItems.authToken, refreshToken: localAllItems.refreshToken, tokenExpiresAt: localAllItems.tokenExpiresAt, userId: localAllItems.userId, userEmail: localAllItems.userEmail, userCredits: localAllItems.userCredits, userPlan: localAllItems.userPlan });
            logDiag("AUTH RESTORED: session repopulated from local storage after restart.");
          }
          const items = { ...localAllItems || {}, ...sessionItems || {} };
          ((_items) => {
            const items2 = _items;
            {
              try {
                if (chrome.runtime.lastError) {
                  return;
                }
                if (items2) {
                  if (items2.targetLang) {
                    selectedLang = items2.targetLang;
                    const lang = LANGUAGES.find((l) => l.code === selectedLang);
                    if (lang && currentLangBadge) currentLangBadge.textContent = formatLangLabel(lang);
                    if (lang && heroLangName) heroLangName.textContent = formatLangLabel(lang);
                  }
                  isActive = !!items2.isEnabled;
                  if (masterToggle) masterToggle.checked = isActive;
                  updateMasterBtn(isActive);
                  const routingMode = items2.routingMode || "ducking";
                  for (const radio of routingRadios) {
                    radio.checked = radio.value === routingMode;
                  }
                  let ytVol = 0.15;
                  let aiVol = 1;
                  if (items2.ytVolume !== void 0) {
                    ytVol = items2.ytVolume;
                  } else {
                    ytVol = routingMode === "mute" ? 0 : 0.15;
                  }
                  if (items2.aiVolume !== void 0) {
                    aiVol = items2.aiVolume;
                  }
                  if (ytVolumeSlider) ytVolumeSlider.value = Math.round(ytVol * 100);
                  if (ytVolumeVal) ytVolumeVal.textContent = `${ytVolumeSlider ? ytVolumeSlider.value : 15}%`;
                  if (aiVolumeSlider) aiVolumeSlider.value = Math.round(aiVol * 100);
                  if (aiVolumeVal) aiVolumeVal.textContent = `${aiVolumeSlider ? aiVolumeSlider.value : 100}%`;
                  updateAccountUI(items2.authToken, items2.userEmail, items2.userCredits, items2.userPlan || "free");
                  if (items2.authToken) {
                    chrome.storage.session.get(["tokenExpiresAt", "refreshToken", "userId"], async (authItems) => {
                      try {
                        let token = items2.authToken;
                        let plan = items2.userPlan || "free";
                        let credits = items2.userCredits !== void 0 ? items2.userCredits : 0;
                        if (isTokenExpired(authItems?.tokenExpiresAt) && authItems?.refreshToken) {
                          logDiag("Stored token is expired. Refreshing on popup open...");
                          try {
                            token = await refreshSupabaseToken();
                          } catch (refreshErr) {
                            logDiag(`Startup token refresh failed: ${refreshErr.message}. Showing login screen.`, "ERROR");
                            updateAccountUI(null, null, null, null);
                            return;
                          }
                          if (authItems?.userId) {
                            try {
                              const creditData = await fetchUserCredits(authItems.userId, token);
                              credits = creditData.credits;
                              plan = creditData.plan;
                              chrome.storage.session.set({ userCredits: credits, userPlan: plan });
                            } catch (creditErr) {
                              logDiag(`Credits fetch failed after token refresh (keeping cached value): ${creditErr.message}`, "WARN");
                              if (!navigator.onLine || (creditErr.message || "").includes("NETWORK_ERROR")) {
                                showInlineError("No internet connection.");
                              }
                            }
                          }
                        } else if (authItems?.tokenExpiresAt) {
                          scheduleTokenRefresh(authItems.tokenExpiresAt);
                          if (authItems?.userId) {
                            try {
                              const creditData = await fetchUserCredits(authItems.userId, token);
                              credits = creditData.credits;
                              plan = creditData.plan;
                              chrome.storage.session.set({ userCredits: credits, userPlan: plan });
                            } catch (e) {
                              logDiag(`Credits fetch failed on popup open (keeping cached value): ${e.message}`, "WARN");
                              if (!navigator.onLine || (e.message || "").includes("NETWORK_ERROR")) {
                                showInlineError("No internet connection.");
                              }
                            }
                          }
                        }
                        updateAccountUI(token, items2.userEmail, credits, plan);
                        startCreditsPolling();
                      } catch (e) {
                      }
                    });
                  }
                  if (!items2.authToken) {
                    updateStatusUI("disconnected");
                    updateAccountUI(null, null, 0, null);
                  } else {
                    if (items2.status !== "live") {
                      chrome.storage.local.remove(["sessionStartTime"], () => {
                      });
                      if (timerDisplay) timerDisplay.textContent = "00:00";
                    }
                    updateStatusUI(items2.status || "disconnected");
                  }
                  recentCodes = Array.isArray(items2.recentLangCodes) ? items2.recentLangCodes : [];
                  buildLangGrid();
                  logDiag(`Dashboard initialized (Orig Vol: ${ytVolumeSlider ? ytVolumeSlider.value : 15}%, AI Vol: ${aiVolumeSlider ? aiVolumeSlider.value : 100}%).`);
                }
              } catch (cbErr) {
              }
            }
          })(items);
        });
      });
    } catch (err) {
    }
    for (const radio of routingRadios) {
      radio.addEventListener("change", () => {
        try {
          if (radio.checked) {
            const routingMode = radio.value;
            let ytVol = 0.15;
            let aiVol = 1;
            if (routingMode === "mute") {
              ytVol = 0;
            }
            if (ytVolumeSlider) ytVolumeSlider.value = Math.round(ytVol * 100);
            if (ytVolumeVal) ytVolumeVal.textContent = `${ytVolumeSlider ? ytVolumeSlider.value : 15}%`;
            if (aiVolumeSlider) aiVolumeSlider.value = Math.round(aiVol * 100);
            if (aiVolumeVal) aiVolumeVal.textContent = `${aiVolumeSlider ? aiVolumeSlider.value : 100}%`;
            chrome.storage.local.set({ routingMode, ytVolume: ytVol, aiVolume: aiVol }, () => {
              if (chrome.runtime.lastError) ;
            });
            safeSendMessage({
              action: "updateSettings",
              settings: { routingMode, ytVolume: ytVol, aiVolume: aiVol }
            });
            logDiag(`Routing preset \u2192 ${routingMode} (Orig Vol: ${ytVolumeSlider ? ytVolumeSlider.value : 15}%, AI Vol: ${aiVolumeSlider ? aiVolumeSlider.value : 100}%)`);
          }
        } catch (e) {
        }
      });
    }
    let volumeDebounceTimer = null;
    let pendingVolumeSettings = null;
    const VOLUME_UPDATE_DEBOUNCE_MS = 75;
    function getRoutingModeFromSliderValues(ytPercent, aiPercent) {
      if (ytPercent === 15 && aiPercent === 100) return "ducking";
      if (ytPercent === 0 && aiPercent === 100) return "mute";
      return "custom";
    }
    function queueVolumeSettingsUpdate(settings) {
      pendingVolumeSettings = {
        ...pendingVolumeSettings || {},
        ...settings
      };
      if (volumeDebounceTimer) {
        try {
          clearTimeout(volumeDebounceTimer);
        } catch (e) {
        }
      }
      volumeDebounceTimer = setTimeout(() => {
        const latestSettings = pendingVolumeSettings;
        pendingVolumeSettings = null;
        volumeDebounceTimer = null;
        if (!latestSettings) return;
        chrome.storage.local.set(latestSettings, () => {
          if (chrome.runtime.lastError) ;
        });
        safeSendMessage({
          action: "updateSettings",
          settings: latestSettings
        });
      }, VOLUME_UPDATE_DEBOUNCE_MS);
    }
    function updateVolumeFromSlider(type) {
      try {
        const slider = type === "yt" ? ytVolumeSlider : aiVolumeSlider;
        const badge = type === "yt" ? ytVolumeVal : aiVolumeVal;
        if (!slider || !badge) return;
        const valPercent = parseInt(slider.value, 10);
        badge.textContent = `${valPercent}%`;
        const valFloat = valPercent / 100;
        const storageKey = type === "yt" ? "ytVolume" : "aiVolume";
        const routingMode = syncPresetsFromSliders();
        queueVolumeSettingsUpdate({
          [storageKey]: valFloat,
          routingMode
        });
      } catch (err) {
      }
    }
    function syncPresetsFromSliders() {
      try {
        if (!ytVolumeSlider || !aiVolumeSlider) return "custom";
        const ytPercent = parseInt(ytVolumeSlider.value, 10);
        const aiPercent = parseInt(aiVolumeSlider.value, 10);
        const matchedMode = getRoutingModeFromSliderValues(ytPercent, aiPercent);
        for (const radio of routingRadios) {
          radio.checked = matchedMode !== "custom" && radio.value === matchedMode;
        }
        return matchedMode;
      } catch (err) {
        return "custom";
      }
    }
    if (ytVolumeSlider) ytVolumeSlider.addEventListener("input", () => updateVolumeFromSlider("yt"));
    if (aiVolumeSlider) aiVolumeSlider.addEventListener("input", () => updateVolumeFromSlider("ai"));
    function updateMasterBtn(active) {
      try {
        document.body.classList.toggle("active-translation", active);
        if (!masterBtn || !masterBtnText || !masterIconPlay || !masterIconStop) return;
        if (active) {
          masterBtn.classList.add("active");
          masterBtnText.textContent = "Stop Translation";
          masterIconPlay.classList.add("hidden");
          masterIconStop.classList.remove("hidden");
        } else {
          masterBtn.classList.remove("active");
          masterBtnText.textContent = "Start Translation";
          masterIconPlay.classList.remove("hidden");
          masterIconStop.classList.add("hidden");
        }
      } catch (e) {
      }
    }
    let connectingStuckTimeoutId = null;
    let connectingFailsafeTimeoutId = null;
    if (masterBtn) {
      masterBtn.addEventListener("click", () => {
        try {
          if (!masterToggle) return;
          const newState = !masterToggle.checked;
          masterToggle.checked = newState;
          isActive = newState;
          updateMasterBtn(newState);
          logDiag(`Master: ${newState ? "ON" : "OFF"}`);
          if (newState) {
            if (!selectedLang) {
              showInlineError("Please select a target language first.");
              const langCard = getEl("card-lang");
              if (langCard) langCard.open = true;
              masterToggle.checked = false;
              isActive = false;
              updateMasterBtn(false);
              return;
            }
            if (!navigator.onLine) {
              showInlineError("No internet connection.");
              updateStatusUI("error", "no_internet");
              if (masterToggle) masterToggle.checked = false;
              isActive = false;
              updateMasterBtn(false);
              return;
            }
            updateStatusUI("connecting");
            if (connectingStuckTimeoutId) {
              clearTimeout(connectingStuckTimeoutId);
              connectingStuckTimeoutId = null;
            }
            if (masterBtn) masterBtn.classList.add("stuck");
            if (connectingFailsafeTimeoutId) clearTimeout(connectingFailsafeTimeoutId);
            connectingFailsafeTimeoutId = setTimeout(() => {
              chrome.storage.local.get(["status"], (items) => {
                if (chrome.runtime.lastError) return;
                if (items && items.status === "connecting") {
                  logDiag("Connecting timed out client-side with no status update from background. Auto-cancelling.", "ERROR");
                  safeSendMessage({ action: "toggleService", isEnabled: false });
                  chrome.storage.local.set({ isEnabled: false });
                  if (masterToggle) masterToggle.checked = false;
                  isActive = false;
                  updateMasterBtn(false);
                  stopSessionTimer();
                  if (masterBtn) masterBtn.classList.remove("stuck");
                  updateStatusUI("error", "already_shown");
                  showInlineError("Couldn't connect. Please try again.");
                }
              });
            }, 45e3);
            chrome.storage.local.get(["authToken", "userCredits", "userPlan"], (localItems) => {
              chrome.storage.session.get(["authToken", "userCredits", "userPlan"], (storeItems) => {
                if (chrome.runtime.lastError) {
                }
                const token = storeItems && storeItems.authToken || localItems && localItems.authToken || null;
                const rawCredits = storeItems && storeItems.userCredits !== void 0 ? storeItems.userCredits : localItems && localItems.userCredits;
                const credits = parseFloat(rawCredits);
                const plan = storeItems && storeItems.userPlan || localItems && localItems.userPlan || null;
                if (localItems && localItems.authToken && (!storeItems || !storeItems.authToken)) {
                  chrome.storage.session.set({ authToken: localItems.authToken, userCredits: localItems.userCredits, userPlan: localItems.userPlan });
                }
                if (!token) {
                  showInlineError("Please sign in to start translation.");
                  updateStatusUI("error", "already_shown");
                  if (heroPipelineStatus) heroPipelineStatus.textContent = "Not Signed In";
                  if (masterToggle) masterToggle.checked = false;
                  isActive = false;
                  updateMasterBtn(false);
                  return;
                }
                if (isNaN(credits) || credits <= 0) {
                  updateStatusUI("error", "credits_exhausted");
                  if (masterToggle) masterToggle.checked = false;
                  isActive = false;
                  updateMasterBtn(false);
                  return;
                }
                chrome.tabs.query({ active: true, currentWindow: true }, (tabs) => {
                  if (chrome.runtime.lastError) {
                    logDiag(`chrome.tabs.query error: ${chrome.runtime.lastError.message}`, "ERROR");
                    showInlineError(`Failed to capture tab: ${chrome.runtime.lastError.message}`);
                    updateStatusUI("error", "already_shown");
                    if (heroPipelineStatus) heroPipelineStatus.textContent = "Tab Capture Error";
                    if (masterToggle) masterToggle.checked = false;
                    isActive = false;
                    updateMasterBtn(false);
                    return;
                  }
                  const activeTab = tabs ? tabs[0] : null;
                  if (!activeTab) {
                    logDiag("No active tab found.", "ERROR");
                    showInlineError("Could not find active browser tab. Make sure you are on a webpage.");
                    updateStatusUI("error", "already_shown");
                    if (heroPipelineStatus) heroPipelineStatus.textContent = "No Active Tab";
                    if (masterToggle) masterToggle.checked = false;
                    isActive = false;
                    updateMasterBtn(false);
                    return;
                  }
                  if (activeTab.url && (activeTab.url.startsWith("chrome://") || activeTab.url.startsWith("chrome-extension://") || activeTab.url.includes("chromewebstore"))) {
                    logDiag("Cannot capture protected Chrome page.", "ERROR");
                    showInlineError("Cannot capture audio on protected Chrome pages. Please open a video website and try again!");
                    updateStatusUI("error", "already_shown");
                    if (heroPipelineStatus) heroPipelineStatus.textContent = "Protected Page";
                    if (masterToggle) masterToggle.checked = false;
                    isActive = false;
                    updateMasterBtn(false);
                    return;
                  }
                  logDiag(`Requesting stream for tab ${activeTab.id}...`);
                  try {
                    chrome.tabCapture.getMediaStreamId({ targetTabId: activeTab.id }, (streamId) => {
                      if (chrome.runtime.lastError) {
                        logDiag(`getMediaStreamId error: ${chrome.runtime.lastError.message}`, "ERROR");
                        const errMsg = chrome.runtime.lastError.message || "";
                        safeSendMessage({ action: "stopCapture" });
                        chrome.storage.local.set({ isEnabled: false });
                        if (errMsg.includes("active stream") || errMsg.includes("already being captured")) {
                          logDiag("Active stream error encountered. Forcing stopCapture clean up.", "WARN");
                          showInlineError("Previous active stream cleared. Please toggle again to start!");
                          if (heroPipelineStatus) heroPipelineStatus.textContent = "Stream Reset";
                        } else {
                          showInlineError(`Audio Capture Permission Error: ${chrome.runtime.lastError.message}`);
                          if (heroPipelineStatus) heroPipelineStatus.textContent = "Capture Permission Error";
                        }
                        updateStatusUI("error", "already_shown");
                        if (masterToggle) masterToggle.checked = false;
                        isActive = false;
                        updateMasterBtn(false);
                        return;
                      }
                      if (!streamId) {
                        logDiag("Failed to acquire MediaStreamID.", "ERROR");
                        showInlineError("No media stream found. Make sure a video or audio is loaded on this tab, then try again.");
                        updateStatusUI("error", "already_shown");
                        if (heroPipelineStatus) heroPipelineStatus.textContent = "No Audio Found";
                        if (masterToggle) masterToggle.checked = false;
                        isActive = false;
                        updateMasterBtn(false);
                        return;
                      }
                      logDiag("MediaStreamID acquired.");
                      chrome.storage.local.set({ isEnabled: true }, () => {
                        if (chrome.runtime.lastError) {
                        }
                      });
                      safeSendMessage({
                        action: "toggleService",
                        isEnabled: true,
                        streamId,
                        tabId: activeTab.id
                      });
                    });
                  } catch (captureErr) {
                    logDiag(`getMediaStreamId throw: ${captureErr.message}`, "ERROR");
                    showInlineError(`Audio Capture Exception: ${captureErr.message}`);
                    updateStatusUI("error", "already_shown");
                    if (heroPipelineStatus) heroPipelineStatus.textContent = "Capture Exception";
                    if (masterToggle) masterToggle.checked = false;
                    isActive = false;
                    updateMasterBtn(false);
                  }
                });
              });
            });
          } else {
            if (connectingStuckTimeoutId) {
              clearTimeout(connectingStuckTimeoutId);
              connectingStuckTimeoutId = null;
            }
            if (connectingFailsafeTimeoutId) {
              clearTimeout(connectingFailsafeTimeoutId);
              connectingFailsafeTimeoutId = null;
            }
            if (masterBtn) masterBtn.classList.remove("stuck");
            updateStatusUI("disconnected");
            chrome.storage.local.set({ isEnabled: false }, () => {
              if (chrome.runtime.lastError) ;
            });
            safeSendMessage({ action: "toggleService", isEnabled: false });
            stopSessionTimer();
          }
        } catch (err) {
        }
      });
    }
    function updatePauseBtn(isPaused, isLive) {
      try {
        if (!pauseBtn) return;
        if (!isLive) {
          pauseBtn.classList.add("hidden");
          return;
        }
        pauseBtn.classList.remove("hidden");
        if (isPaused) {
          pauseBtn.classList.add("is-paused");
          if (pauseBtnText) pauseBtnText.textContent = "Resume Translation";
          if (pauseIconPause) pauseIconPause.classList.add("hidden");
          if (pauseIconResume) pauseIconResume.classList.remove("hidden");
        } else {
          pauseBtn.classList.remove("is-paused");
          if (pauseBtnText) pauseBtnText.textContent = "Pause Translation";
          if (pauseIconPause) pauseIconPause.classList.remove("hidden");
          if (pauseIconResume) pauseIconResume.classList.add("hidden");
        }
      } catch (e) {
      }
    }
    if (pauseBtn) {
      pauseBtn.addEventListener("click", () => {
        try {
          chrome.storage.local.get(["isTranslationPaused"], (items) => {
            try {
              if (chrome.runtime.lastError) {
                return;
              }
              const currentPaused = items ? !!items.isTranslationPaused : false;
              const newPaused = !currentPaused;
              chrome.storage.local.set({ isTranslationPaused: newPaused }, () => {
                if (chrome.runtime.lastError) {
                }
              });
              safeSendMessage({
                action: "updateSettings",
                settings: { isTranslationPaused: newPaused }
              });
              if (newPaused) {
                pauseSessionTimer();
              } else {
                resumeSessionTimer();
              }
              updatePauseBtn(newPaused, true);
              updateStatusUI("live");
              logDiag(`Translation ${newPaused ? "PAUSED" : "RESUMED"} from dashboard.`);
            } catch (cbErr) {
            }
          });
        } catch (e) {
        }
      });
    }
    function updateStatusUI(state, reason = "") {
      try {
        if (!statusPill || !statusText || !waveform) return;
        if (state !== "connecting") {
          if (connectingStuckTimeoutId) {
            clearTimeout(connectingStuckTimeoutId);
            connectingStuckTimeoutId = null;
          }
          if (connectingFailsafeTimeoutId) {
            clearTimeout(connectingFailsafeTimeoutId);
            connectingFailsafeTimeoutId = null;
          }
          if (masterBtn) masterBtn.classList.remove("stuck");
        }
        const labels = {
          "disconnected": "Offline",
          "connecting": "Connecting",
          "live": "Live",
          "error": "Error"
        };
        const subLabels = {
          "disconnected": "System offline",
          "connecting": "Connecting...",
          "live": "Translating...",
          "error": "Pipeline error"
        };
        document.body.setAttribute("data-status", state);
        if (heroPipelineStatus) {
          heroPipelineStatus.textContent = subLabels[state] || state;
        }
        if (state === "live") {
          chrome.storage.local.get(["isTranslationPaused"], (items) => {
            try {
              if (chrome.runtime.lastError) {
                return;
              }
              const isPaused = items ? !!items.isTranslationPaused : false;
              statusPill.className = "status-pill";
              if (isPaused) {
                statusPill.classList.add("connecting");
                statusText.textContent = "Live (Paused)";
                if (heroPipelineStatus) heroPipelineStatus.textContent = "Paused";
                waveform.classList.remove("active");
              } else {
                statusPill.classList.add("live");
                statusText.textContent = "Live";
                waveform.classList.add("active");
              }
              updatePauseBtn(isPaused, true);
              startSessionTimer();
            } catch (innerErr) {
            }
          });
        } else {
          statusPill.className = "status-pill";
          statusPill.classList.add(state.toLowerCase());
          statusText.textContent = labels[state] || state;
          waveform.classList.remove("active");
          updatePauseBtn(false, false);
          stopSessionTimer();
          if (state === "error") {
            if (reason === "credits_exhausted") {
              statusText.textContent = "Credits Exhausted";
              if (heroPipelineStatus) heroPipelineStatus.textContent = "No Credits";
              showInlineError("Your translation credits have been fully used. Please purchase additional credits to continue using the translation service.");
            } else if (reason === "already_shown") {
            } else if (reason) {
              let stateLabel = "Connection Failed";
              let friendlyMsg = "The translation service encountered a connection error. Please try restarting the session.";
              const r = reason.toLowerCase();
              if (r.includes("no media stream") || r.includes("no active audio")) {
                stateLabel = "No Audio Found";
                friendlyMsg = "No media stream found. Make sure a video or audio is loaded on this tab, then try again.";
              } else if (r.includes("permission denied") || r.includes("notallowederror")) {
                stateLabel = "Permission Denied";
                friendlyMsg = "Permission was denied. Please allow the required access and try again.";
              } else if (r.includes("tab has been closed") || r.includes("notfounderror")) {
                stateLabel = "Tab Closed";
                friendlyMsg = "The tab was closed. Please open a video and try again.";
              } else if (r.includes("security constraint") || r.includes("securityerror")) {
                stateLabel = "Blocked by Site";
                friendlyMsg = "This site blocks audio capture. Please try a different page.";
              } else if (r.includes("audioworklet")) {
                stateLabel = "Audio Engine Failed";
                friendlyMsg = "The audio engine failed to start. Please try again.";
              } else if (r.includes("proxy") || r.includes("server not reachable") || r.includes("waking up")) {
                stateLabel = "Server Unreachable";
                friendlyMsg = "Could not reach the server. Please try again in a moment.";
              } else if (r.includes("internet")) {
                stateLabel = "No Internet";
                friendlyMsg = "No internet connection.";
              } else if (r.includes("auth") || r.includes("token")) {
                stateLabel = "Auth Failed";
                friendlyMsg = "Authentication failed. Please sign in again.";
              }
              statusText.textContent = stateLabel;
              if (heroPipelineStatus) heroPipelineStatus.textContent = stateLabel;
              showInlineError(friendlyMsg);
            } else {
              if (heroPipelineStatus) heroPipelineStatus.textContent = "Connection Failed";
              showInlineError("The translation service encountered a connection error. Please try restarting the session.");
            }
          }
        }
      } catch (err) {
      }
    }
    try {
      safeSendMessage({ action: "getStatus" }, (response) => {
        if (response && response.status) {
          updateStatusUI(response.status, response.reason);
        }
      });
    } catch (err) {
    }
    try {
      if (typeof chrome !== "undefined" && chrome.runtime && chrome.runtime.onMessage) {
        chrome.runtime.onMessage.addListener((message) => {
          try {
            if (message && message._target && message._target !== "popup") return;
            if (message && message.action === "statusChange") {
              const state = message.status;
              updateStatusUI(state, message.reason);
              if (state === "disconnected" || state === "error") {
                if (masterToggle) masterToggle.checked = false;
                isActive = false;
                updateMasterBtn(false);
              }
            }
            if (message && message.action === "audioLevels") {
              latestInputRms = message.inputRms || 0;
              latestOutputRms = message.outputRms || 0;
              lastRmsTime = Date.now();
            }
            if (message && message.action === "creditsUpdated") {
              chrome.storage.session.get(["authToken", "userEmail"], (items) => {
                try {
                  updateAccountUI(items?.authToken, items?.userEmail, message.userCredits, message.userPlan);
                } catch (e) {
                }
              });
            }
          } catch (listenerErr) {
          }
        });
      }
    } catch (err) {
    }
    let timerStarted = false;
    let pausedMsAccum = 0;
    let pausedSince = null;
    let timerStartTime = null;
    let timerColdSyncDone = false;
    function _timerTick() {
      try {
        if (!timerStartTime) return;
        const currentPausedMs = pausedSince !== null ? Date.now() - pausedSince : 0;
        const activeMs = Date.now() - timerStartTime - pausedMsAccum - currentPausedMs;
        const elapsed = Math.max(0, Math.floor(activeMs / 1e3));
        const m = String(Math.floor(elapsed / 60)).padStart(2, "0");
        const s = String(elapsed % 60).padStart(2, "0");
        if (timerDisplay) timerDisplay.textContent = m + ":" + s;
      } catch (e) {
      }
    }
    function startSessionTimer() {
      try {
        if (timerColdSyncDone) {
          return;
        }
        chrome.storage.local.get(["sessionStartTime", "pausedElapsedMs", "sessionPausedAt", "status", "isTranslationPaused"], (items) => {
          try {
            if (chrome.runtime.lastError || !items || items.status !== "live" || !items.sessionStartTime) {
              if (timerDisplay) timerDisplay.textContent = "00:00";
              return;
            }
            if (timerColdSyncDone) return;
            timerColdSyncDone = true;
            timerStartTime = items.sessionStartTime;
            pausedMsAccum = items.pausedElapsedMs || 0;
            const isPaused = !!items.isTranslationPaused;
            if (sessionInterval) {
              clearInterval(sessionInterval);
              sessionInterval = null;
            }
            if (isPaused) {
              pausedSince = items.sessionPausedAt || Date.now();
              timerStarted = false;
              _timerTick();
            } else {
              pausedSince = null;
              timerStarted = true;
              _timerTick();
              sessionInterval = setInterval(_timerTick, 1e3);
            }
          } catch (err) {
          }
        });
      } catch (err) {
      }
    }
    function pauseSessionTimer() {
      try {
        timerStarted = false;
        if (sessionInterval) {
          clearInterval(sessionInterval);
          sessionInterval = null;
        }
        pausedSince = Date.now();
      } catch (err) {
      }
    }
    function resumeSessionTimer() {
      try {
        if (pausedSince !== null) {
          pausedMsAccum += Date.now() - pausedSince;
          pausedSince = null;
        }
        if (timerStarted || sessionInterval) return;
        timerStarted = true;
        _timerTick();
        sessionInterval = setInterval(_timerTick, 1e3);
      } catch (err) {
      }
    }
    function stopSessionTimer() {
      try {
        timerStarted = false;
        pausedMsAccum = 0;
        pausedSince = null;
        timerStartTime = null;
        timerColdSyncDone = false;
        if (sessionInterval) {
          clearInterval(sessionInterval);
          sessionInterval = null;
        }
        if (timerDisplay) timerDisplay.textContent = "00:00";
      } catch (err) {
      }
    }
    function updateAccountUI(token, email, credits, plan) {
      try {
        if (token) {
          document.body.classList.remove("logged-out");
          document.body.classList.add("logged-in");
          if (mainAppContent) mainAppContent.classList.remove("hidden");
          if (loginScreen) loginScreen.classList.add("hidden");
          if (accountLoggedOut) accountLoggedOut.classList.add("hidden");
          if (accountLoggedIn) accountLoggedIn.classList.remove("hidden");
          const profileAvatar = getEl("profile-avatar");
          if (profileAvatar && email) {
            profileAvatar.textContent = email.charAt(0).toUpperCase();
          }
          if (userEmailSpan) userEmailSpan.textContent = email;
          if (userCreditsSpan) {
            const creditsVal = parseFloat(credits);
            userCreditsSpan.textContent = isNaN(creditsVal) ? "-- mins" : `${creditsVal.toFixed(1)} mins`;
            const maxMinutes = 30;
            const pct = Math.min(100, Math.max(0, creditsVal / maxMinutes * 100));
            userCreditsSpan.className = "metric-value" + (pct <= 10 ? " low-balance" : "");
            if (creditsProgressFill) {
              creditsProgressFill.value = pct;
              creditsProgressFill.className = `metric-progress-fill${pct <= 10 ? " balance-low" : pct <= 30 ? " balance-medium" : ""}`;
            }
          }
          if (accountStatusBadge) {
            accountStatusBadge.className = "acc-badge status-active";
            accountStatusBadge.textContent = "Active";
          }
          if (proUpgradeBanner) {
            proUpgradeBanner.classList.remove("hidden");
            if (proBannerTitle) proBannerTitle.textContent = "Need more minutes?";
            if (proBannerDesc) proBannerDesc.textContent = "Add dubbing credits \u2014 from $5. Never run out mid-stream.";
            if (btnUpgrade) btnUpgrade.innerHTML = '<span class="pro-cta-icon" aria-hidden="true">\u2726</span><span>Buy credits</span>';
          }
        } else {
          document.body.classList.remove("logged-in");
          document.body.classList.add("logged-out");
          if (mainAppContent) mainAppContent.classList.add("hidden");
          if (loginScreen) loginScreen.classList.remove("hidden");
          if (accountLoggedOut) accountLoggedOut.classList.remove("hidden");
          if (accountLoggedIn) accountLoggedIn.classList.add("hidden");
          if (accountStatusBadge) {
            accountStatusBadge.textContent = "Guest";
            accountStatusBadge.className = "acc-badge status-guest";
          }
          if (proUpgradeBanner) proUpgradeBanner.classList.add("hidden");
          if (creditsProgressFill) {
            creditsProgressFill.value = 0;
            creditsProgressFill.className = "metric-progress-fill balance-low";
          }
          stopSessionTimer();
          if (statusPill) {
            statusPill.className = "status-pill offline";
          }
          if (statusText) {
            statusText.textContent = "Offline";
          }
          if (heroPipelineStatus) {
            heroPipelineStatus.textContent = "System offline";
          }
          if (waveform) {
            waveform.classList.remove("active");
          }
        }
      } catch (e) {
      }
    }
    function setGoogleButtonLoading(isLoading) {
      try {
        if (!btnGoogleLogin) return;
        if (isLoading) {
          btnGoogleLogin.classList.add("is-loading");
          btnGoogleLogin.disabled = true;
        } else {
          btnGoogleLogin.classList.remove("is-loading");
          btnGoogleLogin.disabled = false;
        }
      } catch (e) {
      }
    }
    async function handleGoogleLogin() {
      try {
        setGoogleButtonLoading(true);
        if (!SUPABASE_URL || !GOOGLE_CLIENT_ID || !PROXY_SERVER_URL) {
          setGoogleButtonLoading(false);
          showInlineError("Extension configuration error. Please rebuild the extension.");
          return;
        }
        try {
          fetch(PROXY_SERVER_URL + "/health", { method: "GET", cache: "no-store" }).catch(() => {
          });
        } catch (wakeErr) {
        }
        logDiag("Initializing Google Auth (Authorization Code Flow + PKCE)...");
        const redirectUri = chrome.identity.getRedirectURL();
        const verifierBytes = new Uint8Array(32);
        crypto.getRandomValues(verifierBytes);
        const codeVerifier = btoa(String.fromCharCode(...verifierBytes)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
        const challengeBuffer = await crypto.subtle.digest(
          "SHA-256",
          new TextEncoder().encode(codeVerifier)
        );
        const codeChallenge = btoa(String.fromCharCode(...new Uint8Array(challengeBuffer))).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
        await new Promise((resolve) => {
          chrome.storage.session.set({ pkceCodeVerifier: codeVerifier }, resolve);
        });
        const authUrl = `https://accounts.google.com/o/oauth2/v2/auth?client_id=${GOOGLE_CLIENT_ID}&response_type=code&redirect_uri=${encodeURIComponent(redirectUri)}&scope=openid%20profile%20email&prompt=select_account&code_challenge=${codeChallenge}&code_challenge_method=S256&access_type=offline`;
        logDiag(`Launching OAuth Web Auth Flow (PKCE): ${redirectUri}`);
        chrome.identity.launchWebAuthFlow({
          url: authUrl,
          interactive: true
        }, async (responseUrl) => {
          try {
            if (chrome.runtime.lastError || !responseUrl) {
              const errMsg = chrome.runtime.lastError ? chrome.runtime.lastError.message : "User cancelled or failed to log in";
              logDiag(`Google Sign-In failed: ${errMsg}`, "ERROR");
              setGoogleButtonLoading(false);
              showInlineError(`Login Failed: ${errMsg}`);
              return;
            }
            logDiag("Google Sign-In succeeded! Extracting authorization code...");
            const urlObj = new URL(responseUrl);
            const authCode = urlObj.searchParams.get("code");
            if (!authCode) {
              logDiag("Authorization code not found in response.", "ERROR");
              setGoogleButtonLoading(false);
              showInlineError("Authentication Error: Authorization code missing from response.");
              return;
            }
            const storedVerifier = await new Promise((resolve) => {
              chrome.storage.session.get(["pkceCodeVerifier"], (items) => {
                resolve(items ? items.pkceCodeVerifier : null);
              });
            });
            chrome.storage.session.remove(["pkceCodeVerifier"]);
            if (!storedVerifier) {
              logDiag("PKCE code_verifier not found in session storage.", "ERROR");
              setGoogleButtonLoading(false);
              showInlineError("Security Error: PKCE verification data missing.");
              return;
            }
            logDiag("Exchanging authorization code via secure backend...");
            let authData;
            try {
              authData = await fetchWithTimeout(`${PROXY_SERVER_URL}/api/auth/google`, {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({
                  code: authCode,
                  code_verifier: storedVerifier,
                  redirect_uri: redirectUri
                })
              }, 45e3);
            } catch (err) {
              const errDetail = err.data?.error || err.message || "Network timeout";
              logDiag(`Backend auth exchange failed: ${errDetail}`, "ERROR");
              const isTimeout = /timeout/i.test(String(errDetail));
              setGoogleButtonLoading(false);
              showInlineError(isTimeout ? "The authentication server is starting up. Please wait a moment and try signing in again." : `Authentication Failed: ${errDetail}`);
              return;
            }
            const token = authData.access_token;
            const refreshToken = authData.refresh_token || "";
            const expiresAt = authData.expires_at || Math.floor(Date.now() / 1e3) + (authData.expires_in || 3600);
            const email = authData.user.email;
            const userId = authData.user.id;
            logDiag(`Auth Exchange Success. Logged in as: ${email} (expires_at=${expiresAt})`);
            logDiag("Fetching translation credits...");
            const creditData = await fetchUserCredits(userId, token);
            const _authPayload = { authToken: token, refreshToken, tokenExpiresAt: expiresAt, userId, userEmail: email, userCredits: creditData.credits, userPlan: creditData.plan };
            chrome.storage.local.set(_authPayload);
            chrome.storage.session.set(_authPayload, () => {
              setGoogleButtonLoading(false);
              logDiag("Credentials saved to session+local storage. Launching dashboard...");
              safeSendMessage({
                action: "updateSettings",
                settings: {
                  authToken: token
                }
              });
              updateAccountUI(token, email, creditData.credits, creditData.plan);
              startCreditsPolling();
              scheduleTokenRefresh(expiresAt);
            });
          } catch (innerErr) {
            logDiag(`Authentication callback error: ${innerErr.message}`, "ERROR");
            setGoogleButtonLoading(false);
            showInlineError(`Auth Error: ${innerErr.message}`);
          }
        });
      } catch (e) {
        logDiag(`Auth Flow Launch failed: ${e.message}`, "ERROR");
        setGoogleButtonLoading(false);
        showInlineError(`OAuth Error: ${e.message}`);
      }
    }
    function isTokenExpired(expiresAt) {
      if (!expiresAt) return true;
      return Math.floor(Date.now() / 1e3) >= expiresAt - 60;
    }
    async function refreshSupabaseToken() {
      return new Promise((resolve, reject) => {
        chrome.storage.local.get(["refreshToken"], (localAuth) => {
          chrome.storage.session.get(["refreshToken"], async (items) => {
            try {
              if (chrome.runtime.lastError) {
                reject(new Error(chrome.runtime.lastError.message));
                return;
              }
              const refreshToken = items?.refreshToken || localAuth?.refreshToken;
              if (!refreshToken) {
                reject(new Error("No refresh token available"));
                return;
              }
              logDiag("Refreshing Supabase access token...");
              let data;
              try {
                data = await fetchWithTimeout(`${SUPABASE_URL}/auth/v1/token?grant_type=refresh_token`, {
                  method: "POST",
                  headers: {
                    "Content-Type": "application/json",
                    "apikey": SUPABASE_ANON_KEY
                  },
                  body: JSON.stringify({ refresh_token: refreshToken })
                }, 1e4);
              } catch (err) {
                const errMsg = err.data?.error_description || err.data?.error || err.message || "Refresh failed";
                logDiag(`Token refresh failed: ${errMsg}`, "ERROR");
                reject(new Error(errMsg));
                return;
              }
              const newToken = data.access_token;
              const newRefreshToken = data.refresh_token || refreshToken;
              const newExpiresAt = data.expires_at || Math.floor(Date.now() / 1e3) + (data.expires_in || 3600);
              chrome.storage.local.set({ authToken: newToken, refreshToken: newRefreshToken, tokenExpiresAt: newExpiresAt });
              chrome.storage.session.set({
                authToken: newToken,
                refreshToken: newRefreshToken,
                tokenExpiresAt: newExpiresAt
              }, () => {
                if (chrome.runtime.lastError) {
                  logDiag(`Failed to save refreshed token: ${chrome.runtime.lastError.message}`, "ERROR");
                  reject(new Error(chrome.runtime.lastError.message));
                  return;
                }
                logDiag(`Token refreshed successfully. New expiry: ${new Date(newExpiresAt * 1e3).toLocaleTimeString()}`);
                safeSendMessage({ action: "updateSettings", settings: { authToken: newToken } });
                scheduleTokenRefresh(newExpiresAt);
                resolve(newToken);
              });
            } catch (err) {
              logDiag(`Token refresh error: ${err.message}`, "ERROR");
              reject(err);
            }
          });
        });
      });
    }
    function scheduleTokenRefresh(expiresAt) {
      if (!expiresAt) return;
      chrome.runtime.sendMessage({ action: "scheduleTokenRefresh", expiresAt });
    }
    async function fetchUserCredits(userId, token) {
      try {
        const dbUrl = `${SUPABASE_URL}/rest/v1/profiles?id=eq.${userId}&select=translation_minutes_remaining,plan`;
        let data;
        try {
          data = await fetchWithTimeout(dbUrl, {
            method: "GET",
            headers: {
              "apikey": SUPABASE_ANON_KEY,
              "Authorization": `Bearer ${token}`
            }
          }, 8e3);
        } catch (err) {
          const errorData = err.data || {};
          if (err.status === 401 || errorData.code === "PGRST303" || errorData.message && errorData.message.includes("JWT expired")) {
            logDiag("JWT expired during credits fetch. Attempting token refresh...", "WARN");
            try {
              const newToken = await refreshSupabaseToken();
              const retryData = await fetchWithTimeout(dbUrl, {
                method: "GET",
                headers: {
                  "apikey": SUPABASE_ANON_KEY,
                  "Authorization": `Bearer ${newToken}`
                }
              }, 8e3);
              return {
                credits: retryData[0]?.translation_minutes_remaining || 0,
                plan: retryData[0]?.plan || "free"
              };
            } catch (refreshErr) {
              logDiag(`Retry after refresh failed: ${refreshErr.message}`, "ERROR");
            }
          }
          logDiag(`Database fetch credits failed: ${err.message}`, "ERROR");
          throw new Error("NETWORK_ERROR: " + err.message);
        }
        return {
          credits: data[0]?.translation_minutes_remaining || 0,
          plan: data[0]?.plan || "free"
        };
      } catch (err) {
        logDiag(`Failed to retrieve credits (re-throwing, not resetting to 0): ${err.message}`, "ERROR");
        throw err;
      }
    }
    let creditsPollInterval = null;
    function startCreditsPolling() {
      if (creditsPollInterval) clearInterval(creditsPollInterval);
      creditsPollInterval = setInterval(() => {
        chrome.storage.session.get(["userId", "authToken", "tokenExpiresAt"], async (items) => {
          try {
            if (!items?.userId || !items?.authToken) return;
            let token = items.authToken;
            if (isTokenExpired(items.tokenExpiresAt)) {
              try {
                token = await refreshSupabaseToken();
              } catch (e) {
                logDiag("Poll: token refresh failed, using existing token", "WARN");
              }
            }
            const creditData = await fetchUserCredits(items.userId, token);
            chrome.storage.session.set({ userCredits: creditData.credits, userPlan: creditData.plan });
            chrome.storage.local.set({ userCredits: creditData.credits, userPlan: creditData.plan });
            if (userCreditsSpan) {
              const c = parseFloat(creditData.credits);
              userCreditsSpan.textContent = isNaN(c) ? "-- mins" : `${c.toFixed(1)} mins`;
              chrome.storage.local.get(["userPlan"], (storeItems) => {
                if (chrome.runtime.lastError) return;
                const plan = storeItems ? storeItems.userPlan : null;
                if (!isNaN(c) && c <= 0 && isActive) {
                  logDiag("Credits exhausted during active session. Stopping service...", "WARN");
                  showInlineError("No minutes left. Please upgrade!");
                  updateStatusUI("error");
                  if (masterToggle) masterToggle.checked = false;
                  isActive = false;
                  updateMasterBtn(false);
                  chrome.storage.local.set({ isEnabled: false }, () => {
                    if (chrome.runtime.lastError) ;
                  });
                  safeSendMessage({ action: "toggleService", isEnabled: false });
                  stopSessionTimer();
                }
              });
            }
          } catch (e) {
            const msg = e && e.message || "";
            const looksOffline = !navigator.onLine || msg.includes("NETWORK_ERROR") || msg.includes("Failed to fetch") || msg.includes("timed out");
            if (looksOffline) {
              logDiag("Poll: credits fetch failed \u2014 no internet, keeping cached credits", "WARN");
              showInlineError("No internet connection.");
            } else {
              logDiag(`Poll: credits fetch failed \u2014 keeping cached credits: ${msg}`, "WARN");
            }
          }
        });
      }, 5e3);
    }
    function stopCreditsPolling() {
      if (creditsPollInterval) {
        clearInterval(creditsPollInterval);
        creditsPollInterval = null;
      }
    }
    if (btnLogin) {
      btnLogin.addEventListener("click", () => {
        try {
          handleGoogleLogin().catch((e) => {
            logDiag(`Login promise rejection: ${e.message}`, "ERROR");
            showInlineError(`Login failed: ${e.message}`);
          });
        } catch (e) {
          logDiag(`Login click failed: ${e.message}`, "ERROR");
        }
      });
    }
    if (btnGoogleLogin) {
      btnGoogleLogin.addEventListener("click", () => {
        try {
          handleGoogleLogin().catch((e) => {
            logDiag(`Google Login promise rejection: ${e.message}`, "ERROR");
            showInlineError(`Login failed: ${e.message}`);
          });
        } catch (e) {
          logDiag(`Google Login click failed: ${e.message}`, "ERROR");
        }
      });
    }
    if (linkTos) {
      linkTos.addEventListener("click", (e) => {
        e.preventDefault();
        if (!PRICING_URL) {
          showInlineError("Could not reach the pricing page. Check your connection and try again.");
          return;
        }
        const base = PRICING_URL.replace("/pricing", "");
        chrome.tabs.create({ url: base + "/terms" });
      });
    }
    if (linkPrivacy) {
      linkPrivacy.addEventListener("click", (e) => {
        e.preventDefault();
        if (!PRICING_URL) {
          showInlineError("Could not reach the pricing page. Check your connection and try again.");
          return;
        }
        const base = PRICING_URL.replace("/pricing", "");
        chrome.tabs.create({ url: base + "/privacy" });
      });
    }
    if (btnUpgrade) {
      btnUpgrade.addEventListener("click", () => {
        if (!PRICING_URL) {
          showInlineError("Could not reach the pricing page. Check your connection and try again.");
          return;
        }
        chrome.tabs.create({ url: PRICING_URL });
      });
    }
    if (btnLogout) {
      let logoutConfirmPending = false;
      let logoutConfirmTimeoutId = null;
      const logoutOriginalText = btnLogout.textContent;
      btnLogout.addEventListener("click", () => {
        if (!logoutConfirmPending) {
          logoutConfirmPending = true;
          btnLogout.textContent = "Click again to confirm";
          btnLogout.classList.add("confirm-pending");
          logoutConfirmTimeoutId = setTimeout(() => {
            logoutConfirmPending = false;
            btnLogout.textContent = logoutOriginalText;
            btnLogout.classList.remove("confirm-pending");
          }, 3e3);
          return;
        }
        clearTimeout(logoutConfirmTimeoutId);
        logoutConfirmPending = false;
        btnLogout.textContent = logoutOriginalText;
        btnLogout.classList.remove("confirm-pending");
        try {
          stopCreditsPolling();
          stopSessionTimer();
          chrome.runtime.sendMessage({ action: "cancelTokenRefresh" });
          isActive = false;
          if (masterToggle) masterToggle.checked = false;
          updateMasterBtn(false);
          updateStatusUI("disconnected");
          chrome.storage.local.set({ isEnabled: false }, () => {
            if (chrome.runtime.lastError) {
            }
            chrome.storage.session.remove(["authToken", "refreshToken", "tokenExpiresAt", "userId", "userEmail", "userCredits", "userPlan"], () => {
              chrome.storage.local.remove(["authToken", "refreshToken", "tokenExpiresAt", "userId", "userEmail", "userCredits", "userPlan", "sessionStartTime", "activeTabId"], () => {
                if (chrome.runtime.lastError) {
                } else {
                  logDiag("User signed out and translation stopped.");
                  safeSendMessage({ action: "updateSettings", settings: { isEnabled: false, authToken: "" } });
                  safeSendMessage({ action: "toggleService", isEnabled: false });
                  safeSendMessage({ action: "stopCapture" });
                }
              });
            });
          });
        } catch (e) {
        }
      });
    }
    try {
      if (typeof chrome !== "undefined" && chrome.storage && chrome.storage.onChanged) {
        chrome.storage.onChanged.addListener((changes, area) => {
          try {
            if (area === "local" && changes) {
              if (changes.authToken !== void 0 || changes.userEmail !== void 0 || changes.userCredits !== void 0 || changes.userPlan !== void 0) {
                chrome.storage.session.get(["authToken", "userEmail", "userCredits", "userPlan"], (items) => {
                  try {
                    if (chrome.runtime.lastError) {
                      return;
                    }
                    updateAccountUI(items?.authToken, items?.userEmail, items?.userCredits, items?.userPlan);
                  } catch (cbErr) {
                  }
                });
              }
              if (changes.isEnabled !== void 0) {
                const newEnabled = !!changes.isEnabled.newValue;
                isActive = newEnabled;
                if (masterToggle) masterToggle.checked = newEnabled;
                updateMasterBtn(newEnabled);
                if (!newEnabled) {
                  stopSessionTimer();
                }
              }
              if (changes.status !== void 0) {
                const newStatus = changes.status.newValue || "disconnected";
                if (newStatus === "error") {
                  chrome.storage.local.get(["errorReason"], (items) => {
                    const reason = items && items.errorReason || null;
                    updateStatusUI(newStatus, reason);
                  });
                } else {
                  updateStatusUI(newStatus);
                }
              }
              if (changes.isTranslationPaused !== void 0) {
                safeSendMessage({ action: "getStatus" }, (response) => {
                  if (response && response.status) {
                    updateStatusUI(response.status);
                  }
                });
              }
              if (changes.targetLang !== void 0) {
                const newLang = changes.targetLang.newValue;
                if (newLang && newLang !== selectedLang) {
                  selectedLang = newLang;
                  const lang = LANGUAGES.find((l) => l.code === newLang);
                  if (lang) {
                    if (currentLangBadge) currentLangBadge.textContent = formatLangLabel(lang);
                    if (heroLangName) heroLangName.textContent = formatLangLabel(lang);
                  }
                  const updateSelection = (container) => {
                    if (container) {
                      container.querySelectorAll(".lang-tile").forEach((t) => {
                        t.classList.toggle("selected", t.dataset.code === newLang);
                      });
                    }
                  };
                  updateSelection(langGrid);
                  updateSelection(langPinnedGrid);
                  if (hiddenSelect) hiddenSelect.value = newLang;
                }
              }
            }
          } catch (cbErr) {
          }
        });
      }
    } catch (err) {
    }
    try {
      logDiag("Popup initialized.");
    } catch (e) {
    }
    function generateSinePath(width, height, frequency, phase, amplitude) {
      const points = [];
      const midY = height / 2;
      const step = 4;
      points.push(`M 0 ${midY}`);
      for (let x = 0; x <= width; x += step) {
        const windowScale = Math.sin(x / width * Math.PI);
        const y = midY + Math.sin(x * frequency + phase) * amplitude * windowScale;
        points.push(`L ${x} ${y}`);
      }
      return points.join(" ");
    }
    const _wave1 = document.querySelector(".wave-1");
    const _wave2 = document.querySelector(".wave-2");
    const _wave3 = document.querySelector(".wave-3");
    const _sigWave1 = document.querySelector(".sig-wave-1");
    const _sigWave2 = document.querySelector(".sig-wave-2");
    const _sigWave3 = document.querySelector(".sig-wave-3");
    function animateWaveform() {
      try {
        const activeState = (document.body.getAttribute("data-status") || "disconnected").toLowerCase();
        const isPausedState = statusText && statusText.textContent.toLowerCase().includes("paused");
        const now = Date.now();
        let targetSpeed1 = 0;
        let targetSpeed2 = 0;
        let targetSpeed3 = 0;
        if (activeState === "live") {
          if (isPausedState) {
            targetAmp = 3;
            targetSpeed1 = 0;
            targetSpeed2 = 0;
            targetSpeed3 = 0;
          } else {
            const hasRecentAudio = now - lastRmsTime < 300;
            let audioAmp = 0;
            if (hasRecentAudio) {
              audioAmp = Math.max(latestInputRms * 165, latestOutputRms * 165);
            }
            if (audioAmp > 1.5) {
              targetAmp = Math.min(22, audioAmp);
            } else {
              targetAmp = 5.5 + Math.sin(now / 250) * 2;
            }
            const speedMultiplier = 1 + currentAmp / 12;
            targetSpeed1 = -0.06 * speedMultiplier;
            targetSpeed2 = 0.08 * speedMultiplier;
            targetSpeed3 = -0.04 * speedMultiplier;
          }
        } else if (activeState === "connecting") {
          const statusTextLower = (statusText?.textContent || "").toLowerCase();
          const isReconnecting = statusTextLower.includes("reconnect") || statusTextLower.includes("retrying");
          if (isReconnecting) {
            targetAmp = 5 + Math.sin(now / 300) * 1.5;
            targetSpeed1 = -0.02;
            targetSpeed2 = 0.03;
            targetSpeed3 = -0.015;
          } else {
            targetAmp = 6 + Math.sin(now / 150) * 3;
            targetSpeed1 = -0.04;
            targetSpeed2 = 0.06;
            targetSpeed3 = -0.03;
          }
        } else if (activeState === "error") {
          targetAmp = 1 + Math.sin(now / 80) * 0.4;
          targetSpeed1 = -0.02;
          targetSpeed2 = 0.03;
          targetSpeed3 = -0.01;
        } else {
          targetAmp = 4.5 + Math.sin(now / 500) * 1.5;
          targetSpeed1 = -0.015;
          targetSpeed2 = 0.02;
          targetSpeed3 = -0.01;
        }
        currentAmp += (targetAmp - currentAmp) * 0.15;
        currentSpeed1 += (targetSpeed1 - currentSpeed1) * 0.1;
        currentSpeed2 += (targetSpeed2 - currentSpeed2) * 0.1;
        currentSpeed3 += (targetSpeed3 - currentSpeed3) * 0.1;
        wavePhase1 += currentSpeed1;
        wavePhase2 += currentSpeed2;
        wavePhase3 += currentSpeed3;
        const mainVisible = mainAppContent && !mainAppContent.classList.contains("hidden");
        const loginVisible = loginScreen && !loginScreen.classList.contains("hidden");
        if (mainVisible) {
          if (_wave1 || _wave2 || _wave3) {
            const width = 200;
            const height = 40;
            if (_wave1) _wave1.setAttribute("d", generateSinePath(width, height, 0.08, wavePhase1, currentAmp));
            if (_wave2) _wave2.setAttribute("d", generateSinePath(width, height, 0.12, wavePhase2, currentAmp * 0.7));
            if (_wave3) _wave3.setAttribute("d", generateSinePath(width, height, 0.06, wavePhase3, currentAmp * 0.5));
          }
        }
        if (loginVisible) {
          if (_sigWave1 || _sigWave2 || _sigWave3) {
            const sigWidth = 400;
            const sigHeight = 55;
            if (_sigWave1) _sigWave1.setAttribute("d", generateSinePath(sigWidth, sigHeight, 0.04, wavePhase1, currentAmp * 1.5));
            if (_sigWave2) _sigWave2.setAttribute("d", generateSinePath(sigWidth, sigHeight, 0.06, wavePhase2, currentAmp * 1.05));
            if (_sigWave3) _sigWave3.setAttribute("d", generateSinePath(sigWidth, sigHeight, 0.03, wavePhase3, currentAmp * 0.75));
          }
        }
        requestAnimationFrame(animateWaveform);
      } catch (e) {
        requestAnimationFrame(animateWaveform);
      }
    }
    requestAnimationFrame(animateWaveform);
    window.addEventListener("unload", () => {
      stopCreditsPolling();
      stopSessionTimer();
    });
  });
})();
//# sourceMappingURL=popup.js.map
