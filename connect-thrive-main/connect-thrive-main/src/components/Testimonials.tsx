import { Card, CardContent } from "@/components/ui/card";
import { Star } from "lucide-react";

const Testimonials = () => {
  const testimonials = [
    {
      name: "Sophie Martin",
      role: "Présidente d'association",
      content: "Grâce à CommunityApps, nous avons multiplié par 3 l'engagement de nos membres. Les notifications en temps réel changent vraiment la donne !",
      rating: 5,
      avatar: "👩‍💼",
    },
    {
      name: "Jean Dupont",
      role: "Responsable communication",
      content: "L'application d'administration nous fait gagner un temps précieux. La recherche avancée et les annonces ciblées sont exactement ce dont nous avions besoin.",
      rating: 5,
      avatar: "👨‍💻",
    },
    {
      name: "Marie Laurent",
      role: "Coordinatrice communautaire",
      content: "Interface intuitive, fonctionnalités complètes et support réactif. Nos 2000 membres sont ravis ! Je recommande à 100%.",
      rating: 5,
      avatar: "👩‍🎓",
    },
  ];

  return (
    <section id="testimonials" className="py-20 bg-gradient-soft">
      <div className="container mx-auto px-4">
        <div className="text-center mb-16 animate-fade-in">
          <h2 className="text-3xl md:text-5xl font-display font-bold text-foreground mb-4">
            Ils nous font confiance
          </h2>
          <p className="text-lg text-muted-foreground max-w-2xl mx-auto">
            Découvrez ce que nos utilisateurs pensent de nos applications
          </p>
        </div>

        <div className="grid md:grid-cols-3 gap-8">
          {testimonials.map((testimonial, index) => (
            <Card
              key={index}
              className="border-border shadow-medium hover:shadow-strong transition-all duration-300 animate-scale-in"
              style={{ animationDelay: `${index * 0.15}s` }}
            >
              <CardContent className="p-6">
                <div className="flex items-center gap-1 mb-4">
                  {[...Array(testimonial.rating)].map((_, i) => (
                    <Star key={i} className="text-accent fill-accent" size={18} />
                  ))}
                </div>
                <p className="text-foreground mb-6 leading-relaxed italic">
                  "{testimonial.content}"
                </p>
                <div className="flex items-center gap-3">
                  <div className="w-12 h-12 rounded-full bg-gradient-hero flex items-center justify-center text-2xl">
                    {testimonial.avatar}
                  </div>
                  <div>
                    <p className="font-semibold text-foreground">{testimonial.name}</p>
                    <p className="text-sm text-muted-foreground">{testimonial.role}</p>
                  </div>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      </div>
    </section>
  );
};

export default Testimonials;
