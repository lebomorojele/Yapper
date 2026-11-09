import type { Metadata, Viewport } from "next";
import "./globals.css";

export const metadata: Metadata = {
  metadataBase: new URL("https://yapper.party"),
  openGraph: {
    title: "Yapper — Your voice. Your Mac.",
    description:
      "Private voice dictation for your Mac. Think it. Say it. There it is.",
    url: "https://yapper.party",
    siteName: "Yapper",
    type: "website",
  },
  title: "Yapper — Your voice. Your Mac.",
  description:
    "Think it. Say it. There it is. Yapper is free, private voice dictation for your Mac. Local speech recognition, automatic cleanup, and a little less typing.",
  icons: {
    icon: "/images/yapper-mark.png",
    apple: "/images/yapper-touch-icon.png",
  },
};

export const viewport: Viewport = {
  themeColor: "#f5f3eb",
  width: "device-width",
  initialScale: 1,
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className="antialiased">{children}</body>
    </html>
  );
}
