-- =============================================================
-- MIGRATION : Corriger la table admin_messages
-- Le Bon Taxi — À exécuter dans Supabase SQL Editor
-- =============================================================
-- 
-- Ce script corrige 3 bugs critiques :
-- 1. Le CHECK constraint de recipient_type n'inclut pas 'all'
-- 2. La colonne is_deleted_by_recipient est manquante
-- 3. Les politiques RLS bloquent les chauffeurs/utilisateurs
-- =============================================================

-- ══════════════════════════════════════════════════════════════
-- ÉTAPE 1 : Ajouter 'all' au CHECK constraint de recipient_type
-- ══════════════════════════════════════════════════════════════

-- Supprimer l'ancien constraint
ALTER TABLE admin_messages DROP CONSTRAINT IF EXISTS admin_messages_recipient_type_check;

-- Créer le nouveau constraint avec 'all' inclus
ALTER TABLE admin_messages ADD CONSTRAINT admin_messages_recipient_type_check 
  CHECK (recipient_type IN ('single_driver', 'all_drivers', 'single_user', 'all_users', 'all'));

-- ══════════════════════════════════════════════════════════════
-- ÉTAPE 2 : Ajouter la colonne is_deleted_by_recipient
-- ══════════════════════════════════════════════════════════════

ALTER TABLE admin_messages ADD COLUMN IF NOT EXISTS is_deleted_by_recipient BOOLEAN DEFAULT false;

-- ══════════════════════════════════════════════════════════════
-- ÉTAPE 3 : Politiques RLS pour chauffeurs et utilisateurs
-- ══════════════════════════════════════════════════════════════

-- ── SELECT : Les chauffeurs peuvent lire leurs messages ──────
DROP POLICY IF EXISTS "Drivers can read their messages" ON admin_messages;
CREATE POLICY "Drivers can read their messages" ON admin_messages
  FOR SELECT USING (
    recipient_type IN ('all_drivers', 'all')
    OR (recipient_type = 'single_driver' AND recipient_id = auth.uid()::text)
  );

-- ── SELECT : Les utilisateurs peuvent lire leurs messages ────
DROP POLICY IF EXISTS "Users can read their messages" ON admin_messages;
CREATE POLICY "Users can read their messages" ON admin_messages
  FOR SELECT USING (
    recipient_type IN ('all_users', 'all')
    OR (recipient_type = 'single_user' AND recipient_id = auth.uid()::text)
  );

-- ── INSERT : Les chauffeurs peuvent répondre ─────────────────
DROP POLICY IF EXISTS "Drivers can reply to admin" ON admin_messages;
CREATE POLICY "Drivers can reply to admin" ON admin_messages
  FOR INSERT WITH CHECK (
    recipient_type = 'single_driver'
    AND recipient_id = auth.uid()::text
    AND recipient_name LIKE '↩%'
  );

-- ── INSERT : Les utilisateurs peuvent répondre ──────────────
DROP POLICY IF EXISTS "Users can reply to admin" ON admin_messages;
CREATE POLICY "Users can reply to admin" ON admin_messages
  FOR INSERT WITH CHECK (
    recipient_type = 'single_user'
    AND recipient_id = auth.uid()::text
    AND recipient_name LIKE '↩%'
  );

-- ── UPDATE : Les chauffeurs peuvent marquer lu/supprimé ──────
DROP POLICY IF EXISTS "Drivers can update read status" ON admin_messages;
CREATE POLICY "Drivers can update read status" ON admin_messages
  FOR UPDATE USING (
    (recipient_type = 'single_driver' AND recipient_id = auth.uid()::text)
  ) WITH CHECK (
    (recipient_type = 'single_driver' AND recipient_id = auth.uid()::text)
  );

-- ── UPDATE : Les utilisateurs peuvent marquer lu/supprimé ────
DROP POLICY IF EXISTS "Users can update read status" ON admin_messages;
CREATE POLICY "Users can update read status" ON admin_messages
  FOR UPDATE USING (
    (recipient_type = 'single_user' AND recipient_id = auth.uid()::text)
  ) WITH CHECK (
    (recipient_type = 'single_user' AND recipient_id = auth.uid()::text)
  );

-- ══════════════════════════════════════════════════════════════
-- ÉTAPE 4 : Vérifier le Realtime
-- ══════════════════════════════════════════════════════════════

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'admin_messages'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE admin_messages;
  END IF;
END;
$$;

-- ══════════════════════════════════════════════════════════════
-- VÉRIFICATION : Afficher les politiques actives
-- ══════════════════════════════════════════════════════════════

SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies
WHERE tablename = 'admin_messages'
ORDER BY policyname;
