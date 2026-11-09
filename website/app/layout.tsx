import type { Metadata, Viewport } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Yapper — Your voice. Your Mac.",
  description:
    "Think it. Say it. There it is. Yapper is free, private voice dictation for your Mac. Local speech recognition, automatic cleanup, and a little less typing.",
  icons: {
    icon: "/images/yapper-icon.png",
    apple: "/images/yapper-icon.png",
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
