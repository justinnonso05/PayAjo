"use client";

import { useEffect, useRef } from "react";

const PIN_LENGTH = 4;

export function PinInput({
  value,
  onChange,
  onComplete,
  disabled,
  shakeKey,
}: {
  value: string;
  onChange: (value: string) => void;
  onComplete?: (value: string) => void;
  disabled?: boolean;
  shakeKey?: number;
}) {
  const refs = useRef<Array<HTMLInputElement | null>>([]);

  useEffect(() => {
    refs.current[Math.min(value.length, PIN_LENGTH - 1)]?.focus();
  }, [value.length]);

  const setDigit = (index: number, digit: string) => {
    const clean = digit.replace(/\D/g, "").slice(-1);
    const chars = value.split("");
    chars[index] = clean;
    const next = chars.join("").slice(0, PIN_LENGTH);
    onChange(next);
    if (next.length === PIN_LENGTH) onComplete?.(next);
  };

  const handleKeyDown = (index: number, e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === "Backspace" && !value[index] && index > 0) {
      onChange(value.slice(0, index - 1));
    }
  };

  return (
    <div className={`flex justify-center gap-3 ${shakeKey ? "animate-[shake_0.4s]" : ""}`} key={shakeKey}>
      {Array.from({ length: PIN_LENGTH }).map((_, i) => (
        <input
          key={i}
          ref={(el) => {
            refs.current[i] = el;
          }}
          type="password"
          inputMode="numeric"
          maxLength={1}
          disabled={disabled}
          value={value[i] ?? ""}
          onChange={(e) => setDigit(i, e.target.value)}
          onKeyDown={(e) => handleKeyDown(i, e)}
          className="h-14 w-14 rounded-2xl border border-brand-dark/15 bg-white text-center text-2xl font-bold text-brand-dark outline-none transition-colors focus:border-brand-dark disabled:opacity-50"
        />
      ))}
    </div>
  );
}
