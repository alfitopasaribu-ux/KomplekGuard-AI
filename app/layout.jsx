export const metadata = {
  title: "KomplekGuard AI",
  description: "Warga terhubung. Lingkungan terjaga.",
};

export default function RootLayout({ children }) {
  return (
    <html lang="id">
      <body style={{ margin: 0 }}>{children}</body>
    </html>
  );
}
