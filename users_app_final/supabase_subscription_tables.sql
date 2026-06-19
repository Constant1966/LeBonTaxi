-- ============================================================
-- LE BON TAXI — Script SQL Complet pour Abonnements
-- À exécuter dans le SQL Editor de Supabase
-- ============================================================

-- ============================================================
-- 1. TABLE: app_settings (Tarification globale)
-- ============================================================
DROP TABLE IF EXISTS app_settings CASCADE;

CREATE TABLE app_settings (
  id              INTEGER PRIMARY KEY DEFAULT 1,
  -- Tarification
  base_fare       NUMERIC(10,2) NOT NULL DEFAULT 50.00,
  per_km_rate     NUMERIC(10,2) NOT NULL DEFAULT 150.00,
  minimum_fare    NUMERIC(10,2) NOT NULL DEFAULT 100.00,
  currency        TEXT NOT NULL DEFAULT 'HTG',
  -- Infos app
  app_name        TEXT NOT NULL DEFAULT 'Le Bon Taxi',
  user_app_version TEXT NOT NULL DEFAULT '1.0.0',
  user_app_url    TEXT DEFAULT '',
  driver_app_version TEXT NOT NULL DEFAULT '1.0.0',
  driver_app_url  TEXT DEFAULT '',
  -- Feature toggles
  subscriptions_enabled BOOLEAN NOT NULL DEFAULT true,
  moncash_enabled       BOOLEAN NOT NULL DEFAULT false,
  natcash_enabled       BOOLEAN NOT NULL DEFAULT false,
  -- Contact
  support_phone   TEXT DEFAULT '',
  support_email   TEXT DEFAULT '',
  -- Timestamps
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  -- Contrainte: une seule ligne
  CONSTRAINT single_row CHECK (id = 1)
);

-- Insérer la ligne unique de configuration
INSERT INTO app_settings (id) VALUES (1)
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- 2. TABLE: subscription_plans (Forfaits d'abonnement)
-- ============================================================
DROP TABLE IF EXISTS subscription_plans CASCADE;

CREATE TABLE subscription_plans (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name                TEXT NOT NULL,
  description         TEXT NOT NULL DEFAULT '',
  price               NUMERIC(10,2) NOT NULL,
  currency            TEXT NOT NULL DEFAULT 'HTG',
  duration_days       INTEGER NOT NULL DEFAULT 30,
  discount_percentage NUMERIC(5,2) NOT NULL DEFAULT 0.00,
  is_active           BOOLEAN NOT NULL DEFAULT true,
  -- Ordre d'affichage dans l'app
  display_order       INTEGER NOT NULL DEFAULT 0,
  -- Avantages (JSON array de textes pour affichage)
  features            JSONB DEFAULT '[]'::jsonb,
  -- Limites
  max_trips_per_day   INTEGER DEFAULT NULL,  -- NULL = illimité
  -- Timestamps
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index pour les requêtes fréquentes
CREATE INDEX idx_subscription_plans_active ON subscription_plans (is_active) WHERE is_active = true;
CREATE INDEX idx_subscription_plans_order ON subscription_plans (display_order ASC);

-- ============================================================
-- 3. DONNÉES INITIALES: Forfaits par défaut
-- ============================================================
INSERT INTO subscription_plans (name, description, price, currency, duration_days, discount_percentage, display_order, features) VALUES
(
  'Essentiel',
  'Profitez de réductions sur vos courses quotidiennes.',
  500.00,
  'HTG',
  30,
  10.00,
  1,
  '["10% de réduction sur toutes les courses", "Support prioritaire", "Historique de courses étendu"]'::jsonb
),
(
  'Premium',
  'Le meilleur rapport qualité-prix pour les voyageurs réguliers.',
  1200.00,
  'HTG',
  30,
  20.00,
  2,
  '["20% de réduction sur toutes les courses", "Support prioritaire 24/7", "Annulations gratuites", "Chauffeurs premium en priorité"]'::jsonb
),
(
  'VIP',
  'L''expérience ultime Le Bon Taxi pour les utilisateurs exigeants.',
  2500.00,
  'HTG',
  30,
  30.00,
  3,
  '["30% de réduction sur toutes les courses", "Support VIP dédié", "Annulations gratuites illimitées", "Priorité absolue sur les chauffeurs", "Accès aux véhicules de luxe"]'::jsonb
);

-- ============================================================
-- 4. COLONNES ABONNEMENT SUR TABLE users
-- (ajouter si elles n'existent pas)
-- ============================================================
DO $$ 
BEGIN
  -- subscription_plan_id
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'users' AND table_schema = 'public' AND column_name = 'subscription_plan_id'
  ) THEN
    ALTER TABLE users ADD COLUMN subscription_plan_id UUID REFERENCES subscription_plans(id) ON DELETE SET NULL;
  END IF;

  -- subscription_end_date
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'users' AND table_schema = 'public' AND column_name = 'subscription_end_date'
  ) THEN
    ALTER TABLE users ADD COLUMN subscription_end_date TIMESTAMPTZ DEFAULT NULL;
  END IF;

  -- subscription_start_date
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'users' AND table_schema = 'public' AND column_name = 'subscription_start_date'
  ) THEN
    ALTER TABLE users ADD COLUMN subscription_start_date TIMESTAMPTZ DEFAULT NULL;
  END IF;
