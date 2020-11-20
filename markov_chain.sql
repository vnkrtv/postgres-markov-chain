-- Implementation of markov chain
CREATE TABLE IF NOT EXISTS chain_table
(
    state   text[], -- Words array - state of chain
    choices text[], -- Choices array - possible extensions of 'state' words
    cumdist integer[] -- Occurrence of each word in 'choices'
);

-- Help function for getting occurrences of words - accumulate array: [4, 5, 1] => [4, 9, 10]
CREATE OR REPLACE FUNCTION accumulate(arr integer[]) RETURNS integer[]
    LANGUAGE plpgsql
AS
$$
DECLARE
    total_count integer;
    buf_arr     integer[];
BEGIN
    total_count := 0;
    FOR i IN 1 .. array_upper(arr, 1)
        LOOP
            total_count = total_count + arr[i];
            buf_arr := array_append(buf_arr, total_count);
        END LOOP;
    RETURN buf_arr;
END
$$;

-- Build markov chain from text corpus
CREATE OR REPLACE PROCEDURE train_chain(text_corpus text[], state_size integer)
    LANGUAGE plpgsql
AS
$$
DECLARE
    begin_word   text;
    end_word     text;
    items        text[];
    sentences    text[];
    words        text[];
    buf_state    text[];
    follow       text;
    follow_index integer;
    table_row    record;
BEGIN
    begin_word := '__BEGIN__';
    end_word := '__END__';

    DROP INDEX IF EXISTS pk_chain_table;
    TRUNCATE TABLE chain_table;

    -- Create temporary table for model representation
    CREATE TEMP TABLE temp_model
    (
        state   text[],
        follows text[],
        counter integer[]
    );

    -- Function for searching state in temporary table
    CREATE FUNCTION state_exist(model_state text[]) RETURNS boolean
        LANGUAGE plpgsql
    AS
    $innerstate$
    BEGIN
        IF (SELECT COUNT(*)
            FROM temp_model
            WHERE state = model_state) > 0 THEN
            RETURN true;
        ELSE
            RETURN false;
        end if;
    END
    $innerstate$;

    -- Function for searching specific word (follow) for state in temporary table
    CREATE FUNCTION get_follow_index(model_state text[], follow text) RETURNS integer
        LANGUAGE plpgsql
    AS
    $innerfollow$
    DECLARE
        follows_arr text[];
    BEGIN
        follows_arr := (SELECT follows
                        FROM temp_model
                        WHERE state = model_state
                          AND array [follow]::text[] && follows
                        LIMIT 1);
        IF follows_arr IS NOT NULL THEN
            RETURN array_position(follows_arr, follow);
        ELSE
            RETURN 0;
        end if;
    END
    $innerfollow$;
    RAISE NOTICE 'texts count: %', array_length(text_corpus, 1);

    -- Looping over sentences of processed text corpus
    FOR i IN 1 .. array_upper(text_corpus, 1)
        LOOP
            sentences := tokenize(text_corpus[i]);
            RAISE NOTICE 'text %: % sentences', i, array_length(sentences, 1);

            FOR k IN 1 .. array_length(sentences, 1)
                LOOP
                    words := split_sentence(sentences[k]);
                    IF array_length(words, 1) IS NULL THEN
                        CONTINUE;
                    END IF;

                    IF i = 3 THEN
                        RAISE NOTICE 'sentence: %', array_length(words, 1);
                    end if;

                    FOR t IN 1 .. state_size
                        LOOP
                            items := array_append(items, begin_word);
                        END LOOP;
                    FOR t IN 1 .. array_upper(words, 1)
                        LOOP
                            items := array_append(items, words[t]);
                        END LOOP;
                    items := array_append(items, end_word);

                    FOR t IN 1 .. array_upper(words, 1) + 1
                        LOOP
                            buf_state := array []::text[];
                            FOR k IN t .. t + state_size - 1
                                LOOP
                                    buf_state := array_append(buf_state, items[k]);
                                END LOOP;
                            follow := items[t + state_size];

                            IF NOT state_exist(buf_state) THEN
                                INSERT INTO temp_model(state, follows, counter)
                                VALUES (buf_state, array []::text[], array []::integer[]);
                            END IF;

                            follow_index := get_follow_index(buf_state, follow);
                            IF follow_index > 0 THEN
                                UPDATE temp_model
                                SET counter[follow_index] = 1
                                WHERE state = buf_state;
                            END IF;

                            UPDATE temp_model
                            SET counter[follow_index] = counter[follow_index] + 1
                            WHERE state = buf_state;

                        END LOOP;
                END LOOP;
        END LOOP;

    RAISE NOTICE '%', (SELECT COUNT(*) FROM temp_model)::integer;

    FOR table_row IN (SELECT * FROM temp_model)
        LOOP
            INSERT INTO chain_table(state, choices, cumdist)
            VALUES (table_row.state, table_row.follows, accumulate(table_row.counter));
        END LOOP;

    DROP FUNCTION state_exist(model_state text[]);
    DROP FUNCTION get_follow_index(model_state text[], follow text);
    DROP TABLE temp_model;

    CREATE INDEX pk_chain_table
        ON chain_table USING hash (state);
END
$$;

-- Help function - binary search algorithm for weighted word selection for the continuation of a phrase
CREATE OR REPLACE FUNCTION binary_search(arr integer[], elem float) RETURNS integer
    LANGUAGE plpgsql
AS
$$
DECLARE
    idx         integer;
    left_index  integer;
    right_index integer;
BEGIN
    left_index := 0;
    right_index := array_length(arr, 1) + 1;
    WHILE left_index < right_index - 1
        LOOP
            idx := (left_index + right_index) / 2;
            IF arr[idx] < elem THEN
                left_index := idx;
            ELSE
                right_index := idx;
            END IF;
        END LOOP;
    RETURN right_index;
END
$$;

-- Moving the chain through the state space
CREATE OR REPLACE FUNCTION chain_move(text[]) RETURNS integer
    LANGUAGE plpgsql
AS
$$
DECLARE
    choices_arr   text[];
    cumdist_arr   integer[];
    rand          integer;
BEGIN
    SELECT choices, cumdist
    INTO choices_arr, cumdist_arr
    FROM chain_table
    WHERE state = $1;
    rand := random() * choices_arr[array_upper(choices_arr, 1)];
    RETURN choices_arr[binary_search(choices_arr, rand)];
END;
$$;

-- Chain walk through the state space
CREATE OR REPLACE FUNCTION chain_walk(init_state text[]) RETURNS integer[]
    LANGUAGE plpgsql
AS
$$
DECLARE
    phrase   text[];
    state    text[];
    word     text;
    end_word text;
BEGIN
    end_word := '__END__';
    state := init_state;
    word := chain_move(state);
    WHILE word IS NOT NULL OR word <> end_word
        LOOP
            phrase := array_append(phrase, word);
            state := array_append(state[2:], word);
            word := chain_move(state);
        END LOOP;
    RETURN phrase;
END
$$;
