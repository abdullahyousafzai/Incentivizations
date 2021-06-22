pragma solidity ^0.6.2;

import "./SafeMath.sol";

contract Factory {
    
    Escrow[] public allEscrowContracts;
    uint256 public escrowCount;
    address payable public factoryOwner;
    
    constructor () public {
        factoryOwner = msg.sender;
        escrowCount = 0;
    }
    
    function createContract() public {
        Escrow newContract = new Escrow(factoryOwner, escrowCount++);
        allEscrowContracts.push(newContract);
    }
    
    function getAllContracts() public view returns (Escrow [] memory ) {
        return allEscrowContracts;
    }
    
    function getByID(uint256 queryID) public view returns (Escrow) {
        return allEscrowContracts[queryID];
    }
}

contract Escrow {
    mapping (address => uint256) private balances;

    address payable public seller;
    address payable public buyer;
    address payable public escrowOwner;
    
    

    uint public feePercent;
    uint public escrowID;
    uint256 public escrowCharge;

    bool public sellerApproval;
    bool public buyerApproval;
    
    bool public sellerCancel;
    bool public buyerCancel;
    
    mapping(address => uint256) public deposits;
    uint256 public feeAmount;
    uint256 public sellerAmount;

    enum EscrowState { unInitialized, initialized, buyerDeposited, serviceApproved, escrowComplete, escrowCancelled }
    EscrowState public eState = EscrowState.unInitialized;

    event Deposit(address depositor, uint256 deposited);
    event ServicePayment(uint256 blockNo, uint256 contractBalance);

    modifier onlyBuyer() {
        if (msg.sender == buyer) {
            _;
        } else {
            revert();
        }
    }
    
   

    modifier onlyEscrowOwner() {
        if (msg.sender == escrowOwner) {
            _;
        } else {
            revert();
        }
    }    


    constructor (address payable fOwner, uint256 _escrowID) public {
        escrowOwner = fOwner;
        escrowID = _escrowID;
        escrowCharge = 0;
    }

    fallback () external { // solhint-disable-line
        // fallback function to disallow any other deposits to the contract
        revert();
    }

    function initEscrow(address payable _seller, address payable _buyer, uint _feePercent) public payable onlyEscrowOwner  { // removed the last argument "uint256 _blockNum" 
        require((_seller != msg.sender) && (_buyer != msg.sender));
        seller = _seller;
        buyer = _buyer;
        feePercent = _feePercent;
        eState = EscrowState.initialized;

        balances[seller] = 0;
        balances[buyer] = 0;
    }
    
  
    function depositToEscrow(address _client) public payable onlyBuyer { //removed second modifier checkBlockNumber
        
        balances[buyer] = SafeMath.add(balances[buyer], msg.value);
        deposits[_client] = msg.value;
        escrowCharge += msg.value;
        eState = EscrowState.buyerDeposited;
        emit Deposit(msg.sender, msg.value); // solhint-disable-line
        
    }
    

    function endEscrow() public onlyEscrowOwner {
        killEscrow();
    }

    

    function killEscrow() internal {
        selfdestruct(escrowOwner);
    }


    function PayOutEscrow() public onlyBuyer {
        balances[buyer] = SafeMath.sub(balances[buyer], address(this).balance);
        balances[seller] = SafeMath.add(balances[seller], address(this).balance);
        eState = EscrowState.escrowComplete;
        sellerAmount = address(this).balance;
        seller.transfer(address(this).balance);
        fee();
        emit ServicePayment(block.number, address(this).balance); // solhint-disable-line
    }
    

    function fee() private {
        uint totalFee = address(this).balance * (feePercent / 100);
        feeAmount = totalFee;
        escrowOwner.transfer(totalFee);
    }

    function refund() private {
        buyer.transfer(address(this).balance);
    }
}

