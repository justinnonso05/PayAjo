"use client";

import { X } from "lucide-react";
import type { ReactNode } from "react";

export function Modal({ title, onClose, children }: { title: string; onClose: () => void; children: ReactNode }) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-brand-dark/40 px-4 backdrop-blur-sm" onClick={onClose}>
      <div
        className="w-full max-w-sm rounded-card bg-white p-6 shadow-2xl"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-center justify-between">
          <h3 className="font-display text-lg font-bold text-brand-dark">{title}</h3>
          <button type="button" onClick={onClose} className="flex h-8 w-8 items-center justify-center rounded-full text-brand-dark/40 hover:bg-soft-gray">
            <X size={16} />
          </button>
        </div>
        <div className="mt-4">{children}</div>
      </div>
    </div>
  );
}
