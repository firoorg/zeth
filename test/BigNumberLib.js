// Specifically request an abstraction for BigNumber
var MockBigNumberLib = artifacts.require("MockBigNumberLib"); 

var bn = require('bn.js')
var crypto = require("crypto")  

contract('MockBigNumberLib', function(accounts) {
  var init_runs = 100;
  for(var run=init_runs;run>0;run--){
    it("Addition function: Run " + (init_runs-run) + " - create random inputs for A and B, add to get C, assert equality from contract", async function() {
        instance = await MockBigNumberLib.new()
        var a_size = (Math.floor(Math.random() * 10) + 1) * 32
        var a_val = crypto.randomBytes(a_size).toString('hex');
        var b_size = (Math.floor(Math.random() * 10) + 1) * 32
        var b_val = crypto.randomBytes(b_size).toString('hex'); //create random hex strings

        var a_neg = Math.random() >= 0.5;
        var b_neg = Math.random() >= 0.5; //generates a random boolean.  

        var a_bn = new bn((a_neg ? "-" : "") + a_val, 16);
        var b_bn = new bn((b_neg ? "-" : "") + b_val, 16);

        var res_bn = a_bn.add(b_bn);

        var a_val_enc = "0x" + a_val
        var b_val_enc = "0x" + b_val

        expected_result_val = res_bn.toString('hex')
        if(expected_result_val[0] == '-'){
          expected_result_neg = true;
          expected_result_val = expected_result_val.substr(1)
        }else expected_result_neg = false;
      
        var a_msb_enc = a_bn.bitLength() - 1
        var b_msb_enc = b_bn.bitLength() - 1
        var expected_result_msb = res_bn.bitLength() - 1
        
        expected_result_val = "0x" + ((expected_result_val.length  % 64 != 0) ? "0".repeat(64 - (expected_result_val.length % 64)) : "") + expected_result_val //add any leading zeroes (not present from BN)

        //console.log("expected_result_val:" + expected_result_val + "\na_val:\n" + a_val + "\nb_val:\n" + b_val + "\na_msb:\n" + a_msb_enc + "\nb_msb:\n" + b_msb_enc + "\na_neg:\n" + a_neg + "\nb_neg:\n" + b_neg  );
                   
      instance.mock_bn_add.call(a_val_enc, a_neg, a_msb_enc, b_val_enc, b_neg, b_msb_enc).then(function(actual_result) {
        //console.log(actual_result[2].valueOf())
        assert.equal(expected_result_val, actual_result[0], "returned val did not match. \na_val:\n" + a_val + "\nb_val:\n" + b_val + "\na_msb:\n" + a_msb_enc + "\nb_msb:\n" + b_msb_enc + "\na_neg:\n" + a_neg + "\nb_neg:\n" + b_neg  );
        assert.equal(expected_result_neg, actual_result[1], "returned neg did not match. \na_val:\n" + a_val + "\nb_val:\n" + b_val + "\na_msb:\n" + a_msb_enc + "\nb_msb:\n" + b_msb_enc + "\n" + "\na_neg:\n" + a_neg + "\nb_neg:\n" + b_neg + "\n");
        assert.equal(expected_result_msb, actual_result[2].valueOf(), "returned msb did not match. \nresult: " + expected_result_val + "\na_val:\n" + a_val + "\nb_val:\n" + b_val + "\na_msb:\n" + a_msb_enc + "\nb_msb:\n" + b_msb_enc + "\n" + "\na_neg:\n" + a_neg + "\nb_neg:\n" + b_neg + "\n");
      })
    });

  it("Subtraction function: Run " + (init_runs-run) + " - create random inputs for A and B, sub to get C, assert equality from contract", async function() {
        instance = await MockBigNumberLib.new()
        var a_size = (Math.floor(Math.random() * 10) + 1) * 32
        var a_val = crypto.randomBytes(a_size).toString('hex');
        var b_size = (Math.floor(Math.random() * 10) + 1) * 32
        var b_val = crypto.randomBytes(b_size).toString('hex'); //create random hex strings

        var a_neg = Math.random() >= 0.5;
        var b_neg = Math.random() >= 0.5; //generates a random boolean.  

        var a_bn = new bn((a_neg ? "-" : "") + a_val, 16);
        var b_bn = new bn((b_neg ? "-" : "") + b_val, 16);

        var res_bn = a_bn.sub(b_bn);

        var a_val_enc = "0x" + a_val
        var b_val_enc = "0x" + b_val

        expected_result_val = res_bn.toString('hex')
        if(expected_result_val[0] == '-'){
          expected_result_neg = true;
          expected_result_val = expected_result_val.substr(1)
        }else expected_result_neg = false;
      
        var a_msb_enc = a_bn.bitLength() - 1
        var b_msb_enc = b_bn.bitLength() - 1
        var expected_result_msb = res_bn.bitLength() - 1
        
        expected_result_val = "0x" + ((expected_result_val.length  % 64 != 0) ? "0".repeat(64 - (expected_result_val.length % 64)) : "") + expected_result_val //add any leading zeroes (not present from BN)

        //console.log("expected_result_val:" + expected_result_val + "\na_val:\n" + a_val + "\nb_val:\n" + b_val + "\na_msb:\n" + a_msb_enc + "\nb_msb:\n" + b_msb_enc + "\na_neg:\n" + a_neg + "\nb_neg:\n" + b_neg  );
                   
      instance.mock_bn_sub.call(a_val_enc, a_neg, a_msb_enc, b_val_enc, b_neg, b_msb_enc).then(function(actual_result) {
        //console.log(actual_result[2].valueOf())
        assert.equal(expected_result_val, actual_result[0], "returned val did not match. \na_val:\n" + a_val + "\nb_val:\n" + b_val + "\na_msb:\n" + a_msb_enc + "\nb_msb:\n" + b_msb_enc + "\na_neg:\n" + a_neg + "\nb_neg:\n" + b_neg  );
        assert.equal(expected_result_neg, actual_result[1], "returned neg did not match. \na_val:\n" + a_val + "\nb_val:\n" + b_val + "\na_msb:\n" + a_msb_enc + "\nb_msb:\n" + b_msb_enc + "\n" + "\na_neg:\n" + a_neg + "\nb_neg:\n" + b_neg + "\n");
        assert.equal(expected_result_msb, actual_result[2].valueOf(), "returned msb did not match. \nresult: " + expected_result_val + "\na_val:\n" + a_val + "\nb_val:\n" + b_val + "\na_msb:\n" + a_msb_enc + "\nb_msb:\n" + b_msb_enc + "\n" + "\na_neg:\n" + a_neg + "\nb_neg:\n" + b_neg + "\n");
      })
    });
  }
});