# postgres-markov-chain  

## Description
Text generator based on Markov chains.  
Written on pure PLpgSQL.

## Usage

- ```psql -h host -U username -d dbname -a -f text_processing.sql``` - adds functions and procedures for text processing
- ```psql -h host -U username -d dbname -a -f markov_chain.sql``` - adds functions and procedures for markov chain representation
- ```psql -h host -U username -d dbname -a -f text_processing.sql``` - adds functions and procedures for text generating
- ```CALL train_chain(text_corpus::text[], state_size::integer)``` - train Markov chain with specified state size on text_corpus (array of texts)  
- ```SELECT generate_phrase(input_phrase::text = '', phrase_len::integer = 10)``` - generate phrase by input phrase
