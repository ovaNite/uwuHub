-- TSB Combo Studio: editable per-character profiles.
-- Return a map: character/profile name -> chronological input events.
-- The recorder can also create profiles in the executor's local file storage.
-- Do not invent move timings: record your own tested inputs and copy them here.
--
-- Example FORMAT (disabled, not a claimed working TSB combo):
-- ["Your Character"] = {
--   {t=0.00, key="One", down=true}, {t=0.08, key="One", down=false},
--   {t=0.40, key="Q", down=true},   {t=0.46, key="Q", down=false},
-- }
return {
  Default={},
}
