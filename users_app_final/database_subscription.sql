-- 1. Création de la table des forfaits d'abonnement
CREATE TABLE public.subscription_plans (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  name text NOT NULL,
  description text,
  price numeric(10, 2) NOT NULL DEFAULT 0.00,
  currency text NOT NULL DEFAULT 'HTG',
  discount_percentage numeric(5, 2) NOT NULL DEFAULT 0.00,
  duration_days integer NOT NULL DEFAULT 30,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now()
);

-- Ajouter des données par défaut (Exemples modifiables depuis le pannel)
INSERT INTO public.subscription_plans (name, description, price, currency, discount_percentage, duration_days)
VALUES 
('Le Bon Taxi Gratuit', 'Utilisateur standard sans forfait.', 0.00, 'HTG', 0.00, 365),
('Le Bon Taxi Plus (Mensuel)', 'Réductions de 10% sur tous vos trajets !', 500.00, 'HTG', 10.00, 30),
('Le Bon Taxi Plus (Annuel)', 'Réductions de 15% sur tous vos trajets !', 5000.00, 'HTG', 15.00, 365);


-- 2. Mise à jour de la table "users" pour lier l'utilisateur au forfait
ALTER TABLE public.users 
ADD COLUMN subscription_plan_id uuid REFERENCES public.subscription_plans(id),
ADD COLUMN subscription_end_date timestamp with time zone;

-- 3. Ajout des règles de sécurité (Row Level Security)
ALTER TABLE public.subscription_plans ENABLE ROW LEVEL SECURITY;

-- Autoriser la lecture publique des plans actifs pour que l'app mobile puisse les afficher
CREATE POLICY "Les plans actifs sont visibles de tous"
ON public.subscription_plans
FOR SELECT
USING (is_active = true);
