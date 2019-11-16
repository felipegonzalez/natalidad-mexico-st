#!/bin/bash
for archivo in ./json_data/*.json; do
    echo "$archivo"
    bq --location=US load --source_format=NEWLINE_DELIMITED_JSON decent-oxygen-259223:natalidad_mexico_1985_2017.nacimientos "$archivo" nacimientos_schema.json
done
