pragma solidity ^0.4.18;

library BigNumberLib {
    /*
     values in memory on the EVM are in 256 bit words - BigNumbers are considered to be consecutive words in big-endian order (top-bottom: word 0 - word n).
     the BigNumber value is in the 'bytes' data structure. by default, this data structure is 'tightly packed', ie. it has no leading zeroes, and it has a 'length' word indicating the number of bytes in the structure.
     we consider each BigNumber value to NOT be tightly packed in the bytes data structure, and where the length byte is equal the number of words * 32. 
     for explanation's sake, imagine that solidity had a 32 bit word width, and the following value (in bytes):

     ae1b6b9f1be57476a6948f77effc

     this is 14 bytes. by default, solidity's 'bytes' would prepend this structure with the value '0x0E' (14 in hex), and it's representation in memory would be like so:
     0000000e - length
     ae1b6b9f - word 0
     1be57476 - word 1
     a6948f77 - word 2
     effc0000 - word 3

     in our scheme, the values are literally shifted to the right by the amount of zero bytes in the final word, and the length is changed to include these bytes.
     our scheme:

     00000010 - length (16 - num words * 4, 4 bytes per word)
     0000ae1b - word 0
     6b9f1be5 - word 1
     7476a694 - word 2
     8f77effc - word 3

     our scheme is the same as above with 32 byte words. This is actually how the uint array represents values (bar the length being the number of words as opposed to number of bytes), but the rationale here is that as we are manipulating values in memory anyway, it's unnecessary to use uint[]. 
     (also, the modexp function expects as parameters, AND returns, bytes, so it saves the conversion either side).
     why the right shift? this is a kind of 'normalisation'. values will 'line up' with their number representation in memory and so it saves us the hassle of trying to manage the offset when performing operations like add and subtract.

     the sign of the value is controlled artificially, as is the case with other big integer libraries. at present the msb is tracked throughout the lifespan of the BigNumber instance.

     when the caller creates a BigNumber in the zerocoin contract, they also indicate the most significant bit of the value. this is verified in the contract by right shifting the most significant word by the passed value mod 256, and verifying the result is equal to 1. 
     the value itself, therefore, is the overall msb of the BigNumber value. 
    */

    struct BigNumber { 
        bytes val;
        bool neg;
        uint msb;
    }
    
    //in order to do correct addition or subtraction we have to handle the sign.
    //the following two functions takes two BigNumbers, discovers the sign of the result based on the values, and calls the correct operation.
    function prepare_add(BigNumber a, BigNumber b) internal returns(BigNumber r) {
        BigNumber memory zero = BigNumber(hex"0000000000000000000000000000000000000000000000000000000000000000",false,0); 
        bytes memory val;
        uint msb;
        int compare = cmp(a,b);

        if(a.neg || b.neg){
            if(a.neg && b.neg){
                if(compare>=0) (val, msb) = bn_add(a.val,b.val,a.msb);
                else (val, msb) = bn_add(b.val,a.val,b.msb);
                r.neg = true;
            }
            else {
                if(compare==1){
                    (val, msb) = bn_sub(a.val,b.val);
                    r.neg = a.neg;
                }
                else if(compare==-1){
                    (val, msb) = bn_sub(b.val,a.val);
                    r.neg = !a.neg;
                }
                else return zero;//one pos and one neg, and same value.
            }
        }
        else{
            if(compare>=0){ //a>=b
                (val, msb) = bn_add(a.val,b.val,a.msb);
            }
            else {
                (val, msb) = bn_add(b.val,a.val,b.msb);
            }
            r.neg = false;
        }

        r.val = val;
        r.msb = msb;
    }

    //add function. takes two BigNumber values, the msb of the max value, and whether or not the result will be negative.
    //the values may be of different sizes, in any order of size, and of different signs: this is handled in the prepare_add function.
    //the function calculates the new msb (basically if msbs are the same, max_msb++) and returns a new BigNumber.
    function bn_add(bytes a, bytes b, uint a_msb) private returns (bytes memory, uint) {
        bytes memory c;
        assembly {

            let c_start := msize() // Get the highest available block of memory
            
            let max := sub(0,1)

            let carry := 0

            let max_ptr := add(a, mload(a))
            let min_ptr := add(b, mload(b)) //go to end of arrays
            let c_ptr := add(add(c_start,0x20), mload(a))
            
            for { let i := mload(a) } eq(eq(i,0),0) { i := sub(i, 0x20) } {
                let max_val := mload(max_ptr)
                switch gt(i,sub(mload(a),mload(b))) //remainder after min words complete.
                    case 1{ 

                        let min_val := mload(min_ptr)
        
                        mstore(c_ptr, add(add(max_val,min_val),carry))
                    
                        switch gt(max_val, sub(max,sub(min_val,carry)))
                            case 1  { carry := 1 }
                            default {
                                switch and(eq(max_val,max),or(gt(carry,0), gt(min_val,0)))
                                case 1 { carry := 1 }
                                default{ carry := 0 }
                            }
                            
                        min_ptr := sub(min_ptr,0x20)
                    }
                    default{  //after smallest length
                        mstore(c_ptr, add(max_val,carry))
                        
                        switch and( eq(max,max_val), eq(carry,1) )
                            case 1  { carry := 1 }
                            default { carry := 0 }
                    }
                c_ptr := sub(c_ptr,0x20)  
                max_ptr := sub(max_ptr,0x20)
            }

            switch eq(carry,0) 
                case 1{ c_start := add(c_start,0x20) } //if carry is 0, increment c_start.
                default { mstore(c_ptr, 1) } //else if carry is 1, store 1 in final position.

            c := c_start
            mstore(c,add(mload(a),mul(0x20,carry)))

            let c_bytes := add(mload(a),add(0x20,mul(0x20,carry))) //handles size word, value word(s) and final word for uint[].
            
            mstore(0x40, add(c,c_bytes)) // Update the msize offset to be our memory reference plus the amount of bytes we're using
        }
        
        //we now calc the new msb.
        //with addition, if we assume that a is at least equal to b, the the resulting msb will be a_msb or ++a_msb.
        //we check for that here
        uint res; 
        assembly {res := mload(add(c,0x20))} //get msword of result
        if(res>>(a_msb % 256)==1 || res==1) ++a_msb; //if msword >> a_msb (mod 256 to get word shift),or overflow occured, new msb is ++a_msb. 
        
        return (c, a_msb);
    }

    function prepare_sub(BigNumber a, BigNumber b) internal returns(BigNumber r) {
        BigNumber memory zero = BigNumber(hex"0000000000000000000000000000000000000000000000000000000000000000",false,0); 
        bytes memory val;
        int compare;
        uint msb;
        compare = cmp(a,b);
        if(a.neg || b.neg) {
            if(a.neg && b.neg){           
                if(compare == 1) { 
                    (val,msb) = bn_sub(a.val,b.val); 
                    r.neg = true;
                }
                else if(compare == -1) { 

                    (val,msb) = bn_sub(b.val,a.val); 
                    r.neg = false;
                }
                else return zero;
            }
            else {
                if(compare >= 0) (val,msb) = bn_add(a.val,b.val,a.msb);
                else (val,msb) = bn_add(b.val,a.val,b.msb);
                
                r.neg = (a.neg) ? true : false;
            }
        }
        else {
            if(compare == 1) {
                (val,msb) = bn_sub(a.val,b.val);
                r.neg = false;
             }
            else if(compare == -1) { 
                (val,msb) = bn_sub(b.val,a.val);
                r.neg = true;
            }
            else return zero; 
        }

        r.val = val;
        r.msb = msb;
    }

 

   //sub function. similar to add above, except we pass the msb of both values (this is needed for msb calculation at the end)
   function bn_sub(bytes a, bytes b) private returns (bytes memory, uint) {
        //assuming here that values arrive from prepare_sub as a=max and b=min (or both the same size)
        bytes memory c;
        uint carry = 0;
        assembly {
                
            let c_start := msize() // Get the highest available block of memory
        
            let uint_max := sub(0,1) //max size of uint (underflows: 0-1 = 2^256 - 1)
            let a_len := mload(a)
            let b_len := mload(b)
            
            let len_diff := sub(a_len,b_len)
            
            let a_ptr := add(a, a_len)
            let b_ptr := add(b, b_len) //go to end of arrays
            let c_ptr := add(c_start, a_len)
            
            for { let i := a_len } eq(eq(i,0),0) { i := sub(i, 0x20) } {
                let a_val := mload(a_ptr)
                switch gt(i,len_diff) //remainder after min words complete.
                    case 1{ 
                        let b_val := mload(b_ptr)
        
                        mstore(c_ptr, sub(sub(a_val,b_val),carry))
                    
                        switch or(lt(a_val, add(b_val,carry)), and(eq(b_val,uint_max), eq(carry,1)))
                            case 1  { carry := 1 }
                            default { carry := 0 }
                            
                        b_ptr := sub(b_ptr,0x20)
                    }
                    default{  //up to smallest length

                        mstore(c_ptr, sub(a_val,carry))
                    
                        switch and( eq(a_val,0), eq(carry,1) )
                            case 1  { carry := 1 }
                            default { carry := 0 }

                    }
                c_ptr := sub(c_ptr,0x20)  
                a_ptr := sub(a_ptr,0x20)
            }      

            //the following code removes any leading words containing all zeroes in the result.
            c_ptr := add(c_ptr,0x20)
            for { } eq ( eq(mload(c_ptr), 0), 1) { c_ptr := add(c_ptr,0x20) } {
               c_start := add(c_start, 0x20)        //push up the start pointer for the result..
               a_len := sub(a_len,0x20) //and subtract a word (32 bytes) from the result length.
            } 

            c := c_start 
            
            mstore(c,a_len)
            
            mstore(0x40, add(c,add(0x20, a_len))) // Update the msize offset to be our memory reference plus the amount of bytes we're using
        }

        uint uint_size;
        assembly{ uint_size := mload(add(c,0x20))} 
        uint new_msb = get_uint_size(uint_size) + ((c.length-32)*8);
        
        return (c, new_msb);
    }

    function bn_mul(BigNumber a, BigNumber b) internal returns(BigNumber res){
        // (a * b) = (((a + b)**2 - (a - b)**2) / 4
        // we use modexp contract for squaring of (a # b), passing modulus as 1|0*n, where n = 2 * bit length of (a # b) (and # = +/- depending on call).
        // therefore the modulus is the minimum value we can pass that will allow us to do the squaring.
                
        bytes memory two_val = hex"0000000000000000000000000000000000000000000000000000000000000002";
        BigNumber memory two = BigNumber(two_val,false,2);        
        
        uint mod_index = 0;
        uint val;
        bytes memory _modulus;
        
        BigNumber memory add_and_modexp = prepare_add(a,b);
        uint add_and_modexp_msb = add_and_modexp.msb;
        assembly { mod_index := mul(add_and_modexp_msb,2) }
        val = uint(1) << ((mod_index % 256));
        
        _modulus = hex"00";
        assembly {
            mstore(_modulus, mul(add(div(mod_index,256),1),0x20))
            mstore(add(_modulus,0x20), val)
            mstore(0x40, add(_modulus, add(mload(_modulus),0x20)))//update freemem pointer to be modulus index + length
        }

        BigNumber memory modulus;
        modulus.val = _modulus;
        modulus.neg = false;
        modulus.msb = mod_index;
        add_and_modexp = prepare_modexp(add_and_modexp,two,modulus);
        
        BigNumber memory sub_and_modexp = prepare_sub(a,b);
        uint sub_and_modexp_msb = sub_and_modexp.msb;
        assembly {mod_index := mul(sub_and_modexp_msb,2)}
        val = uint(1) << ((mod_index % 256));
        
        _modulus = hex"00";
        assembly {
            mstore(_modulus, mul(add(div(mod_index,256),1),0x20))
            mstore(add(_modulus,0x20), val)
            mstore(0x40, add(_modulus, add(mload(_modulus),0x20)))//update freemem pointer to be modulus index + length
        }
        modulus.val = _modulus;
        modulus.neg = false;
        modulus.msb = mod_index;
        sub_and_modexp = prepare_modexp(sub_and_modexp,two,modulus);
        
        res = prepare_sub(add_and_modexp,sub_and_modexp);
        res = right_shift(res, 2); // LHS - RHS / 4
        
     }
    
    // function bn_div(BigNumber a, BigNumber b) internal returns(BigNumber res){
    //     //TODO turn into oracle call. we will setup api with oraclize. (this is not actually necessary for zerocoin but including it anyway for the sake of the library).

    // }
    
    function prepare_modexp(BigNumber base, BigNumber exponent, BigNumber modulus) internal returns(BigNumber result) {
        if(exponent.neg==true){ 
            // base^-exp = (base^-1)^exp
            //base = inverse(base, modulus); TODO implement inverse function
            exponent.neg = false; //make e positive
        }

        bytes memory _result = modexp(base.val,exponent.val,modulus.val);
        //get msb of result (TODO: optimise. we know msb is in the same byte as the modulus msb byte)
        uint msb;
        assembly { msb := mload(add(_result,0x20))}
        msb = get_uint_size(msb) + (((_result.length/32)-1)*256); 
        result.val = _result;
        result.neg = (base.neg==false || base.neg && is_even(exponent)==0) ? false : true;
        result.msb = msb;
        return result;
     }
    
    // Wrapper for built-in BigNumber_modexp (contract 0x5) as described here. https://github.com/ethereum/EIPs/pull/198
    //this function takes in bytes values and returns a tightly packed byte array. we then convert this into our scheme
    function modexp(bytes memory _base, bytes memory _exp, bytes memory _mod) private view returns(bytes memory ret) {
        

        assembly {
            
            let bl := mload(_base)
            let el := mload(_exp)
            let ml := mload(_mod)
            
            // Free memory pointer is always stored at 0x40
            let freemem := mload(0x40)
            
            // arg[0] = base.length @ +0
            mstore(freemem, bl)
            
            // arg[1] = exp.length @ +32
            mstore(add(freemem,32), el)
            
            // arg[2] = mod.length @ +64
            mstore(add(freemem,64), ml)
            
            // arg[3] = base.bits @ + 96
            // Use identity built-in (contract 0x4) as a cheap memcpy
            let success := call(450, 0x4, 0, add(_base,32), bl, add(freemem,96), bl)
            
            // arg[4] = exp.bits @ +96+base.length
            let size := add(96, bl)
            success := call(450, 0x4, 0, add(_exp,32), el, add(freemem,size), el)
            
            // arg[5] = mod.bits @ +96+base.length+exp.length
            size := add(size,el)
            success := call(450, 0x4, 0, add(_mod,32), ml, add(freemem,size), ml)
            
            switch success case 0 { invalid() } //fail where we haven't enough gas to make the call

            // Total size of input = 96+base.length+exp.length+mod.length
            size := add(size,ml)
            // Invoke contract 0x5, put return value right after mod.length, @ +96
            success := call(sub(gas, 1350), 0x5, 0, freemem, size, add(96,freemem), ml)

            let length := ml
            let length_ptr := add(96,freemem)

            ///the following code removes any leading words containing all zeroes in the result.
            //start_ptr := add(start_ptr,0x20)
            for { } eq ( eq(mload(length_ptr), 0), 1) { } {
               length_ptr := add(length_ptr, 0x20)        //push up the start pointer for the result..
               length := sub(length,0x20) //and subtract a word (32 bytes) from the result length.
            } 

            ret := sub(length_ptr,0x20)
            mstore(ret, length)
            
            // point to the location of the return value (length, bits)
            //assuming mod length is multiple of 32, return value is already in the right format.
            //function visibility is changed to internal to reflect this.
            //ret := add(64,freemem) 
            
            mstore(0x40, add(add(96, freemem),ml)) //deallocate freemem pointer
        }
        
    }
    
    function modmul(BigNumber a, BigNumber b, BigNumber modulus) internal returns(BigNumber res){
        BigNumber memory one = BigNumber(hex"0000000000000000000000000000000000000000000000000000000000000001",false,1);
        res = prepare_modexp(bn_mul(a,b),one,modulus);       
    }

    function inverse(BigNumber base, BigNumber modulus) internal returns(BigNumber new_BigNumber){
        //TODO Turn this into call to Oraclize
        //verify with modmul - verify (base * result) % m == 1
        return new_BigNumber;
     }
     
    
    function is_even(BigNumber _in) internal returns(uint ret){
        assembly{
            let in_ptr := add(mload(_in), mload(mload(_in))) //go to last value
            ret := mod(mload(in_ptr),2)
        }
    }

    function cmp(BigNumber a, BigNumber b) internal returns(int){
        if(a.msb>b.msb) return 1;
        if(b.msb>a.msb) return -1;

        uint a_ptr;
        uint b_ptr;
        uint a_word;
        uint b_word;

        uint len = a.val.length; //msb is same so no need to check length.

        assembly{
            a_ptr := add(mload(a),0x20) 
            b_ptr := add(mload(b),0x20) // 'a' and 'b' store the memory address of 'val' of the struct.
        }

        for(uint i=0; i<len;i+=32){
            assembly{
                a_word := mload(add(a_ptr,i))
                b_word := mload(add(b_ptr,i))
            }

            if(a_word>b_word) return 1;
            if(b_word>a_word) return -1;

        }

        return 0; //same value.
    }
    

    //takes in a bytes value and returns the value shifted to the right by 'value' bits.
    function right_shift(BigNumber dividend, uint value) internal returns(BigNumber){
        bytes memory val;
        uint word_shifted;
        uint mask_shift = 256-value;
        uint mask;
        uint val_ptr;
        uint max;
        uint length = dividend.val.length;

        assembly {
            max := sub(0,32)
            val_ptr := add(mload(dividend), length) 
            
        }

        for(uint i= length-32; i<max;i-=32){
            assembly{
                word_shifted := mload(val_ptr)
                switch eq(i,0)
                case 1 { mask := 0 }
                default { mask := mload(sub(val_ptr,0x20)) } //handles msword: no mask needed.
            }
            word_shifted >>= value; //right shift current by value
            mask <<= mask_shift; //left shift next MSWord by mask_shift
            assembly{ mstore(val_ptr, or(word_shifted,mask)) } //store OR'd mask and shifted value in-place
            val_ptr-=32;
        }

        assembly{
            //the following code removes any leading words in the result containing all zeroes.
            val_ptr := add(val_ptr,0x20)
            for { } eq ( eq(mload(val_ptr), 0), 1) { } {
               val_ptr := add(val_ptr, 0x20) //push up the start pointer for the result..
               length  := sub(  length,0x20) //and subtract a word (32 bytes) from the result length.
            }
            
            val := sub(val_ptr,0x20)
            mstore(val, length) 
        }
        
        dividend.val = val;
        dividend.msb = dividend.msb-value;
        return dividend;
    }

//log2Nfor uint - ie. calculates most significant bit of 256 bit value. credit: Tjaden Hess @ ethereum.stackexchange
  function get_uint_size(uint x) internal returns (uint y){
       uint arg = x;
       assembly {
            x := sub(x,1)
            x := or(x, div(x, 0x02))
            x := or(x, div(x, 0x04))
            x := or(x, div(x, 0x10))
            x := or(x, div(x, 0x100))
            x := or(x, div(x, 0x10000))
            x := or(x, div(x, 0x100000000))
            x := or(x, div(x, 0x10000000000000000))
            x := or(x, div(x, 0x100000000000000000000000000000000))
            x := add(x, 1)
            let m := mload(0x40)
            mstore(m,           0xf8f9cbfae6cc78fbefe7cdc3a1793dfcf4f0e8bbd8cec470b6a28a7a5a3e1efd)
            mstore(add(m,0x20), 0xf5ecf1b3e9debc68e1d9cfabc5997135bfb7a7a3938b7b606b5b4b3f2f1f0ffe)
            mstore(add(m,0x40), 0xf6e4ed9ff2d6b458eadcdf97bd91692de2d4da8fd2d0ac50c6ae9a8272523616)
            mstore(add(m,0x60), 0xc8c0b887b0a8a4489c948c7f847c6125746c645c544c444038302820181008ff)
            mstore(add(m,0x80), 0xf7cae577eec2a03cf3bad76fb589591debb2dd67e0aa9834bea6925f6a4a2e0e)
            mstore(add(m,0xa0), 0xe39ed557db96902cd38ed14fad815115c786af479b7e83247363534337271707)
            mstore(add(m,0xc0), 0xc976c13bb96e881cb166a933a55e490d9d56952b8d4e801485467d2362422606)
            mstore(add(m,0xe0), 0x753a6d1b65325d0c552a4d1345224105391a310b29122104190a110309020100)
            mstore(0x40, add(m, 0x100))
            let magic := 0x818283848586878898a8b8c8d8e8f929395969799a9b9d9e9faaeb6bedeeff
            let shift := 0x100000000000000000000000000000000000000000000000000000000000000
            let a := div(mul(x, magic), shift)
            y := div(mload(add(m,sub(255,a))), shift)
            y := add(y, mul(256, gt(arg, 0x8000000000000000000000000000000000000000000000000000000000000000)))
        }  
        if(arg & arg-1 == 0 && x!=0) ++y; //where x is a power of two, result needs to be incremented. we use the power of two trick here
    }
}