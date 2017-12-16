pragma solidity ^0.4.18;

import "contracts/BigNumberLib.sol";

//mock contract for accessing BigNumber library.
//js file in this directory instantiates and uses this to access the library

contract MockBigNumberLib {
  using BigNumberLib for *; 

  //******* bn_add setup **********//

  function mock_bn_add(bytes a_val, bool a_neg, uint a_msb,  bytes b_val, bool b_neg, uint b_msb) public returns (bytes memory n){
    BigNumberLib.BigNumber memory a = BigNumberLib.BigNumber(a_val, a_neg, a_msb);
    BigNumberLib.BigNumber memory b = BigNumberLib.BigNumber(b_val, b_neg, b_msb);
    BigNumberLib.BigNumber memory res = a.prepare_add(b);

    n = res.val;
  }
}