import Image from "next/image";
import { VoiceDemo } from "@/components/voice-demo";

const download = "/downloads/Yapper-latest.dmg";

function DownloadLink({
  className = "",
  children = "Download for Mac",
}: {
  className?: string;
  children?: React.ReactNode;
}) {
  return (
    <a className={`download ${className}`} href={download} download>
      <svg viewBox="0 0 20 20" fill="none" aria-hidden="true">
        <path
          d="M10 2v10m-4-4 4 4 4-4M3 13v4h14v-4"
          stroke="currentColor"
          strokeWidth="1.5"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
      </svg>
      {children}
      <span aria-hidden="true">↗</span>
    </a>
  );
}

export default function Home() {
  return (
    <>
      <a href="#main" className="skip-link">
        Skip to content
      </a>
      <header className="site-header">
        <a href="#" className="wordmark" aria-label="Yapper home">
          <Image src="/images/yapper-icon.png" alt="" width={34} height={34} />
          yapper<span className="brand-period">✳</span>
        </a>
        <nav aria-label="Main navigation">
          <a href="#how-it-works">The feeling</a>
          <a href="#details">The details</a>
          <a href="#download" className="nav-download">
            Get Yapper <span aria-hidden="true">↗</span>
          </a>
        </nav>
      </header>
      <main id="main">
        <section className="hero" aria-labelledby="hero-title">
          <div className="hero-topline">
            <span>
              <i /> YOUR VOICE. YOUR MAC.
            </span>
            <span>A LITTLE LESS TYPING, PLEASE.</span>
          </div>
          <h1 id="hero-title">
            You have a lot
            <br />
            to <em>say.</em>
            <span className="hero-asterisk" aria-hidden="true">
              ✳
            </span>
          </h1>
          <div className="hero-bottom">
            <p>
              Let it out. Yapper turns your voice into text
              <br className="desktop-break" /> in the app you're already using.
              <br />
              <span>All on your Mac. All yours.</span>
            </p>
            <div>
              <DownloadLink />
              <p className="download-note">
                Free to use · Apple silicon · macOS 15+
              </p>
              <a className="first-launch-link" href="#first-launch">
                Early build · First-launch help ↗
              </a>
            </div>
          </div>
          <div className="hero-rule">
            <span>THINK IT. SAY IT. THERE IT IS.</span>
            <a href="#how-it-works">
              MEET YOUR NEW FLOW <span aria-hidden="true">↓</span>
            </a>
          </div>
        </section>

        <section
          className="demo-section"
          id="how-it-works"
          aria-labelledby="demo-title"
        >
          <div className="section-intro">
            <p className="eyebrow">01 / LESS FRICTION, MORE THOUGHT</p>
            <h2 id="demo-title">
              Keep up with
              <br />
              your <em>own mind.</em>
            </h2>
            <p>
              The message. The first draft. That idea before it disappears. Tap
              the Globe key, speak naturally, and tap again. Yapper takes care
              of the typing.
            </p>
          </div>
          <VoiceDemo />
          <div className="demo-caption">
            <span>SMALL ENOUGH TO STAY OUT OF YOUR WAY.</span>
            <span>YOUR NEXT THOUGHT IS THE MAIN EVENT.</span>
          </div>
        </section>

        <section
          className="manifesto"
          id="details"
          aria-labelledby="details-title"
        >
          <p className="eyebrow">02 / MADE FOR YOUR MAC</p>
          <h2 id="details-title">
            Your words shouldn't
            <br />
            need a <em>round trip.</em>
          </h2>
          <div className="details-grid">
            <article>
              <span className="detail-symbol" aria-hidden="true">
                ↳
              </span>
              <p className="detail-number">01</p>
              <h3>Stays with you.</h3>
              <p>
                Speech recognition happens on your Mac. Your audio isn't sent to
                a transcription service. Download the speech model once, then
                dictate offline.
              </p>
            </article>
            <article>
              <span className="detail-symbol" aria-hidden="true">
                ✴
              </span>
              <p className="detail-number">02</p>
              <h3>Sounds like you.</h3>
              <p>
                Automatic punctuation and casing make your words ready to use.
                Optional local cleanup helps with longer thoughts. Your meaning
                stays yours.
              </p>
            </article>
            <article>
              <span className="detail-symbol key-symbol" aria-hidden="true">
                fn
              </span>
              <p className="detail-number">03</p>
              <h3>Right where you are.</h3>
              <p>
                A little pill shows your transcript as you speak. Yapper inserts
                the result into the focused text field, with a clipboard
                fallback for other apps.
              </p>
            </article>
          </div>
          <div className="privacy-line">
            <span className="privacy-dot" />
            <p>
              No account. No transcription subscription. No cloud transcription.
            </p>
            <a href="https://github.com/lebomorojele/Yapper">
              Read the source <span aria-hidden="true">↗</span>
            </a>
          </div>
        </section>

        <section className="getting-started" aria-labelledby="start-title">
          <div>
            <p className="eyebrow">03 / YOUR FIRST WORDS</p>
            <h2 id="start-title">
              A minute to set up.
              <br />
              <em>Then just talk.</em>
            </h2>
          </div>
          <ol>
            <li>
              <span>1</span>
              <div>
                <h3>Make yourself at home.</h3>
                <p>
                  Download the DMG, open it, and drag Yapper into Applications.
                  Launch it from there.
                </p>
              </div>
            </li>
            <li>
              <span>2</span>
              <div>
                <h3>Give your voice a way in.</h3>
                <p>
                  Allow Microphone, Accessibility, and Input Monitoring when
                  prompted. The speech model downloads on first launch.
                </p>
              </div>
            </li>
            <li>
              <span>3</span>
              <div>
                <h3>Say what you came to say.</h3>
                <p>
                  Place your cursor in a text field. Tap Globe / Fn to start,
                  speak, then tap again to finish.
                </p>
              </div>
            </li>
          </ol>
        </section>

        <section className="faq" aria-label="Questions and answers">
          <p className="eyebrow">A FEW GOOD QUESTIONS</p>
          <details id="first-launch">
            <summary>
              What if macOS blocks the first launch?<span>+</span>
            </summary>
            <p>
              This early build is ad-hoc signed and is not Apple-notarized.
              After you try opening Yapper, go to System Settings → Privacy
              &amp; Security and choose Open Anyway for Yapper. Updates are
              signed separately with Yapper's update key.
            </p>
          </details>
          <details>
            <summary>
              Does Yapper work without the internet?<span>+</span>
            </summary>
            <p>
              Yes, after the initial speech model download. Speech recognition
              and text cleanup run locally. Internet access is used to download
              models and check for app updates.
            </p>
          </details>
          <details>
            <summary>
              Which Macs can run Yapper?<span>+</span>
            </summary>
            <p>
              This build is for Apple silicon Macs running macOS 15 Sequoia or
              later. The speech model runs on your Mac, so allow space for the
              initial model download.
            </p>
          </details>
          <details>
            <summary>
              What if my Globe key changes input language?<span>+</span>
            </summary>
            <p>
              Open System Settings → Keyboard and set “Press Globe key to” to
              “Do Nothing.” Make sure Yapper has Accessibility and Input
              Monitoring access in Privacy & Security.
            </p>
          </details>
          <details>
            <summary>
              How do updates work?<span>+</span>
            </summary>
            <p>
              Choose “Check for Updates…” from the Yapper menu in your menu bar.
              You can also download the current installer here whenever you need
              it.
            </p>
          </details>
        </section>

        <section
          className="download-section"
          id="download"
          aria-labelledby="download-title"
        >
          <span className="download-flower" aria-hidden="true">
            ✳
          </span>
          <p className="eyebrow">LESS KEYBOARD. MORE YOU.</p>
          <h2 id="download-title">
            Go on.
            <br />
            <em>Yap a little.</em>
          </h2>
          <DownloadLink className="download-light" />
          <p className="download-note">For Apple silicon · macOS 15 or later</p>
          <p className="release-note">
            Early release. Have feedback?{" "}
            <a href="https://github.com/lebomorojele/Yapper/issues">
              Tell us what happened ↗
            </a>
          </p>
        </section>
      </main>
      <footer className="site-footer">
        <a href="#" className="wordmark">
          yapper<span className="brand-period">✳</span>
        </a>
        <p>Made for the way you think.</p>
        <div>
          <a href="https://github.com/lebomorojele/Yapper">GitHub ↗</a>
          <a href="/appcast.xml">Update feed ↗</a>
          <span>© {new Date().getFullYear()} Yapper</span>
        </div>
      </footer>
    </>
  );
}
