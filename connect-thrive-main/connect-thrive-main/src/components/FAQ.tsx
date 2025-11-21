import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from "@/components/ui/accordion";

const FAQ = () => {
  const faqs = [
    {
      question: "Les applications sont-elles disponibles sur iOS et Android ?",
      answer: "Oui ! Nos deux applications (communautaire et d'administration) sont disponibles sur l'App Store pour iOS et sur Google Play pour Android. Elles sont optimisées pour offrir la meilleure expérience sur chaque plateforme.",
    },
    {
      question: "Mes données sont-elles sécurisées ?",
      answer: "Absolument. Nous utilisons un cryptage de bout en bout pour toutes vos données. Vos informations personnelles et les contenus de votre communauté sont stockés sur des serveurs sécurisés conformes aux normes RGPD. La confidentialité et la sécurité sont nos priorités absolues.",
    },
    {
      question: "Combien d'utilisateurs peuvent utiliser l'application ?",
      answer: "Nos applications sont conçues pour évoluer avec vous. Que vous ayez 50 ou 50 000 membres, l'expérience reste fluide et performante. Nous proposons différentes formules adaptées à la taille de votre communauté.",
    },
    {
      question: "Puis-je personnaliser l'application pour ma communauté ?",
      answer: "Oui ! L'application d'administration vous permet de personnaliser de nombreux aspects : couleurs, logo, catégories de posts, règles de modération, et bien plus. Nous pouvons également développer des fonctionnalités sur mesure selon vos besoins spécifiques.",
    },
    {
      question: "Quel type de support proposez-vous ?",
      answer: "Nous offrons un support complet incluant : documentation détaillée, tutoriels vidéo, chat en direct pendant les heures ouvrables, et assistance par email 7j/7. Pour les formules premium, un gestionnaire de compte dédié est disponible.",
    },
    {
      question: "Y a-t-il une période d'essai gratuite ?",
      answer: "Oui ! Nous proposons une période d'essai de 30 jours pour tester toutes les fonctionnalités de nos applications sans engagement. Vous pouvez également demander une démonstration personnalisée pour voir comment nos outils répondent à vos besoins spécifiques.",
    },
  ];

  return (
    <section id="faq" className="py-20 bg-background">
      <div className="container mx-auto px-4 max-w-4xl">
        <div className="text-center mb-16 animate-fade-in">
          <h2 className="text-3xl md:text-5xl font-display font-bold text-foreground mb-4">
            Questions fréquentes
          </h2>
          <p className="text-lg text-muted-foreground">
            Vous avez des questions ? Nous avons les réponses
          </p>
        </div>

        <Accordion type="single" collapsible className="space-y-4">
          {faqs.map((faq, index) => (
            <AccordionItem
              key={index}
              value={`item-${index}`}
              className="border border-border rounded-xl px-6 shadow-soft hover:shadow-medium transition-all animate-fade-in"
              style={{ animationDelay: `${index * 0.1}s` }}
            >
              <AccordionTrigger className="text-left font-semibold text-foreground hover:text-primary">
                {faq.question}
              </AccordionTrigger>
              <AccordionContent className="text-muted-foreground leading-relaxed">
                {faq.answer}
              </AccordionContent>
            </AccordionItem>
          ))}
        </Accordion>
      </div>
    </section>
  );
};

export default FAQ;
