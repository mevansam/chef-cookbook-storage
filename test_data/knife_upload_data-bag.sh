#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage ./knife_upload_data-bag.sh [DATA_BAG_ITEM]"
    exit 1
fi

dir=$(dirname $0)

knife data bag delete "service_endpoints-_default" "$1" --yes
knife data bag create "service_endpoints-_default"
knife data bag from file "service_endpoints-_default" $dir/data-bag_$1.json --secret 1234
