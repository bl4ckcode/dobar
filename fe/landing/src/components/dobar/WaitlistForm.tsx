import { useState } from "react";
import { z } from "zod";
import { Store, User, Mail, Phone, ShieldCheck, Lock, CheckCircle, Loader2 } from "lucide-react";
import { copy } from "@/lib/i18n";
import { toast } from "sonner";

const schema = z.object({
  bar: z.string().trim().min(2, "Nome do bar muito curto").max(80),
  name: z.string().trim().min(2, "Nome muito curto").max(80),
  email: z.string().trim().email("E-mail inválido").max(160),
  phone: z.string().trim().min(10, "WhatsApp inválido").max(20),
  city: z.string().min(1, "Selecione uma cidade"),
});

const maskPhone = (v: string) => {
  const d = v.replace(/\D/g, "").slice(0, 11);
  if (d.length <= 2) return d;
  if (d.length <= 7) return `(${d.slice(0, 2)}) ${d.slice(2)}`;
  return `(${d.slice(0, 2)}) ${d.slice(2, 7)}-${d.slice(7)}`;
};

const API_BASE_URL = "https://barz-backend-bold-sun-5691.fly.dev";

interface WaitlistPayload {
  bar_name: string;
  contact_name: string;
  email: string;
  phone: string;
  city: string;
  source: string;
  utm_params?: {
    source?: string;
    medium?: string;
    campaign?: string;
  };
}

const Confetti = () => (
  <div className="pointer-events-none absolute inset-0 overflow-hidden">
    {Array.from({ length: 30 }).map((_, i) => (
      <span
        key={i}
        className="absolute w-1.5 h-3 bg-barz-gold rounded-sm"
        style={{
          left: `${Math.random() * 100}%`,
          top: "-10%",
          animation: `fall ${1.5 + Math.random() * 1.5}s ${Math.random() * 0.5}s ease-out forwards`,
          transform: `rotate(${Math.random() * 360}deg)`,
        }}
      />
    ))}
    <style>{`@keyframes fall { to { transform: translateY(120vh) rotate(720deg); opacity: 0; } }`}</style>
  </div>
);

