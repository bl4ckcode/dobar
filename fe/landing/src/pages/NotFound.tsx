import { useEffect } from "react";
import { useLocation, Link } from "react-router-dom";

export default function NotFound() {
  const location = useLocation();

  useEffect(() => {
    console.error(
      "404 Error: User attempted to access non-existent route:",
      location.pathname
    );
  }, [location.pathname]);

  return (
    <div className="min-h-screen flex flex-col items-center justify-center bg-barz-dark text-foreground px-4">
      <h1 className="text-6xl font-extrabold text-gradient-gold mb-4">404</h1>
      <p className="text-xl text-muted-foreground mb-8">Página não encontrada</p>
      <Link
        to="/"
        className="bg-gradient-gold text-barz-dark font-bold px-8 py-3 rounded-full hover:opacity-90 transition"
      >
        Voltar para home
      </Link>
    </div>
  );
}
