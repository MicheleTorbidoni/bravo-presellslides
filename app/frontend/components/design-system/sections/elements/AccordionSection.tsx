import { SectionShell } from "@/components/design-system/SectionShell";
import {
  Accordion,
  AccordionContent,
  AccordionTrigger,
} from "@/components/ui/accordion";

const code = `import {
  Accordion,
  AccordionTrigger,
  AccordionContent,
} from "@/components/ui/accordion";

<Accordion>
  <AccordionTrigger description="Optional supporting line.">
    Section title
  </AccordionTrigger>
  <AccordionContent>
    <p>Hidden until the trigger is clicked.</p>
  </AccordionContent>
</Accordion>

{/* Expanded on first render */}
<Accordion open>
  <AccordionTrigger>Already open</AccordionTrigger>
  <AccordionContent>
    <p>Visible by default.</p>
  </AccordionContent>
</Accordion>`;

export function AccordionSection() {
  return (
    <SectionShell
      id="accordion"
      title="Accordion"
      description={
        <>
          A single collapsible disclosure built on the native{" "}
          <code>&lt;details&gt;</code>/<code>&lt;summary&gt;</code> elements — no
          JS state, keyboard- and screen-reader-accessible out of the box, and
          safe to render server-side. Collapsed by default; pass the standard{" "}
          <code>open</code> attribute to start expanded.
        </>
      }
      whenToUse={
        <ul>
          <li>Secondary or optional content that shouldn't crowd the first view.</li>
          <li>Progressive disclosure — extra detail one click away.</li>
          <li>FAQ-style lists (stack several, each its own <code>Accordion</code>).</li>
        </ul>
      }
      whenNotToUse={
        <ul>
          <li>Content the user must see — leave it inline.</li>
          <li>Mutually exclusive choices — use tabs or a radio group.</li>
          <li>Blocking, focused tasks — use the <code>Dialog</code> primitive.</li>
        </ul>
      }
      preview={
        <div className="flex max-w-lg flex-col gap-3">
          <Accordion>
            <AccordionTrigger description="Temi vicini al tuo contesto che potrebbero interessarti.">
              Altri approfondimenti
            </AccordionTrigger>
            <AccordionContent>
              <p className="text-ink-body">
                Questo contenuto resta nascosto finché non si clicca sul titolo.
                Le immagini e gli iframe qui dentro si caricano solo
                all'apertura.
              </p>
            </AccordionContent>
          </Accordion>

          <Accordion open>
            <AccordionTrigger>Aperto di default</AccordionTrigger>
            <AccordionContent>
              <p className="text-ink-body">
                Con l'attributo <code>open</code> la sezione è già espansa al
                primo render.
              </p>
            </AccordionContent>
          </Accordion>
        </div>
      }
      code={code}
      options={
        <ul className="list-disc pl-5">
          <li>
            <code>&lt;Accordion&gt;</code> renders a <code>&lt;details&gt;</code>;
            pass <code>open</code> to expand on first render.
          </li>
          <li>
            <code>&lt;AccordionTrigger&gt;</code> takes an optional{" "}
            <code>description</code> prop for the supporting line under the
            title; the chevron rotates automatically on open.
          </li>
          <li>
            <code>&lt;AccordionContent&gt;</code> is a plain container — compose
            its layout with utilities (e.g. <code>flex flex-col gap-6</code>).
          </li>
        </ul>
      }
    />
  );
}
