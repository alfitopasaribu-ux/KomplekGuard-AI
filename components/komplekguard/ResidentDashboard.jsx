"use client";

import {
  ArrowRight, Bell, ChevronRight, Clock3,
  MapPinned, MessageCircle, Navigation,
  ShieldCheck, Siren, Sparkles, UserRound
} from "lucide-react";
import "./resident-dashboard.css";

const isActive = (status) =>
  status === "AKTIF" || status === "DIPROSES";

const riskLabel = (risk) =>
  risk ? `Risiko ${risk.toLowerCase()}` : "Menunggu analisis";

export default function ResidentDashboard({
  viewer,
  alerts = [],
  lastSyncLabel = "Belum tersinkron",
  loading = false,
  onCreateAlert,
  onOpenAlert,
  onOpenMap,
  onOpenProfile,
  onOpenAssistant,
}) {
  const current = alerts.filter((item) => isActive(item.status));
  const waiting = current.filter((item) => item.status === "AKTIF").length;
  const recently = alerts.slice(0, 4);
  const firstName = viewer.name.trim().split(/\s+/)[0] || "Warga";

  return (
    <main className="kg-shell">
      <header className="kg-header">
        <div className="kg-header-inner">
          <div className="kg-brand">
            <span className="kg-brand-mark">
              <ShieldCheck size={24} />
            </span>
            <span>
              <strong>KomplekGuard</strong>
              <small>Warga terhubung. Lingkungan terjaga.</small>
            </span>
          </div>

          <div className="kg-header-actions">
            <span className="kg-location-pill">
              <span className="kg-location-dot" />
              {viewer.neighborhood}
            </span>
            <button
              type="button"
              className="kg-icon-button"
              onClick={onOpenProfile}
              aria-label="Buka profil"
            >
              <UserRound size={20} />
            </button>
          </div>
        </div>
      </header>

      <div className="kg-container">
        <div className="kg-page-intro">
          <p className="kg-eyebrow">BERANDA WARGA</p>
          <h1>
            Selamat datang, {firstName}
            <span className="kg-greeting-period">.</span>
          </h1>
          <p>
            Informasi lingkungan dan bantuan warga,
            semuanya dalam satu tempat.
          </p>
        </div>

        <section className="kg-overview">
          <div className="kg-hero">
            <div className="kg-hero-glow" aria-hidden="true" />
            <div className="kg-hero-content">
              <span className="kg-hero-kicker">
                <ShieldCheck size={15} />
                PUSAT KEAMANAN LINGKUNGAN
              </span>

              <h2>
                Bersama, kita bisa
                <br />
                bertindak lebih cepat.
              </h2>

              <p>
                Laporkan kejadian berbahaya agar warga
                terdaftar dapat melihat lokasi dan
                memberikan pertolongan.
              </p>

              <button
                type="button"
                className="kg-emergency-button"
                onClick={onCreateAlert}
              >
                <Siren size={21} />
                Kirim Laporan Darurat
                <ArrowRight size={20} />
              </button>
            </div>

            <div className="kg-hero-decoration" aria-hidden="true">
              <ShieldCheck size={122} strokeWidth={1} />
            </div>
          </div>

          <div className="kg-stats">
            <div className="kg-stat-card">
              <span className="kg-stat-icon kg-stat-icon-red">
                <Bell size={19} />
              </span>
              <div>
                <span className="kg-stat-number">
                  {loading ? "…" : current.length}
                </span>
                <span className="kg-stat-label">
                  Laporan aktif
                </span>
              </div>
            </div>

            <div className="kg-stat-card">
              <span className="kg-stat-icon kg-stat-icon-amber">
                <Clock3 size={19} />
              </span>
              <div>
                <span className="kg-stat-number">
                  {loading ? "…" : waiting}
                </span>
                <span className="kg-stat-label">
                  Menunggu respons
                </span>
              </div>
            </div>

            <div className="kg-current-status">
              <span
                className={
                  current.length
                    ? "kg-status-dot is-alert"
                    : "kg-status-dot"
                }
              />
              <div>
                <strong>
                  {current.length
                    ? "Ada laporan yang perlu diperhatikan"
                    : "Belum ada laporan aktif"}
                </strong>
                <span>
                  Terakhir diperbarui: {lastSyncLabel}
                </span>
              </div>
            </div>
          </div>
        </section>

        <section className="kg-content-grid">
          <div className="kg-feed kg-panel">
            <div className="kg-section-head">
              <div>
                <p className="kg-eyebrow">INFORMASI TERKINI</p>
                <h2>Laporan lingkungan</h2>
              </div>
              <button
                type="button"
                className="kg-text-button"
                onClick={onOpenMap}
              >
                Lihat peta <ArrowRight size={17} />
              </button>
            </div>

            {loading ? (
              <p className="kg-empty-message">
                Memuat laporan terbaru…
              </p>
            ) : recently.length ? (
              <div className="kg-list">
                {recently.map((item) => (
                  <button
                    type="button"
                    className="kg-alert-row"
                    key={item.id}
                    onClick={() => onOpenAlert(item.id)}
                  >
                    <span className={
                      "kg-alert-marker " +
                      (["KRITIS", "TINGGI"].includes(item.riskLevel)
                        ? "is-high"
                        : "")
                    }>
                      <Bell size={19} />
                    </span>

                    <span className="kg-alert-copy">
                      <strong>{item.title}</strong>
                      <span className="kg-alert-description">
                        {item.category} · {item.location}
                      </span>
                      <span className="kg-alert-meta">
                        {item.timeLabel} ·{" "}
                        {item.userId === viewer.id
                          ? "Laporan Anda"
                          : "Laporan warga"}
                      </span>
                    </span>

                    <span className="kg-alert-end">
                      <span className={
                        `kg-risk kg-risk-${(
                          item.riskLevel || "PENDING"
                        ).toLowerCase()}`
                      }>
                        {riskLabel(item.riskLevel)}
                      </span>
                      <ChevronRight size={17} />
                    </span>
                  </button>
                ))}
              </div>
            ) : (
              <div className="kg-empty-state">
                <ShieldCheck size={32} />
                <strong>Belum ada laporan terbaru</strong>
                <p>
                  Laporan warga akan ditampilkan
                  di sini ketika tersedia.
                </p>
              </div>
            )}
          </div>

          <div className="kg-aside">
            <button
              type="button"
              className="kg-map-card kg-panel"
              onClick={onOpenMap}
            >
              <span className="kg-map-art">
                <MapPinned size={31} />
              </span>
              <span>
                <strong>Peta Kejadian</strong>
                <small>
                  Lihat lokasi laporan di sekitar lingkungan.
                </small>
              </span>
              <Navigation size={20} />
            </button>

            <button
              type="button"
              className="kg-ai-card kg-panel"
              onClick={onOpenAssistant}
            >
              <span className="kg-ai-icon">
                <Sparkles size={22} />
              </span>
              <span>
                <strong>Asisten Keamanan</strong>
                <small>
                  Panduan awal dan informasi keselamatan
                  berbantuan AI.
                </small>
              </span>
              <ChevronRight size={19} />
            </button>

            <div className="kg-help-note">
              <MessageCircle size={18} />
              <span>
                Dalam keadaan darurat nyata, utamakan
                keselamatan diri dan hubungi layanan
                darurat resmi.
              </span>
            </div>
          </div>
        </section>
      </div>

      <nav className="kg-bottom-nav" aria-label="Navigasi utama">
        <span className="kg-tab is-active">
          <ShieldCheck size={19} />Beranda
        </span>
        <button type="button" className="kg-tab" onClick={onOpenMap}>
          <MapPinned size={19} />Peta
        </button>
        <button type="button" className="kg-tab kg-tab-alert" onClick={onCreateAlert}>
          <Siren size={22} />Lapor
        </button>
        <button type="button" className="kg-tab" onClick={onOpenAssistant}>
          <Sparkles size={19} />Asisten
        </button>
        <button type="button" className="kg-tab" onClick={onOpenProfile}>
          <UserRound size={19} />Profil
        </button>
      </nav>
    </main>
  );
}
