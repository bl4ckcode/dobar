import { Smartphone, Zap, Wallet, TrendingUp, ScanLine, Camera, Sparkles, Smartphone as PhoneIcon, ArrowRight, LucideIcon } from "lucide-react";
import { copy } from "@/lib/i18n";
import { useEffect, useRef } from "react";

const icons: LucideIcon[] = [Smartphone, Zap, Wallet, TrendingUp, ScanLine];

export const Features = () => {
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const els = ref.current?.querySelectorAll<HTMLElement>("[data-card]");
    if (!els) return;
    const obs = new IntersectionObserver(
      (entries) => {
        entries.forEach((e) => {
          if (e.isIntersecting) {
            (e.target as HTMLElement).style.opacity = "1";
            (e.target as HTMLElement).style.transform = "translateY(0)";
          }
        });
      },
      { threshold: 0.15 }
    );
    els.forEach((el, i) => {
      el.style.transitionDelay = `${i * 100}ms`;
      obs.observe(el);
    });
    return () => obs.disconnect();
  }, []);

  return (
    <section id="features" className="py-24 bg-barz-dark">
      <div className="container">
        <div className="text-center max-w-2xl mx-auto mb-14">
          <h2 className="text-3xl md:text-5xl font-extrabold leading-tight">
            {copy.features.title} <span className="text-gradient-gold">{copy.features.titleAlt}</span>
          </h2>
          <p className="mt-4 text-muted-foreground">{copy.features.sub}</p>
        </div>
        <div ref={ref} className="grid sm:grid-cols-2 lg:grid-cols-3 gap-6">
          {copy.features.items.map((f, i) => {
            const Icon = icons[i];
            const isAi = i === 4;
            return (
              <div
                key={f.title}
                data-card
                className={`group p-6 rounded-2xl bg-barz-darkCard border border-barz-border/60 transition-all duration-500 hover:border-barz-gold hover:shadow-[0_0_30px_rgba(255,222,89,0.2)] ${isAi ? "sm:col-span-2 lg:col-span-1 lg:row-span-1 relative overflow-hidden" : ""}`}
                style={{ opacity: 0, transform: "translateY(24px)", transitionProperty: "opacity, transform, border-color, box-shadow", transitionDuration: "600ms" }}
              >
                <div className="w-12 h-12 rounded-full bg-gradient-gold flex items-center justify-center mb-5 group-hover:scale-110 transition-transform">
                  <Icon className="text-barz-dark" size={24} strokeWidth={2.5} />
                </div>
                <h3 className="font-bold text-lg mb-2">
                  {f.title}
                  {isAi && (
                    <span className="ml-2 inline-flex items-center gap-1 text-[10px] font-bold uppercase tracking-wider bg-gradient-gold text-barz-dark px-2 py-0.5 rounded-full">
                      <Sparkles size={10} /> Novo
                    </span>
                  )}
                </h3>
                <p className="text-sm text-muted-foreground leading-relaxed">{f.desc}</p>

                {isAi && (
                  <div className="mt-5 pt-5 border-t border-barz-border/60">
                    <div className="flex items-center justify-between gap-2">
                      <AiStep icon={Camera} label={copy.features.aiDemo.step1} />
                      <ArrowRight className="text-barz-gold shrink-0 animate-pulse" size={16} />
                      <AiStep icon={Sparkles} label={copy.features.aiDemo.step2} pulse />
                      <ArrowRight className="text-barz-gold shrink-0 animate-pulse" size={16} />
                      <AiStep icon={PhoneIcon} label={copy.features.aiDemo.step3} />
                    </div>
                  </div>
                )}
              </div>
            );
          })}
        </div>
      </div>
    </section>
  );
};

const AiStep = ({ icon: Icon, label, pulse }: { icon: LucideIcon; label: string; pulse?: boolean }) => (
  <div className="flex flex-col items-center gap-1.5 flex-1 min-w-0">
    <div className={`w-9 h-9 rounded-lg bg-barz-dark border border-barz-gold/40 flex items-center justify-center ${pulse ? "shadow-[0_0_15px_rgba(255,222,89,0.4)]" : ""}`}>
      <Icon size={16} className="text-barz-gold" />
    </div>
    <span className="text-[10px] text-muted-foreground text-center leading-tight">{label}</span>
  </div>
);
