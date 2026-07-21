import { useState, type InputHTMLAttributes } from "react";
import { Eye, EyeOff } from "lucide-react";

type TextFieldProps = InputHTMLAttributes<HTMLInputElement> & {
  label: string;
  error?: { message?: string };
};

export function TextField({ label, error, id, className, type, ...props }: TextFieldProps) {
  const inputId = id ?? props.name;
  const [showPassword, setShowPassword] = useState(false);
  const isPassword = type === "password";
  const inputType = isPassword ? (showPassword ? "text" : "password") : type;

  return (
    <div>
      <label htmlFor={inputId} className="mb-1.5 block text-xs font-bold text-brand-dark">
        {label}
      </label>
      <div className="relative">
        <input
          id={inputId}
          type={inputType}
          {...props}
          className={`w-full rounded-xl border bg-white px-4 py-3 text-sm text-brand-dark outline-none transition-colors placeholder:text-brand-dark/30 focus:border-brand-dark ${
            isPassword ? "pr-11" : ""
          } ${error ? "border-red-400" : "border-brand-dark/15"} ${className ?? ""}`}
        />
        {isPassword && (
          <button
            type="button"
            onClick={() => setShowPassword((prev) => !prev)}
            aria-label={showPassword ? "Hide password" : "Show password"}
            className="absolute right-3.5 top-1/2 -translate-y-1/2 text-brand-dark/40 hover:text-brand-dark transition-colors"
          >
            {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
          </button>
        )}
      </div>
      {error && <p className="mt-1.5 text-xs font-semibold text-red-500">{error.message}</p>}
    </div>
  );
}
