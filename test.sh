#/bin/sh

# empty
LANGUAGE=ja_JP.UTF8 dub test --config="test-empty"
LANGUAGE=en dub test --config="test-empty"
LANGUAGE="" dub test --config="test-empty"

# ja-de
LANGUAGE=ja_JP.UTF8:de_DE.UTF-8 dub test --config="test-ja-de"
# fr and es are not provided, so they should be ignored
LANGUAGE=fr_FR@euro:ja_JP:es:de_DE.UTF-8 dub test --config="test-ja-de"

