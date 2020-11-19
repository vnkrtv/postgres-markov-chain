-- Implementation of markov chain
CREATE TABLE IF NOT EXISTS chain_table
(
    state   text[], -- Words array - state of chain
    choices text[], -- Choices array - possible extensions of 'state' words
    cumdist integer[], -- Occurrence of each word in 'choices'

    CONSTRAINT pk_chain_table
        PRIMARY KEY (state)
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
CREATE OR REPLACE PROCEDURE train_chain(sentences text[], state_size integer)
    LANGUAGE plpgsql
AS
$$
DECLARE
    begin_word   text;
    end_word     text;
    items        text[];
    sentence     text[];
    buf_state    text[];
    follow       text;
    follow_index integer;
    table_row    record;
BEGIN
    begin_word := '__BEGIN__';
    end_word := '__END__';

    -- Create temporary table for model representation
    CREATE TEMP TABLE temp_model
    (
        state   text[],
        follows text[],
        counter integer[]
    );

    -- Function for searching state in temporary table
    CREATE OR REPLACE FUNCTION state_exist(model_state text[]) RETURNS boolean
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
    CREATE OR REPLACE FUNCTION get_follow_index(model_state text[], follow text) RETURNS integer
        LANGUAGE plpgsql
    AS
    $innerfollow$
    DECLARE
        follows_arr text[];
    BEGIN
        follows_arr := (SELECT follows
                        FROM temp_model
                        WHERE state = model_state
                          AND follow && follows
                        LIMIT 1);
        IF follows_arr IS NOT NULL THEN
            RETURN array_position(follows_arr, follow);
        ELSE
            RETURN 0;
        end if;
    END
    $innerfollow$;

    -- Looping over sentences of processed text corpus
    FOR i IN 1 .. array_upper(sentences, 1)
        LOOP
            sentence := sentences[i];

            --
            FOR t IN 1 .. state_size
                LOOP
                    items := array_append(items, begin_word);
                END LOOP;
            FOR t IN 1 .. array_upper(sentence, 1)
                LOOP
                    items := array_append(items, sentence[t]);
                END LOOP;
            items := array_append(items, end_word);

            FOR t IN 1 .. array_upper(sentence, 1) + 1
                LOOP
                    buf_state := items[t:t + state_size];
                    follow := items[t + state_size];

                    IF NOT state_exist(buf_state) THEN
                        INSERT INTO temp_model(state, follows, counter)
                        VALUES (buf_state, array [], array []);
                    END IF;

                    follow_index := get_follow_index(buf_state, follow);
                    IF follow_index > 0 THEN
                        UPDATE temp_model
                        SET follows[follow_index] = 1
                        WHERE state = buf_state;
                    END IF;

                    UPDATE temp_model
                    SET follows[follow_index] = follows[follow_index] + 1
                    WHERE state = buf_state;

                END LOOP;
        END LOOP;

    FOR table_row IN (SELECT * FROM temp_model)
        LOOP
            INSERT INTO chain_table(state, choices, cumdist)
            VALUES (table_row.state, table_row.follows, accumulate(table_row.counter));
        END LOOP;

    DROP FUNCTION state_exist(model_state text[]);
    DROP FUNCTION get_follow_index(model_state text[], follow text);
    DROP TABLE temp_model;
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
