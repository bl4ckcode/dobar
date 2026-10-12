import { useEffect, useRef, useState } from "react";
import { copy } from "@/lib/i18n";

const bars = ["BV", "LB", "RH", "BC", "MX", "VZ", "TK", "CC"];

const Counter = ({ value }: { value: string }) => {
  const ref = useRef<HTMLDivElement>(null);
  const [display, setDisplay] = useState("0");
  useEffect(() => {
    const num = parseInt(value.replace(/\D/g, ""), 10);
    if (!num) { setDisplay(value); return; }
    const obs = new IntersectionObserver(([e]) => {
      if (e.isIntersecting) {
        let cur = 0;
        const step = Math.max(1, Math.floor(num / 30));
        const id = setInterval(() => {
          cur += step;
          if (cur >= num) { cur = num; clearInterval(id); }
          setDisplay(value.replace(/(\d+)/, String(cur)));
        }, 40);
        obs.disconnect();
      }
    });
    if (ref.current) obs.observe(ref.current);
    return () => obs.disconnect();
  }, [value]);
  return <div ref={ref} className="text-4xl md:text-5xl font-extrabold text-gradient-gold">{display}</div>;
};

export const SocialProof = () => (
  <section id="social" className="bg-barz-darkLight py-20 border-y border-barz-border/50">
    <div className="container">
      <h2 className="text-center text-2xl md:text-3xl font-bold mb-10">{copy.social.title}</h2>

      <div className="overflow-hidden mb-16 mask-image">
        <div className="marquee-track flex gap-8 w-max">
          {[...bars, ...bars].map((b, i) => (
            <div key={i} className="flex items-center gap-3 shrink-0">
              <div className="w-14 h-14 rounded-full bg-barz-darkCard border border-barz-border flex items-center justify-center text-muted-foreground font-bold">
                {b}
              </div>
              <span className="text-muted-foreground text-sm uppercase tracking-wider">Bar {b}</span>
            </div>
          ))}
        </div>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-6">
        {copy.social.stats.map((s) => (
          <div key={s.label} className="text-center p-6 rounded-2xl bg-barz-darkCard border border-barz-border/60">
            <Counter value={s.value} />
            <div className="mt-2 text-sm text-muted-foreground">{s.label}</div>
          </div>
        ))}
      </div>
    </div>
  </section>
);
