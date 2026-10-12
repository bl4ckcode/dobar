import { copy } from "@/lib/i18n";

export const HowItWorks = () => (
  <section id="how" className="py-24 bg-barz-dark diagonal-lines relative">
    <div className="container relative">
      <h2 className="text-center text-3xl md:text-5xl font-extrabold mb-16">
        {copy.how.title}
      </h2>

      <div className="relative grid md:grid-cols-3 gap-10 md:gap-6">
        <div className="hidden md:block absolute top-12 left-[16%] right-[16%] h-px bg-gradient-to-r from-transparent via-barz-gold to-transparent opacity-50" />
        {copy.how.steps.map((s) => (
          <div key={s.n} className="relative text-center md:text-left z-10">
            <div className="inline-flex items-center justify-center w-20 h-20 rounded-2xl bg-barz-darkCard border border-barz-gold/40 mb-5 mx-auto md:mx-0">
              <span className="text-3xl font-extrabold text-gradient-gold">{s.n}</span>
            </div>
            <h3 className="text-xl font-bold mb-2">{s.title}</h3>
            <p className="text-muted-foreground">{s.desc}</p>
          </div>
        ))}
      </div>

      <div className="text-center mt-16">
        <a
          href="#waitlist"
          className="shimmer-btn inline-flex items-center justify-center bg-gradient-gold text-barz-dark font-bold h-14 px-10 rounded-full hover:scale-[1.02] active:scale-[0.98] transition-transform"
        >
          {copy.hero.cta}
        </a>
      </div>
    </div>
  </section>
);
