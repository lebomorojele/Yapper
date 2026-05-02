const clockEl = document.getElementById("clock");
const activeAppLabelEl = document.getElementById("active-app-label");
const commandEl = document.getElementById("terminal-command");
const outputEl = document.getElementById("terminal-output");
const textpadOutputEl = document.getElementById("textpad-output");
const desktopEl = document.querySelector(".desktop");
const yapperOverlayEl = document.querySelector(".yapper-overlay");
const yapperPillEl = document.getElementById("yapper-pill");
const yapperLiveTextEl = document.getElementById("yapper-live-text");
const yapperSelectButtons = [...document.querySelectorAll(".select-options button")];
const creditsLogoButtonEl = document.getElementById("credits-logo-button");
const creditsCopyHintEl = document.getElementById("credits-copy-hint");

const windows = [...document.querySelectorAll("[data-window]")];
const openButtons = [...document.querySelectorAll("[data-open-window]")];
const actionButtons = [...document.querySelectorAll("[data-window-action]")];
const dockButtons = [...document.querySelectorAll(".dock__item[data-open-window]")];
const resizeHandles = [...document.querySelectorAll("[data-resize-handle]")];

const installScript = {
  command: "brew install yapper",
  lines: [
    { text: "==> Downloading https://ghcr.io/v2/homebrew/core/yapper/manifests/0.1.0", className: "terminal-output__line--muted" },
    { text: "==> Pouring yapper--0.1.0.arm64_sequoia.bottle.tar.gz", className: "terminal-output__line--muted" },
    { text: "/opt/homebrew/Cellar/yapper/0.1.0: 12 files, 4.2MB", className: "terminal-output__line--success" },
    { text: "==> Caveats", className: "terminal-output__line--accent" },
    { text: "Press fn to dictate. Press fn fn for smart mode.", className: "terminal-output__line--green" },
    { text: "", className: "" },
    { text: "                                    ", className: "terminal-output__line--muted" },
    { text: "                                    ", className: "terminal-output__line--muted" },
    { text: "██  ██ ▄▄▄  ▄▄▄▄  ▄▄▄▄  ▄▄▄▄▄ ▄▄▄▄  ", className: "terminal-output__line--success" },
    { text: " ▀██▀ ██▀██ ██▄█▀ ██▄█▀ ██▄▄  ██▄█▄ ", className: "terminal-output__line--success" },
    { text: "  ██  ██▀██ ██    ██    ██▄▄▄ ██ ██ ", className: "terminal-output__line--success" },
    { text: "                                    ", className: "terminal-output__line--muted" },
    { text: "visitor@yapper-demo:~$ yapper", className: "terminal-output__line--success" },
    { text: "Listening...", className: "terminal-output__line--green" }
  ]
};

const textpadSeedLines = [
  "Yapper is a native macOS dictation app built for people who want to speak and keep moving.",
  "",
  "About Yapper:"
];

const textpadSummaryAdds = [
  "It lives in the menu bar, stays out of the way, and appears only when you invoke it.",
  "It can clean up rough speech into something polished for Slack, email, chat, or a prompt.",
  "The magic is speed: record, transcribe, rewrite if needed, and drop the result back into your flow."
];

let highestZ = 40;
let installLoopHandle;
let terminalAutoPresentDisabled = false;
let yapperUserMoved = false;
let textpadSummaryIndex = 0;
let textpadTypingRun = 0;
let creditsCopyResetHandle;
let spokenWordIndex = 0;
let currentSpokenWords = [];

function isMobileLayout() {
  return window.innerWidth <= 768;
}

function isCompactLandscapeLayout() {
  return window.innerHeight <= 500 && window.innerWidth <= 980;
}

function isSmallScreenLayout() {
  return isMobileLayout() || isCompactLandscapeLayout();
}

function setDockRunning(name, isRunning) {
  dockButtons.forEach((button) => {
    if (button.dataset.openWindow === name) {
      button.classList.toggle("is-running", isRunning);
    }
  });
}

function updateDockActive(name) {
  dockButtons.forEach((button) => {
    button.classList.toggle("is-active", button.dataset.openWindow === name);
  });
}

function bringToFront(win) {
  highestZ += 1;
  win.style.zIndex = String(highestZ);
}

function updateActiveAppLabel(name) {
  const win = document.querySelector(`[data-window="${name}"]`);
  const label = win?.dataset.windowLabel || "Terminal";
  activeAppLabelEl.textContent = label;
}