export const WaitlistForm = () => {
  const [form, setForm] = useState({ bar: "", name: "", email: "", phone: "", city: "" });
  const [loading, setLoading] = useState(false);
  const [success, setSuccess] = useState(false);
  const [errors, setErrors] = useState<Record<string, string>>({});

  const onSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    const r = schema.safeParse(form);
    if (!r.success) {
      const errs: Record<string, string> = {};
      r.error.errors.forEach((er) => (errs[er.path[0] as string] = er.message));
      setErrors(errs);
      return;
    }
    setErrors({});
    setLoading(true);
    try {
      const payload: WaitlistPayload = {
        bar_name: form.bar,
        contact_name: form.name,
        email: form.email,
        phone: form.phone.replace(/\D/g, ""),
        city: form.city,
        source: "landing_page",
        utm_params: {
          source: new URLSearchParams(window.location.search).get("utm_source") || undefined,
          medium: new URLSearchParams(window.location.search).get("utm_medium") || undefined,
          campaign: new URLSearchParams(window.location.search).get("utm_campaign") || undefined,
        },
      };

      const response = await fetch(`${API_BASE_URL}/api/v1/waitlist/signup`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify(payload),
      });

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({}));
        throw new Error(errorData.message || `HTTP error! status: ${response.status}`);
      }

      setSuccess(true);
      toast.success("Cadastro confirmado!");
    } catch (err) {
      const message = err instanceof Error ? err.message : "Algo deu errado. Tente novamente.";
      toast.error(message);
    } finally {
      setLoading(false);
    }
  };

  const inputCls = "w-full bg-barz-darkCard border border-barz-border rounded-xl h-12 pl-11 pr-4 text-sm placeholder:text-muted-foreground/60 focus:outline-none focus:border-barz-gold focus:ring-2 focus:ring-barz-gold/30 transition";

  return (
    <section id="waitlist" className="py-24 bg-barz-dark">
      <div className="container max-w-2xl">
        <div className="relative bg-barz-darkLight border border-barz-gold/30 rounded-3xl p-8 md:p-10 shadow-[0_0_60px_-20px_rgba(255,222,89,0.4)] overflow-hidden">
          {success && <Confetti />}

          {!success ? (
            <>
              <div className="text-center mb-8">
                <h2 className="text-3xl md:text-4xl font-extrabold mb-3">{copy.form.title}</h2>
                <p className="text-muted-foreground">{copy.form.sub}</p>
              </div>

              <form onSubmit={onSubmit} className="space-y-4" noValidate>
                <div className="relative">
                  <Store className="absolute left-4 top-1/2 -translate-y-1/2 text-barz-gold" size={18} />
                  <input className={inputCls} placeholder={copy.form.fields.bar} value={form.bar} onChange={(e) => setForm({ ...form, bar: e.target.value })} maxLength={80} />
                  {errors.bar && <p className="text-errorRed text-xs mt-1 ml-1">{errors.bar}</p>}
                </div>
                <div className="relative">
                  <User className="absolute left-4 top-1/2 -translate-y-1/2 text-barz-gold" size={18} />
                  <input className={inputCls} placeholder={copy.form.fields.name} value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} maxLength={80} />
                  {errors.name && <p className="text-errorRed text-xs mt-1 ml-1">{errors.name}</p>}
                </div>
                <div className="relative">
                  <Mail className="absolute left-4 top-1/2 -translate-y-1/2 text-barz-gold" size={18} />
                  <input type="email" className={inputCls} placeholder={copy.form.fields.email} value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} maxLength={160} />
                  {errors.email && <p className="text-errorRed text-xs mt-1 ml-1">{errors.email}</p>}
                </div>
                <div className="relative">
                  <Phone className="absolute left-4 top-1/2 -translate-y-1/2 text-barz-gold" size={18} />
                  <input className={inputCls} placeholder="(11) 99999-9999" value={form.phone} onChange={(e) => setForm({ ...form, phone: maskPhone(e.target.value) })} />
                  {errors.phone && <p className="text-errorRed text-xs mt-1 ml-1">{errors.phone}</p>}
                </div>
                <div className="relative">
                  <select
                    className={`${inputCls} pl-4 appearance-none cursor-pointer ${form.city ? "text-foreground" : "text-muted-foreground/60"}`}
                    value={form.city}
                    onChange={(e) => setForm({ ...form, city: e.target.value })}
                  >
                    <option value="">{copy.form.fields.city}</option>
                    {copy.form.cities.map((c) => (
                      <option key={c} value={c} className="text-foreground bg-barz-darkCard">{c}</option>
                    ))}
                  </select>
                  {errors.city && <p className="text-errorRed text-xs mt-1 ml-1">{errors.city}</p>}
                </div>

                <button
                  type="submit"
                  disabled={loading}
                  className="shimmer-btn w-full h-14 rounded-full bg-gradient-gold text-barz-dark font-bold text-base mt-2 hover:scale-[1.01] active:scale-[0.97] transition-transform disabled:opacity-70 inline-flex items-center justify-center gap-2"
                >
                  {loading ? <Loader2 className="animate-spin" size={20} /> : copy.form.submit}
                </button>

                <div className="flex flex-wrap items-center justify-center gap-x-6 gap-y-2 pt-3 text-xs text-muted-foreground">
                  <span className="inline-flex items-center gap-1.5"><ShieldCheck size={14} className="text-pixGreen" /> {copy.form.secure}</span>
                  <span className="inline-flex items-center gap-1.5"><Lock size={14} className="text-pixGreen" /> {copy.form.nospam}</span>
                </div>
              </form>
            </>
          ) : (
            <div className="text-center py-6 relative z-10">
              <div className="mx-auto w-16 h-16 rounded-full bg-pixGreen/15 flex items-center justify-center mb-5">
                <CheckCircle className="text-pixGreen" size={36} />
              </div>
              <h3 className="text-2xl md:text-3xl font-extrabold mb-3">{copy.form.successTitle}</h3>
              <p className="text-muted-foreground mb-6 max-w-md mx-auto">{copy.form.successDesc}</p>
              <div className="flex justify-center gap-3">
                <a
                  target="_blank" rel="noreferrer"
                  href={`https://wa.me/?text=${encodeURIComponent("Acabei de entrar na lista de espera do Dobar — o futuro dos pedidos no bar! https://dobar.app")}`}
                  className="px-5 h-11 inline-flex items-center rounded-full bg-pixGreen text-white font-semibold text-sm hover:opacity-90 transition"
                >WhatsApp</a>
                <a
                  target="_blank" rel="noreferrer"
                  href="https://instagram.com"
                  className="px-5 h-11 inline-flex items-center rounded-full bg-barz-darkCard border border-barz-border text-foreground font-semibold text-sm hover:border-barz-gold transition"
                >Instagram</a>
              </div>
            </div>
          )}
        </div>
      </div>
    </section>
  );
};
