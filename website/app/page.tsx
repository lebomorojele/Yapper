"use client"

import { useEffect, useState } from "react"
import Image from "next/image"
import { LiquidGlassPill } from "@/components/liquid-glass-pill"

const SENTENCES = [
  "Speak naturally, Yapper transcribes locally,",
  "cleans up your words, and inserts them instantly.",
  "No cloud. No latency. Just your voice, perfected.",
]

const FULL_TEXT = SENTENCES.join(" ")
const DOWNLOAD_URL = "/downloads/Yapper-latest.dmg"

export default function Home() {
  const [scrollProgress, setScrollProgress] = useState(0)

  useEffect(() => {
    const handleScroll = () => {
      const scrollTop = window.scrollY
      const docHeight = document.documentElement.scrollHeight - window.innerHeight
      const progress = docHeight > 0 ? Math.min(scrollTop / docHeight, 1) : 0
      setScrollProgress(progress)
    }

    window.addEventListener("scroll", handleScroll, { passive: true })
    handleScroll()

    return () => window.removeEventListener("scroll", handleScroll)
  }, [])

  // Phase breakdown:
  // 0-15%:   Listening (dots)
  // 15-75%:  Transcribing (3 sentences, one at a time, typing in → clearing → next)
  // 75-85%:  Complete (checkmark)
  // 85-100%: Download button
  // 88%+:    Transcribed text fades in below

  const listeningEnd = 0.15
  const transcribingEnd = 0.75
  const completeEnd = 0.85

  type Phase = "listening" | "transcribing" | "complete" | "download"
  let bubbleState: Phase = "listening"
  if (scrollProgress < listeningEnd) bubbleState = "listening"
  else if (scrollProgress < transcribingEnd) bubbleState = "transcribing"
  else if (scrollProgress < completeEnd) bubbleState = "complete"
  else bubbleState = "download"

  const getTranscribingText = (): string => {
    const t = scrollProgress

    // Each sentence: short type-in window → dwell (full text) → clear gap
    const segments = [
      { typeStart: 0.15, typeEnd: 0.20, dwellEnd: 0.34, clearEnd: 0.37, idx: 0 },
      { typeStart: 0.37, typeEnd: 0.42, dwellEnd: 0.56, clearEnd: 0.59, idx: 1 },
      { typeStart: 0.59, typeEnd: 0.64, dwellEnd: 0.75, clearEnd: 0.75, idx: 2 },
    ]

    for (const s of segments) {
      if (t >= s.typeStart && t < s.typeEnd) {
        const p = (t - s.typeStart) / (s.typeEnd - s.typeStart)
        return SENTENCES[s.idx].slice(0, Math.ceil(p * SENTENCES[s.idx].length))
      }
      if (t >= s.typeEnd && t < s.dwellEnd) return SENTENCES[s.idx]
      if (t >= s.dwellEnd && t < s.clearEnd) return ""
    }

    return ""
  }

  const currentText = bubbleState === "transcribing" ? getTranscribingText() : undefined

  const parallaxOffset = (() => {
    if (scrollProgress < listeningEnd) return (scrollProgress / listeningEnd) * 15
    if (scrollProgress < transcribingEnd) return 15
    const post = (scrollProgress - transcribingEnd) / (1 - transcribingEnd)
    return 15 + post * 35
  })()

  const showFooter = scrollProgress >= 0.75
  const showTranscribedText = scrollProgress >= 0.88
  const showAppIcon = scrollProgress >= 0.85

  const handleDownload = () => {
    window.location.href = DOWNLOAD_URL
  }

  return (
    <div className="relative">
      <div style={{ height: "500vh" }} />

      {/* Background */}
      <div className="fixed inset-0 z-0 overflow-hidden">
        <div
          className="absolute w-full transition-transform duration-200 ease-out"
          style={{ height: "150%", top: `-${parallaxOffset}%` }}
        >
          <Image
            src="/images/ceiling-painting.jpg"
            alt=""
            fill
            className="object-cover"
            priority
            quality={95}
            sizes="100vw"
          />
        </div>
        <div
          className="absolute inset-0 pointer-events-none"
          style={{
            background: "radial-gradient(ellipse at center, transparent 40%, rgba(0,0,0,0.25) 100%)",
          }}
        />
      </div>

      {/* App icon - appears above the download bubble */}
      <div
        className="fixed z-40 left-1/2 transition-all duration-700 pointer-events-none"
        style={{
          top: "36%",
          transform: "translate(-50%, -50%)",
          opacity: showAppIcon ? 1 : 0,
        }}
      >
        <Image
          src="/images/yapper-icon.png"
          alt="Yapper"
          width={80}
          height={80}
          className="rounded-[22%] shadow-xl"
          style={{ filter: "drop-shadow(0 8px 24px rgba(0,0,0,0.4))" }}
        />
      </div>

      {/* Single bubble - centered, internal content changes with scroll */}
      <div className="fixed inset-0 z-40 flex items-center justify-center pointer-events-none">
        <div className="pointer-events-auto">
          <LiquidGlassPill
            text={bubbleState === "transcribing" ? currentText : undefined}
            state={bubbleState}
            onClick={bubbleState === "download" ? handleDownload : undefined}
          />
        </div>
      </div>

      {/* Transcribed text - appears below the download bubble */}
      <div
        className="fixed inset-x-0 z-30 flex flex-col items-center justify-center px-8 transition-all duration-1000 pointer-events-none"
        style={{
          top: "60%",
          opacity: showTranscribedText ? 1 : 0,
          transform: showTranscribedText ? "translateY(0)" : "translateY(20px)",
        }}
      >
        <p
          className="max-w-xl text-center text-lg md:text-2xl font-light leading-relaxed text-white/90"
          style={{
            textShadow: "0 2px 30px rgba(0,0,0,0.8), 0 4px 60px rgba(0,0,0,0.6)",
          }}
        >
          {FULL_TEXT}
        </p>
      </div>

      {/* Footer */}
      <div
        className="fixed bottom-8 inset-x-0 z-50 text-center transition-all duration-700 pointer-events-none"
        style={{
          opacity: showFooter ? 1 : 0,
          transform: showFooter ? "translateY(0)" : "translateY(20px)",
        }}
      >
        <p
          className="text-white/70 text-sm tracking-wide pointer-events-auto"
          style={{ textShadow: "0 2px 20px rgba(0,0,0,0.9)" }}
        >
          <span className="font-medium text-white/90">Yapper</span>
          <span className="mx-3 text-white/40">|</span>
          <a
            href={DOWNLOAD_URL}
            className="hover:text-white/90 transition-colors underline underline-offset-2"
          >
            Download
          </a>
          <span className="mx-3 text-white/40">|</span>
          Voice to text. Local. Private.
        </p>
      </div>

      {/* Scroll indicator */}
      <div
        className="fixed bottom-10 left-1/2 -translate-x-1/2 z-40 transition-opacity duration-500 pointer-events-none"
        style={{ opacity: scrollProgress < 0.03 ? 1 : 0 }}
      >
        <div className="flex flex-col items-center gap-2 text-white/50">
          <span className="text-xs tracking-[0.2em] uppercase">Scroll</span>
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" className="animate-bounce">
            <path d="M12 5v14M12 19l-5-5M12 19l5-5" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
          </svg>
        </div>
      </div>
    </div>
  )
}
