import { Logo } from "./Logo";
import { copy } from "@/lib/i18n";

export const Navbar = () => (
  <header className="fixed top-0 inset-x-0 z-50 backdrop-blur-md bg-barz-dark/70 border-b border-barz-border/50">
    <div className="container flex items-center justify-between h-16">
      <a href="#top" aria-label="Dobar"><Logo size="sm" /></a>
      <nav className="hidden md:flex items-center gap-8 text-sm text-muted-foreground">
        <a href="#features" className="hover:text-barz-gold transition-colors">{copy.nav.features}</a>
        <a href="#how" className="hover:text-barz-gold transition-colors">{copy.nav.how}</a>
        <a href="#faq" className="hover:text-barz-gold transition-colors">{copy.nav.faq}</a>
      </nav>
      <a
        href="#waitlist"
        className="bg-gradient-gold text-barz-dark text-sm font-semibold px-4 py-2 rounded-full hover:opacity-90 transition"
      >
        {copy.nav.join}
      </a>
    </div>
  </header>
);