END $$;

-- Index pour les requêtes d'abonnement
CREATE INDEX IF NOT EXISTS idx_users_subscription ON users (subscription_plan_id) WHERE subscription_plan_id IS NOT NULL;

-- ============================================================
-- 5. TABLE: subscription_history (Historique des abonnements)
-- ============================================================
DROP TABLE IF EXISTS subscription_history CASCADE;

CREATE TABLE subscription_history (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  plan_id         UUID NOT NULL REFERENCES subscription_plans(id) ON DELETE CASCADE,
  plan_name       TEXT NOT NULL,
  amount_paid     NUMERIC(10,2) NOT NULL,
  currency        TEXT NOT NULL DEFAULT 'HTG',
  payment_method  TEXT DEFAULT 'cash',
  start_date      TIMESTAMPTZ NOT NULL,
  end_date        TIMESTAMPTZ NOT NULL,
  status          TEXT NOT NULL DEFAULT 'active', -- active, expired, cancelled
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_sub_history_user ON subscription_history (user_id);
CREATE INDEX idx_sub_history_status ON subscription_history (status);

-- ============================================================
-- 6. FONCTION: Auto-update updated_at
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers
DROP TRIGGER IF EXISTS trigger_app_settings_updated ON app_settings;
CREATE TRIGGER trigger_app_settings_updated
  BEFORE UPDATE ON app_settings
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS trigger_subscription_plans_updated ON subscription_plans;
CREATE TRIGGER trigger_subscription_plans_updated
  BEFORE UPDATE ON subscription_plans
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- 7. COLONNE ROLE SUR TABLE users (pour admin)
-- ============================================================
-- Créer la table users si elle n'existe pas (pour éviter l'erreur 42703)
CREATE TABLE IF NOT EXISTS public.users (
  id UUID PRIMARY KEY
);

DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'users' AND table_schema = 'public' AND column_name = 'role'
  ) THEN
    ALTER TABLE public.users ADD COLUMN role TEXT NOT NULL DEFAULT 'user';
  END IF;
END $$;

-- ============================================================
-- 8. RLS (Row Level Security) Policies
-- ============================================================

-- app_settings: lecture publique, écriture pour tous les authentifiés
-- (Le web panel utilisera le service_role key qui bypass RLS)
ALTER TABLE app_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "app_settings_read" ON app_settings;
CREATE POLICY "app_settings_read" ON app_settings
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "app_settings_write" ON app_settings;
DO $$ BEGIN
  EXECUTE 'CREATE POLICY "app_settings_write" ON app_settings FOR ALL USING ((SELECT role FROM public.users WHERE id = auth.uid()) = ''admin'')';
END $$;

-- subscription_plans: lecture publique, écriture authentifiée
ALTER TABLE subscription_plans ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "subscription_plans_read" ON subscription_plans;
CREATE POLICY "subscription_plans_read" ON subscription_plans
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "subscription_plans_write" ON subscription_plans;
DO $$ BEGIN
  EXECUTE 'CREATE POLICY "subscription_plans_write" ON subscription_plans FOR ALL USING ((SELECT role FROM public.users WHERE id = auth.uid()) = ''admin'')';
END $$;

-- subscription_history: lecture par l'utilisateur, écriture authentifié
ALTER TABLE subscription_history ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "subscription_history_read" ON subscription_history;
CREATE POLICY "subscription_history_read" ON subscription_history
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "subscription_history_insert" ON subscription_history;
DO $$ BEGIN
  EXECUTE 'CREATE POLICY "subscription_history_insert" ON subscription_history FOR INSERT WITH CHECK ((SELECT role FROM public.users WHERE id = auth.uid()) = ''admin'')';
END $$;

-- ============================================================
-- 8. VÉRIFICATION
-- ============================================================
-- Vérifier que tout est en place
SELECT 'app_settings' AS table_name, count(*) AS rows FROM app_settings
UNION ALL
SELECT 'subscription_plans', count(*) FROM subscription_plans
UNION ALL
SELECT 'subscription_history', count(*) FROM subscription_history;
