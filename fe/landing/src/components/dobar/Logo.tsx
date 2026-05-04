interface LogoProps {
  size?: "sm" | "md" | "lg";
}

export const Logo = ({ size = "md" }: LogoProps) => {
  // For navbar (sm) - use text
  if (size === "sm") {
    return (
      <span
        className="text-2xl font-extrabold tracking-tight text-gradient-gold leading-none select-none"
        style={{ fontFamily: "Inter, sans-serif", letterSpacing: "-0.04em" }}
      >
        dobar
      </span>
    );
  }

  // For larger sizes (Hero) - use animated GIF icon (30% bigger, extends behind text)
  const heightClass = size === "lg" ? "h-32 md:h-44" : "h-24 md:h-28";
  return (
    <img
      src="/dobar-logo.gif"
      alt="Dobar"
      className={`${heightClass} w-auto object-contain -mb-8 md:-mb-12 relative z-0`}
    />
  );
};
