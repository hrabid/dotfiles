#!/bin/bash

CURRENT=$(ibus engine)

if [[ "$CURRENT" == "xkb:us::eng" ]]; then
  ibus engine ibus-avro
else
  ibus engine xkb:us::eng
fi
