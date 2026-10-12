import { Instagram, Linkedin } from "lucide-react";
import { Logo } from "./Logo";
import { copy } from "@/lib/i18n";

export const Footer = () => (
  <footer className="border-t border-barz-border bg-barz-dark py-12">
    <div className="container flex flex-col items-center gap-6 text-center">
      <Logo size="sm" />
      <nav className="flex flex-wrap justify-center gap-x-6 gap-y-2 text-sm text-muted-foreground">
        {copy.footer.links.map((l) => (
          <a key={l} href="#" className="hover:text-barz-gold transition-colors">{l}</a>
        ))}
      </nav>
      <div className="flex gap-4">
        <a href="#" aria-label="Instagram" className="w-10 h-10 rounded-full border border-barz-border flex items-center justify-center text-muted-foreground hover:text-barz-gold hover:border-barz-gold transition">
          <Instagram size={18} />
        </a>
        <a href="#" aria-label="LinkedIn" className="w-10 h-10 rounded-full border border-barz-border flex items-center justify-center text-muted-foreground hover:text-barz-gold hover:border-barz-gold transition">
          <Linkedin size={18} />
        </a>
      </div>
      <p className="text-xs text-muted-foreground">{copy.footer.rights}</p>
    </div>
  </footer>
);
