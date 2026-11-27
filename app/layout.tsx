import type { Metadata } from "next";
import "./globals.css";
import AuthHeader from "./auth/AuthHeader";

export const metadata: Metadata = {
  title: "Judgment Engineering",
  description: "Preserve and apply organizational judgment.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="h-full antialiased">
      <body className="min-h-full flex flex-col"><AuthHeader />{children}</body>
    </html>
  );
}
