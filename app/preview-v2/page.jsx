"use client";

import ResidentDashboard from "../../components/komplekguard/ResidentDashboard";

export default function PreviewPage() {
  const info = () =>
    window.alert("Ini pratinjau UI. Belum terhubung ke API asli.");

  return (
    <ResidentDashboard
      viewer={{
        id: "contoh-user",
        name: "Warga",
        neighborhood: "Gang Taruna"
      }}
      alerts={[
        {
          id: "contoh-1",
          title: "Pohon tumbang dekat jalan masuk",
          category: "Pohon Tumbang",
          location: "Gang Taruna",
          timeLabel: "Contoh laporan",
          status: "AKTIF",
          riskLevel: "TINGGI",
          userId: "warga-lain"
        },
        {
          id: "contoh-2",
          title: "Lampu jalan tidak berfungsi",
          category: "Fasilitas Lingkungan",
          location: "Jalan lingkungan",
          timeLabel: "Contoh laporan",
          status: "DIPROSES",
          riskLevel: null,
          userId: "contoh-user"
        }
      ]}
      lastSyncLabel="Data pratinjau"
      onCreateAlert={info}
      onOpenAlert={info}
      onOpenMap={info}
      onOpenProfile={info}
      onOpenAssistant={info}
    />
  );
}
