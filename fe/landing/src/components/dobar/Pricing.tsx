import { Check, X } from "lucide-react";
import { copy } from "@/lib/i18n";
import { Button } from "@/components/ui/button";

export const Pricing = () => {
  return (
    <section id="pricing" className="py-24 bg-barz-dark relative">
      <div className="absolute inset-0 diagonal-lines opacity-50 pointer-events-none" />
      <div className="container relative">
        <div className="text-center max-w-2xl mx-auto mb-14">
          <h2 className="text-3xl md:text-5xl font-extrabold leading-tight">
            <span className="text-gradient-gold">{copy.pricing.title}</span>
          </h2>
          <p className="mt-4 text-muted-foreground">{copy.pricing.sub}</p>
        </div>

        <div className="grid md:grid-cols-3 gap-6 max-w-6xl mx-auto items-stretch">
          {copy.pricing.plans.map((plan) => {
            const isMaster = plan.highlight;
            const isVip = plan.premium;
            return (
              <div
                key={plan.name}
                className={`relative rounded-2xl p-[1px] transition-transform duration-300 hover:-translate-y-1 ${
                  isVip ? "bg-gradient-gold" : "bg-barz-border/60"
                } ${isMaster ? "md:scale-105 md:-mt-2" : ""}`}
              >
                {isMaster && (
                  <div className="absolute -top-3 left-1/2 -translate-x-1/2 z-10">
                    <span className="bg-gradient-gold text-barz-dark text-xs font-bold uppercase tracking-wider px-4 py-1 rounded-full shadow-[0_0_20px_rgba(255,222,89,0.5)]">
                      {copy.pricing.popular}
                    </span>
                  </div>
                )}
                <div
                  className={`h-full rounded-2xl p-8 flex flex-col bg-barz-darkCard ${
                    isMaster ? "shadow-[0_0_40px_rgba(255,222,89,0.15)]" : ""
                  }`}
                >
                  <div className="mb-6">
                    <h3 className="text-2xl font-extrabold mb-1">{plan.name}</h3>
                    <p className="text-sm text-muted-foreground">{plan.commission}</p>
                  </div>

                  <div className="mb-6">
                    <div className="flex items-baseline gap-1">
                      <span className={`text-4xl font-extrabold ${isVip || isMaster ? "text-gradient-gold" : ""}`}>
                        {plan.price}
                      </span>
                      {plan.priceUnit && (
                        <span className="text-muted-foreground font-medium">{plan.priceUnit}</span>
                      )}
                    </div>
                    <p className="text-xs text-muted-foreground mt-1">{plan.priceSub}</p>
                  </div>

                  <ul className="space-y-3 mb-8 flex-1">
                    {plan.features.map((f) => (
                      <li key={f.label} className="flex items-start gap-2 text-sm">
                        {f.ok ? (
                          <Check size={16} className="text-barz-gold shrink-0 mt-0.5" strokeWidth={3} />
                        ) : (
                          <X size={16} className="text-muted-foreground/40 shrink-0 mt-0.5" />
                        )}
                        <span className={f.ok ? "text-foreground" : "text-muted-foreground/50 line-through"}>
                          {f.label}
                        </span>
                      </li>
                    ))}
                  </ul>

                  <Button
                    asChild
                    size={isVip ? "lg" : "default"}
                    className={
                      plan.ctaVariant === "primary"
                        ? "w-full bg-gradient-gold text-barz-dark font-bold hover:opacity-90 hover:bg-gradient-gold shimmer-btn"
                        : "w-full bg-transparent border border-barz-gold text-barz-gold font-bold hover:bg-barz-gold hover:text-barz-dark"
                    }
                  >
                    <a href="#waitlist">{plan.cta}</a>
                  </Button>
                </div>
              </div>
            );
          })}
        </div>

        <p className="text-center text-xs text-muted-foreground mt-6">{copy.pricing.vipNote}</p>

        <div className="mt-10 max-w-2xl mx-auto p-5 rounded-xl bg-barz-darkCard border border-barz-gold/30 text-center">
          <p className="text-sm text-foreground/90">{copy.pricing.trust}</p>
        </div>
      </div>
    </section>
  );
};
