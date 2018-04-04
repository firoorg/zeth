
pragma solidity ^0.4.21;
pragma experimental ABIEncoderV2;

import "https://raw.githubusercontent.com/zcoinofficial/solidity-BigNumber/master/contracts/BigNumber.sol";

contract Zerocoin { 

    using BigNumber for *;
    
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
      */

    uint constant zkp_iterations = 80;

    //accumulator params
    uint k_prime = 160;
    uint k_dprime = 128;
    
    BigNumber.instance T1;
    BigNumber.instance T2;
    

    //the following value is used in the commitment PoK verification and is equal to:
    //64 * (COMMITMENT_EQUALITY_CHALLENGE_SIZE (==256) + COMMITMENT_EQUALITY_SECMARGIN (==512) +
    //      max(max(serial_number_sok_commitment_group.modulus.bit_size(),    accumulator_pok_commitment_group.modulus.bit_size()),
    //      max(serial_number_sok_commitment_group.group_order.bit_size(), accumulator_pok_commitment_group.group_order.bit_size())));
    // move out of storage - cheaper. TODO
    uint commitment_pok_max_size = 115264;

    // 2^COMMITMENT_EQUALITY_CHALLENGE_SIZE(==256) - 1 : so max uint
    BigNumber.instance commitment_pok_challenge_size = BigNumber.instance(
        hex"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",false,256);

    //greatest and smallest values for coin
    BigNumber.instance min_coin_value = BigNumber.instance(
        hex"000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", false, 516
    );
    
    BigNumber.instance max_coin_value = BigNumber.instance(
        hex"e5f1c46cf7c4676f8e17f88373e340d6678a6054f55dc93694479a2844706f5e72ae264e793226cac0e59480a0d9037729a47201c7e67d82894bbc986b1b478341649e3d59372cec09f9e2f5dd0815e9d4e93fd4918fe1dd2ec4ee9375ac0be438f82f715c6f5f1d673785d79c962c6097f7961d37c2508d2b933024723ba241", false, 1024
    );

    //hash of challenge commitment identification string and parameters. (bytes32?)
    bytes challenge_commitment_base; 

    //for hash function in serial number SoK verification & others
    bytes32 constant params_hash = hex"ebd4446751f9c32bbac17dfa1e69308f0d1a3bccefaa8b7a2b82dea90dec83e8";

    //RSA-2048 Factoring Challenge encoded as a bignum.
    BigNumber.instance modulus = BigNumber.instance(
        hex"c7970ceedcc3b0754490201a7aa613cd73911081c790f5f1a8726f463550bb5b7ff0db8e1ea1189ec72f93d1650011bd721aeeacc2acde32a04107f0648c2813a31f5b0b7765ff8b44b4b6ffc93384b646eb09c7cf5e8592d40ea33c80039f35b4f14a04b51f7bfd781be4d1673164ba8eb991c2c4d730bbbe35f592bdef524af7e8daefd26c66fc02c479af89d64d373f442709439de66ceb955f3ea37d5159f6135809f85334b5cb1813addc80cd05609f10ac6a95ad65872c909525bdad32bc729592642920f24c61dc5b3c3b7923e56b16a4d9d373d8721f24a3fc0f1b3131f55615172866bccc30f95054c824e733a5eb6817f7bc16399d48c6361cc7e5", false, 2048
    );

    //the following value is used in the accumulator verification and is equal to:
    //maxCoinValue * BigNumber.instance(2).pow(k_prime + k_dprime + 1))
    BigNumber.instance result_range_value = BigNumber.instance(
        hex"00000000000000000000000000000000000000000000000000000001cbe388d9ef88cedf1c2ff106e7c681accf14c0a9eabb926d288f345088e0debce55c4c9cf2644d9581cb290141b206ee5348e4038fccfb0512977930d6368f0682c93c7ab26e59d813f3c5ebba102bd3a9d27fa9231fc3ba5d89dd26eb5817c871f05ee2b8debe3ace6f0baf392c58c12fef2c3a6f84a11a57266048e4774482000000000000000000000000000000000000000000000000000000000000000000000000", false, 1313
    );
    
    struct commitment_group {
        BigNumber.instance g;
        BigNumber.instance h;
        BigNumber.instance modulus;
        BigNumber.instance group_order;
    }

    commitment_group accumulator_pok_commitment_group = commitment_group(
        BigNumber.instance(hex"000000000000000000000000000000000000000000000000000001d5868e648ac6d41756e0409a510ff5a54bf1ebad22904ab359af54bb0d20a599324cba5ef004d7837cfa6b5904dbc221de6332101df5ef8d99992e8d5679969cc3221c0ba7",false,553), 
        BigNumber.instance(hex"00000000000000000000000000000000000000000000000000000408f47ff9a66729f6e6ad9796ce794e702995429c7f621294491042b63e1db4ed3cd9572e69fd82bd8cadf3e386dceb4064838be8310576460c3d4f40670b2d14b12ac23a86",false,553),
        BigNumber.instance(hex"00000000000000000000000000000000000000000000000000000f09b3785fa945027296dbbb660809191b7aaa73581fb6af13ffdfa319a597ffda256bfd0a922a442a80d48c9809849b001999e9e8da06f12ec9807996d550f10beda5d7b871",false,556),
        BigNumber.instance(hex"0000000000000000000000000000000000000000000000000000000000000001723c6b5051557deef6da8dd8d3f3e48f68972cbbac1ca80d910777f72f38b25f",false,257)
    );
    
    commitment_group accumulator_qrn_commitment_group = commitment_group(
        BigNumber.instance(hex"6324dc564e2b4afec9cabebb4d77daf9bac097fc2b72caffb0fd6db968ce1e4aff24137928fefecd636b8a987b5879e06b1ab52b1d69b2caf5a0102328680fda67440691c7d36429560ead7490a21d90d92bd216e47a04ed810d3b4a79182dfbea9ff48d9631c6a5139c805d7a1ea5e320b96b4fbc192ed8c957d5318fbc45b00bd911c58783b266ec71cad61a7b79236d2936024869d64dfb003173491932ba487dae5f6e7b089445f0579297c221f7953c1143b4c9eae022f2c171401e6f49d89369ad0ef6ccd169f4b84a1e8cfe241bb2bacf362b18e967a379775b70f176f269a96c5e51f16b9c7e902336e293fcf45f1769d58d705075966ce97377f63a",false,2047),
        BigNumber.instance(hex"61a3be57d109c4bd2560ed3d52fb1b153612af0fecd25795ea0c64ef7fa730f081d2b2fd12d4d3f52b6d524fe47e07bed9397711491d4e012b7d744ebd37b448726f38fd9252b16111a4454dbda10f0d4eb6b76b78cecfb37c1061d2cc7d75d73b5a59f508214caa29e0cc35f21968324b39d477007905d345cbb262b2574550f146c7371b4ce09fb804eba9bfeae2c68d22a585e7264402accd7863c49e1073a0358a14f70e00662591bbdc2d4dc6a4fae0390757f128ee320bd7cb51f50ed0f64721fe11b116f00234ec807f56a85ce1649a6026eb9179e97d00323cf6a2109e6a4b6d60b38a4f36744e2884442a62b48fd395dce9b6f7b5c564c6ef47d802",false,2047),
        BigNumber.instance(hex"0000000000000000000000000000000000000000000000000000000000000000",false,0),
        BigNumber.instance(hex"0000000000000000000000000000000000000000000000000000000000000000",false,0)
    );

    commitment_group coin_commitment_group = commitment_group(
        BigNumber.instance(hex"9a7fd6508dfa79258e50019ab6cb59b4f91b2823dcd9250fb3ccf9fd8263b29a15b005c429915cec63e7d3eba1da337f45dd713246c41e39ac671cf2f87adfc6d45c842ae7ad21ed291e3a48b2a6e5d39381f6d4a9ab83d5aaa5031d17554df70cf5ecfe10096cf1a565d0f826b71eb4d105a3016afc445613f04ffbd0dd4162",false,1024),
        BigNumber.instance(hex"ccbbdd469de23cfba19728b625ee7b197b60389eebb7383ec63184fe6ddc94acf0e6e68eb49523acff5e4d0c6fd20b744df744c1a7b554140d110e6398040425790fe3b9b32e87238f0338c4f52e3f9b84bef7bceace17f26ada12fa5e1ca0d992b79599f0ef29b66c323b88c1471d9367f991604a97414f99f748ead3d38622",false,1024),
        BigNumber.instance(hex"e5f1c46cf7c4676f8e17f88373e340d6678a6054f55dc93694479a2844706f5e72ae264e793226cac0e59480a0d9037729a47201c7e67d82894bbc986b1b478341649e3d59372cec09f9e2f5dd0815e9d4e93fd4918fe1dd2ec4ee9375ac0be438f82f715c6f5f1d673785d79c962c6097f7961d37c2508d2b933024723ba241",false,1024),
        BigNumber.instance(hex"a33a39fceb03fef51aa5f50322b557664a8364d7ad0ada150487fae8576af9e3",false,256)
    );

    commitment_group serial_number_sok_commitment_group = commitment_group(
        BigNumber.instance(hex"00000000000000000000000000000000000000000000000000000000000000755af74f335a187e660d329f9ff1f2186b8e087797b3043ce17dd4fe734359fa17d5aa2e4190afee489b0a1fee25c9fc08836cb658bdeb7efe63fc75e67e3dc3514b2bed4685f82ed104c7ad7c19d171e8dbd589d4c8888e70eec79c5a2d72e6346c91d17e7af34482a5d446423059dba15e857d4020bcd5095429da2886990032",false,1031),
        BigNumber.instance(hex"0000000000000000000000000000000000000000000000000000000000000005e257cc3861dfbbd85a95f16fdc867780188c0bc469a7744871f9fa79cfb942d3eb60642736d3e6db940f69fd05d19d57a2b1aa686ad8d2695b39fef8a4c6c92c99636a6172e5b2b9df49e113508185d15b18158f05d63fa4d6819c126f9065b01183043a17022f6c583735797f3e72c3c9c2485327127158e4cf0eb23391d739",false,1027),
        BigNumber.instance(hex"000000000000000000000000000000000000000000000000000000000000010f4335b88c49b20599a0472b12b6167cee253da43974a35e62ec77db80bca3616b49713092f929c32f8ed52fbdc00216931ffe7e19d1e80ffdf7587bce5a2e5cd724b2ac5f3f16fe73c4c9be0abf89d9d92b294cc3b7bc72ed2c5171f4d0f6073b34c7f7bb0b6234afc37fe45ab92859f346131677c73b068967a2cafec25968af",false,1033),
        BigNumber.instance(hex"e5f1c46cf7c4676f8e17f88373e340d6678a6054f55dc93694479a2844706f5e72ae264e793226cac0e59480a0d9037729a47201c7e67d82894bbc986b1b478341649e3d59372cec09f9e2f5dd0815e9d4e93fd4918fe1dd2ec4ee9375ac0be438f82f715c6f5f1d673785d79c962c6097f7961d37c2508d2b933024723ba241",false,1024)
    );
    
    //*************************************** End Parameters ********************************************


    //*************************************** Begin Values **********************************************

    //add eth value pool here. TBD

    BigNumber.instance accumulator_base = BigNumber.instance(hex"00000000000000000000000000000000000000000000000000000000000003c1",false,10); //initial value for accumulator.

    //*************************************** End Values ************************************************



    //*************************************** Begin Persistent Data Structures ********************************
    //both maps and dynamic arrays are used.
    //maps give constant access time where needed, but are not easily iterable, and so we use lists for storage.

    mapping(bytes32 => BigNumber.instance) private serial_numbers; // Revealed serial numbers, mapped by SHA256 hash
    mapping(bytes32 => BigNumber.instance) private commitments;    // Minted commitments, mapped by SHA256 hash
    mapping(bytes32 => BigNumber.instance) private accumulators;   // Iteratively computed accumulators, mapped by SHA256 hash

    BigNumber.instance[] accumulator_list;
    BigNumber.instance[] commitment_list; // accumulator_n^ commitment_n = accumulator_n+1
    
    //*************************************** End Persistent Data Structures **********************************



    //********************************* Begin Temporary Proof Structures *********************************
    //These data structures exist only in memory, i.e. for the duration of the transaction call.

    // The client initially generates two separate commitments (here, serial_number_commitment and accumulator_commitment) 
    // to their public coin (C), each under a different set of public parameters.
    // the ZK proof takes these values as parameters and verifies that the two commitments contain the same public coin.
    struct Commitment_pok {
        BigNumber.instance S1;
        BigNumber.instance S2;
        BigNumber.instance S3;
        BigNumber.instance challenge;
    }

    // Proves that the committed public coin is in the Accumulator (PoK of "witness")
    struct Accumulator_pok {
        BigNumber.instance C_e;
        BigNumber.instance C_u;
        BigNumber.instance C_r;
        BigNumber.instance[3] st;
        BigNumber.instance[4] t;
        BigNumber.instance s_alpha;
        BigNumber.instance s_beta;
        BigNumber.instance s_zeta;
        BigNumber.instance s_sigma;
        BigNumber.instance s_eta;
        BigNumber.instance s_epsilon;
        BigNumber.instance s_delta;
        BigNumber.instance s_xi;
        BigNumber.instance s_phi;
        BigNumber.instance s_gamma;
        BigNumber.instance s_psi;
    }

    // Proves that the coin is correct w.r.t. serial number and hidden coin secret
    struct Serial_number_sok {
        BigNumber.instance[zkp_iterations] s_notprime;
        BigNumber.instance[zkp_iterations] sprime;
        bytes32 hash;
    }

    //********************************* End Temporary Proof Structures *******************************************

    //pass randomness explicitly for now.
    function validate_coin_mint(BigNumber.instance commitment, BigNumber.instance[3] randomness) public returns (bool success){ //TODO instead of bool - perhaps log an event?
        //TODO denominations & eth/gas handling.
        
        //should not be set if commitment is new.
        BigNumber.instance memory stored_commitment = commitments[BigNumber.hash(commitment)]; 
        assert (BigNumber.cmp(min_coin_value,commitment,true)==-1 && 
                BigNumber.cmp(commitment, max_coin_value,true)==-1 && 
                BigNumber.is_prime(commitment, randomness) &&
                !(BigNumber.cmp(stored_commitment,commitment,true)==0)); // if new struct == stored struct, commitment is not new.

        // must also check that denomination of eth sent is correct
        
        //add to accumulator. new accumulator = old accumulator ^ serial_number_commitment mod modulus.
        BigNumber.instance memory old_accumulator = accumulator_list[accumulator_list.length-1];
        BigNumber.instance memory accumulator = BigNumber.prepare_modexp(old_accumulator, commitment, modulus);
        accumulators[BigNumber.hash(accumulator)] = accumulator; 
        accumulator_list.push(accumulator); //add to list and map

        commitments[BigNumber.hash(commitment)] = commitment;
        commitment_list.push(commitment); //add to list and map

        // add eth denomination to value pool.

        return true;
    }
    //********************************* End 'Mint' validation ****************************************************
    
    function zerocoin_mint_() public{
            //constructor: sets up basic accumulator.
            accumulator_list.push(accumulator_base);
            accumulators[BigNumber.hash(accumulator_base)] = accumulator_base;
    }
       
    
    //********************************* Begin 'Spend' verification *****************************************************

    function verify_coin_spend(Commitment_pok commitment_pok, 
                               Accumulator_pok accumulator_pok, 
                               Serial_number_sok serial_number_sok, 
                               BigNumber.instance accumulator,
                               BigNumber.instance coin_serial_number,
                               BigNumber.instance serial_number_commitment,
                               BigNumber.instance accumulator_commitment,
                               BigNumber.instance[4] accumulator_inverses,
                               BigNumber.instance[2] commitment_inverses,
                               address output_address) internal returns (bool result) { //internal for now - will be made public/external

        BigNumber.instance memory stored_coin_serial_number = commitments[BigNumber.hash(coin_serial_number)]; //should be empty if this is a new serial

        assert(verify_commitment_pok(commitment_pok, serial_number_commitment, accumulator_commitment, commitment_inverses) &&
               verify_accumulator_pok(accumulator_pok, accumulator, accumulator_commitment, accumulator_inverses) &&
               //verify_serial_number_sok(serial_number_sok, coin_serial_number, serial_number_commitment) &&
               !( BigNumber.cmp(stored_coin_serial_number,coin_serial_number,true)==0) );
        
        //TODO send denomination of eth from value pool to output_address

        //add coin_serial_number to map of used serial numbers
        serial_numbers[BigNumber.hash(coin_serial_number)] = coin_serial_number;
    }


    //******************************* Start commitment verification functions *********************************//

    //Structs of external library values cannot be passed externally yet - so have to set up entry from a separate function.
    function serialize_verify_commitment_pok(BigNumber.instance[3] s, 
                      BigNumber.instance challenge,
                      BigNumber.instance serial_number_commitment,
                      BigNumber.instance accumulator_commitment,
                      BigNumber.instance[2] inverse_results) public {

        Commitment_pok memory commitment_pok;
        commitment_pok.S1 = s[0];
        commitment_pok.S2 = s[1];
        commitment_pok.S3 = s[2];
        commitment_pok.challenge = challenge;
        verify_commitment_pok(commitment_pok, serial_number_commitment, accumulator_commitment,inverse_results);
    }
    

    function verify_commitment_pok(Commitment_pok commitment_pok, 
                                   BigNumber.instance serial_number_commitment, 
                                   BigNumber.instance accumulator_commitment,
                                   BigNumber.instance[2] inverse_results) private returns (bool result){ //CHANGE THIS BACK TO PRIVATE!!11!
        // Compute the maximum range of S1, S2, S3 and verify that the given values are in a correct range.

        //get bit sizes of each of the arguments.
        assert(commitment_pok.S1.bitlen < commitment_pok_max_size &&
               commitment_pok.S2.bitlen < commitment_pok_max_size &&
               commitment_pok.S3.bitlen < commitment_pok_max_size &&
               (BigNumber.cmp(commitment_pok.challenge, commitment_pok_challenge_size,true) == -1)); 
            

        // Compute T1 = g1^S1 * h1^S2 * inverse(A^{challenge}) mod p1
        T1 = BigNumber.prepare_modexp(serial_number_commitment, commitment_pok.challenge, serial_number_sok_commitment_group.modulus);
        T1 = BigNumber.mod_inverse(T1, serial_number_sok_commitment_group.modulus,inverse_results[0]);
        T1 = BigNumber.modmul(T1, 
                    BigNumber.modmul(BigNumber.prepare_modexp(serial_number_sok_commitment_group.g, commitment_pok.S1, serial_number_sok_commitment_group.modulus), BigNumber.prepare_modexp(serial_number_sok_commitment_group.h, commitment_pok.S2, serial_number_sok_commitment_group.modulus), serial_number_sok_commitment_group.modulus),
                    serial_number_sok_commitment_group.modulus);

        // Compute T2 = g2^S1 * h2^S3 * inverse(B^{challenge}) mod p2
        T2 = BigNumber.prepare_modexp(accumulator_commitment, commitment_pok.challenge, accumulator_pok_commitment_group.modulus);
        T2 = BigNumber.mod_inverse(T2, accumulator_pok_commitment_group.modulus, inverse_results[1]);
        BigNumber.instance memory inner = BigNumber.modmul(BigNumber.prepare_modexp( accumulator_pok_commitment_group.g,  commitment_pok.S1,  accumulator_pok_commitment_group.modulus), BigNumber.prepare_modexp(  accumulator_pok_commitment_group.h,  commitment_pok.S3,   accumulator_pok_commitment_group.modulus),   accumulator_pok_commitment_group.modulus);
        T2 = BigNumber.modmul(T2, inner, accumulator_pok_commitment_group.modulus);
        
        // Hash T1 and T2 along with all of the public parameters
        BigNumber.instance memory computed_challenge = calculate_challenge_commitment_pok(serial_number_commitment, accumulator_commitment, T1, T2);

        // Return success if the computed challenge matches the incoming challenge
        if(BigNumber.cmp(computed_challenge,commitment_pok.challenge,true)==0) return true;

        // Otherwise return failure
        return false;

    }

    function reverse(bytes base) internal returns(bytes){
    
            bytes memory reversed = new bytes(base.length);
            
            for(uint i=0;i<base.length; i++){
                reversed[base.length - i - 1] = base[i];
            }
            return reversed;
        }
    
     function calculate_challenge_commitment_pok(BigNumber.instance serial_number_commitment, BigNumber.instance accumulator_commitment, BigNumber.instance t1, BigNumber.instance t2) private returns(BigNumber.instance result) {
            /* Hash together the following elements:
             * -proof identifier
             * -Commitment A
             * -Commitment B
             * -Ephemeral commitment t1
             * -Ephemeral commitment t2
             * -commitment A parameters
             * -commitment B parameters
             * all representented as bytes.
             * the byte object identifying the proof and parameters is constant and therefore pre created.
             */
             
            bytes memory hasher;
            
            //parameters. TODO change to single hash, for now this is to mirror libzerocoin functionality
            bytes memory ZEROCOIN_COMMITMENT_EQUALITY_PROOF = hex"19434F4D4D49544D454E545F455155414C4954595F50524F4F46";
        
            bytes memory barbar = hex"027C7C";
        
            bytes memory apbp = hex"00813200998628DA295409D5BC20407D855EA1DB59304246D4A58244F37A7ED1916C34E6722D5A9CC7EE708E88C8D489D5DBE871D1197CADC704D12EF88546ED2B4B51C33D7EE675FC63FE7EEBBD58B66C8308FCC925EE1F0A9B48EEAF90412EAAD517FA594373FED47DE13C04B39777088E6B18F2F19F9F320D667E185A334FF75A758139D79133B20ECFE4587112275348C2C9C3723E7F793537586C2F02173A048311B065906F129C81D6A43FD6058F15185BD185815013E149DFB9B2E572616A63992CC9C6A4F8FE395B69D2D86A68AAB1A2579DD105FD690F94DBE6D336276460EBD342B9CF79FAF9714874A769C40B8C18807786DC6FF1955AD8BBDF6138CC57E20582AF6859C2FECAA26789063BC777161346F35928B95AE47FC3AF34620BBBF7C7343B07F6D0F471512CED72BCB7C34C292BD9D989BF0ABEC9C473FE163F5FACB224D75C2E5ACE7B58F7FD0FE8D1197EFE1F931602C0BD2FD58E2FC329F9923071496B61A3BC80DB77EC625EA37439A43D25EE7C16B6122B47A09905B2498CB835430F018141A23B722430932B8D50C2371D96F797602C969CD78537671D5F6F5C712FF838E40BAC7593EEC42EDDE18F91D43FE9D4E91508DDF5E2F909EC2C37593D9E644183471B6B98BC4B89827DE6C70172A4297703D9A08094E5C0CA2632794E26AE725E6F7044289A479436C95DF554608A67D640E37383F8178E6F67C4F76CC4F1E500027C7C0046A70B1C22C39C9679568D2E99998DEFF51D103263DE21C2DB04596BFA7C83D704F05EBA4C3299A5200DBB54AF59B34A9022ADEBF14BA5F50F519A40E05617D4C68A648E86D50146863AC22AB1142D0B67404F3D0C46760531E88B836440EBDC86E3F3AD8CBD82FD692E57D93CEDB41D3EB64210499412627F9C429529704E79CE9697ADE6F62967A6F97FF408044671B8D7A5ED0BF150D5967980C92EF106DAE8E99919009B8409988CD4802A442A920AFD6B25DAFF97A519A3DFFF13AFB61F5873AA7A1B19090866BBDB96720245A95F78B3090F215FB2382FF77707910DA81CACBB2C97688FE4F3D3D88DDAF6EE7D5551506B3C7201";
      
             
             //first reverse inputs. these will be added and prepended with their length
             
            serial_number_commitment.val = reverse(serial_number_commitment.val);
            accumulator_commitment.val = reverse(accumulator_commitment.val);
            t1.val = reverse(t1.val);
            t2.val = reverse(t2.val);
             
             //memcopy each parameter into the new location.
             assembly {
                let m_alloc := msize()
                hasher := m_alloc
                
                let ptr := add(hasher,0x20)
    
                
                //--ZEROCOIN_COMMITMENT_EQUALITY_PROOF--
                //copy ZEROCOIN_COMMITMENT_EQUALITY_PROOF (reversed)
                let success := staticcall(450, 0x4, add(ZEROCOIN_COMMITMENT_EQUALITY_PROOF,0x20), mload(ZEROCOIN_COMMITMENT_EQUALITY_PROOF), ptr, mload(ZEROCOIN_COMMITMENT_EQUALITY_PROOF))

                //update ptr location
                ptr := add(ptr, mload(ZEROCOIN_COMMITMENT_EQUALITY_PROOF))
                
                //--t1--
                //copy length
                success := staticcall(450, 0x4, add(mload(t1),0x1f), 0x1, ptr, 0x1)
                
                //update ptr location
                ptr := add(ptr, 0x1)
                
                //copy t1 (reversed)
                success := staticcall(450, 0x4, add(mload(t1),0x20), mload(mload(t1)), ptr, mload(mload(t1)))

                //update ptr location
                ptr := add(ptr, mload(mload(t1)))
                
                //copy ||
                success := staticcall(450, 0x4, add(barbar,0x20), mload(barbar), ptr, mload(barbar))
                
                //update ptr location
                ptr := add(ptr, mload(barbar))



                //--t2--
                //copy length
                success := staticcall(450, 0x4, add(mload(t2),0x1f), 0x1, ptr, 0x1)
                
                //update ptr location
                ptr := add(ptr, 0x1)
                
                //copy t2 (reversed)
                success := staticcall(450, 0x4, add(mload(t2),0x20), mload(mload(t2)), ptr, mload(mload(t2)))

                //update ptr location
                ptr := add(ptr, mload(mload(t2)))
                
                //copy ||
                success := staticcall(450, 0x4, add(barbar,0x20), mload(barbar), ptr, mload(barbar))
                
                //update ptr location
                ptr := add(ptr, mload(barbar))



                //--serial_number_commitment--
                //copy length
                success := staticcall(450, 0x4, add(mload(serial_number_commitment),0x1f), 0x1, ptr, 0x1)
                
                //update ptr location
                ptr := add(ptr, 0x1)
                
                //copy serial_number_commitment (reversed)
                success := staticcall(450, 0x4, add(mload(serial_number_commitment),0x20), mload(mload(serial_number_commitment)), ptr, mload(mload(serial_number_commitment)))

                //update ptr location
                ptr := add(ptr, mload(mload(serial_number_commitment)))
                
                //copy ||
                success := staticcall(450, 0x4, add(barbar,0x20), mload(barbar), ptr, mload(barbar))
                
                //update ptr location
                ptr := add(ptr, mload(barbar))



                //--accumulator_commitment--
                //copy length
                success := staticcall(450, 0x4, add(mload(accumulator_commitment),0x1f), 0x1, ptr, 0x1)
                
                //update ptr location
                ptr := add(ptr, 0x1)
                
                //copy accumulator_commitment (reversed)
                success := staticcall(450, 0x4, add(mload(accumulator_commitment),0x20), mload(mload(accumulator_commitment)), ptr, mload(mload(accumulator_commitment)))

                //update ptr location
                ptr := add(ptr, mload(mload(accumulator_commitment)))
                
                //copy ||
                success := staticcall(450, 0x4, add(barbar,0x20), mload(barbar), ptr, mload(barbar))
                
                //update ptr location
                ptr := add(ptr, mload(barbar))
                
                //mstore(m_alloc, sub(ptr,add(m_alloc,0x20))) //store length
                
                //--copy apbp--
                success := staticcall(450, 0x4, add(apbp,0x20), mload(apbp), ptr, mload(apbp))
                
                //update ptr location
                ptr := add(ptr, mload(apbp))
                
                mstore(m_alloc, sub(ptr,add(m_alloc,0x20))) //store length
                
             }

             result = BigNumber._new(reverse(bytes(sha256(sha256(hasher))), false, false);
        }
    
    function calculate_challenge_serial_number_pok(BigNumber.instance a_exp, BigNumber.instance b_exp, BigNumber.instance h_exp) private returns (BigNumber.instance){
        BigNumber.instance memory a = coin_commitment_group.g;
        BigNumber.instance memory b = coin_commitment_group.h;
        BigNumber.instance memory g = serial_number_sok_commitment_group.g;
        BigNumber.instance memory h = serial_number_sok_commitment_group.h;


        //both of these operations are modmuls.
        BigNumber.instance memory exponent = BigNumber.modmul(BigNumber.prepare_modexp(a, a_exp, serial_number_sok_commitment_group.group_order), BigNumber.prepare_modexp(b, b_exp, serial_number_sok_commitment_group.group_order), serial_number_sok_commitment_group.group_order);

        return BigNumber.modmul(BigNumber.prepare_modexp(g, exponent, serial_number_sok_commitment_group.modulus), BigNumber.prepare_modexp(h, h_exp, serial_number_sok_commitment_group.modulus), serial_number_sok_commitment_group.modulus);   
    }
    //******************************* End challenge verification functions *********************************//


    //***************************** Start serial number verification functions *******************************//
    
    function verify_serial_number_sok(Serial_number_sok serial_number_sok, BigNumber.instance coin_serial_number, BigNumber.instance serial_number_commitment) private returns (bool result){

        //initially verify that coin_serial_number has not already been used. mapping gives O(1) access
        require(!(keccak256(serial_numbers[keccak256(coin_serial_number)]) == keccak256(coin_serial_number)));
        
        BigNumber.instance memory a = coin_commitment_group.g;
        BigNumber.instance memory b = coin_commitment_group.h;
        BigNumber.instance memory g = serial_number_sok_commitment_group.g;
        BigNumber.instance memory h = serial_number_sok_commitment_group.h;
        BigNumber.instance memory exp;

        bytes memory hasher;
        //hasher << *params << valueOfCommitmentToCoin <<coinSerialNumber;
        //hash the above into hasher

        BigNumber.instance[zkp_iterations] memory tprime;
        BigNumber.instance memory one = BigNumber.instance(hex"01",false,1);

        for(uint i = 0; i < zkp_iterations; i++) {
            uint bit = i % 8;
            uint _byte = i / 8;
            uint challenge_bit;// = ((serial_number_sok.hash[_byte] >> bit) & 0x01); //TODO likely asm implementation
            if(challenge_bit == 1) {
                tprime[i] = calculate_challenge_serial_number_pok(coin_serial_number, serial_number_sok.s_notprime[i], serial_number_sok.sprime[i]);
            } else {
                exp = BigNumber.prepare_modexp(b, serial_number_sok.s_notprime[i], serial_number_sok_commitment_group.group_order);
                tprime[i] = BigNumber.modmul(BigNumber.prepare_modexp(BigNumber.prepare_modexp(serial_number_commitment, exp, serial_number_sok_commitment_group.modulus), one, serial_number_sok_commitment_group.modulus),
                                    BigNumber.prepare_modexp(BigNumber.prepare_modexp(h, serial_number_sok.sprime[i], serial_number_sok_commitment_group.modulus), one, serial_number_sok_commitment_group.modulus),
                                    serial_number_sok_commitment_group.modulus);
            }
        }
        for(i = 0; i < zkp_iterations; i++) {
            //hasher.push(tprime[i]); TODO assembly implementation
        }
        return (sha256(hasher) == serial_number_sok.hash);
        
        }
    //***************************** End serial number verification functions *******************************//
    

    //**************************** Start accumulator verification functions ******************************** //
    function serialize_verify_accumulator_pok(BigNumber.instance[21] accumulator_pok_raw,
                                              BigNumber.instance accumulator, 
                                              BigNumber.instance accumulator_commitment,
                                              BigNumber.instance[4] inverse_results) public {

            Accumulator_pok memory accumulator_pok;
            a
            string memory n = "got to before accumulator check";
            string_event(n);
            
            require(BigNumber.cmp(accumulators[BigNumber.hash(accumulator)], accumulator, true)==0); //TODO add to serial number. here now as stack too deep in accumulator verification
            
            accumulator_pok.C_e = accumulator_pok_raw[0];
            accumulator_pok.C_u = accumulator_pok_raw[1];
            accumulator_pok.C_r = accumulator_pok_raw[2];
            accumulator_pok.s_alpha = accumulator_pok_raw[10];
            accumulator_pok.s_beta = accumulator_pok_raw[11];
            accumulator_pok.s_zeta = accumulator_pok_raw[12];
            accumulator_pok.s_sigma = accumulator_pok_raw[13];
            accumulator_pok.s_eta = accumulator_pok_raw[14];
            accumulator_pok.s_epsilon = accumulator_pok_raw[15];
            accumulator_pok.s_delta = accumulator_pok_raw[16];
            accumulator_pok.s_xi = accumulator_pok_raw[17];
            accumulator_pok.s_phi = accumulator_pok_raw[18];
            accumulator_pok.s_gamma = accumulator_pok_raw[19];
            accumulator_pok.s_psi = accumulator_pok_raw[20];
            
            verify_accumulator_pok(accumulator_pok, accumulator, accumulator_commitment, inverse_results);
        
    }

    //calculates the 'c' value in the accumulator PoK.
    function calculate_challege_accumulator_pok(Accumulator_pok accumulator_pok, 
                                       BigNumber.instance accumulator_commitment) private returns(BigNumber.instance result){
        //TODO like commitment challenge.
    }

    // Verifies that a commitment c is accumulated in accumulator a
    function verify_accumulator_pok(Accumulator_pok accumulator_pok, 
                                    BigNumber.instance accumulator, 
                                    BigNumber.instance accumulator_commitment,
                                    BigNumber.instance[4] inverse_results) private returns (bool){

        //initially verify that accumulator exists. mapping gives O(1) access
        bytes32 accumulator_hash = BigNumber.hash(accumulator);
        require(BigNumber.cmp(accumulators[BigNumber.hash(accumulator)], accumulator, true)==0);

        //hash together inputs above in calculate
        BigNumber.instance memory c = calculate_challege_accumulator_pok(accumulator_pok, accumulator_commitment); //this hash should be of length k_prime bits TODO layout

        BigNumber.instance[3] memory st_prime;
        BigNumber.instance[4] memory t_prime;

        BigNumber.instance memory A;
        BigNumber.instance memory B;
        BigNumber.instance memory C;
        
        BigNumber.instance memory one = BigNumber.instance(hex"0000000000000000000000000000000000000000000000000000000000000001",false,1);
        
        A = BigNumber.prepare_modexp(accumulator_commitment, c, accumulator_pok_commitment_group.modulus);
        B = BigNumber.prepare_modexp(accumulator_pok_commitment_group.g, accumulator_pok.s_alpha, accumulator_pok_commitment_group.modulus);
        C = BigNumber.prepare_modexp(accumulator_pok_commitment_group.h, accumulator_pok.s_phi, accumulator_pok_commitment_group.modulus);
        st_prime[0] = BigNumber.prepare_modexp(BigNumber.bn_mul(BigNumber.bn_mul(A,B),C), 
                                               one, 
                                               accumulator_pok_commitment_group.modulus);                        

        A = BigNumber.prepare_modexp(accumulator_pok_commitment_group.g, c, accumulator_pok_commitment_group.modulus);
        B = BigNumber.prepare_modexp(BigNumber.bn_mul(accumulator_commitment, 
                                                      BigNumber.mod_inverse(accumulator_pok_commitment_group.g, 
                                                                            accumulator_pok_commitment_group.modulus, 
                                                                            inverse_results[0])), 
                                     accumulator_pok.s_gamma, 
                                     accumulator_pok_commitment_group.modulus);
        C = BigNumber.prepare_modexp(accumulator_pok_commitment_group.h, accumulator_pok.s_psi, accumulator_pok_commitment_group.modulus);
        st_prime[1] = BigNumber.prepare_modexp(BigNumber.bn_mul(BigNumber.bn_mul(A,B), C), 
                                               one, 
                                               accumulator_pok_commitment_group.modulus);                        

        A = BigNumber.prepare_modexp(accumulator_pok_commitment_group.g, c, accumulator_pok_commitment_group.modulus);
        B = BigNumber.prepare_modexp(BigNumber.bn_mul(accumulator_pok_commitment_group.g, accumulator_commitment),
                                     accumulator_pok.s_sigma, 
                                     accumulator_pok_commitment_group.modulus);
        C = BigNumber.prepare_modexp(accumulator_pok_commitment_group.h, accumulator_pok.s_xi, accumulator_pok_commitment_group.modulus);
        st_prime[2] = BigNumber.prepare_modexp(BigNumber.bn_mul(BigNumber.bn_mul(A,B),C), 
                                               one, 
                                               accumulator_pok_commitment_group.modulus); 


        A = BigNumber.prepare_modexp(accumulator_pok.C_r, c, modulus);
        B = BigNumber.prepare_modexp(accumulator_qrn_commitment_group.h, accumulator_pok.s_zeta, modulus);
        C = BigNumber.prepare_modexp(accumulator_qrn_commitment_group.g, accumulator_pok.s_epsilon, modulus);
        t_prime[0] = BigNumber.prepare_modexp(BigNumber.bn_mul(BigNumber.bn_mul(A,B),C), 
                                              one, 
                                              modulus); 

        A = BigNumber.prepare_modexp(accumulator_pok.C_e, c, modulus);
        B = BigNumber.prepare_modexp(accumulator_qrn_commitment_group.h, accumulator_pok.s_eta, modulus);
        C = BigNumber.prepare_modexp(accumulator_qrn_commitment_group.g, accumulator_pok.s_alpha, modulus);
        t_prime[1] = BigNumber.prepare_modexp(BigNumber.bn_mul(BigNumber.bn_mul(A,B),C), 
                                              one, 
                                              modulus); 

        A = BigNumber.prepare_modexp(accumulator, c, modulus);
        B = BigNumber.prepare_modexp(accumulator_pok.C_u, accumulator_pok.s_alpha, modulus);
        C = BigNumber.prepare_modexp(BigNumber.mod_inverse(accumulator_qrn_commitment_group.h, modulus, inverse_results[1]), 
                                     accumulator_pok.s_beta, 
                                     modulus);
        t_prime[2] = BigNumber.prepare_modexp(BigNumber.bn_mul(BigNumber.bn_mul(A,B),C), one, modulus);

        A = BigNumber.prepare_modexp(accumulator_pok.C_r, accumulator_pok.s_alpha, modulus);
        B = BigNumber.prepare_modexp(BigNumber.mod_inverse(accumulator_qrn_commitment_group.h,modulus,inverse_results[2]),
                                     accumulator_pok.s_delta, 
                                     modulus);
        C = BigNumber.prepare_modexp(BigNumber.mod_inverse(accumulator_qrn_commitment_group.g, modulus,inverse_results[3]),
                                     accumulator_pok.s_beta, 
                                     modulus);
        t_prime[3] = BigNumber.prepare_modexp(BigNumber.bn_mul(BigNumber.bn_mul(A,B),C), one, modulus); 

        require(BigNumber.hash(accumulator_pok.st[0]) == BigNumber.hash(st_prime[0]));
        require(BigNumber.hash(accumulator_pok.st[1]) == BigNumber.hash(st_prime[1]));
        require(BigNumber.hash(accumulator_pok.st[2]) == BigNumber.hash(st_prime[2]));
        require(BigNumber.hash(accumulator_pok.t[0]) == BigNumber.hash(t_prime[0]));
        require(BigNumber.hash(accumulator_pok.t[1]) == BigNumber.hash(t_prime[1]));
        require(BigNumber.hash(accumulator_pok.t[2]) == BigNumber.hash(t_prime[2]));
        require(BigNumber.hash(accumulator_pok.t[3]) == BigNumber.hash(t_prime[3]));

        //(maxCoinValue * BigNumber.instance(2).pow(k_prime + k_dprime + 1))) in params as upper_result_range_value
        //we check here that s_alpha lies between the positive and negative of this value.
        bool result_range = (BigNumber.cmp(accumulator_pok.s_alpha, result_range_value,true) == -1);
        result_range_value.neg = true;
        result_range = result_range && (BigNumber.cmp(accumulator_pok.s_alpha, result_range_value,true) == -1);
        result_range_value.neg = false; //reset negativity.

        require(result_range);

        return true;

    }
    //**************************** End accumulator verification functions ******************************** //


    
    //********************************* End 'Spend' verification *****************************************************
}