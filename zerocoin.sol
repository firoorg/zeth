contract zerocoin {
    /*
     * This smart contract is an implementation of the Zerocoin coin-mixing protocol.
     * paper found here: http://zerocoin.org/media/pdf/ZerocoinOakland.pdf
     * original authors: Ian Miers, Christina Garman, Matthew Green, Aviel D. Rubin
     * implemented by: Tadhg Riordan - github.com/riordant
     */

    //****** Begin Default Parameters ******
    bytes min_coin_value;
    bytes max_coin_value;
    int zkp_iterations;
    //****** End Default Parameters ******  

    //****** Begin Basic Values ******
    bytes[] spent_serial_numbers; //maybe a map?..

    bytes serial_number;

    struct accumulator {
       bytes value;
       bytes params; //FIXME
    }
    //****** End Basic Values ******

    //****** Begin Commitments ******
    bytes serial_number_commitment;

    bytes accumulator_commitment;

    bytes coin_commitment;
    //****** End Commitments ******


    //****** Begin Proof Structures ******
    // ZK proof that the two commitments contain the same public coin.
    struct commitment_pok {

    }

    // Proves that the committed public coin is in the Accumulator (PoK of "witness")
    struct accumulator_pok {
        //VALUES
    }

    // Proves that the coin is correct w.r.t. serial number and hidden coin secret
    struct serial_number_sok {
        //VALUES
    }
    //****** End Proof Structures ******

    



    //****** Begin Misc. Functions ******
    function miller_rabin_primality_test(bytes serial_number_commitment) returns (bool){

    }

    function add_to_accumulator(bytes serial_number) returns (bool){

    }

    //Bignum from bytes and subsequent comparison operations here too
    //****** End Misc. Functions ******

    
    //****** Begin 'Mint' validation ******
    function validate_coin_mint(bytes serial_number_commitment) returns (bool success){

        bool success = (this.min_coin_value < serial_number_commitment) && 
                       (serial_number_commitment < this.max_coin_value) && 
                        miller_rabin_primality_test(serial_number_commitment);

        if(success){
            //- add commitment to accumulator
            //- add eth denomination to value pool
        }
    }
    //****** End 'Mint' validation ******

    //****** Begin 'Spend' validation ******
    function verify_coin_spend(bytes commitment_pok, 
                               bytes accumulator_pok, 
                               bytes serial_number_sok, 
                               bytes coin_serial_number,
                               bytes serial_number_commitment,
                               bytes accumulator_commitment,
                               bytes coin_commitment) returns (bool result) { 
        //store byte inputs as objects

        bool success  =    verify_commitment_pok(serial_number_commitment, accumulator_commitment)
                        && verify_accumulator_pok(this.accumulator, accumulator_commitment)
                        && verify_serial_number_sok(coin_serial_number, serial_number_commitment);
    }

    function verify_commitment_pok() returns (bool result){

    }

    function verify_serial_number_sok() returns (bool result){
        
    }

    function verify_accumulator_pok() returns (bool result){
        
    }
    //****** End 'Spend' validation ******
}