function syncActiveAppFromVisibleWindows(preferredName) {
  const preferredWindow = preferredName
    ? document.querySelector(`[data-window="${preferredName}"]`)
    : null;

  if (preferredWindow?.classList.contains("is-active")) {
    updateActiveAppLabel(preferredName);
    updateDockActive(preferredName);
    return;
  }

  const topVisibleWindow = windows
    .filter((win) => win.classList.contains("is-active"))
    .sort((a, b) => (Number(b.style.zIndex || 0) - Number(a.style.zIndex || 0)))[0];

  if (topVisibleWindow) {
    const name = topVisibleWindow.dataset.window;
    updateActiveAppLabel(name);
    updateDockActive(name);
    return;
  }

  updateActiveAppLabel("terminal");
  updateDockActive("terminal");
}

function clampWindow(win) {
  const desktopRect = desktopEl.getBoundingClientRect();
  const rect = win.getBoundingClientRect();
  const left = Math.min(Math.max(rect.left - desktopRect.left, 0), Math.max(desktopRect.width - rect.width, 0));
  const top = Math.min(Math.max(rect.top - desktopRect.top, 0), Math.max(desktopRect.height - rect.height, 0));

  win.style.left = `${left}px`;
  win.style.top = `${top}px`;
}

function resetCreditsWindowPosition(win) {
  if (!win || win.dataset.window !== "credits" || !isSmallScreenLayout()) {
    return;
  }

  win.style.left = "50%";
  win.style.top = "50%";
  win.style.right = "auto";
  win.style.transform = "translate(-50%, -50%)";
}

function isWindowActive(name) {
  return document.querySelector(`[data-window="${name}"]`)?.classList.contains("is-active") ?? false;
}

function openWindow(name, options = {}) {
  const { userInitiated = false } = options;
  const win = document.querySelector(`[data-window="${name}"]`);
  if (!win) {
    return;
  }

  if (name === "terminal" && userInitiated) {
    terminalAutoPresentDisabled = false;
  }

  if (name === "credits") {
    resetCreditsWindowPosition(win);
  }

  win.classList.add("is-active");
  bringToFront(win);
  setDockRunning(name, true);
  updateActiveAppLabel(name);
  updateDockActive(name);

  if (isSmallScreenLayout()) {
    window.requestAnimationFrame(() => {
      if (name !== "credits") {
        win.scrollIntoView({ block: "nearest", inline: "nearest", behavior: "smooth" });
      }
    });
  }
}

function hideWindow(name, options = {}) {
  const { userInitiated = false } = options;
  const win = document.querySelector(`[data-window="${name}"]`);
  if (!win) {
    return;
  }

  if (name === "terminal" && userInitiated) {
    terminalAutoPresentDisabled = true;
  }

  win.classList.remove("is-active");
  setDockRunning(name, true);
  syncActiveAppFromVisibleWindows(name);
}

function initializePositions() {
  windows.forEach((win) => {
    const left = isSmallScreenLayout()
      ? Number(win.dataset.mobileLeft || win.dataset.initialLeft || 0)
      : Number(win.dataset.initialLeft || 0);
    const top = isSmallScreenLayout()
      ? Number(win.dataset.mobileTop || win.dataset.initialTop || 0)
      : Number(win.dataset.initialTop || 0);
    win.style.left = `${left}px`;
    win.style.top = `${top}px`;
    bringToFront(win);
  });

  if (isSmallScreenLayout()) {
    document.querySelector('[data-window="terminal"]')?.classList.add("is-active");
    document.querySelector('[data-window="textpad"]')?.classList.add("is-active");
    document.querySelector('[data-window="credits"]')?.classList.remove("is-active");
  }

  updateActiveAppLabel("terminal");
  updateDockActive("terminal");
}

