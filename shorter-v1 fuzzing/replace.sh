#!/bin/bash

if grep -q -H -r "pragma solidity >=0.6.0<0.8.0;" "node_modules/@openzeppelin/contracts/"; then
    grep -H -r "pragma solidity >=0.6.0<0.8.0;" node_modules/@openzeppelin/contracts/ | cut -d: -f1 | xargs sed -i 's/pragma solidity >=0.6.0<0.8.0;/pragma solidity >=0.6.0 <0.8.0;/'
else
    echo "son"
fi