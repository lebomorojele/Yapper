"use client"

import { cn } from "@/lib/utils"
import { useIsMobile } from "@/hooks/use-mobile"

type PillState = "listening" | "transcribing" | "complete" | "download"

interface LiquidGlassPillProps {
  text?: string
  state?: PillState
  className?: string
  onClick?: () => void
}

export function LiquidGlassPill({
  text,
  state = "listening",
  className,
  onClick,
}: LiquidGlassPillProps) {
  const showDots = state === "listening"
  const isComplete = state === "complete"
  const isDownload = state === "download"
  const isMobile = useIsMobile()

  const Component = onClick ? "button" : "div"

  return (
    <Component
      onClick={onClick}
      className={cn(
        "relative inline-flex items-center justify-center",
        "h-11 rounded-full",
        "transition-all duration-500 ease-out",
        onClick && "cursor-pointer hover:scale-[1.02] active:scale-[0.98]",
        className
      )}
      style={{
        boxShadow: '0 8px 40px rgba(0, 0, 0, 0.12), 0 2px 8px rgba(0, 0, 0, 0.08)',
        padding: showDots ? '0 20px' : '0 24px',
        minWidth: showDots ? '72px' : 'auto',
      }}
    >
      {/* Uniform glass background */}
      <div
        className="absolute inset-0 rounded-full overflow-hidden"
        style={{
          backdropFilter: 'blur(40px) saturate(180%)',
          WebkitBackdropFilter: 'blur(40px) saturate(180%)',
        }}
      >
        <div
          className="absolute inset-0"
          style={{
            background: 'linear-gradient(135deg, rgba(255,255,255,0.75) 0%, rgba(255,255,255,0.55) 100%)',
          }}
        />
        <div
          className="absolute inset-0"
          style={{
            boxShadow: 'inset 0 0 0 0.5px rgba(255,255,255,0.8), inset 0 1px 0 rgba(255,255,255,0.6)',
            borderRadius: '9999px',
          }}
        />
      </div>

      {/* Text content */}
      <div
        className="relative z-10 text-[#1A1A1A]"
        style={{
          fontSize: '15px',
          fontWeight: 500,
          letterSpacing: '-0.01em',
          lineHeight: 1,
          fontFamily: '-apple-system, BlinkMacSystemFont, "SF Pro Text", system-ui, sans-serif',
        }}
      >
        {showDots ? (
          <span className="inline-flex items-center justify-center gap-[6px]">
            <span className="dot dot-1" />
            <span className="dot dot-2" />
            <span className="dot dot-3" />
          </span>
        ) : isDownload ? (
          isMobile ? (
            <span className="whitespace-nowrap">Available on Mac OS</span>
          ) : (
            <span className="inline-flex items-center gap-2 whitespace-nowrap">
              <svg width="16" height="16" viewBox="0 0 16 16" fill="none" className="flex-shrink-0">
                <path
                  d="M8 2v8M8 10L4.5 6.5M8 10l3.5-3.5M2.5 14h11"
                  stroke="currentColor"
                  strokeWidth="1.5"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
              </svg>
              Download for macOS
            </span>
          )
        ) : isComplete ? (
          <span className="inline-flex items-center gap-2 whitespace-nowrap">
            complete
            <svg width="14" height="14" viewBox="0 0 14 14" fill="none" className="flex-shrink-0">
              <path
                d="M12 4L5.5 10.5L2 7"
                stroke="currentColor"
                strokeWidth="2"
                strokeLinecap="round"
                strokeLinejoin="round"
              />
            </svg>
          </span>
        ) : (
          <span className="whitespace-nowrap">
            {text || "\u00A0"}
          </span>
        )}
      </div>

      <style jsx>{`
        .dot {
          width: 5px;
          height: 5px;
          border-radius: 50%;
          background-color: currentColor;
        }
        .dot-1 {
          animation: dotBounce 1.4s ease-in-out infinite;
          animation-delay: 0s;
        }
        .dot-2 {
          animation: dotBounce 1.4s ease-in-out infinite;
          animation-delay: 0.2s;
        }
        .dot-3 {
          animation: dotBounce 1.4s ease-in-out infinite;
          animation-delay: 0.4s;
        }
        @keyframes dotBounce {
          0%, 80%, 100% {
            opacity: 0.4;
            transform: scale(0.9);
          }
          40% {
            opacity: 1;
            transform: scale(1.15);
          }
        }
      `}</style>
    </Component>
  )
}
