-- Metalnini — circle pit, jouabilité (2026-11-15) : attirer un pote se fait en freinant au bord (angle 15°, 0,3 s),
-- se relever par une poussée franche du pouce vers le haut (0,15 s). Réglages lus par le nouveau moteur seulement.
update public.settings set value = jsonb_set(value, '{game}', coalesce(value -> 'game', '{}'::jsonb) || '{"pullAngle": 0.041666666666666664, "pullHoldS": 0.3, "upPushS": 0.15}'::jsonb)
 where key = 'pit';
