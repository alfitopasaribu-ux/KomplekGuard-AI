"use client";
import { useState, useEffect, useRef } from "react";
import Image from "next/image";
import CameraCapture from "@/components/profile/CameraCapture";

export default function ProfilePage() {
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [showCamera, setShowCamera] = useState(false);
  const [showSourcePicker, setShowSourcePicker] = useState(false);
  const [preview, setPreview] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);
  const [form, setForm] = useState({
    name: "",
    phone: "",
    address: "",
    image: "",
  });

  useEffect(() => {
    fetch("/api/profile")
      .then((r) => r.json())
      .then((data) => {
        setForm({
          name: data.name || "",
          phone: data.phone || "",
          address: data.address || "",
          image: data.image || "",
        });
        if (data.image) setPreview(data.image);
      });
  }, []);

  const handleGallery = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onloadend = () => {
      setPreview(reader.result as string);
      setForm((f) => ({ ...f, image: reader.result as string }));
    };
    reader.readAsDataURL(file);
    setShowSourcePicker(false);
  };

  const handleCameraCapture = (imageSrc: string) => {
    setPreview(imageSrc);
    setForm((f) => ({ ...f, image: imageSrc }));
    setShowCamera(false);
    setShowSourcePicker(false);
  };

  const handleSave = async () => {
    setSaving(true);
    await fetch("/api/profile", {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(form),
    });
    setSaving(false);
    setSaved(true);
    setTimeout(() => setSaved(false), 3000);
  };

  return (
    <div className="min-h-screen bg-[#0D0D1A] text-white p-6">
      {/* Camera Modal */}
      {showCamera && (
        <CameraCapture
          onCapture={handleCameraCapture}
          onClose={() => setShowCamera(false)}
        />
      )}

      {/* Source Picker Modal */}
      {showSourcePicker && (
        <div className="fixed inset-0 bg-black/70 z-40 flex items-end justify-center">
          <div className="bg-[#1A1A2E] w-full max-w-md rounded-t-2xl p-6 border-t border-[#00FF88]/30">
            <p className="text-[#00FF88] text-xs tracking-[4px] mb-6 text-center">
              PILIH SUMBER FOTO
            </p>
            <div className="grid grid-cols-3 gap-4 mb-4">
              {/* Galeri */}
              <button
                onClick={() => fileInputRef.current?.click()}
                className="flex flex-col items-center gap-2 p-4 border border-[#00FF88]/30 rounded-xl hover:border-[#00FF88] hover:bg-[#00FF88]/5 transition-all"
              >
                <span className="text-3xl">???</span>
                <span className="text-xs text-gray-400 tracking-widest">GALERI</span>
              </button>
              {/* Kamera Depan */}
              <button
                onClick={() => setShowCamera(true)}
                className="flex flex-col items-center gap-2 p-4 border border-[#00FF88]/30 rounded-xl hover:border-[#00FF88] hover:bg-[#00FF88]/5 transition-all"
              >
                <span className="text-3xl">??</span>
                <span className="text-xs text-gray-400 tracking-widest">KAMERA</span>
              </button>
              {/* Kamera Belakang */}
              <button
                onClick={() => setShowCamera(true)}
                className="flex flex-col items-center gap-2 p-4 border border-[#00FF88]/30 rounded-xl hover:border-[#00FF88] hover:bg-[#00FF88]/5 transition-all"
              >
                <span className="text-3xl">??</span>
                <span className="text-xs text-gray-400 tracking-widest">LIVE</span>
              </button>
            </div>
            <button
              onClick={() => setShowSourcePicker(false)}
              className="w-full py-3 text-gray-500 text-sm tracking-widest"
            >
              BATAL
            </button>
          </div>
        </div>
      )}

      {/* Hidden file input */}
      <input
        ref={fileInputRef}
        type="file"
        accept="image/*"
        className="hidden"
        onChange={handleGallery}
      />

      {/* Header */}
      <div className="flex items-center justify-between mb-8">
        <div>
          <p className="text-[#00FF88] text-xs tracking-[4px]">KOMPLEKGUARD</p>
          <h1 className="text-2xl font-bold tracking-widest">PROFILE</h1>
        </div>
        <button
          onClick={handleSave}
          disabled={saving}
          className="px-6 py-2 bg-[#00FF88] text-black text-sm font-bold tracking-widest rounded-lg hover:bg-[#00FF88]/80 disabled:opacity-50 transition-all"
        >
          {saving ? "..." : saved ? "? TERSIMPAN" : "SIMPAN"}
        </button>
      </div>

      {/* Avatar */}
      <div className="flex flex-col items-center mb-10">
        <div
          className="relative cursor-pointer group"
          onClick={() => setShowSourcePicker(true)}
        >
          <div className="w-28 h-28 rounded-full border-2 border-[#00FF88] overflow-hidden bg-[#1A1A2E] flex items-center justify-center">
            {preview ? (
              <Image src={preview} alt="avatar" width={112} height={112} className="object-cover w-full h-full" />
            ) : (
              <span className="text-5xl">??</span>
            )}
          </div>
          {/* Edit badge */}
          <div className="absolute bottom-0 right-0 w-8 h-8 bg-[#00FF88] rounded-full flex items-center justify-center shadow-lg group-hover:scale-110 transition-transform">
            <span className="text-black text-sm">??</span>
          </div>
        </div>
        <button
          onClick={() => setShowSourcePicker(true)}
          className="mt-3 text-[#00FF88] text-xs tracking-[3px] hover:underline"
        >
          GANTI FOTO PROFIL
        </button>
      </div>

      {/* Form */}
      <div className="space-y-5 max-w-md mx-auto">
        {[
          { label: "NAMA LENGKAP", key: "name", icon: "??", type: "text" },
          { label: "NO. TELEPON", key: "phone", icon: "??", type: "tel" },
          { label: "ALAMAT", key: "address", icon: "??", type: "text" },
        ].map(({ label, key, icon, type }) => (
          <div key={key}>
            <label className="text-[#00FF88] text-xs tracking-[3px] mb-2 block">
              {icon} {label}
            </label>
            <input
              type={type}
              value={form[key as keyof typeof form]}
              onChange={(e) => setForm((f) => ({ ...f, [key]: e.target.value }))}
              className="w-full bg-[#1A1A2E] border border-[#00FF88]/20 focus:border-[#00FF88] text-white rounded-lg px-4 py-3 text-sm outline-none transition-colors tracking-wide"
              placeholder={`Masukkan ${label.toLowerCase()}`}
            />
          </div>
        ))}
      </div>

      {/* Save toast */}
      {saved && (
        <div className="fixed bottom-6 left-1/2 -translate-x-1/2 bg-[#00FF88] text-black px-6 py-3 rounded-full text-sm font-bold tracking-widest shadow-xl">
          ? PROFILE DIPERBARUI
        </div>
      )}
    </div>
  );
}
