-- ============================================================
-- RealtyWize Session 9 — tax/depreciation columns on analyses
-- ============================================================
ALTER TABLE deal_analyses
  ADD COLUMN IF NOT EXISTS tax_rate            numeric,
  ADD COLUMN IF NOT EXISTS land_pct            numeric,
  ADD COLUMN IF NOT EXISTS annual_depreciation numeric,
  ADD COLUMN IF NOT EXISTS annual_tax_savings  numeric;
