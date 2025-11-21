import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Card, CardContent } from "@/components/ui/card";
import { Mail, Phone, MapPin } from "lucide-react";
import { useToast } from "@/hooks/use-toast";
import { z } from "zod";

const contactSchema = z.object({
  name: z.string().trim().min(1, "Le nom est requis").max(100),
  email: z.string().trim().email("Email invalide").max(255),
  subject: z.string().trim().min(1, "Le sujet est requis").max(200),
  message: z.string().trim().min(10, "Le message doit contenir au moins 10 caractères").max(1000),
});

const ContactForm = () => {
  const { toast } = useToast();
  const [formData, setFormData] = useState({
    name: "",
    email: "",
    subject: "",
    message: "",
  });
  const [errors, setErrors] = useState<Record<string, string>>({});

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    
    try {
      contactSchema.parse(formData);
      setErrors({});
      
      // Ici, vous pourriez envoyer les données à votre backend
      toast({
        title: "Message envoyé !",
        description: "Nous vous répondrons dans les plus brefs délais.",
      });
      
      setFormData({ name: "", email: "", subject: "", message: "" });
    } catch (error) {
      if (error instanceof z.ZodError) {
        const newErrors: Record<string, string> = {};
        error.errors.forEach((err) => {
          if (err.path[0]) {
            newErrors[err.path[0].toString()] = err.message;
          }
        });
        setErrors(newErrors);
      }
    }
  };

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
    const { name, value } = e.target;
    setFormData((prev) => ({ ...prev, [name]: value }));
    if (errors[name]) {
      setErrors((prev) => ({ ...prev, [name]: "" }));
    }
  };

  return (
    <section id="contact" className="py-20 bg-gradient-soft">
      <div className="container mx-auto px-4">
        <div className="text-center mb-16 animate-fade-in">
          <h2 className="text-3xl md:text-5xl font-display font-bold text-foreground mb-4">
            Contactez-nous
          </h2>
          <p className="text-lg text-muted-foreground max-w-2xl mx-auto">
            Une question ? Un projet ? Notre équipe est là pour vous accompagner
          </p>
        </div>

        <div className="grid md:grid-cols-2 gap-12 max-w-6xl mx-auto">
          <div className="animate-slide-in-left">
            <Card className="shadow-medium border-border h-full">
              <CardContent className="p-8">
                <form onSubmit={handleSubmit} className="space-y-6">
                  <div>
                    <label htmlFor="name" className="block text-sm font-medium text-foreground mb-2">
                      Nom complet *
                    </label>
                    <Input
                      id="name"
                      name="name"
                      value={formData.name}
                      onChange={handleChange}
                      className={errors.name ? "border-destructive" : ""}
                      placeholder="Jean Dupont"
                    />
                    {errors.name && (
                      <p className="text-destructive text-sm mt-1">{errors.name}</p>
                    )}
                  </div>

                  <div>
                    <label htmlFor="email" className="block text-sm font-medium text-foreground mb-2">
                      Email *
                    </label>
                    <Input
                      id="email"
                      name="email"
                      type="email"
                      value={formData.email}
                      onChange={handleChange}
                      className={errors.email ? "border-destructive" : ""}
                      placeholder="jean.dupont@example.com"
                    />
                    {errors.email && (
                      <p className="text-destructive text-sm mt-1">{errors.email}</p>
                    )}
                  </div>

                  <div>
                    <label htmlFor="subject" className="block text-sm font-medium text-foreground mb-2">
                      Sujet *
                    </label>
                    <Input
                      id="subject"
                      name="subject"
                      value={formData.subject}
                      onChange={handleChange}
                      className={errors.subject ? "border-destructive" : ""}
                      placeholder="Demande de démonstration"
                    />
                    {errors.subject && (
                      <p className="text-destructive text-sm mt-1">{errors.subject}</p>
                    )}
                  </div>

                  <div>
                    <label htmlFor="message" className="block text-sm font-medium text-foreground mb-2">
                      Message *
                    </label>
                    <Textarea
                      id="message"
                      name="message"
                      value={formData.message}
                      onChange={handleChange}
                      className={errors.message ? "border-destructive" : ""}
                      placeholder="Parlez-nous de votre projet..."
                      rows={5}
                    />
                    {errors.message && (
                      <p className="text-destructive text-sm mt-1">{errors.message}</p>
                    )}
                  </div>

                  <Button
                    type="submit"
                    className="w-full bg-gradient-accent text-accent-foreground shadow-medium hover:opacity-90"
                  >
                    Envoyer le message
                  </Button>
                </form>
              </CardContent>
            </Card>
          </div>

          <div className="space-y-6 animate-slide-in-right">
            <Card className="shadow-soft border-border">
              <CardContent className="p-6">
                <div className="flex items-start gap-4">
                  <div className="w-12 h-12 rounded-lg bg-primary/10 flex items-center justify-center flex-shrink-0">
                    <Mail className="text-primary" size={24} />
                  </div>
                  <div>
                    <h3 className="font-semibold text-foreground mb-1">Email</h3>
                    <p className="text-muted-foreground">contact@communityapps.fr</p>
                    <p className="text-muted-foreground">support@communityapps.fr</p>
                  </div>
                </div>
              </CardContent>
            </Card>

            <Card className="shadow-soft border-border">
              <CardContent className="p-6">
                <div className="flex items-start gap-4">
                  <div className="w-12 h-12 rounded-lg bg-accent/10 flex items-center justify-center flex-shrink-0">
                    <Phone className="text-accent" size={24} />
                  </div>
                  <div>
                    <h3 className="font-semibold text-foreground mb-1">Téléphone</h3>
                    <p className="text-muted-foreground">+33 1 23 45 67 89</p>
                    <p className="text-sm text-muted-foreground mt-1">Lun - Ven, 9h - 18h</p>
                  </div>
                </div>
              </CardContent>
            </Card>

            <Card className="shadow-soft border-border">
              <CardContent className="p-6">
                <div className="flex items-start gap-4">
                  <div className="w-12 h-12 rounded-lg bg-primary/10 flex items-center justify-center flex-shrink-0">
                    <MapPin className="text-primary" size={24} />
                  </div>
                  <div>
                    <h3 className="font-semibold text-foreground mb-1">Adresse</h3>
                    <p className="text-muted-foreground">123 Avenue des Champs-Élysées</p>
                    <p className="text-muted-foreground">75008 Paris, France</p>
                  </div>
                </div>
              </CardContent>
            </Card>

            <Card className="shadow-medium border-primary/20 bg-gradient-hero">
              <CardContent className="p-6">
                <h3 className="font-display font-bold text-primary-foreground text-xl mb-2">
                  Besoin d'une démo ?
                </h3>
                <p className="text-primary-foreground/90 mb-4">
                  Découvrez nos applications en action avec une démonstration personnalisée de 30 minutes.
                </p>
                <Button variant="secondary" className="shadow-soft">
                  Réserver une démo
                </Button>
              </CardContent>
            </Card>
          </div>
        </div>
      </div>
    </section>
  );
};

export default ContactForm;
