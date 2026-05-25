-- 1. Création de la table de configuration de l'application
CREATE TABLE public.app_settings (
  id integer PRIMARY KEY DEFAULT 1,
  base_fare numeric(10, 2) NOT NULL DEFAULT 50.00,
  per_km_rate numeric(10, 2) NOT NULL DEFAULT 150.00,
  minimum_fare numeric(10, 2) NOT NULL DEFAULT 100.00,
  currency text NOT NULL DEFAULT 'HTG',
  updated_at timestamp with time zone DEFAULT now(),
  -- Contrainte pour forcer une seule ligne de configuration (id = 1)
  CONSTRAINT enforce_single_row CHECK (id = 1)
);

-- 2. Insertion de la valeur par défaut pour démarrer
INSERT INTO public.app_settings (id, base_fare, per_km_rate, minimum_fare, currency)
VALUES (1, 50.00, 150.00, 100.00, 'HTG')
ON CONFLICT (id) DO NOTHING;

-- 3. Ajout des règles de sécurité (Row Level Security)
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

-- Autoriser la lecture publique de cette configuration (les utilisateurs de l'app doivent pouvoir la lire)
CREATE POLICY "Les paramètres sont visibles par tous"
ON public.app_settings
FOR SELECT
USING (true);
