#!/bin/bash

myArray=()
libraries=( $(find ./contracts/ -name "*.sol" | grep "libraries") )
proxies=( $(find ./contracts/ -name "*.sol" | grep "proxy") )
list=( $(find ./contracts/ -name "*.sol" | grep -v "libraries" | grep -v "proxy") )

# echo "const hre = require(\"hardhat\");
# const { ethers } = require(\"hardhat\");
# // const { ethers, artifacts } from 'hardhat';

# async function main() {
#   await hre.run('compile');

#   const [wallet] = await ethers.getSigners();"
# echo " "

for arr in "${libraries[@]}"
do : 
    # IFS='/'
    # read -a strarr <<< "$arr"
    # IFS=' '
    # if [[ ! " ${myArray[*]} " =~ " ${strarr[-1]} " ]]; then
    #     IFS='.'
    #     read -a sol <<< "${strarr[-1]}"
    #     echo "  const ${sol[0]} = await ethers.getContractFactory(\"${sol[0]}\");"
    #     echo "  const ${sol[0],,} = await ${sol[0]}.deploy();"
    #     echo "  await ${sol[0],,}.deployed();"
    #     echo " "
    # fi
done

for arr in "${list[@]}"
do : 
    IFS='/'
    read -a strarr <<< "$arr"
    IFS='.'
    read -a sol <<< "${strarr[-1]}"
    IFS=''
    if grep -q "constructor(" "$arr"; then
        if ! grep -q "constructor(address _SAVIOR" "$arr"; then
            echo ${sol[0]}
            var=$(grep "constructor(" "$arr")
            echo $var
        fi
    fi
    # if ! grep -q "interface ${sol[0]}" "$arr"; then 
    #     if grep -q "using" "$arr"; then
    #         if [[ "${sol[0]}" == "EnumerableMap" || "${sol[0]}" == "ShorterFactory" ]]; then
    #             echo "  const ${sol[0]} = await ethers.getContractFactory(\"${sol[0]}\");"
    #         else
    #             IFS=$'\n'
    #             gre=( $(grep "$arr" -e "using") )
    #             if [[ "${gre[@]}" == *"EnumerableSet"* || "${gre[@]}" == *"SafeToken"* || "${gre[@]}" == *"BoringMath"* ]]; then
    #                 echo "  const ${sol[0]} = await ethers.getContractFactory(\"${sol[0]}\");"
    #             else
    #                 echo "  const ${sol[0]} = await ethers.getContractFactory(\"${sol[0]}\", {"
    #                 echo "      libraries: {"
    #                 len=${#gre[@]}
    #                 for line in "${gre[@]}"
    #                 do :
    #                     IFS=' '
    #                     read -a lib <<< "$line"
    #                     if [ $len -gt 1 ]; then
    #                         echo "        ${lib[1]}: ${lib[1],,}.address,"
    #                         ((len=len-1))
    #                     else
    #                         echo "        ${lib[1]}: ${lib[1],,}.address"
    #                     fi
    #                 done
    #                 echo "    },"
    #                 echo "  });"
    #             fi
    #         fi
    #     else
    #         if [[ "${sol[0]}" == "Pausable" ]]; then
    #             echo "  const ${sol[0]} = await ethers.getContractFactory(\"contracts/util/Pausable.sol:Pausable\");"
    #         else
    #             echo "  const ${sol[0]} = await ethers.getContractFactory(\"${sol[0]}\");"
    #         fi
    #     fi

    #     if grep -q "constructor(" "$arr"; then
    #         if grep -q "(address _SAVIOR)" "$arr"; then
    #             echo "  const ${sol[0],,} = await ${sol[0]}.deploy(wallet.address);"
    #         elif grep -q "(address _SAVIOR, address _implementationContract)" "$arr"; then
    #             echo "  const ${sol[0],,} = await ${sol[0]}.deploy(wallet.address, ${sol[0],,}impl.address);"
    #         else
    #             echo "  const ${sol[0],,} = await ${sol[0]}.deploy();" 
    #         fi
    #     else
    #         echo "  const ${sol[0],,} = await ${sol[0]}.deploy();"
    #     fi
    #     echo "  await ${sol[0],,}.deployed();"
    #     echo " "

    #     # res=$(grep "$arr" -e "constructor(")
    #     # res2=$(grep "$arr" -e "using")
    #     # echo $arr
    #     # echo $res2 
    # fi
done

# echo "}

# // We recommend this pattern to be able to use async/await everywhere
# // and properly handle errors.
# main()
#   .then(() => process.exit(0))
#   .catch((error) => {
#     console.error(error);
#     process.exit(1);
#   });"