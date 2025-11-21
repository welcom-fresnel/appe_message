import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { MessageSquare, Bell, Image, Users, Search, BarChart, ShieldAlert, Send } from "lucide-react";
import mainAppMockup from "@/assets/app-main-mockup.png";
import adminAppMockup from "@/assets/app-admin-mockup.png";

const AppShowcase = () => {
  return (
    <section id="apps" className="py-20 bg-gradient-soft">
      <div className="container mx-auto px-4">
        <div className="text-center mb-16 animate-fade-in">
          <h2 className="text-3xl md:text-5xl font-display font-bold text-foreground mb-4">
            Deux applications, une solution complète
          </h2>
          <p className="text-lg text-muted-foreground max-w-2xl mx-auto">
            Que vous soyez membre ou administrateur, nous avons l'outil parfait pour vous
          </p>
        </div>

        {/* App Principale */}
        <div className="mb-24">
          <div className="grid md:grid-cols-2 gap-12 items-center">
            <div className="order-2 md:order-1 animate-slide-in-left">
              <div className="inline-block px-4 py-1 bg-primary/10 text-primary rounded-full text-sm font-semibold mb-4">
                Application Communautaire
              </div>
              <h3 className="text-3xl md:text-4xl font-display font-bold text-foreground mb-4">
                Restez connecté avec votre communauté
              </h3>
              <p className="text-lg text-muted-foreground mb-6">
                Partagez, échangez et restez informé en temps réel avec une interface intuitive et puissante.
              </p>

              <div className="space-y-4 mb-8">
                <div className="flex items-start gap-3">
                  <div className="w-10 h-10 rounded-lg bg-primary/10 flex items-center justify-center flex-shrink-0">
                    <MessageSquare className="text-primary" size={20} />
                  </div>
                  <div>
                    <h4 className="font-semibold text-foreground mb-1">Posts et commentaires</h4>
                    <p className="text-muted-foreground text-sm">
                      Partagez vos idées, photos et participez aux discussions
                    </p>
                  </div>
                </div>

                <div className="flex items-start gap-3">
                  <div className="w-10 h-10 rounded-lg bg-accent/10 flex items-center justify-center flex-shrink-0">
                    <Bell className="text-accent" size={20} />
                  </div>
                  <div>
                    <h4 className="font-semibold text-foreground mb-1">Notifications en temps réel</h4>
                    <p className="text-muted-foreground text-sm">
                      Ne manquez jamais une annonce importante
                    </p>
                  </div>
                </div>

                <div className="flex items-start gap-3">
                  <div className="w-10 h-10 rounded-lg bg-primary/10 flex items-center justify-center flex-shrink-0">
                    <Image className="text-primary" size={20} />
                  </div>
                  <div>
                    <h4 className="font-semibold text-foreground mb-1">Partage multimédia</h4>
                    <p className="text-muted-foreground text-sm">
                      Photos, audio et vidéos en toute simplicité
                    </p>
                  </div>
                </div>

                <div className="flex items-start gap-3">
                  <div className="w-10 h-10 rounded-lg bg-accent/10 flex items-center justify-center flex-shrink-0">
                    <ShieldAlert className="text-accent" size={20} />
                  </div>
                  <div>
                    <h4 className="font-semibold text-foreground mb-1">Signalement et modération</h4>
                    <p className="text-muted-foreground text-sm">
                      Un espace sûr et respectueux pour tous
                    </p>
                  </div>
                </div>
              </div>

              <div className="flex flex-wrap gap-4">
                <Button className="bg-gradient-hero text-primary-foreground shadow-medium hover:opacity-90">
                  <Download className="mr-2" size={18} />
                  App Store
                </Button>
                <Button variant="outline" className="shadow-soft">
                  <Download className="mr-2" size={18} />
                  Google Play
                </Button>
              </div>
            </div>

            <div className="order-1 md:order-2 animate-slide-in-right">
              <div className="relative">
                <div className="absolute -inset-4 bg-gradient-accent opacity-20 blur-2xl rounded-full" />
                <img
                  src={mainAppMockup}
                  alt="Application Communautaire"
                  className="relative rounded-3xl shadow-strong mx-auto max-w-xs animate-float"
                />
              </div>
            </div>
          </div>
        </div>

        {/* App Admin */}
        <div>
          <div className="grid md:grid-cols-2 gap-12 items-center">
            <div className="animate-slide-in-left">
              <div className="relative">
                <div className="absolute -inset-4 bg-gradient-hero opacity-20 blur-2xl rounded-full" />
                <img
                  src={adminAppMockup}
                  alt="Application d'Administration"
                  className="relative rounded-3xl shadow-strong mx-auto max-w-xs animate-float"
                  style={{ animationDelay: "1s" }}
                />
              </div>
            </div>

            <div className="animate-slide-in-right">
              <div className="inline-block px-4 py-1 bg-accent/10 text-accent rounded-full text-sm font-semibold mb-4">
                Application d'Administration
              </div>
              <h3 className="text-3xl md:text-4xl font-display font-bold text-foreground mb-4">
                Gérez votre communauté efficacement
              </h3>
              <p className="text-lg text-muted-foreground mb-6">
                Des outils puissants pour administrer, modérer et engager votre communauté.
              </p>

              <div className="space-y-4 mb-8">
                <div className="flex items-start gap-3">
                  <div className="w-10 h-10 rounded-lg bg-accent/10 flex items-center justify-center flex-shrink-0">
                    <Search className="text-accent" size={20} />
                  </div>
                  <div>
                    <h4 className="font-semibold text-foreground mb-1">Recherche avancée</h4>
                    <p className="text-muted-foreground text-sm">
                      Trouvez rapidement n'importe quel utilisateur ou contenu
                    </p>
                  </div>
                </div>

                <div className="flex items-start gap-3">
                  <div className="w-10 h-10 rounded-lg bg-primary/10 flex items-center justify-center flex-shrink-0">
                    <Users className="text-primary" size={20} />
                  </div>
                  <div>
                    <h4 className="font-semibold text-foreground mb-1">Gestion des utilisateurs</h4>
                    <p className="text-muted-foreground text-sm">
                      Profils détaillés, permissions et statistiques
                    </p>
                  </div>
                </div>

                <div className="flex items-start gap-3">
                  <div className="w-10 h-10 rounded-lg bg-accent/10 flex items-center justify-center flex-shrink-0">
                    <Send className="text-accent" size={20} />
                  </div>
                  <div>
                    <h4 className="font-semibold text-foreground mb-1">Annonces ciblées</h4>
                    <p className="text-muted-foreground text-sm">
                      Envoyez des messages à des groupes spécifiques
                    </p>
                  </div>
                </div>

                <div className="flex items-start gap-3">
                  <div className="w-10 h-10 rounded-lg bg-primary/10 flex items-center justify-center flex-shrink-0">
                    <BarChart className="text-primary" size={20} />
                  </div>
                  <div>
                    <h4 className="font-semibold text-foreground mb-1">Tableaux de bord</h4>
                    <p className="text-muted-foreground text-sm">
                      Statistiques et insights sur votre communauté
                    </p>
                  </div>
                </div>
              </div>

              <div className="flex flex-wrap gap-4">
                <Button className="bg-gradient-accent text-accent-foreground shadow-medium hover:opacity-90">
                  <Download className="mr-2" size={18} />
                  App Store
                </Button>
                <Button variant="outline" className="shadow-soft">
                  <Download className="mr-2" size={18} />
                  Google Play
                </Button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
};

const Download = ({ className, size }: { className?: string; size?: number }) => (
  <svg
    xmlns="http://www.w3.org/2000/svg"
    width={size || 24}
    height={size || 24}
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    strokeWidth="2"
    strokeLinecap="round"
    strokeLinejoin="round"
    className={className}
  >
    <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
    <polyline points="7 10 12 15 17 10" />
    <line x1="12" x2="12" y1="15" y2="3" />
  </svg>
);

export default AppShowcase;
