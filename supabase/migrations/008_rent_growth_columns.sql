-- ============================================================
-- RealtyWize Session 10 — rent growth columns on analyses
-- ============================================================
ALTER TABLE deal_analyses
  ADD COLUMN IF NOT EXISTS rent_growth          numeric,
  ADD COLUMN IF NOT EXISTS expense_growth       numeric,
  ADD COLUMN IF NOT EXISTS yr5_cash_flow        numeric,
  ADD COLUMN IF NOT EXISTS cumulative_cash_flow numeric;
