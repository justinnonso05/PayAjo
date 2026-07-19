"use client";

import { useState } from "react";
import { PinInput } from "@/components/auth/pin-input";
import { Modal } from "./modal";

export function PinConfirmModal({
  title,
  subtitle,
  onConfirm,
  onClose,
}: {
  title: string;
  subtitle: string;
  onConfirm: (pin: string) => Promise<void> | void;
  onClose: () => void;
}) {
  const [digits, setDigits] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleComplete = async (pin: string) => {
    setIsSubmitting(true);
    try {
      await onConfirm(pin);
    } finally {
      setIsSubmitting(false);
      setDigits("");
    }
  };

  return (
    <Modal title={title} onClose={onClose}>
      <p className="text-sm text-brand-dark/55">{subtitle}</p>
      <div className="mt-6">
        <PinInput value={digits} onChange={setDigits} onComplete={handleComplete} disabled={isSubmitting} />
      </div>
    </Modal>
  );
}
