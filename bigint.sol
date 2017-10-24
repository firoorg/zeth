pragma solidity ^0.4.8;

contract bigint_zerocoin {
    /* 
     *  Bigint library for use with the Zerocoin protocol implementation;
     *  It is however designed for general use.
     *  @author Tadhg Riordan (github.com/riordant)
     */

    //0-3 index: LSB-MSB bits.

    uint constant VALUE = 0;
    uint constant SIGN  = 1;

    uint constant LEFT = 0;
    uint constant RIGHT = 1;
    
    int constant LT = -1;
    int constant EQ = 0;
    int constant GT = 1; //for comparison

    uint uint_size = 256;
    uint half =     2**(uint_size/2);      // Half bitwidth
    uint low  =     half - 1;              // Low mask
    uint high =     low << (uint_size/2);  // High mask
    uint max  =     low | high;            // Max uint value

    //values for bitsize function - log2 of uint
    uint[8] log2_a = [2, 12, 240, 65280, 4294901760, 18446744069414584320, 340282366920938463444927863358058659840, 115792089237316195423570985008687907852929702298719625575994209400481361428480];
    uint[8] log2_b = [1, 2, 4, 8, 16, 32, 64, 128];

    //bigints are of size 256, 512, 1024 or 2048; so size passed as 1,2,4 or 8 respectively.
    struct bigint { 
        uint size;
        uint[] value;
        bytes _bytes; //byte encoding of value (for precompiled contract calls)
        bool negative;
    }
    
    //usually we can call the struct constructor directly. this is useful where we have single uint values
    function create_bigint(uint _size, uint _value, bool _negative) public pure returns (bigint new_bigint){
        new_bigint.size = _size;
        new_bigint.value = new uint[](_size);
        new_bigint.value[0] = _value;
        for(uint i=1;i<_size;i++) {
            new_bigint.value[i] = 0;
        }
        new_bigint._bytes = new bytes(_size * 8); //FIXME add method to cast uint to byte array
        new_bigint.negative = _negative;
        
        return new_bigint;
    }
    

    function add(bigint a, bigint b) private pure returns(bigint sum, uint carry){
        uint max_size = a.size > b.size ? a.size : b.size;
        uint[] memory sum_value = new uint[](max_size);
        //sum = bigint(max_size, empty, _empty, false); //set output size to max_size size of inputs.

        // Start from the least significant bits
        for (uint i = 0; i < sum.size; ++i){
            sum_value[i] = a.value[i] + b.value[i] + carry;
            if (a.value[i] > max_size - b.value[i] - carry)  // Check for overflow
                carry = 1;
            else if (a.value[i] == max_size && (carry > 0 || b.value[i] > 0)) // Special case
                carry = 1;
            else
                carry = 0;
        }

        sum = bigint(max_size, sum_value, bigint_to_bytes(sum_value), false); //set output size to max_size size of inputs.

        return (sum, carry); //carry is 1 if overflow
    }
    
    function sub(bigint a, bigint b) private returns(bigint diff, uint borrow){
        uint max_size = a.size > b.size ? a.size : b.size;
        uint[] memory diff_value = new uint[](max_size);

        // Start from the least significant bits
        for (uint i = 0; i < a.size; ++i){
            diff_value[i] = a.value[i] - b.value[i] - borrow;
            if (a.value[i] < b.value[i] + borrow || (b.value[i] == max && borrow == 1))   // Check for underflow
                borrow = 1;
            else
                borrow = 0;
        }

        diff = bigint(max_size, diff_value, bigint_to_bytes(diff_value), false); //set output size to max_size size of inputs.

        return (diff, borrow); //carry is 1 if underflow
    }

    function mul(bigint a, bigint b) private returns(bigint res){
        // a * b = ((a + b)**2 - (a - b)**2) / 4
        // we use modexp contract for exponentiations, passing modulus as 1|0*n, where n = 2 * bit length of (a+b)
        
        bigint memory add_and_modexp;
        bigint memory sub_and_modexp;
        bigint memory modulus;
        bigint memory two = create_bigint(1,2,false);
        
        uint _sign;
        uint mod_index;

        (add_and_modexp, _sign) = add(a,b);
        require(_sign==0); //if overflow
        modulus = create_bigint((add_and_modexp.size*2), 0, false);
        mod_index = get_bit_size(add_and_modexp)*2;
        modulus.value[mod_index/max] = uint(1) << (mod_index%max); //set this index to be 1.
        add_and_modexp = _modexp(add_and_modexp,two,modulus);

        (sub_and_modexp, _sign) = sub(a,b);
        require(_sign==0); //if underflow
        modulus = create_bigint((sub_and_modexp.size*2), 0, false);
        mod_index = get_bit_size(sub_and_modexp)*2;
        modulus.value[mod_index/max] = uint(1) << (mod_index%max); //set this index to be 1.
        add_and_modexp = _modexp(sub_and_modexp,two,modulus);
        
        (res, _sign) = sub(add_and_modexp,sub_and_modexp);
        res = right_shift(res, 2); // LHS - RHS / 4

        return res;

     }

     function modmul(bigint a, bigint b, bigint modulus) private returns(bigint n){
        //calls to modexp with certain values
        uint _sign;
        bigint memory add_and_modexp;
        bigint memory sub_and_modexp;
        bigint memory two = create_bigint(1,2,false);
        
        (add_and_modexp, _sign) = add(a,b);
        require(_sign==0);
        add_and_modexp = _modexp(add_and_modexp,two,modulus);

        (sub_and_modexp, _sign) = sub(a,b); //no need to handle sign as squared negative==squared positive value.
        sub_and_modexp = _modexp(sub_and_modexp,two,modulus);

        (n, _sign) = sub(add_and_modexp,sub_and_modexp);
        if(_sign==1){ //underflow. add modulus and n (same result achieved with modulus-(n without sign))
            (n, _sign) = sub(modulus,n);
        }

        //Now divide twice by 2 % m.
        for(int i=0;i<=1;i++){
            (n, _sign) = add(n, modulus);
            if(n.value[0]%2==0 && cmp(n,modulus) == LT){ //n is even and < modulus
                n = right_shift(n,1);
            }
            else { //n is odd. add modulus
                (n, _sign) = add(n,modulus);
                 n = right_shift(n,1);
            }
        }

        return n;
     }

     function _modexp(bigint base, bigint exponent, bigint modulus) private returns(bigint result) {
        if(exponent.negative==true){
            // g^-x = (g^-1)^x
            base = inverse(base, modulus);
            exponent.negative = false; //make e positive
        }
        bytes memory _result = modexp(base._bytes,exponent._bytes,modulus._bytes); //not recursive - precompiled contract call
        result = bigint(modulus.size, bytes_to_bigint(_result), _result, false);
        return result;
     }

     function inverse(bigint base, bigint modulus) private returns(bigint new_bigint){
        //TODO
        //Turn this into oracle call
        //verify with modmul - verify (base * result) % m == 1
        return new_bigint;
     }
    
    
    function right_shift(bigint dividend, uint value) private returns(bigint r){
        r = dividend;
        uint shift_value = uint_size-value;
        
        for(uint i = dividend.size-1; i>=0;i--){
            r.value[i] = (dividend.value[i] >> value) | (dividend.value[i==(dividend.size-1) ? 0 : i+1] << shift_value);
        }
    }
    
    /*
     * Comparison function.
     * handles negativity and different sizes of inputs.
     */
    function cmp(bigint a, bigint b) private returns (int) {   
        if(is_zero(a) && is_zero(b)) return 0;
        if(a.negative == true && b.negative == false) return -1;
        if(a.negative == false && b.negative == true) return 1;
        //at this point both signs are the same; ie. either negative or positive, 
        //and so return opposite results depending on sign.
        
        //to handle different sized inputs, get largest and see if it has a value
        //at any of the uints greater than the size of the smallest.
        uint i;
        if(a.size > b.size){
            for(i=a.size-1; i>(a.size-1-(a.size-b.size));i--){
                if(a.value[i]>0) return ((a.negative==false) ? GT : LT);
            }
        }
        else if(b.size > a.size){
            for(i=b.size-1; i>(b.size-1-(b.size-a.size));i--){
                if(b.value[i]>0) return ((b.negative==false) ? GT : LT);
            }
        }
        
        //main loop. only compares up to size of minimum bigint
        for(;i>=0;i--){
            if(a.value[i] > b.value[i]) return (a.negative==false ? GT : LT);
            else if(b.value[i] > a.value[i]) return (a.negative==false ? GT : LT);
        }
        //returns equality if no difference found.
        return EQ;
    }
    
    function is_zero(bigint bi) private pure returns (bool) {
        for(uint i=0;i<bi.size;i++){
            if(bi.value[i] != 0){
                return false;
            }
        }
        return true;
    }

    function get_bit_size(bigint n) private returns (uint r){
        //gets bit size of bigint.
        //start from most significant uint and loop until > 0.
        //could also potentially be oraclized as it's verifiable in a single operation: true iff ((n >> result) == 1)
        for(uint i=n.size;i>=0;i--){
            if(n.value[i] > 0){
                //uses log2 function with lookup to find MSB (Bit Twiddling Hacks - Sean Eron Anderson)
                r = 0;
                for (uint j = 8; j >= 0; j--) {// unrolling
                    if ((n.value[i] & log2_a[j]) == 1){
                        n.value[i] >>= log2_b[j];
                        r  |= log2_b[j];
                    } 
                }

                return r + (256 * i); //include bits from remaining uints
            }
        }
        return 0; //if empty bigint
    }
    
    function bigint_to_bytes(uint[] n) public pure returns (bytes b) {
        //FIXME assembly implementation
    }

    function bytes_to_bigint(bytes n) public pure returns (uint[] b) {
        //FIXME assembly implementation
    } 
}