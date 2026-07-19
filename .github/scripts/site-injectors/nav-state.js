(() => {
  const storageKey = "zensical-nav-state-v1";
  let lastSignature = "";

  const getToggles = () =>
    Array.from(document.querySelectorAll("input.md-nav__toggle.md-toggle[id]"));

  const getPrimaryList = () =>
    document.querySelector("nav.md-nav--primary > ul.md-nav__list");

  const applyDefaultTopLevelState = (toggles) => {
    const primaryList = getPrimaryList();
    if (!primaryList) {
      return;
    }

    const topLevelToggles = Array.from(
      primaryList.querySelectorAll(
        ":scope > li > input.md-nav__toggle.md-toggle[id]",
      ),
    );
    const topLevelIds = new Set(topLevelToggles.map((toggle) => toggle.id));

    for (const toggle of toggles) {
      toggle.checked = topLevelIds.has(toggle.id);
    }
  };

  const restoreState = (toggles) => {
    const raw = localStorage.getItem(storageKey);
    if (!raw) {
      applyDefaultTopLevelState(toggles);
      return;
    }

    try {
      const state = JSON.parse(raw);
      for (const toggle of toggles) {
        if (Object.hasOwn(state, toggle.id)) {
          toggle.checked = !!state[toggle.id];
        }
      }
    } catch {
      applyDefaultTopLevelState(toggles);
    }
  };

  const persistState = (toggles) => {
    const state = {};
    for (const toggle of toggles) {
      state[toggle.id] = !!toggle.checked;
    }
    localStorage.setItem(storageKey, JSON.stringify(state));
  };

  const initialize = () => {
    const toggles = getToggles();
    if (toggles.length === 0) {
      return;
    }

    const signature = toggles.map((toggle) => toggle.id).join("|");
    if (signature === lastSignature) {
      return;
    }

    lastSignature = signature;
    restoreState(toggles);
    for (const toggle of toggles) {
      if (toggle.dataset.navStateBound === "true") {
        continue;
      }

      toggle.dataset.navStateBound = "true";
      toggle.addEventListener("change", () => persistState(getToggles()));
    }
  };

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initialize, { once: true });
  } else {
    initialize();
  }

  setInterval(initialize, 500);
})();
