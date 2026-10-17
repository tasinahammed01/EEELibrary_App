import type { Metadata } from "next";
import type { ReactNode } from "react";
import { SessionProvider } from "../features/auth/session";
import "./globals.css";
export const metadata: Metadata = {
  title: "EEELibrary Admin",
  description: "Trusted EEELibrary administration",
};
export const dynamic = "force-dynamic";
export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <body>
        <a className="skip-link" href="#main-content">
          Skip to content
        </a>
        <SessionProvider>{children}</SessionProvider>
      </body>
    </html>
  );
}
