-- ============================================================
-- RealtyWize Session 6 — Investor schema
-- Extends existing profiles table, adds 6 new tables
-- Run after existing admin_migration.sql and supabase_schema.sql
-- ============================================================

-- -------------------------------------------------------
-- 1. Extend profiles table with investor-specific columns
-- -------------------------------------------------------
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS investor_name     text,
  ADD COLUMN IF NOT EXISTS phone             text,
  ADD COLUMN IF NOT EXISTS markets           text,
  ADD COLUMN IF NOT EXISTS preferred_exits   text[],
  ADD COLUMN IF NOT EXISTS onboarded_at      timestamptz;

-- -------------------------------------------------------
-- 2. buy_box_profiles
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS buy_box_profiles (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  markets          text,
  prop_types       text[],
  min_price        numeric,
  max_price        numeric,
  min_coc          numeric,
  min_equity       numeric,
  max_rehab        numeric,
  min_arv_spread   numeric,
  exit_strats      text[],
  signals          text[],
  created_at       timestamptz DEFAULT now(),
  updated_at       timestamptz DEFAULT now()
);

ALTER TABLE buy_box_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own buy box"
  ON buy_box_profiles FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_buy_box_user ON buy_box_profiles(user_id);

-- -------------------------------------------------------
-- 3. investor_leads  (renamed from "leads" to avoid
--    collision with the existing realtor-era leads table)
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS investor_leads (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  address          text,
  city             text,
  state            text,
  zip              text,
  value            numeric,
  equity_pct       numeric,
  owner            text,
  years_owned      int,
  beds             int,
  baths            numeric,
  sqft             int,
  prop_type        text,
  signals          text[],
  buy_box_label    text CHECK (buy_box_label IS NULL OR buy_box_label IN ('strong','near','out')),
  buy_box_score    numeric,
  buy_box_hard_fails  text[],
  buy_box_near_misses text[],
  source           text DEFAULT 'csv',
  local_id         text,
  created_at       timestamptz DEFAULT now(),
  updated_at       timestamptz DEFAULT now()
);

ALTER TABLE investor_leads ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own investor leads"
  ON investor_leads FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_investor_leads_user ON investor_leads(user_id);
CREATE INDEX IF NOT EXISTS idx_investor_leads_bbox ON investor_leads(user_id, buy_box_label);

-- -------------------------------------------------------
-- 4. deal_analyses
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS deal_analyses (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  lead_id          uuid REFERENCES investor_leads(id) ON DELETE SET NULL,
  address          text,
  -- inputs
  price            numeric,
  down_pct         numeric,
  rate             numeric,
  term             int,
  closing          numeric,
  rehab            numeric,
  rent1            numeric,
  rent2            numeric,
  rent3            numeric,
  rent4            numeric,
  tax_yr           numeric,
  insurance        numeric,
  utilities        numeric,
  mgmt_pct         numeric,
  vacancy_pct      numeric,
  maint_pct        numeric,
  arv              numeric,
  appreciation     numeric,
  strategy         text,
  notes            text,
  -- computed outputs
  monthly_cash_flow  numeric,
  noi_yr             numeric,
  cap_rate           numeric,
  coc_return         numeric,
  dcr                numeric,
  monthly_mortgage   numeric,
  total_cash_in      numeric,
  gross_flip_profit  numeric,
  meets_70_rule      boolean,
  yr5_value          numeric,
  -- AI output
  ai_grade           text,
  ai_grade_summary   text,
  ai_flip_score      text,
  ai_brrrr_score     text,
  ai_hold_score      text,
  ai_best_strategy   text,
  ai_risks           text,
  ai_recommendation  text,
  ai_max_offer       text,
  ai_one_thing       text,
  created_at         timestamptz DEFAULT now()
);

ALTER TABLE deal_analyses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own analyses"
  ON deal_analyses FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_analyses_user ON deal_analyses(user_id);
CREATE INDEX IF NOT EXISTS idx_analyses_lead ON deal_analyses(lead_id);

-- -------------------------------------------------------
-- 5. pipeline_stages
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS pipeline_stages (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  lead_id          uuid REFERENCES investor_leads(id) ON DELETE CASCADE,
  analysis_id      uuid REFERENCES deal_analyses(id) ON DELETE SET NULL,
  stage            text NOT NULL CHECK (stage IN ('prospect','offer','under_contract','closed','passed')),
  offer_price      numeric,
  notes            text,
  created_at       timestamptz DEFAULT now(),
  updated_at       timestamptz DEFAULT now()
);

ALTER TABLE pipeline_stages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own pipeline"
  ON pipeline_stages FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_pipeline_user  ON pipeline_stages(user_id);
CREATE INDEX IF NOT EXISTS idx_pipeline_stage ON pipeline_stages(user_id, stage);

-- -------------------------------------------------------
-- 6. portfolio
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS portfolio (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  lead_id          uuid REFERENCES investor_leads(id) ON DELETE SET NULL,
  analysis_id      uuid REFERENCES deal_analyses(id) ON DELETE SET NULL,
  address          text,
  city             text,
  state            text,
  purchase_price   numeric,
  current_value    numeric,
  loan_balance     numeric,
  monthly_rent     numeric,
  monthly_expense  numeric,
  acquired_at      date,
  notes            text,
  created_at       timestamptz DEFAULT now(),
  updated_at       timestamptz DEFAULT now()
);

ALTER TABLE portfolio ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own portfolio"
  ON portfolio FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_portfolio_user ON portfolio(user_id);

-- -------------------------------------------------------
-- 7. updated_at trigger (applies to all new tables)
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$ BEGIN
  CREATE TRIGGER trg_buy_box_updated_at
    BEFORE UPDATE ON buy_box_profiles
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TRIGGER trg_investor_leads_updated_at
    BEFORE UPDATE ON investor_leads
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TRIGGER trg_pipeline_updated_at
    BEFORE UPDATE ON pipeline_stages
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TRIGGER trg_portfolio_updated_at
    BEFORE UPDATE ON portfolio
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
