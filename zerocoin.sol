pragma solidity ^0.4.8;

import "./bigint_functions.sol";

contract zerocoin is bigint_functions { //inherit all members from bigint
    /*
     * This smart contract is an implementation of the Zerocoin coin-mixing protocol.
     * paper found here: http://zerocoin.org/media/pdf/ZerocoinOakland.pdf
     * original authors: Ian Miers, Christina Garman, Matthew Green, Aviel D. Rubin
     * this version implemented by: Tadhg Riordan - github.com/riordant
     */

     //*************************************** Begin Parameters ********************************************

     /* The parameters are generated based on the 2048 bit value generated for the RSA Factoring Challenge - the same 
      * value used for parameter generation in Zcoin.
      * This can be verified by using the paramgen tool in the libzerocoin lib by building project 
      * @ https://github.com/zcoinofficial/zcoin/tree/master/src/libzerocoin.
      * struct and bigint values will be generated in this contract's constructor by the Zcoin team.
      */
    address deployment; //address of contract creators. Ability to perform limited changes and for contract deployment. TBD
    bool set = false; //parameters set

    int zkp_iterations = 80;

    //accumulator params
    uint k_prime = 160;
    uint k_dprime = 128;


    //the following value is used in the commitment PoK verification and is equal to:
    //64 * (COMMITMENT_EQUALITY_CHALLENGE_SIZE (==256) + COMMITMENT_EQUALITY_SECMARGIN (==512) +
    //      max(max(serialNumberSoKCommitmentGroup.modulus.bitSize(),    accumulatorPoKCommitmentGroup.modulus.bitSize()),
    //      max(serialNumberSoKCommitmentGroup.groupOrder.bitSize(), accumulatorPoKCommitmentGroup.groupOrder.bitSize())));
    uint commitment_pok_max_size;

    bigint commitment_pok_challenge_size; // 2^COMMITMENT_EQUALITY_CHALLENGE_SIZE(==256) - 1

    //greatest and smallest values for coin
    bigint min_coin_value;
    bigint max_coin_value;

    bytes challenge_commitment_base; //hash of challenge commitment identification string and parameters


    //for hash function in serial number SoK verification
    bigint params_bytes;

    //RSA-2048 Factoring Challenge encoded as bytes.
    bigint modulus; //RSA-2048

    //the following value is used in the accumulator verification and is equal to:
    //maxCoinValue * bigint(2).pow(k_prime + k_dprime + 1))
    bigint upper_result_range_value;
    
    _accumulatorPoKCommitmentGroup accumulatorPoKCommitmentGroup;
    _accumulatorQRNCommitmentGroup accumulatorQRNCommitmentGroup;
    _coinCommitmentGroup coinCommitmentGroup;
    _serialNumberSoKCommitmentGroup serialNumberSoKCommitmentGroup;

    //these structs will be assigned in contract contructor.
    struct _accumulatorPoKCommitmentGroup{
        bigint g;
        bigint h;
        bigint modulus;
        bigint groupOrder;
    }

    struct _accumulatorQRNCommitmentGroup{
        bigint g;
        bigint h;
    }

    struct _coinCommitmentGroup{
        bigint g;
        bigint h;
        bigint modulus;
        bigint groupOrder;
    }

    struct _serialNumberSoKCommitmentGroup{
        bigint g;
        bigint h;
        bigint modulus;
        bigint groupOrder;
    }
    //*************************************** End Parameters ********************************************


    //*************************************** Begin Values **********************************************

    //add eth value pool here.

    uint accumulator = 961; //initial value for accumulator (accumulatorBase)

    //*************************************** End Values ************************************************


    //*************************************** Begin Persistent Data Structures ********************************
    //both maps and dynamic arrays are used.
    //maps give constant access time where needed, but are not easily iterable, and so we use lists for storage.

    mapping(bytes32 => bigint) public serial_numbers; //revealed serial numbers, mapped by SHA256 hash
    mapping(bytes32 => bigint) public commitments; //minted commitments, mapped by SHA256 hash
    mapping(bytes32 => bigint) public accumulators; //iteratively computed accumulators, mapped by SHA256 hash

    bigint[] accumulator_list;
    bigint[] commitment_list; // accumulator_n^ commitment_n = accumulator_n+1
    
    //*************************************** Begin Persistent Data Structures **********************************


    //********************************* Begin Temporary Proof Structures *********************************
    //These data structures exist only in memory, i.e. for the duration of the transaction call.

    // The client initially generates two separate commitments (here, serial_number_commitment and accumulator_commitment) 
    // to the public coin (C), each under a different set of public parameters.
    // the ZK proof takes these values as parameters and verifies that the two commitments contain the same public coin.
    struct _commitment_pok {
        bigint S1;
        bigint S2;
        bigint S3;
        bigint challenge;
    }

    // Proves that the committed public coin is in the Accumulator (PoK of "witness")
    struct _accumulator_pok {
        bigint C_e;
        bigint C_u;
        bigint C_r;
        bigint[3] st;
        bigint[4] t;
        bigint s_alpha;
        bigint s_beta;
        bigint s_zeta;
        bigint s_sigma;
        bigint s_eta;
        bigint s_epsilon;
        bigint s_delta;
        bigint s_xi;
        bigint s_phi;
        bigint s_gamma;
        bigint s_psi;
    }

    // Proves that the coin is correct w.r.t. serial number and hidden coin secret
    struct _serial_number_sok {
        bigint[80] s_notprime;
        bigint[80] sprime;
        bytes32 hash;
    }

    //********************************* End Temporary Proof Structures //*****************************************

    //********************************* Begin Misc. Functions ****************************************************
    

    function serialized_bytes_to_bigint(bytes input, string proof) private returns (bigint result){


    }

    function serialized_struct_to_bigint(bytes input, string proof) private returns (bigint result){

        if(proof=="commitment_pok"){
            commitment_pok
        }

    }

    //********************************* End Misc. Functions ******************************************************

    
    //********************************* Begin 'Mint' validation ****************************************************
    function validate_coin_mint(bytes _commitment) returns (bool success){
        bigint commitment; //serialize bytes input as struct object here

        bool success = (cmp(min_coin_value,serial_number_commitment)==LT) && 
                       (cmp(serial_number_commitment, max_coin_value)==LT) && 
                       is_prime(serial_number_commitment) &&
                       !(commitments[sha256(serial_number_commitment)]==serial_number_commitment);

        //must also check that denomination of eth sent is correct

        if(success){
            //add to accumulator. new accumulator = old accumulator ^ serial_number_commitment mod modulus.
            bigint old_accumulator = accumulator_list[accumulator_list.length-1];
            bigint accumulator = modexp(old_accumulator, serial_number_commitment, modulus);
            accumulators[sha256(accumulator)] = accumulator; 
            accumulator_list.push(accumulator); //add to list and map

            commitments[serial_number_commitment]==serial_number_commitment;
            commitment_list.push(serial_number_commitment); //add to list and map

            //- && add eth denomination to value pool
            return true;
        }
        return false; //if unsuccessful validation
    }

    function is_prime(bigint serial_number_commitment) returns (bool){
        //executes Miller-Rabin Primality Test for input.

    }

    //********************************* End 'Mint' validation **********************************************************

    //********************************* Begin 'Spend' verification *****************************************************
    function verify_coin_spend(bytes commitment_pok_in, 
                               bytes accumulator_pok_in, 
                               bytes serial_number_sok_in, 
                               bytes accumulator,
                               bytes coin_serial_number,
                               bytes serial_number_commitment,
                               bytes accumulator_commitment,
                               bytes output_address) returns (bool result) { 

        //serialize bytes inputs as struct objects.

        require(verify_commitment_pok(c_pok, serial_number_commitment, accumulator_commitment) &&
                verify_accumulator_pok(accumulator, accumulator_commitment) &&
                verify_serial_number_sok(coin_serial_number, serial_number_commitment));
        
        //send denomination of eth from value pool to output_address
        //add coin_serial_number to map of used serial numbers
        }
    }

    function verify_commitment_pok(_commitment_pok commitment_pok, bigint serial_number_commitment, bigint accumulator_commitment) private returns (bool result){
        // Compute the maximum range of S1, S2, S3 and verify that the given values are in a correct range.

        //get bit sizes of each of the arguments.
        uint s1_bit_size = get_bit_size(commitment_pok.S1);
        uint s2_bit_size = get_bit_size(commitment_pok.S2);
        uint s3_bit_size = get_bit_size(commitment_pok.S3); 

        require(s1_bit_size < commitment_pok_max_size &&
                s2_bit_size < commitment_pok_max_size &&
                s3_bit_size < commitment_pok_max_size &&
                (cmp(challenge, challenge_size) == LT)); 
            

        // Compute T1 = g1^S1 * h1^S2 * inverse(A^{challenge}) mod p1
        bigint T1 = pow_mod(serial_number_commitment, challenge, serialNumberSoKCommitmentGroup.modulus);
        T1 = inverse(T1, serialNumberSoKCommitmentGroup.modulus);
        T1 = mul_mod(T1, 
                    mul_mod(pow_mod(serialNumberSoKCommitmentGroup.g, S1, serialNumberSoKCommitmentGroup.modulus), pow_mod(serialNumberSoKCommitmentGroup.h, S2, serialNumberSoKCommitmentGroup.modulus), serialNumberSoKCommitmentGroup.modulus),
                    serialNumberSoKCommitmentGroup.modulus);

        // Compute T2 = g2^S1 * h2^S3 * inverse(B^{challenge}) mod p2
        bigint T2 = pow_mod(accumulator_commitment, challenge, accumulatorPoKCommitmentGroup.modulus);
        T2 = inverse(T2, accumulatorPoKCommitmentGroup.modulus);
        T2 = mul_mod(T2,
                    mul_mod(pow_mod( accumulatorPoKCommitmentGroup.g, S1,  accumulatorPoKCommitmentGroup.modulus), pow_mod( accumulatorPoKCommitmentGroup.h, S3,  accumulatorPoKCommitmentGroup.modulus),  accumulatorPoKCommitmentGroup.modulus),
                    accumulatorPoKCommitmentGroup.modulus);

        // Hash T1 and T2 along with all of the public parameters
        Bignum computed_challenge = calculate_challenge_commitment_pok(serial_number_commitment, accumulator_commitment, T1, T2);

        // Return success if the computed challenge matches the incoming challenge
        require(computed_challenge == commitment_pok.challenge) return true;

        // Otherwise return failure
        return false;


    }

    function calculate_challenge_commitment_pok(bigint serial_number_commitment, bigint accumulator_commitment, bigint T1, bigint T2) returns (bytes32){
        /* Hash together the following elements:
         * -proof identifier
         * -Commitment A
         * -Commitment B
         * -Ephemeral commitment T1
         * -Ephemeral commitment T2
         * -commitment A parameters
         * -commitment B parameters
         * all representented as bytes.
         * the byte object identifying the proof and parameters is constant and therefore pre created.
         */

         bytes hasher = challenge_commitment_base;
         hasher.push(serial_number_commitment._bytes);
         hasher.push(accumulator_commitment._bytes);
         hasher.push(T1._bytes);
         hasher.push(T2._bytes);

         return sha256(hasher);
    }

    function calculate_challenge_serial_number_pok(bigint a_exp, bigint b_exp, bigint h_exp) private returns (bigint){
        bigint a = coinCommitmentGroup.g;
        bigint b = coinCommitmentGroup.h;
        bigint g = serialNumberSoKCommitmentGroup.g;
        bigint h = serialNumberSoKCommitmentGroup.h;

        //both of those operations are modmuls.
        bigint exponent = (pow_mod(a, a_exp, serialNumberSoKCommitmentGroup.groupOrder) * pow_mod(b, b_exp, serialNumberSoKCommitmentGroup.groupOrder)) % serialNumberSoKCommitmentGroup.groupOrder;

        return mul_mod(pow_mod(g, exponent, serialNumberSoKCommitmentGroup.modulus), pow_mod(h, h_exp, serialNumberSoKCommitmentGroup.modulus), serialNumberSoKCommitmentGroup.modulus);   
    }

    function verify_serial_number_sok(_serial_number_sok serial_number_sok, bigint coin_serial_number, bigint serial_number_commitment) private returns (bool result){

        //initially verify that coin_serial_number has not already been accumulated. mapping gives O(1) access
        if((serial_numbers[sha256(coin_serial_number)] == coin_serial_number)) throw;
        
        bigint a = coinCommitmentGroup.g;
        bigint b = coinCommitmentGroup.h;
        bigint g = serialNumberSoKCommitmentGroup.g;
        bigint h = serialNumberSoKCommitmentGroup.h;

        bytes hasher_bytes = params_bytes + uint_to_bytes(serial_number_commitment) + uint_to_bytes(coin_serial_number);

        //hash hasher_bytes into hasher

        bigint[zkp_iterations] tprime;

        bytes32 hashbytes = bytes32(hash);

        for(uint i = 0; i < zkp_iterations; i++) {
            int bit = i % 8;
            int byte = i / 8;
            int challenge_bit = ((hashbytes[byte] >> bit) & 0x01);
            if(challenge_bit == 1) {
                tprime[i] = calculate_challenge_serial_number_pok(coin_serial_number, serial_number_sok.s_notprime[i], serial_number_sok.sprime[i]);
            } else {
                Bignum exp = pow_mod(b, serial_number_sok.s_notprime[i], serialNumberSoKCommitmentGroup.groupOrder);
                tprime[i] = mul_mod(pow_mod(pow_mod(serial_number_commitment, exp, serialNumberSoKCommitmentGroup.modulus), 1, serialNumberSoKCommitmentGroup.modulus),
                                    pow_mod(pow_mod(h, serial_number_sok.sprime[i], serialNumberSoKCommitmentGroup.modulus), 1, serialNumberSoKCommitmentGroup.modulus),
                                    serialNumberSoKCommitmentGroup.modulus);
            }
        }
        for(uint32_t i = 0; i < zkp_iterations; i++) {
            hasher << tprime[i];
        }
        return hasher.GetArith256Hash() == hash;
        
        }
    
    function calculate_accumulator_hash()

    // Verifies that a commitment c is accumulated in accumulator a
    function verify_accumulator_pok(_accumulator_pok accumulator_pok, bigint accumulator, bigint accumulator_commitment) private returns (bool){

        //initially verify that accumulator exists. mapping gives O(1) access
        if(!(serial_numbers[sha256(accumulator)] == accumulator)) throw;

        bigint sg = accumulatorPoKCommitmentGroup.g;
        bigint sh = accumulatorPoKCommitmentGroup.h;

        bigint g_n = accumulatorQRNCommitmentGroup.g;
        bigint h_n = accumulatorQRNCommitmentGroup.h;

        bytes hasher;
        //hasher << *params << sg << sh << g_n << h_n << accumulator_commitment << accumulator_pok.C_e << accumulator_pok.C_u << accumulator_pok.C_r << accumulator_pok.st[0] << accumulator_pok.st[1] << accumulator_pok.st[2] << accumulator_pok.t[0] << accumulator_pok.t[1] << accumulator_pok.t[2] << accumulator_pok.t[3];
        //hash together inputs above
        bigint c = bytes_to_bigint(hasher); //this hash should be of length k_prime bits

        bigint[3] st_prime;
        bigint[4] t_prime;

        bigint A,B,C;

        A = pow_mod(accumulator_commitment, c, accumulatorPoKCommitmentGroup.modulus);
        B = pow_mod(sg, accumulator_pok.s_alpha, accumulatorPoKCommitmentGroup.modulus);
        C = pow_mod(sh, accumulator_pok.s_phi, accumulatorPoKCommitmentGroup.modulus);
        st_prime[0] = pow_mod(mul(mul(A,B),C), 1, accumulatorPoKCommitmentGroup.modulus;                        

        A = pow_mod(sg, c, accumulatorPoKCommitmentGroup.modulus);
        B = pow_mod(mul(accumulator_commitment,inverse(sg,accumulatorPoKCommitmentGroup.modulus)), accumulator_pok.s_gamma, accumulatorPoKCommitmentGroup.modulus);
        C = pow_mod(sh, accumulator_pok.s_psi, accumulatorPoKCommitmentGroup.modulus);
        st_prime[1] = pow_mod(mul(mul(A,B),C), 1, accumulatorPoKCommitmentGroup.modulus;                        

        A = pow_mod(sg, c, accumulatorPoKCommitmentGroup.modulus);
        B = pow_mod(mul(sg,accumulator_commitment),accumulator_pok.s_sigma, accumulatorPoKCommitmentGroup.modulus);
        C = pow_mod(sh, accumulator_pok.s_xi, accumulatorPoKCommitmentGroup.modulus);
        st_prime[2] = pow_mod(mul(mul(A,B),C), 1, accumulatorPoKCommitmentGroup.modulus; 


        A = pow_mod(accumulator_pok.C_r, c, modulus);
        B = pow_mod(h_n, accumulator_pok.s_zeta, modulus);
        C = pow_mod(g_n, accumulator_pok.s_epsilon, modulus);
        t_prime[0] = pow_mod(mul(mul(A,B),C), 1, modulus; 

        A = pow_mod(accumulator_pok.C_e, c, modulus);
        B = pow_mod(h_n, accumulator_pok.s_eta, modulus);
        C = pow_mod(g_n, accumulator_pok.s_alpha, modulus);
        t_prime[1] = pow_mod(mul(mul(A,B),C), 1, modulus; 

        A = pow_mod(accumulator, c, modulus);
        B = pow_mod(accumulator_pok.C_u, accumulator_pok.s_alpha, modulus);
        C = pow_mod(inverse(h_n, modulus), accumulator_pok.s_beta, modulus);
        t_prime[2] = pow_mod(mul(mul(A,B),C), 1, modulus;

        A = pow_mod(accumulator_pok.C_r, accumulator_pok.s_alpha, modulus);
        B = pow_mod(inverse(h_n,modulus),accumulator_pok.s_delta, modulus);
        C = pow_mod(inverse(g_n, modulus),accumulator_pok.s_beta, modulus);
        t_prime[3] = pow_mod(mul(mul(A,B),C), 1, modulus; 

        bool[3] result_st;
        bool[4] result_t;

        bool result_st[0] = (st[0] == st_prime[0]);
        bool result_st[1] = (st[1] == st_prime[1]);
        bool result_st[2] = (st[2] == st_prime[2]);

        bool result_t[0] = (t[0] == t_prime[0]);
        bool result_t[1] = (t[1] == t_prime[1]);
        bool result_t[2] = (t[2] == t_prime[2]);
        bool result_t[3] = (t[3] == t_prime[3]);

        //(maxCoinValue * bigint(2).pow(k_prime + k_dprime + 1))) in params as upper_result_range_value
        bigint lower_result_range_value = upper_result_range_value;
        lower_result_range_value.neg = 1;
        bool result_range = (cmp(accumulator_pok.s_alpha, result_range_value) == LT) && (cmp(accumulator_pok.s_alpha, result_range_value) == GT);

        return (result_st[0] && result_st[1] && result_st[2] && result_t[0] && result_t[1] && result_t[2] && result_t[3] && result_range);   
    }
    //********************************* End 'Spend' verification *****************************************************
}