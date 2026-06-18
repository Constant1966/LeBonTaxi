-- =============================================================
-- Script SQL pour créer les tables nécessaires au panel admin
-- Le Bon Taxi — À exécuter dans Supabase SQL Editor
-- =============================================================

-- ==========================================
-- TABLE app_settings (tarification)
-- Colonnes alignées avec les apps mobiles
-- ==========================================
-- L'app client lit: base_fare, per_km_rate, minimum_fare
-- L'app chauffeur lit avec AppSettingsService les mêmes colonnes
-- Le panel admin écrit/lit les mêmes colonnes

CREATE TABLE IF NOT EXISTS app_settings (
  id INTEGER PRIMARY KEY DEFAULT 1,
  base_fare DOUBLE PRECISION DEFAULT 50.0,
  per_km_rate DOUBLE PRECISION DEFAULT 150.0,
  per_minute_fare DOUBLE PRECISION DEFAULT 0.0,
  minimum_fare DOUBLE PRECISION DEFAULT 100.0,
  commission_percentage DOUBLE PRECISION DEFAULT 0.0,
  waiting_per_minute DOUBLE PRECISION DEFAULT 0.0,
  night_surcharge DOUBLE PRECISION DEFAULT 0.0,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insérer la ligne par défaut si elle n'existe pas
INSERT INTO app_settings (id, base_fare, per_km_rate, minimum_fare)
VALUES (1, 50.0, 150.0, 100.0)
ON CONFLICT (id) DO NOTHING;

ALTER TABLE app_settings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can read settings" ON app_settings FOR SELECT USING (true);
CREATE POLICY "Admins can update settings" ON app_settings FOR UPDATE USING (auth.role() = 'authenticated');
CREATE POLICY "Admins can insert settings" ON app_settings FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- ==========================================
-- TABLE admin_logs (audit admin)
-- ==========================================
CREATE TABLE IF NOT EXISTS admin_logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  admin_email TEXT NOT NULL,
  action TEXT NOT NULL,
  target_type TEXT,
  target_id TEXT,
  details JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE admin_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admins can read all logs" ON admin_logs FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Admins can insert logs" ON admin_logs FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- ==========================================
-- TABLE discounts (rabais/promotions)
-- ==========================================
CREATE TABLE IF NOT EXISTS discounts (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('percentage', 'fixed')),
  value DOUBLE PRECISION NOT NULL,
  applies_to TEXT NOT NULL DEFAULT 'all' CHECK (applies_to IN ('all', 'specific_users', 'zone')),
  user_ids TEXT[],
  zone_name TEXT,
  zone_coordinates JSONB,
  start_date TIMESTAMPTZ,
  end_date TIMESTAMPTZ,
  is_active BOOLEAN DEFAULT true,
  min_fare DOUBLE PRECISION DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE discounts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admins can manage discounts" ON discounts USING (auth.role() = 'authenticated');
CREATE POLICY "Admins can insert discounts" ON discounts FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Admins can update discounts" ON discounts FOR UPDATE USING (auth.role() = 'authenticated');
CREATE POLICY "Admins can delete discounts" ON discounts FOR DELETE USING (auth.role() = 'authenticated');

-- ==========================================
-- TABLE admin_messages (messagerie admin + annonces)
-- ==========================================
CREATE TABLE IF NOT EXISTS admin_messages (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  sender_admin_email TEXT NOT NULL,
  recipient_type TEXT NOT NULL CHECK (recipient_type IN ('single_driver', 'all_drivers', 'single_user', 'all_users')),
  recipient_id TEXT,
  recipient_name TEXT,
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  category TEXT DEFAULT 'general' CHECK (category IN ('general', 'maintenance', 'promotion', 'alert', 'security')),
  priority TEXT DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
  is_read BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE admin_messages ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admins can manage messages" ON admin_messages USING (auth.role() = 'authenticated');
CREATE POLICY "Admins can insert messages" ON admin_messages FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- ==========================================
-- TABLE admin_conversations (messagerie bidirectionnelle)
-- ==========================================
CREATE TABLE IF NOT EXISTS admin_conversations (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  participant_type TEXT NOT NULL CHECK (participant_type IN ('driver', 'user')),
  participant_id TEXT NOT NULL,
  participant_name TEXT,
  participant_photo TEXT,
  last_message TEXT,
  last_message_at TIMESTAMPTZ DEFAULT NOW(),
  unread_admin INTEGER DEFAULT 0,
  unread_participant INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS conversation_messages (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  conversation_id UUID NOT NULL REFERENCES admin_conversations(id) ON DELETE CASCADE,
  sender_type TEXT NOT NULL CHECK (sender_type IN ('admin', 'driver', 'user')),
  sender_id TEXT,
  sender_name TEXT,
  message TEXT NOT NULL,
  is_read BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE admin_conversations ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admins can manage conversations" ON admin_conversations USING (auth.role() = 'authenticated');
CREATE POLICY "Admins can insert conversations" ON admin_conversations FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Admins can update conversations" ON admin_conversations FOR UPDATE USING (auth.role() = 'authenticated');

ALTER TABLE conversation_messages ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admins can manage conv_messages" ON conversation_messages USING (auth.role() = 'authenticated');
CREATE POLICY "Admins can insert conv_messages" ON conversation_messages FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Admins can update conv_messages" ON conversation_messages FOR UPDATE USING (auth.role() = 'authenticated');

-- ==========================================
-- TABLE suspensions (blocages temporaires)
-- ==========================================
CREATE TABLE IF NOT EXISTS suspensions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  target_type TEXT NOT NULL CHECK (target_type IN ('driver', 'user')),
  target_id TEXT NOT NULL,
  target_name TEXT,
  reason TEXT NOT NULL,
  suspended_at TIMESTAMPTZ DEFAULT NOW(),
  suspended_until TIMESTAMPTZ NOT NULL,
  is_active BOOLEAN DEFAULT true,
  reactivated_at TIMESTAMPTZ,
  reactivated_by TEXT,
  admin_email TEXT NOT NULL
);

ALTER TABLE suspensions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admins can manage suspensions" ON suspensions USING (auth.role() = 'authenticated');
CREATE POLICY "Admins can insert suspensions" ON suspensions FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Admins can update suspensions" ON suspensions FOR UPDATE USING (auth.role() = 'authenticated');

-- ==========================================
-- TABLE reviews (avis clients)
-- ==========================================
CREATE TABLE IF NOT EXISTS reviews (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  trip_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  user_name TEXT,
  driver_id TEXT NOT NULL,
  driver_name TEXT,
  rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
  comment TEXT,
  admin_response TEXT,
  admin_response_type TEXT CHECK (admin_response_type IN ('public', 'private')),
  admin_response_at TIMESTAMPTZ,
  has_issue BOOLEAN DEFAULT false,
  issue_status TEXT CHECK (issue_status IN ('open', 'in_progress', 'resolved', 'closed')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admins can manage reviews" ON reviews USING (auth.role() = 'authenticated');
CREATE POLICY "Admins can insert reviews" ON reviews FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Admins can update reviews" ON reviews FOR UPDATE USING (auth.role() = 'authenticated');

-- ==========================================
-- ACTIVER LE REALTIME
-- ==========================================
ALTER PUBLICATION supabase_realtime ADD TABLE admin_messages;
ALTER PUBLICATION supabase_realtime ADD TABLE discounts;
ALTER PUBLICATION supabase_realtime ADD TABLE suspensions;
ALTER PUBLICATION supabase_realtime ADD TABLE reviews;
ALTER PUBLICATION supabase_realtime ADD TABLE admin_conversations;
ALTER PUBLICATION supabase_realtime ADD TABLE conversation_messages;
ALTER PUBLICATION supabase_realtime ADD TABLE app_settings;

-- ==========================================
-- MIGRATION : Changement de véhicule
-- Ajouter ces colonnes à la table `drivers`
-- ==========================================
ALTER TABLE drivers ADD COLUMN IF NOT EXISTS vehicle_change_pending BOOLEAN DEFAULT false;
ALTER TABLE drivers ADD COLUMN IF NOT EXISTS previous_vehicle_info JSONB;

-- ==========================================
-- RÉFÉRENCE : Structure des tables existantes
-- (ne pas exécuter si elles existent déjà)
-- ==========================================
-- 
-- Table `users` (app client) :
--   id, email, name, phone, block_status, 
--   subscription_plan_id, subscription_end_date
--
-- Table `drivers` (app chauffeur) :
--   id, email, name, phone, photo, block_status,
--   is_online, is_available, verified, profile_completed,
--   car_model, car_color, car_number, car_year,
--   car_front_photo, car_back_photo, car_side_photo,
--   license_photo, nin, current_latitude, current_longitude,
--   last_location_update, fcm_token,
--   document_status, documents_rejection_note,
--   vehicle_change_pending, previous_vehicle_info
--
-- Table `driver_documents` :
--   id, driver_id, document_type, document_label,
--   file_url, status (pending/approved/rejected),
--   rejection_reason, reviewed_by, submitted_at,
--   reviewed_at, updated_at
--
-- Table `trip_requests` (partagée) :
--   id (auto), trip_id, user_id, user_name, user_phone,
--   driver_id, driver_name, driver_phone, driver_photo,
--   car_model, car_color, car_number,
--   pickup_address, dropoff_address,
--   pickup_latitude, pickup_longitude,
--   dropoff_latitude, dropoff_longitude,
--   distance, duration, fare_amount,
--   status (new/accepted/arrived/ontrip/completed/cancelled),
--   rating, comment, cancel_reason,
--   created_at, accepted_at, arrived_at, started_at,
--   completed_at, cancelled_at
--
-- Table `earnings` :
--   id, driver_id, trip_id, amount, created_at

