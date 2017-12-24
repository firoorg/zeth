pragma solidity ^0.4.18;

import "contracts/BigNumberLib.sol";

/* 
 * mock contract for accessing BigNumber library.
 * Library is mostly internal functions and tf. requires a contract to instantiate it to be used.
 * js file in ../test directory instantiates and uses this contract to access the library.
 */

contract MockBigNumberLib {
  using BigNumberLib for *; 

  //******* bn_add setup **********//

  //calls prepare_add, and by extension bn_add and bn_sub
  function mock_bn_add(bytes a_val, bool a_neg, uint a_msb,  bytes b_val, bool b_neg, uint b_msb) public returns (bytes, bool, uint){
    BigNumberLib.BigNumber memory a = BigNumberLib.BigNumber(a_val, a_neg, a_msb);
    BigNumberLib.BigNumber memory b = BigNumberLib.BigNumber(b_val, b_neg, b_msb);
    BigNumberLib.BigNumber memory res = a.prepare_add(b);

    return (res.val, res.neg, res.msb);
  }

  //calls prepare_sub, and by extension bn_add and bn_sub
  function mock_bn_sub(bytes a_val, bool a_neg, uint a_msb,  bytes b_val, bool b_neg, uint b_msb) public returns (bytes, bool, uint){
    BigNumberLib.BigNumber memory a = BigNumberLib.BigNumber(a_val, a_neg, a_msb);
    BigNumberLib.BigNumber memory b = BigNumberLib.BigNumber(b_val, b_neg, b_msb);
    BigNumberLib.BigNumber memory res = a.prepare_sub(b);

    return (res.val, res.neg, res.msb);
  }
  
  //calls bn_mul, and by extension add, sub and right_shift.
  function mock_bn_mul(bytes a_val, bool a_neg, uint a_msb,  bytes b_val, bool b_neg, uint b_msb) public returns(bytes, bool, uint){
    BigNumberLib.BigNumber memory a = BigNumberLib.BigNumber(a_val, a_neg, a_msb);
    BigNumberLib.BigNumber memory b = BigNumberLib.BigNumber(b_val, b_neg, b_msb);
    BigNumberLib.BigNumber memory res = a.bn_mul(b);

    return (res.val, res.neg, res.msb);
  }

  //stack too deep error when passing in 9 distinct variables as arguments where 3 bignums are expected.
  //instead we encode each msb/neg value in a bytes array and decode.
  function mock_modexp(bytes a_val, bytes a_extra, bytes b_val, bytes b_extra, bytes mod_val, bytes mod_extra) public returns(bytes, bool, uint){    
      BigNumberLib.BigNumber memory a;
      BigNumberLib.BigNumber memory b;
      BigNumberLib.BigNumber memory mod;
    
      uint neg;
      uint msb;
      
      assembly {
         neg := mload(add(a_extra,0x20))
         msb := mload(add(a_extra,0x40))
      }
      
      a.val = a_val;
      a.msb = msb;
      a.neg = (neg==1) ? true : false;
      
      assembly {
         neg := mload(add(b_extra,0x20))
         msb := mload(add(b_extra,0x40))
      }
      
      b.val = b_val;
      b.msb = msb;
      b.neg = (neg==1) ? true : false;
      
      assembly {
         neg := mload(add(mod_extra,0x20))
         msb := mload(add(mod_extra,0x40))
      }
      
      mod.val = mod_val;
      mod.msb = msb;
      mod.neg = (neg==1) ? true : false;
    
      BigNumberLib.BigNumber memory res = a.prepare_modexp(b,mod);
      
      return (res.val, res.neg, res.msb);
  }

  //stack too deep error when passing in 9 distinct variables as arguments where 3 bignums are expected.
  //instead we encode each msb/neg value in a bytes array and decode.
  function mock_modmul(bytes a_val, bytes a_extra, bytes b_val, bytes b_extra, bytes mod_val, bytes mod_extra) public returns(bytes, bool, uint){    
      BigNumberLib.BigNumber memory a;
      BigNumberLib.BigNumber memory b;
      BigNumberLib.BigNumber memory mod;
    
      uint neg;
      uint msb;
      
      assembly {
         neg := mload(add(a_extra,0x20))
         msb := mload(add(a_extra,0x40))
      }
      
      a.val = a_val;
      a.msb = msb;
      a.neg = (neg==1) ? true : false;
      
      assembly {
         neg := mload(add(b_extra,0x20))
         msb := mload(add(b_extra,0x40))
      }
      
      b.val = b_val;
      b.msb = msb;
      b.neg = (neg==1) ? true : false;
      
      assembly {
         neg := mload(add(mod_extra,0x20))
         msb := mload(add(mod_extra,0x40))
      }
      
      mod.val = mod_val;
      mod.msb = msb;
      mod.neg = (neg==1) ? true : false;
    
      BigNumberLib.BigNumber memory res = a.modmul(b,mod);
      
      return (res.val, res.neg, res.msb);
  }
}