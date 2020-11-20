-- Generate phrase by input phrase
CREATE OR REPLACE FUNCTION generate_phrase(input_phrase text = '', phrase_len integer = 10) RETURNS text
    LANGUAGE plpgsql
AS
$$
DECLARE
    phrase      text;
    words_arr   text[];
    begin_word  text;
    state_size  integer;
    init_state  text[];
    phrase_arr  text[];
BEGIN
    begin_word := '__begin__';
    state_size := (
        SELECT array_length(state, 1)
        FROM chain_table
        LIMIT 1);
    IF state_size IS NULL THEN
        RAISE EXCEPTION 'Error: chain_table is empty';
    END IF;

    IF input_phrase = '' THEN
        FOR i IN 1 .. state_size
        LOOP
            phrase_arr := array_append(phrase_arr, begin_word);
        END LOOP;
    ELSE
        phrase_arr := split_sentence(input_phrase);
    END IF;

    FOR i IN array_length(phrase_arr, 1) - state_size + 1 .. array_length(phrase_arr, 1)
        LOOP
            init_state := array_append(init_state, phrase_arr[i]);
        END LOOP;

    words_arr := chain_walk(init_state, phrase_len);
    RAISE NOTICE '%', words_arr;
    phrase := '';
    FOR i IN 1 .. array_length(phrase_arr, 1) - state_size - 1
        LOOP
            phrase := phrase || phrase_arr[i] || ' ';
        END LOOP;
    FOR i IN 1 .. array_length(words_arr, 1)
        LOOP
            phrase := phrase || words_arr[i] || ' ';
        END LOOP;
    RETURN phrase;
END
$$;