function setupDragging() {
  const desktopRect = () => desktopEl.getBoundingClientRect();

  windows.forEach((win) => {
    const handle = win.querySelector("[data-drag-handle]");
    if (!handle) {
      return;
    }

    handle.addEventListener("pointerdown", (event) => {
      if (event.target.closest("button")) {
        return;
      }

      event.preventDefault();
      openWindow(win.dataset.window);
      handle.classList.add("is-dragging");

      const desktopBounds = desktopRect();
      const computedStyle = window.getComputedStyle(win);

      if (computedStyle.transform !== "none") {
        const rect = win.getBoundingClientRect();
        win.style.left = `${rect.left - desktopBounds.left}px`;
        win.style.top = `${rect.top - desktopBounds.top}px`;
        win.style.right = "auto";
        win.style.transform = "none";
      }

      const rect = win.getBoundingClientRect();
      const offsetX = event.clientX - rect.left;
      const offsetY = event.clientY - rect.top;

      const onMove = (moveEvent) => {
        const nextLeft = Math.min(
          Math.max(moveEvent.clientX - desktopBounds.left - offsetX, 0),
          Math.max(desktopBounds.width - rect.width, 0)
        );
        const nextTop = Math.min(
          Math.max(moveEvent.clientY - desktopBounds.top - offsetY, 0),
          Math.max(desktopBounds.height - rect.height, 0)
        );

        win.style.left = `${nextLeft}px`;
        win.style.top = `${nextTop}px`;
      };

      const onUp = () => {
        handle.classList.remove("is-dragging");
        window.removeEventListener("pointermove", onMove);
        window.removeEventListener("pointerup", onUp);
      };

      window.addEventListener("pointermove", onMove);
      window.addEventListener("pointerup", onUp);
    });
  });
}

function setupResizing() {
  const desktopRect = () => desktopEl.getBoundingClientRect();

  resizeHandles.forEach((handle) => {
    const win = handle.closest("[data-window]");
    if (!win) {
      return;
    }

    handle.addEventListener("pointerdown", (event) => {
      if (window.innerWidth <= 1100) {
        return;
      }

      event.preventDefault();
      event.stopPropagation();
      openWindow(win.dataset.window);

      const rect = win.getBoundingClientRect();
      const desktopBounds = desktopRect();
      const startX = event.clientX;
      const startY = event.clientY;
      const startWidth = rect.width;
      const startHeight = rect.height;
      const minWidth = Math.max(parseFloat(getComputedStyle(win).minWidth) || 0, 280);
      const minHeight = Math.max(parseFloat(getComputedStyle(win).minHeight) || 0, 180);
      const maxWidth = desktopBounds.width - (rect.left - desktopBounds.left);
      const maxHeight = desktopBounds.height - (rect.top - desktopBounds.top);

      const onMove = (moveEvent) => {
        const nextWidth = Math.min(
          Math.max(startWidth + (moveEvent.clientX - startX), minWidth),
          maxWidth
        );
        const nextHeight = Math.min(
          Math.max(startHeight + (moveEvent.clientY - startY), minHeight),
          maxHeight
        );

        win.style.width = `${nextWidth}px`;
        win.style.height = `${nextHeight}px`;
      };

      const onUp = () => {
        window.removeEventListener("pointermove", onMove);
        window.removeEventListener("pointerup", onUp);
      };

      window.addEventListener("pointermove", onMove);
      window.addEventListener("pointerup", onUp);
    });
  });
}

function centerYapperOverlay() {
  if (isMobileLayout()) {
    yapperUserMoved = false;
    yapperOverlayEl.style.left = "50%";
    yapperOverlayEl.style.right = "auto";
    yapperOverlayEl.style.top = "44px";
    return;
  }

  if (isCompactLandscapeLayout()) {
    yapperUserMoved = false;
    yapperOverlayEl.style.left = "50%";
    yapperOverlayEl.style.right = "auto";
    yapperOverlayEl.style.top = "38px";
    return;
  }

  yapperUserMoved = false;
  const desktopRect = desktopEl.getBoundingClientRect();
  const pillRect = yapperPillEl.getBoundingClientRect();
  const left = Math.max((desktopRect.width - pillRect.width) / 2, 0);
  yapperOverlayEl.style.left = `${left}px`;
  yapperOverlayEl.style.right = "auto";
  yapperOverlayEl.style.top = "50px";
}

function clampYapperOverlay() {
  const desktopRect = desktopEl.getBoundingClientRect();
  const pillRect = yapperPillEl.getBoundingClientRect();
  const overlayRect = yapperOverlayEl.getBoundingClientRect();

  const left = Math.min(
    Math.max(overlayRect.left - desktopRect.left, 0),
    Math.max(desktopRect.width - pillRect.width, 0)
  );
  const top = Math.min(
    Math.max(overlayRect.top - desktopRect.top, 0),
    Math.max(desktopRect.height - pillRect.height, 0)
  );

  yapperOverlayEl.style.left = `${left}px`;
  yapperOverlayEl.style.top = `${top}px`;
}

