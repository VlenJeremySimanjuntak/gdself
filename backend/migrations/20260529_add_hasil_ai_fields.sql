-- Migration: add new fields to hasil_ai to match model changes
-- Run this on the gdself_db database

ALTER TABLE hasil_ai
  ADD COLUMN id_user INT NULL AFTER id_hasil_ai,
  ADD COLUMN kesimpulan_lab TEXT NULL AFTER score,
  ADD COLUMN status_harian VARCHAR(100) NULL AFTER kesimpulan_lab,
  ADD COLUMN pesan_harian TEXT NULL AFTER status_harian,
  ADD COLUMN trend_report TEXT NULL AFTER pesan_harian,
  ADD COLUMN arah_perubahan VARCHAR(100) NULL AFTER trend_report,
  ADD COLUMN flag_urgensi VARCHAR(100) NULL AFTER arah_perubahan;

-- Optional: add foreign key constraint to user
ALTER TABLE hasil_ai
  ADD CONSTRAINT fk_hasil_ai_user FOREIGN KEY (id_user) REFERENCES user(id_user) ON DELETE CASCADE;

-- Notes:
-- 1) We add columns as NULL to avoid issues with existing rows. After migrating and
--    backfilling values as needed, you may convert columns to NOT NULL if required.
-- 2) To run: mysql -u <user> -p gdself_db < migrations/20260529_add_hasil_ai_fields.sql
