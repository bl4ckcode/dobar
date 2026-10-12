import { Navbar } from "@/components/dobar/Navbar";
import { Hero } from "@/components/dobar/Hero";
import { SocialProof } from "@/components/dobar/SocialProof";
import { Features } from "@/components/dobar/Features";
import { Pricing } from "@/components/dobar/Pricing";
import { HowItWorks } from "@/components/dobar/HowItWorks";
import { WaitlistForm } from "@/components/dobar/WaitlistForm";
import { FAQ } from "@/components/dobar/FAQ";
import { Footer } from "@/components/dobar/Footer";
import { useEffect } from "react";

const Index = () => {
  useEffect(() => {
    document.title = "Dobar — O Futuro dos Pedidos no Bar";
    const meta = document.querySelector('meta[name="description"]') || (() => {
      const m = document.createElement("meta");
      m.setAttribute("name", "description");
      document.head.appendChild(m);
      return m;
    })();
    meta.setAttribute("content", "Dobar: pedidos digitais, PIX instantâneo e marketing para bares. Entre na lista de espera do lançamento.");
  }, []);

  return (
    <main className="bg-barz-dark text-foreground min-h-screen">
      <Navbar />
      <Hero />
      <SocialProof />
      <Features />
      <Pricing />
      <HowItWorks />
      <WaitlistForm />
      <FAQ />
      <Footer />
    </main>
  );
};

export default Index;
