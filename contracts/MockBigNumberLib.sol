pragma solidity ^0.4.18;

import "contracts/BigNumberLib.sol";

//mock contract for accessing BigNumber library.
//js file in this directory instantiates and uses this to access the library

contract MockBigNumberLib {
  using BigNumberLib for *; 

  //******* bn_add setup **********//

  // function mock_get_uint_size() public returns (uint){
  //   bytes val_bytes = "de305f0b83cc448e97bb85777a7be18e699de1a63ae8d0d938a8aa04aeaf3882"
  //   uint val;
  //   assembly{val := add(val_bytes,0x20)}

  //   return BigNumberLib.get_uint_size(val);
  // }

  function mock_bn_add(bytes a_val, bool a_neg, uint a_msb,  bytes b_val, bool b_neg, uint b_msb) public returns (bytes, bool, uint){
    BigNumberLib.BigNumber memory a = BigNumberLib.BigNumber(a_val, a_neg, a_msb);
    BigNumberLib.BigNumber memory b = BigNumberLib.BigNumber(b_val, b_neg, b_msb);
    BigNumberLib.BigNumber memory res = a.prepare_add(b);

    return (res.val, res.neg, res.msb);
  }
}