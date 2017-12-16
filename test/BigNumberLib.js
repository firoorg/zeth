// Specifically request an abstraction for BigNumber
var MockBigNumberLib = artifacts.require("MockBigNumberLib"); 

var bn = require('bn.js')
var crypto = require("crypto")  

contract('MockBigNumberLib', function(accounts) {
  for(var runs=100;runs>0;runs--){
    it("create random positive input for A and B, add to get C, assert ==  from contract", function() {
      return MockBigNumberLib.deployed().then(function(instance) {
          var a_size = (Math.floor(Math.random() * 10) + 1) * 32
          var a_val = crypto.randomBytes(a_size).toString('hex');

          var b_size = (Math.floor(Math.random() * 10) + 1) * 32
          var b_val = crypto.randomBytes(b_size).toString('hex'); //create random hex strings

          var a_bn = new bn(a_val, 16);
          var b_bn = new bn(b_val, 16);
          var res_bn = a_bn.add(b_bn);

          var a_val_enc = "0x" + a_val
          var b_val_enc = "0x" + b_val

          var a_neg_enc = false;
          var b_neg_enc = false; //generates a random boolean. 

          var a_msb_enc = a_bn.bitLength() - 1
          var b_msb_enc = b_bn.bitLength() - 1

          var expected_result = res_bn.toString('hex')

          expected_result = "0x" + ((expected_result.length  % 64 != 0) ? "0".repeat(64 - (expected_result.length % 64)) : "") + expected_result //add any leading zeroes (not present from BN)
           
           
        instance.mock_bn_add.call(a_val_enc, a_neg_enc, a_msb_enc, b_val_enc, b_neg_enc, b_msb_enc)
        .then(function(actual_result_a) {
          assert.equal(expected_result, actual_result_a, "returned value did not match. \na_val:\n" + a_val + "\nb_val:\n" + b_val + "\na_msb:\n" + a_msb_enc + "\nb_msb:\n" + b_msb_enc + "\n");
      })
      }); 
    });
  }
});