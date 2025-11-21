import { Button } from "@/components/ui/button";
import { Download, Play } from "lucide-react";
import heroImage from "@/assets/hero-bg.jpg";

const Hero = () => {
  const scrollToContact = () => {
    const element = document.getElementById("contact");
    if (element) {
      element.scrollIntoView({ behavior: "smooth" });
    }
  };

  return (
    <section className="relative min-h-screen flex items-center justify-center overflow-hidden">
      <div
        className="absolute inset-0 bg-cover bg-center"
        style={{ backgroundImage: `url(${heroImage})` }}
      >
        <div className="absolute inset-0 bg-gradient-to-br from-primary/90 to-primary/70" />
      </div>

      <div className="container mx-auto px-4 relative z-10 pt-20">
        <div className="max-w-4xl mx-auto text-center">
          <div className="animate-fade-in">
            <h1 className="text-4xl md:text-6xl lg:text-7xl font-display font-bold text-primary-foreground mb-6 leading-tight">
              Connectez votre communauté comme jamais auparavant
            </h1>
            <p className="text-lg md:text-xl text-primary-foreground/90 mb-8 max-w-2xl mx-auto leading-relaxed">
              Deux applications puissantes pour transformer la communication et la gestion de votre communauté. 
              Simple, sécurisé et conçu pour vous.
            </p>
          </div>

          <div className="flex flex-col sm:flex-row gap-4 justify-center items-center animate-scale-in">
            <Button
              size="lg"
              className="bg-accent text-accent-foreground hover:opacity-90 shadow-strong text-lg px-8 py-6 group"
            >
              <Download className="mr-2 group-hover:animate-bounce" />
              Télécharger maintenant
            </Button>
            <Button
              size="lg"
              variant="outline"
              className="bg-background/10 border-primary-foreground/30 text-primary-foreground hover:bg-background/20 backdrop-blur-sm text-lg px-8 py-6"
              onClick={scrollToContact}
            >
              <Play className="mr-2" />
              Voir la démo
            </Button>
          </div>

          <div className="mt-12 flex flex-wrap justify-center gap-8 text-primary-foreground/80 animate-fade-in">
            <div className="flex items-center gap-2">
              <div className="w-12 h-12 rounded-full bg-accent/20 flex items-center justify-center">
                <span className="text-2xl">📱</span>
              </div>
              <div className="text-left">
                <p className="font-semibold">iOS & Android</p>
                <p className="text-sm">Disponible partout</p>
              </div>
            </div>
            <div className="flex items-center gap-2">
              <div className="w-12 h-12 rounded-full bg-accent/20 flex items-center justify-center">
                <span className="text-2xl">🔒</span>
              </div>
              <div className="text-left">
                <p className="font-semibold">100% Sécurisé</p>
                <p className="text-sm">Données protégées</p>
              </div>
            </div>
            <div className="flex items-center gap-2">
              <div className="w-12 h-12 rounded-full bg-accent/20 flex items-center justify-center">
                <span className="text-2xl">⚡</span>
              </div>
              <div className="text-left">
                <p className="font-semibold">Temps réel</p>
                <p className="text-sm">Notifications instantanées</p>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div className="absolute bottom-0 left-0 right-0 h-32 bg-gradient-to-t from-background to-transparent" />
    </section>
  );
};

export default Hero;
