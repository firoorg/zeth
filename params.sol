pragma solidity ^0.4.8;

import "./bigint_functions.sol";
contract params is bigint_functions {

     /* The parameters are generated based on the 2048 bit value generated for the RSA Factoring Challenge - the same 
      * value used for parameter generation in Zcoin.
      * This can be verified by using the paramgen tool in the libzerocoin lib by building project 
      * @ https://github.com/zcoinofficial/zcoin/tree/master/src/libzerocoin.
      */
    address deployment; //address of contract creators. Ability to perform limited changes and for contract deployment. TBD
    bool is_set = false;

    int zkp_iterations = 80;

    //accumulator params
    uint k_prime = 160;
    uint k_dprime = 128;

    //greatest and smallest values for coin
    bigint min_coin_value;
    bigint max_coin_value;

    //the following value is used in the commitment PoK verification and is equal to:
    //64 * (COMMITMENT_EQUALITY_CHALLENGE_SIZE (==256) + COMMITMENT_EQUALITY_SECMARGIN (==512) +
    //      max(max(serialNumberSoKCommitmentGroup.modulus.bitSize(),    accumulatorPoKCommitmentGroup.modulus.bitSize()),
    //      max(serialNumberSoKCommitmentGroup.groupOrder.bitSize(), accumulatorPoKCommitmentGroup.groupOrder.bitSize())));
    uint commitment_pok_max_size;

    //for hash function in serial number SoK verification
    bytes params_bytes;

    //RSA-2048 Factoring Challenge encoded as bytes.
    bytes modulus; //RSA-2048

    //the following value is used in the accumulator verification and is equal to:
    //maxCoinValue * bigint(2).pow(k_prime + k_dprime + 1))
    bigint upper_result_range_value;

    //these structs were assigned in contract contructor.
    struct accumulatorPoKCommitmentGroup{
        bigint g;
        bigint h;
        bigint modulus;
        bigint groupOrder;
    }

    struct accumulatorQRNCommitmentGroup{
        bigint g;
        bigint h;
    }

    struct CoinCommitmentGroup{
        bigint g;
        bigint h;
        bigint modulus;
        bigint groupOrder;
    }

    struct serialNumberSoKCommitmentGroup{
        bigint g;
        bigint h;
        bigint modulus;
        bigint groupOrder;
    }

    function params(address in, bytes _params){
        if(is_set==false && in!=deployment) {
            //add parameters to storage.
            //also add functions for exposing storage of external contract.
        }
        is_set = true;
    }
}