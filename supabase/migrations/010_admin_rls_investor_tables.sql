-- ============================================================
-- RealtyWize Session 17a — admin RLS overrides on investor tables
--
-- The Session 6 investor schema (006_investor_schema.sql) shipped
-- with plain "auth.uid() = user_id" RLS policies on 5 tables:
--   buy_box_profiles, investor_leads, deal_analyses,
--   pipeline_stages, portfolio
-- The earlier admin_migration.sql already wraps its own tables
-- (profiles, leads, tasks, valuations, conversations) with
-- "OR is_admin()" so admins can query directly in the Supabase
-- dashboard. The investor tables were missed.
--
-- This migration replaces those 5 policies with is_admin()-aware
-- versions. All 3 CRUD verbs mirrored where appropriate. Uses the
-- same idempotent DROP-then-CREATE pattern from the original 006.
--
-- App-facing behavior is unchanged: the serverless proxy uses the
-- service-role key which bypasses RLS entirely, so client requests
-- are unaffected. Only direct DB queries (Supabase dashboard,
-- psql, etc.) as an admin gain the override.
-- ============================================================

-- buy_box_profiles
DROP POLICY IF EXISTS "Users manage own buy box" ON buy_box_profiles;
CREATE POLICY "Users manage own buy box"
  ON buy_box_profiles FOR ALL
  USING (auth.uid() = user_id OR is_admin())
  WITH CHECK (auth.uid() = user_id OR is_admin());

-- investor_leads
DROP POLICY IF EXISTS "Users manage own investor leads" ON investor_leads;
CREATE POLICY "Users manage own investor leads"
  ON investor_leads FOR ALL
  USING (auth.uid() = user_id OR is_admin())
  WITH CHECK (auth.uid() = user_id OR is_admin());

-- deal_analyses
DROP POLICY IF EXISTS "Users manage own analyses" ON deal_analyses;
CREATE POLICY "Users manage own analyses"
  ON deal_analyses FOR ALL
  USING (auth.uid() = user_id OR is_admin())
  WITH CHECK (auth.uid() = user_id OR is_admin());

-- pipeline_stages
DROP POLICY IF EXISTS "Users manage own pipeline" ON pipeline_stages;
CREATE POLICY "Users manage own pipeline"
  ON pipeline_stages FOR ALL
  USING (auth.uid() = user_id OR is_admin())
  WITH CHECK (auth.uid() = user_id OR is_admin());

-- portfolio
DROP POLICY IF EXISTS "Users manage own portfolio" ON portfolio;
CREATE POLICY "Users manage own portfolio"
  ON portfolio FOR ALL
  USING (auth.uid() = user_id OR is_admin())
  WITH CHECK (auth.uid() = user_id OR is_admin());
