pragma solidity ^0.6.2;

import "./SafeMath.sol";

contract Escrow {
    mapping (address => uint256) private balances;

    address payable public seller;
    address payable public buyer;
    address payable public escrowOwner;
    
    address[] public clients;
    
    // mapping(address => uint256) private clients;
    // address[] private clientIndex;
    

    uint public feePercent;
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


    modifier ifApprovedOrCancelled() {
        if ((eState == EscrowState.serviceApproved) || (eState == EscrowState.escrowCancelled)) {
            _;
        } else {
            revert();
        }
    }

    constructor () public {
        escrowOwner = msg.sender;
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
    
    function addClient(address _client) public onlyBuyer {
        clients.push(_client);
    }
    
    function getClientByID(uint256 queryID) public view returns (address) {
        return clients[queryID];
    }

    function depositToEscrow(address _client) public payable onlyBuyer { //removed second modifier checkBlockNumber
        
        balances[buyer] = SafeMath.add(balances[buyer], msg.value);
        deposits[_client] = msg.value;
        clients.push(_client);
        escrowCharge += msg.value;
        eState = EscrowState.buyerDeposited;
        emit Deposit(msg.sender, msg.value); // solhint-disable-line
        
    }
    
    function adjustDepositToEscrow(address _client, uint _amount) public payable onlyEscrowOwner { //removed second modifier checkBlockNumber
            balances[buyer] = SafeMath.add(balances[buyer], msg.value);
            deposits[_client] = deposits[_client] + msg.value;
            escrowCharge += msg.value;
            eState = EscrowState.buyerDeposited;
            buyer.transfer(_amount);
            emit Deposit(buyer, msg.value); // solhint-disable-line

        
    }

    function approveEscrow() public {
        if (msg.sender == seller) {
            sellerApproval = true;
        } else if (msg.sender == buyer) {
            buyerApproval = true;
        }
        if (sellerApproval && buyerApproval) {
            eState = EscrowState.serviceApproved;
            fee();
            payOutFromEscrow();
            emit ServicePayment(block.number, address(this).balance); // solhint-disable-line
        }
    }

    function cancelEscrow() public  { //removed modifier after public that is "checkBlockNumber"
        if (msg.sender == seller) {
            sellerCancel = true;
        } else if (msg.sender == buyer) {
            buyerCancel = true;
        }
        if (sellerCancel && buyerCancel) {
            eState = EscrowState.escrowCancelled;
            refund();
        }
    }

    function endEscrow() public ifApprovedOrCancelled onlyEscrowOwner {
        killEscrow();
    }

    function checkEscrowStatus() public view returns (EscrowState) {
        return eState;
    }
    
    function getEscrowContractAddress() public view returns (address) {
        return address(this);
    }
    
    // function getAllDeposits() public view returns (uint256[] memory) {
    //     return deposits;
    // }
    
    function hasBuyerApproved() public view returns (bool) {
        if (buyerApproval) {
            return true;
        } else {
            return false;
        }
    }

    function hasSellerApproved() public view returns (bool) {
        if (sellerApproval) {
            return true;
        } else {
            return false;
        }
    }
    
    function hasBuyerCancelled() public view returns (bool) {
        if(buyerCancel) {
            return true;
        }
        return false;
    }
    
    function hasSellerCancelled() public view returns (bool) {
        if(sellerCancel) {
            return true;
        }
        return false;
    }
    
    function getFeeAmount() public view returns (uint256) {
        return feeAmount;
    }
    
    function getSellermount() public view returns (uint256) {
        return sellerAmount;
    }
    
    function totalEscrowBalance() public view returns (uint256) {
        return address(this).balance;
    }

    
    function getBlockNumber() public view returns (uint256) {
        return block.number;
    }

    function killEscrow() internal {
        selfdestruct(escrowOwner);
    }

    function payOutFromEscrow() private {
        balances[buyer] = SafeMath.sub(balances[buyer], address(this).balance);
        balances[seller] = SafeMath.add(balances[seller], address(this).balance);
        eState = EscrowState.escrowComplete;
        sellerAmount = address(this).balance;
        seller.transfer(address(this).balance);
    }
    
    function payOutFromEscrowByBuyer() public onlyBuyer {
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
