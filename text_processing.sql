-- Tokenize text to array of sentences removing brackets, punctuation and sentences endings
CREATE OR REPLACE FUNCTION tokenize(text_corpus text) RETURNS text[][]
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
    re_to_sentences := '(?<!\w\.\w.)(?<![A-Z][a-z][а-я][А-Я]\.)(?<=\.|\?)\s';
    re_remove_brackets := '\((.*?)\)';
    re_remove_punctuation := '[^a-zA-Zа-яА-Я ]';

    -- Split text corpus to array of texts
    texts_arr := string_to_array(text_corpus, '\n');

    -- Remove empty strings
    texts_arr := (WITH cte(arr1, arr2) as (
        values (texts_arr, array [''])
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
                    buf_text := substr(buf_sentences_arr[t], 1, length(buf_sentences_arr[t]) - 1);
                    IF buf_text <> '' THEN
                        sentences := array_append(sentences, buf_text);
                    END IF;
                END LOOP;
        END LOOP;

    -- Remove punctuation and brackets from sentences
    FOR i IN 1 .. array_upper(sentences, 1)
        LOOP
            sentences[i] := regexp_replace(sentences[i], re_remove_brackets, '');
            sentences[i] := regexp_replace(sentences[i], re_remove_punctuation, '');
        END LOOP;

    RETURN sentences;
END
$$;

-- Tokenize each text from text corpus to get array of sentences
CREATE OR REPLACE FUNCTION get_train_corpus(text_corpus text[]) RETURNS text[]
    LANGUAGE plpgsql
AS
$$
DECLARE
    buf_sentences_arr text[];
    sentences         text[];
BEGIN
    FOR i IN 1 .. array_upper(text_corpus, 1)
        LOOP
            buf_sentences_arr := tokenize(text_corpus[i]);
            FOR t IN 1 .. array_upper(buf_sentences_arr, 1)
                LOOP
                    sentences := array_append(sentences, buf_sentences_arr[t]);
                END LOOP;
        END LOOP;
    RETURN sentences;
END
$$;