function setupYapperDragging() {
  yapperPillEl.addEventListener("pointerdown", (event) => {
    if (window.innerWidth <= 1100 || isMobileLayout()) {
      return;
    }

    event.preventDefault();
    yapperPillEl.classList.add("is-dragging");

    const desktopRect = desktopEl.getBoundingClientRect();
    const overlayRect = yapperOverlayEl.getBoundingClientRect();
    const pillRect = yapperPillEl.getBoundingClientRect();
    const offsetX = event.clientX - overlayRect.left;
    const offsetY = event.clientY - overlayRect.top;

    const onMove = (moveEvent) => {
      yapperUserMoved = true;

      const nextLeft = Math.min(
        Math.max(moveEvent.clientX - desktopRect.left - offsetX, 0),
        Math.max(desktopRect.width - pillRect.width, 0)
      );
      const nextTop = Math.min(
        Math.max(moveEvent.clientY - desktopRect.top - offsetY, 0),
        Math.max(desktopRect.height - pillRect.height, 0)
      );

      yapperOverlayEl.style.left = `${nextLeft}px`;
      yapperOverlayEl.style.top = `${nextTop}px`;
    };

    const onUp = () => {
      yapperPillEl.classList.remove("is-dragging");
      window.removeEventListener("pointermove", onMove);
      window.removeEventListener("pointerup", onUp);
    };

    window.addEventListener("pointermove", onMove);
    window.addEventListener("pointerup", onUp);
  });
}

function wait(ms) {
  return new Promise((resolve) => window.setTimeout(resolve, ms));
}

async function copyInstallCommand() {
  const installCommand = "brew install yapper";

  try {
    if (navigator.clipboard?.writeText) {
      await navigator.clipboard.writeText(installCommand);
    } else {
      const input = document.createElement("textarea");
      input.value = installCommand;
      document.body.appendChild(input);
      input.select();
      document.execCommand("copy");
      input.remove();
    }

    if (creditsCopyHintEl) {
      creditsCopyHintEl.textContent = "copied: brew install yapper";
      creditsCopyHintEl.classList.add("is-copied");
      window.clearTimeout(creditsCopyResetHandle);
      creditsCopyResetHandle = window.setTimeout(() => {
        creditsCopyHintEl.textContent = "click logo to copy `brew install yapper`";
        creditsCopyHintEl.classList.remove("is-copied");
      }, 1800);
    }
  } catch {
    if (creditsCopyHintEl) {
      creditsCopyHintEl.textContent = "brew install yapper";
      creditsCopyHintEl.classList.add("is-copied");
      window.clearTimeout(creditsCopyResetHandle);
      creditsCopyResetHandle = window.setTimeout(() => {
        creditsCopyHintEl.textContent = "click logo to copy `brew install yapper`";
        creditsCopyHintEl.classList.remove("is-copied");
      }, 1800);
    }
  }
}

async function typeCommand(text) {
  commandEl.textContent = "";
  for (const char of text) {
    commandEl.textContent += char;
    await wait(48);
  }
}

async function printLines(lines) {
  outputEl.innerHTML = "";

  for (const line of lines) {
    const row = document.createElement("div");
    row.className = `terminal__line ${line.className}`.trim();
    row.textContent = line.text;
    outputEl.appendChild(row);
    await wait(line.text ? 360 : 150);
  }
}

async function typeTextpadLine(line, runId) {
  const paragraph = document.createElement("p");
  textpadOutputEl.appendChild(paragraph);

  if (!line) {
    paragraph.innerHTML = "&nbsp;";
    return;
  }

  for (const char of line) {
    if (runId !== textpadTypingRun) {
      return;
    }

    paragraph.textContent += char;
    await wait(12);
  }
}

async function renderTextpadFrame() {
  textpadTypingRun += 1;
  const runId = textpadTypingRun;
  textpadOutputEl.innerHTML = "";

  const lines = [
    ...textpadSeedLines,
    ...textpadSummaryAdds.slice(0, textpadSummaryIndex + 1).map((line, index) => `${index + 1}. ${line}`)
  ];

  for (const line of lines) {
    await typeTextpadLine(line, runId);
    if (runId !== textpadTypingRun) {
      return;
    }
  }
}

function wordsForCurrentOutputLine() {
  const line = textpadSummaryAdds[textpadSummaryIndex] || textpadSummaryAdds[0];
  return line
    .replace(/[,.:;]/g, "")
    .split(/\s+/)
    .map((word) => word.trim())
    .filter(Boolean);
}

