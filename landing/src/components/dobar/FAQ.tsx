import { Accordion, AccordionContent, AccordionItem, AccordionTrigger } from "@/components/ui/accordion";
import { copy } from "@/lib/i18n";

export const FAQ = () => (
  <section id="faq" className="py-24 bg-barz-dark">
    <div className="container max-w-3xl">
      <h2 className="text-3xl md:text-5xl font-extrabold text-center mb-12">{copy.faq.title}</h2>
      <Accordion type="single" collapsible className="space-y-3">
        {copy.faq.items.map((it, i) => (
          <AccordionItem
            key={i}
            value={`item-${i}`}
            className="bg-barz-darkCard border border-barz-border/60 rounded-xl px-5 data-[state=open]:border-barz-gold/60 transition-colors"
          >
            <AccordionTrigger className="text-left text-base font-semibold hover:no-underline py-5">
              {it.q}
            </AccordionTrigger>
            <AccordionContent className="text-muted-foreground leading-relaxed pb-5">
              {it.a}
            </AccordionContent>
          </AccordionItem>
        ))}
      </Accordion>
    </div>
  </section>
);
