-- ============================================================
-- RealtyWize Session 16 — pipeline label column
-- The pipeline_stages table (from 006_investor_schema.sql) has no
-- column for a human-readable deal label. Brief #16 prefers a real
-- column over a notes-prefix hack, so add it here.
-- ============================================================
ALTER TABLE pipeline_stages
  ADD COLUMN IF NOT EXISTS label text;
