"use client";

import { useEffect, useState } from "react";

const examples = [
  {
    label: "A quick message",
    spoken:
      "hey Maya let's move our catch up to Thursday I have something good to show you",
    result:
      "Hey Maya, let's move our catch-up to Thursday. I have something good to show you.",
  },
  {
    label: "The next idea",
    spoken:
      "what if the best part of the product was how little you had to think about using it",
    result:
      "What if the best part of the product was how little you had to think about using it?",
  },
  {
    label: "A little reminder",
    spoken: "remember to book the little place by the ocean for next weekend",
    result: "Remember to book the little place by the ocean for next weekend.",
  },
];

export function VoiceDemo() {
  const [exampleIndex, setExampleIndex] = useState(0);
  const [phase, setPhase] = useState<"ready" | "listening" | "done">("ready");
  const [wordCount, setWordCount] = useState(0);
  const example = examples[exampleIndex];
  const words = example.spoken.split(" ");

  useEffect(() => {
    if (phase !== "listening") return;
    if (wordCount >= words.length) {
      const timer = setTimeout(() => setPhase("done"), 600);
      return () => clearTimeout(timer);
    }
    const timer = setTimeout(() => setWordCount((count) => count + 1), 125);
    return () => clearTimeout(timer);
  }, [phase, wordCount, words.length]);

  function play() {
    setWordCount(0);
    setPhase("listening");
  }

  return (
    <div className="demo-stage">
      <div className="demo-tabs" role="group" aria-label="Demo example">
        {examples.map((item, index) => (
          <button
            key={item.label}
            aria-pressed={exampleIndex === index}
            onClick={() => {
              setExampleIndex(index);
              setPhase("ready");
              setWordCount(0);
            }}
          >
            {item.label}
          </button>
        ))}
      </div>
      <div className="letter-window">
        <div className="window-toolbar">
          <div className="traffic-lights" aria-hidden="true">
            <i />
            <i />
            <i />
          </div>
          <span>A little note</span>
          <span aria-hidden="true">↗</span>
        </div>
        <div className="letter-meta">
          <span>To</span>
          <span>{exampleIndex === 0 ? "Maya" : "My future self"}</span>
          <span className="letter-date">JUST NOW</span>
        </div>
        <div className="letter-body">
          <span className="letter-greeting">
            {exampleIndex === 0 ? "Hey, a thought…" : "Before I forget…"}
          </span>
          <p className={phase === "done" ? "finished-text" : ""}>
            {phase === "ready" ? (
              <span className="placeholder-text">
                Your next thought goes here
                <span className="typing-caret" />
              </span>
            ) : phase === "done" ? (
              example.result
            ) : (
              <>
                {words.slice(0, wordCount).join(" ")}
                <span className="typing-caret" />
              </>
            )}
          </p>
        </div>
        <div className="letter-footer">
          <span>Written with a voice.</span>
          <span aria-hidden="true">↵</span>
        </div>
      </div>
      <button
        className={`demo-pill ${phase}`}
        onClick={play}
        disabled={phase === "listening"}
        aria-label={phase === "done" ? "Replay voice demo" : "Play voice demo"}
      >
        <span className="waveform" aria-hidden="true">
          {[0, 1, 2, 3, 4, 5, 6].map((index) => (
            <i key={index} style={{ animationDelay: `${index * 90}ms` }} />
          ))}
        </span>
        <span>
          {phase === "listening"
            ? "Listening to your thought…"
            : phase === "done"
              ? "That's your thought, typed."
              : "Give it a little yap"}
        </span>
        <span className="pill-key" aria-hidden="true">
          {phase === "done" ? "↻" : "fn"}
        </span>
      </button>
      <p className="demo-disclosure">
        {phase === "listening"
          ? "An example of the Yapper flow"
          : phase === "done"
            ? "Play again, or try another thought above"
            : "Play the demo. No microphone needed."}
      </p>
      <span className="demo-sticker" aria-hidden="true">
        SPEAK
        <br />
        YOUR
        <br />
        <em>MIND.</em>
      </span>
    </div>
  );
}
