-- Tokenize text to array of sentences removing brackets, punctuation and sentences endings
CREATE OR REPLACE FUNCTION tokenize(text_corpus text) RETURNS text[]
    LANGUAGE plpgsql
AS
$$
DECLARE
    texts_arr             text[];
    sentences             text[];
    buf_sentences_arr     text[];
    buf_text              text;
    re_to_sentences       text;
    re_remove_brackets    text;
    re_remove_punctuation text;
BEGIN
    -- Init regex
    re_to_sentences := '(?<!\w\.\w.)(?<![A-Z][a-z][а-я][А-Я]ёЁ\.)(?<=\.|\?)\s';
    re_remove_brackets := '\((.*?)\)';
    re_remove_punctuation := '[^a-zA-Zа-яА-ЯёЁ ]';

    -- Split text corpus to array of texts
    texts_arr := string_to_array(text_corpus, '\n');

    -- Remove empty strings
    texts_arr := (WITH cte(arr1, arr2) AS (
        VALUES (texts_arr, array [''])
    )
                  SELECT array_agg(elem)
                  FROM cte,
                       unnest(arr1) elem
                  WHERE elem <> ALL (arr2));

    -- Get array of sentences from texts_arr
    FOR i IN 1 .. array_upper(texts_arr, 1)
        LOOP
        buf_sentences_arr := regexp_split_to_array(texts_arr[i], re_to_sentences);
            FOR t IN 1 .. array_upper(buf_sentences_arr, 1)
                LOOP
                    IF buf_sentences_arr[t] <> '' THEN
                        buf_text := substr(buf_sentences_arr[t], 1, length(buf_sentences_arr[t]) - 1);
                        IF buf_text <> '' THEN
                            sentences := array_append(sentences, buf_text);
                        END IF;
                    END IF;
                END LOOP;
        END LOOP;

    -- Remove punctuation and brackets from sentences
    FOR i IN 1 .. array_upper(sentences, 1)
        LOOP
            sentences[i] := regexp_replace(sentences[i], re_remove_brackets, '');
            sentences[i] := regexp_replace(sentences[i], re_remove_punctuation, '');
            sentences[i] := lower(sentences[i]);
        END LOOP;

    RETURN sentences;
END
$$;

-- Process sentence to array of words
CREATE OR REPLACE FUNCTION split_sentence(sentence text) RETURNS text[]
    LANGUAGE plpgsql
AS
$$
DECLARE
    words_arr             text[];
BEGIN
    -- Split text corpus to array of texts
    words_arr := string_to_array(sentence, ' ');

    -- Remove empty strings
    words_arr := (WITH cte(arr1, arr2) AS (
        VALUES (words_arr, array [''])
    )
                  SELECT array_agg(elem)
                  FROM cte,
                       unnest(arr1) elem
                  WHERE elem <> ALL (arr2));

    RETURN words_arr;
END
$$;
