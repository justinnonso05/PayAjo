/** A circle that pops in, followed by a checkmark that "draws" itself —
 * the same signature success micro-interaction used in the mobile app's
 * AnimatedCheckmark widget, rebuilt with SVG + CSS (no animation library). */
export function AnimatedCheckmark({
  size = 88,
  circleColor = "var(--color-brand)",
  checkColor = "var(--color-brand-dark)",
}: {
  size?: number;
  circleColor?: string;
  checkColor?: string;
}) {
  return (
    <svg width={size} height={size} viewBox="0 0 100 100" className="animate-[checkmark-circle_0.55s_cubic-bezier(0.34,1.56,0.64,1)_both]">
      <circle cx="50" cy="50" r="50" fill={circleColor} />
      <path
        d="M22 52 L42 72 L80 30"
        fill="none"
        stroke={checkColor}
        strokeWidth="9"
        strokeLinecap="round"
        strokeLinejoin="round"
        pathLength={1}
        className="animate-[checkmark-check_0.33s_ease-out_0.22s_both]"
        style={{ strokeDasharray: 1, strokeDashoffset: 1 }}
      />
    </svg>
  );
}
