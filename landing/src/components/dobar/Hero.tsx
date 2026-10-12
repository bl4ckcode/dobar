import { ChevronDown } from "lucide-react";
import { Logo } from "./Logo";
import { Particles } from "./Particles";
import { copy } from "@/lib/i18n";

export const Hero = () => (
  <section id="top" className="relative min-h-screen flex flex-col items-center justify-center px-6 pt-24 pb-16 overflow-hidden">
    <Particles />
    <div className="relative z-10 max-w-4xl mx-auto text-center fade-up">
      <div className="mb-10 flex justify-center">
        <Logo size="lg" />
      </div>
      <h1 className="text-4xl md:text-6xl lg:text-7xl font-extrabold leading-[1.05] tracking-tight relative z-10">
        {copy.hero.headlinePre}
        <span className="text-gradient-gold">{copy.hero.headlineHighlight}</span>
      </h1>
      <p className="mt-6 text-base md:text-lg text-muted-foreground max-w-2xl mx-auto">
        {copy.hero.sub}
      </p>
      <div className="mt-10 flex flex-col items-center gap-4">
        <a
          href="#waitlist"
          className="shimmer-btn bg-gradient-gold text-barz-dark font-bold w-full max-w-[400px] h-14 rounded-full inline-flex items-center justify-center text-base hover:scale-[1.02] active:scale-[0.98] transition-transform shadow-[0_10px_40px_-10px_rgba(255,222,89,0.6)]"
        >
          {copy.hero.cta}
        </a>
        <a href="#login" className="text-sm text-muted-foreground hover:text-barz-gold transition-colors">
          {copy.hero.secondary}
        </a>
      </div>
    </div>
    <a href="#social" aria-label="Scroll" className="absolute bottom-8 z-10 text-barz-gold pulse-down">
      <ChevronDown size={32} />
    </a>
  </section>
);
