-- =============================================================================
-- V2__add_processing_fee.sql
-- Add processing_fee column to loans table
-- =============================================================================

ALTER TABLE loans
ADD COLUMN processing_fee DECIMAL(19, 2) NOT NULL DEFAULT 0.00;
