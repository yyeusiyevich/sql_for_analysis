-- 3. Create function that inserts new movie with the given name in �film� table. �release_year�, �language� are optional arguments and default to current year and 
-- Klingon respectively. The function must return film_id of the inserted movie. 
-- the function takes three parameters; two of the are default according to the task condition
CREATE OR REPLACE FUNCTION public.insert_film(film_title TEXT, film_release_year INTEGER DEFAULT EXTRACT(YEAR FROM NOW()), film_language TEXT DEFAULT 'Klingon') 
-- returns film_id of the inserted movie
RETURNS INTEGER AS $$
-- delare a variable for movie_id
DECLARE
    inserted_film_id INTEGER;
   -- delcare an additional varuable for language check
    var_language_id INTEGER;
BEGIN
	-- language check; if language does not exists - insert language
    SELECT language_id INTO var_language_id 
    FROM language 
    WHERE UPPER(name) = UPPER(film_language);
    IF NOT FOUND THEN
        INSERT INTO language (name) VALUES (film_language) 
        RETURNING language_id INTO var_language_id;
    END IF;
    -- film insertion
    INSERT INTO film (title, release_year, language_id)
	SELECT film_title, film_release_year, var_language_id
	-- data validation
	WHERE NOT EXISTS (
					    SELECT 1
					    FROM film
					    WHERE UPPER(title) = UPPER(film_title)
					        AND release_year = film_release_year
					        AND language_id = var_language_id
					)
    RETURNING film_id INTO inserted_film_id;
RETURN inserted_film_id;
END;
$$ LANGUAGE plpgsql;

-- test
-- SELECT * FROM public.insert_film('some title');
-- SELECT * FROM public.insert_film('another_title', 2006, 'English');