function showYapperCompact(index) {
  currentSpokenWords = wordsForCurrentOutputLine();
  spokenWordIndex = 0;
  yapperPillEl.classList.add("is-visible");
  yapperPillEl.classList.remove("is-processing", "is-complete");
  yapperPillEl.dataset.mode = "speaking";
  yapperLiveTextEl.textContent = currentSpokenWords[spokenWordIndex] || "Yapper";
}

function showYapperProcessing() {
  yapperPillEl.classList.remove("is-recording", "is-complete");
  yapperPillEl.classList.add("is-visible", "is-processing");
  yapperPillEl.dataset.mode = "thinking";
}

function showYapperSelect() {
  yapperPillEl.classList.remove("is-recording", "is-processing", "is-complete");
  yapperPillEl.classList.add("is-visible");
  yapperPillEl.dataset.mode = "select";
}

function showYapperComplete() {
  yapperPillEl.classList.remove("is-recording", "is-processing");
  yapperPillEl.classList.add("is-visible", "is-complete");
  yapperPillEl.dataset.mode = "speaking";
  if (!currentSpokenWords.length) {
    currentSpokenWords = wordsForCurrentOutputLine();
  }
  yapperLiveTextEl.textContent = currentSpokenWords[spokenWordIndex] || "Yapper";
}

function hideYapper() {
  yapperPillEl.classList.remove("is-visible", "is-recording", "is-processing", "is-complete");
  yapperPillEl.dataset.mode = "idle";
}

async function runInstallLoop() {
  clearTimeout(installLoopHandle);
  if (!terminalAutoPresentDisabled && !isWindowActive("credits")) {
    openWindow("terminal");
  }

  showYapperCompact(textpadSummaryIndex);
  void renderTextpadFrame();

  await typeCommand(installScript.command);
  await wait(260);
  await printLines(installScript.lines);

  installLoopHandle = window.setTimeout(async () => {
    hideYapper();
    textpadSummaryIndex = (textpadSummaryIndex + 1) % textpadSummaryAdds.length;
    await wait(260);
    runInstallLoop();
  }, 700);
}

function tickClock() {
  const now = new Date();
  const month = now.toLocaleString([], { month: "short" });
  const day = now.toLocaleString([], { day: "numeric" });
  const time = now.toLocaleTimeString([], { hour: "numeric", minute: "2-digit" });
  clockEl.textContent = `${month} ${day} ${time}`;
}

openButtons.forEach((button) => {
  button.addEventListener("click", () => {
    openWindow(button.dataset.openWindow, { userInitiated: true });
  });
});

creditsLogoButtonEl?.addEventListener("click", () => {
  void copyInstallCommand();
});

actionButtons.forEach((button) => {
  button.addEventListener("click", () => {
    hideWindow(button.dataset.target, { userInitiated: true });
  });
});

windows.forEach((win) => {
  win.addEventListener("pointerdown", () => {
    openWindow(win.dataset.window);
  });
});

window.addEventListener("resize", () => {
  if (window.innerWidth > 1100) {
    windows.forEach((win) => clampWindow(win));
  }

  if (isSmallScreenLayout()) {
    centerYapperOverlay();
    syncActiveAppFromVisibleWindows();
    return;
  }

  if (yapperUserMoved) {
    clampYapperOverlay();
  } else {
    centerYapperOverlay();
  }
});

window.addEventListener("keydown", (event) => {
  if (yapperPillEl.dataset.mode !== "select") {
    return;
  }

  const button = yapperSelectButtons.find((item) => item.dataset.key === event.key);
  if (!button) {
    return;
  }

  yapperSelectButtons.forEach((item) => item.classList.remove("active"));
  button.classList.add("active");
});

window.setInterval(() => {
  if (yapperPillEl.dataset.mode !== "speaking") {
    return;
  }

  if (!currentSpokenWords.length) {
    currentSpokenWords = wordsForCurrentOutputLine();
  }

  spokenWordIndex = (spokenWordIndex + 1) % currentSpokenWords.length;
  yapperLiveTextEl.textContent = currentSpokenWords[spokenWordIndex];
  yapperLiveTextEl.style.animation = "none";
  void yapperLiveTextEl.offsetHeight;
  yapperLiveTextEl.style.animation = "";
}, 420);

tickClock();
window.setInterval(tickClock, 30000);
initializePositions();
centerYapperOverlay();
setupDragging();
setupResizing();
setupYapperDragging();
void renderTextpadFrame();
runInstallLoop();
