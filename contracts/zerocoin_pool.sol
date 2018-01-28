pragma solidity ^0.4.18;

//contract to hold minted eth and to handle receiving/sending it.
//this is for separation of ethereum balances; in _logic contract, it's used for executing callback transactions & storage removal.
contract zerocoin_pool {

    function receive_mint() internal payable {
    }

    function send_spend(address receiver) internal {
    }

}