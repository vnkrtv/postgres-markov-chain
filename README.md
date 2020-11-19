# postgres-markov-chain  

## Description
Text generator based on Markov chains.  
Written on pure PLpgSQL.

## Usage

- ```psql -h host -U username -d dbname -a -f markov_chain.sql``` - adds necessary functions and procedures  
- ```CALL build_markov_chain(text_corpus, state_size)``` - train Markov chain with specified state size on text_corpus (array of texts)  
- ```SELECT generate_phrase(input_phrase)``` - generate phrase by input phrase
