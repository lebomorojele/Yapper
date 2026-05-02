const capsuleEl = document.getElementById("yapper-capsule");
const liveWordEl = document.getElementById("live-word");
const timerEl = document.getElementById("timer");
const dictationTextEl = document.getElementById("dictation-text");
const outputTextEl = document.getElementById("output-text");
const dockYapperEl = document.getElementById("dock-yapper");
const optionButtons = [...document.querySelectorAll(".capsule-state--options button")];

const rawText = "Yapper lives in the macOS menu bar, records when you ask, and turns rough thoughts into clean text wherever your cursor is.";
const polishedText = "Yapper sits quietly in the menu bar, wakes instantly, and turns natural speech into clean text for Notes, Messages, email, and prompts.";
const words = rawText.replace(/[,.]/g, "").split(/\s+/);

let runId = 0;
let wordIndex = 0;
let seconds = 3;

function wait(ms) {
  return new Promise((resolve) => window.setTimeout(resolve, ms));
}

function setState(state) {
  capsuleEl.dataset.state = state;
}

async function typeText(target, text, speed, currentRunId) {
  target.textContent = "";

  for (const char of text) {
    if (currentRunId !== runId) {
      return;
    }
    target.textContent += char;
    await wait(speed);
  }
}

async function runLoop() {
  runId += 1;
  const currentRunId = runId;

  seconds = 3;
  timerEl.textContent = "0:03";
  outputTextEl.textContent = "";
  setState("listening");
  void typeText(dictationTextEl, rawText, 18, currentRunId);

  await wait(2800);
  if (currentRunId !== runId) return;

  setState("polishing");
  await wait(950);
  if (currentRunId !== runId) return;

  setState("options");
  await typeText(outputTextEl, polishedText, 12, currentRunId);
  await wait(2300);
  if (currentRunId !== runId) return;

  runLoop();
}

function tickRecording() {
  if (capsuleEl.dataset.state !== "listening") {
    return;
  }

  seconds += 1;
  wordIndex = (wordIndex + 1) % words.length;
  liveWordEl.textContent = words[wordIndex];
  timerEl.textContent = `0:${String(seconds).padStart(2, "0")}`;
}

optionButtons.forEach((button) => {
  button.addEventListener("click", () => {
    optionButtons.forEach((item) => item.classList.remove("is-selected"));
    button.classList.add("is-selected");
  });
});

dockYapperEl.addEventListener("click", () => {
  dockYapperEl.style.animation = "none";
  void dockYapperEl.offsetHeight;
  dockYapperEl.style.animation = "";
  runLoop();
});

window.addEventListener("keydown", (event) => {
  if (capsuleEl.dataset.state !== "options") {
    return;
  }

  const button = optionButtons[Number(event.key) - 1];
  if (button) {
    button.click();
  }
});

window.setInterval(tickRecording, 650);
runLoop();
