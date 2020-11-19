-- Train Markov chain with specified state size on input text corpus
CREATE OR REPLACE PROCEDURE build_markov_chain(text_corpus text[], state_size integer)
    LANGUAGE plpgsql
AS
$$
DECLARE
    train_corpus text[];
BEGIN
    train_corpus := get_train_corpus(text_corpus);
    CALL train_chain(train_corpus, state_size);
END
$$;

-- Generate phrase by input phrase
CREATE OR REPLACE FUNCTION generate_phrase(input_phrase text) RETURNS text
    LANGUAGE plpgsql
AS
$$
DECLARE
    phrase     text;
    words_arr  text[];
    state_size integer;
    init_state text[];
BEGIN
    state_size := (
        SELECT array_length(state, 1)
        FROM chain_table
        LIMIT 1);
    init_state := string_to_array(input_phrase, ' ');
    init_state := init_state[array_length(init_state, 1) - state_size:array_length(init_state, 1)];

    words_arr := chain_walk(init_state);
    phrase := '';
    FOR i IN 1 .. array_length(init_state, 1) - state_size - 1
        LOOP
            phrase := phrase || init_state[i] || ' ';
        END LOOP;
    FOR i IN 1 .. array_length(words_arr, 1)
        LOOP
            phrase := phrase || words_arr[i] || ' ';
        END LOOP;
    RETURN phrase;
END
$$;
