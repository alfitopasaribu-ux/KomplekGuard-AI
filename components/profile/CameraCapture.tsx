"use client";
import { useRef, useState, useCallback } from "react";
import Webcam from "react-webcam";

interface CameraCaptureProps {
  onCapture: (imageSrc: string) => void;
  onClose: () => void;
}

export default function CameraCapture({ onCapture, onClose }: CameraCaptureProps) {
  const webcamRef = useRef<Webcam>(null);
  const [facingMode, setFacingMode] = useState<"user" | "environment">("user");

  const capture = useCallback(() => {
    const imageSrc = webcamRef.current?.getScreenshot();
    if (imageSrc) onCapture(imageSrc);
  }, [onCapture]);

  return (
    <div className="fixed inset-0 bg-black/90 z-50 flex flex-col items-center justify-center gap-4 p-4">
      <div className="relative w-full max-w-sm rounded-xl overflow-hidden border border-[#00FF88]">
        <Webcam
          ref={webcamRef}
          screenshotFormat="image/jpeg"
          videoConstraints={{ facingMode }}
          className="w-full"
        />
        {/* Overlay corner brackets */}
        <div className="absolute top-2 left-2 w-6 h-6 border-t-2 border-l-2 border-[#00FF88]" />
        <div className="absolute top-2 right-2 w-6 h-6 border-t-2 border-r-2 border-[#00FF88]" />
        <div className="absolute bottom-2 left-2 w-6 h-6 border-b-2 border-l-2 border-[#00FF88]" />
        <div className="absolute bottom-2 right-2 w-6 h-6 border-b-2 border-r-2 border-[#00FF88]" />
      </div>

      <div className="flex gap-3">
        <button
          onClick={() => setFacingMode(facingMode === "user" ? "environment" : "user")}
          className="px-4 py-2 border border-[#00FF88]/50 text-[#00FF88] rounded-lg text-sm tracking-widest hover:bg-[#00FF88]/10 transition-all"
        >
          ?? BALIK KAMERA
        </button>
        <button
          onClick={capture}
          className="px-6 py-2 bg-[#00FF88] text-black font-bold rounded-lg text-sm tracking-widest hover:bg-[#00FF88]/80 transition-all"
        >
          ?? AMBIL FOTO
        </button>
        <button
          onClick={onClose}
          className="px-4 py-2 border border-red-500/50 text-red-400 rounded-lg text-sm tracking-widest hover:bg-red-500/10 transition-all"
        >
          ? BATAL
        </button>
      </div>
    </div>
  );
}
