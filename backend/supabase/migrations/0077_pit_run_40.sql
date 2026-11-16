-- Metalnini — circle pit : courses de 40 s (nouveau moteur, le temps de se reposer). À appliquer au moment de la mise en ligne.
update public.settings set value = value || '{"run_s": 40}'::jsonb where key = 'pit';
