import { useMemo } from "react";

export const Particles = ({ count = 40 }: { count?: number }) => {
  const dots = useMemo(
    () =>
      Array.from({ length: count }).map((_, i) => ({
        id: i,
        top: Math.random() * 100,
        left: Math.random() * 100,
        size: Math.random() * 3 + 1,
        delay: Math.random() * 8,
        duration: 6 + Math.random() * 6,
        opacity: 0.2 + Math.random() * 0.5,
      })),
    [count]
  );
  return (
    <div className="absolute inset-0 overflow-hidden pointer-events-none">
      <div className="absolute inset-0 radial-glow" />
      {dots.map((d) => (
        <span
          key={d.id}
          className="absolute rounded-full bg-barz-gold particle"
          style={{
            top: `${d.top}%`,
            left: `${d.left}%`,
            width: d.size,
            height: d.size,
            opacity: d.opacity,
            animationDelay: `${d.delay}s`,
            animationDuration: `${d.duration}s`,
            boxShadow: "0 0 8px rgba(255,222,89,0.6)",
          }}
        />
      ))}
    </div>
  );
};
