import { Card, CardContent } from "@/components/ui/card";
import { MessageSquare, Users, Shield, Zap, Globe, Heart } from "lucide-react";

const Features = () => {
  const features = [
    {
      icon: MessageSquare,
      title: "Communication fluide",
      description: "Échangez instantanément avec posts, commentaires et notifications en temps réel.",
      color: "primary",
    },
    {
      icon: Users,
      title: "Gestion centralisée",
      description: "Administrez votre communauté avec des outils puissants et intuitifs.",
      color: "accent",
    },
    {
      icon: Shield,
      title: "Sécurité maximale",
      description: "Vos données sont cryptées et protégées selon les normes les plus strictes.",
      color: "primary",
    },
    {
      icon: Zap,
      title: "Performance optimale",
      description: "Application rapide et réactive, même avec des milliers d'utilisateurs.",
      color: "accent",
    },
    {
      icon: Globe,
      title: "Accessibilité totale",
      description: "Disponible sur iOS et Android, accessible partout, à tout moment.",
      color: "primary",
    },
    {
      icon: Heart,
      title: "Support dédié",
      description: "Notre équipe vous accompagne pour une expérience optimale.",
      color: "accent",
    },
  ];

  return (
    <section id="features" className="py-20 bg-background">
      <div className="container mx-auto px-4">
        <div className="text-center mb-16 animate-fade-in">
          <h2 className="text-3xl md:text-5xl font-display font-bold text-foreground mb-4">
            Pourquoi choisir nos applications ?
          </h2>
          <p className="text-lg text-muted-foreground max-w-2xl mx-auto">
            Des fonctionnalités conçues pour simplifier et enrichir l'expérience de votre communauté
          </p>
        </div>

        <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-8">
          {features.map((feature, index) => {
            const Icon = feature.icon;
            const bgColor = feature.color === "primary" ? "bg-primary/10" : "bg-accent/10";
            const textColor = feature.color === "primary" ? "text-primary" : "text-accent";

            return (
              <Card
                key={index}
                className="border-border shadow-soft hover:shadow-medium transition-all duration-300 hover:-translate-y-1 animate-scale-in"
                style={{ animationDelay: `${index * 0.1}s` }}
              >
                <CardContent className="p-6">
                  <div className={`w-14 h-14 ${bgColor} rounded-xl flex items-center justify-center mb-4`}>
                    <Icon className={textColor} size={28} />
                  </div>
                  <h3 className="text-xl font-display font-bold text-foreground mb-2">
                    {feature.title}
                  </h3>
                  <p className="text-muted-foreground leading-relaxed">
                    {feature.description}
                  </p>
                </CardContent>
              </Card>
            );
          })}
        </div>
      </div>
    </section>
  );
};

export default Features;
