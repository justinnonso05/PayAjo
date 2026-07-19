import type { InputHTMLAttributes } from "react";

type TextFieldProps = InputHTMLAttributes<HTMLInputElement> & {
  label: string;
  error?: { message?: string };
};

export function TextField({ label, error, id, className, ...props }: TextFieldProps) {
  const inputId = id ?? props.name;
  return (
    <div>
      <label htmlFor={inputId} className="mb-1.5 block text-xs font-bold text-brand-dark">
        {label}
      </label>
      <input
        id={inputId}
        {...props}
        className={`w-full rounded-xl border bg-white px-4 py-3 text-sm text-brand-dark outline-none transition-colors placeholder:text-brand-dark/30 focus:border-brand-dark ${
          error ? "border-red-400" : "border-brand-dark/15"
        } ${className ?? ""}`}
      />
      {error && <p className="mt-1.5 text-xs font-semibold text-red-500">{error.message}</p>}
    </div>
  );
}
