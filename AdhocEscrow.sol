pragma solidity ^0.6.2;
import "./SafeMath.sol";
contract AdhocEscrow {
    mapping (address => uint256) private EscrowAccountLedger;
    address payable public provider;
    address payable public consumer;
    address payable public authorityNode;
    uint256 public blockNumber;
    uint public feePercent;
    uint256 public escrowCharge;
    bool public providerApproval;
    bool public consumerApproval;
    bool public providerCancel;
    bool public consumerCancel;
    uint256[] public deposits;
    uint256 public feeAmount;
    uint256 public providerAmount;
    enum EscrowState { unInitialized, initialized, consumerDeposited,
    serviceApproved, escrowComplete, escrowCancelled }
    EscrowState public EscrowStatus = EscrowState.unInitialized;
    event Deposit(address depositor, uint256 deposited);
    event ServicePayment(uint256 blockNo, uint256 contractBalance);
    modifier onlyConsumer() {
        if (msg.sender == consumer) {
            _;
        } else {
            revert();
        }
    }
    modifier onlyAuthorityNode() {
        if (msg.sender == authorityNode) {
            _;
        } else {
            revert();
        }
    }    
    modifier checkBlockNumber() {
        if (blockNumber > block.number) {
            _;
        } else {
            revert();
        }
    }
    modifier ifApprovedOrCancelled() {
        if ((EscrowStatus == EscrowState.serviceApproved) ||
        (EscrowStatus == EscrowState.escrowCancelled)) {
            _;
        } else {
            revert();
        }
    }
    constructor () public {
        authorityNode = msg.sender;
        escrowCharge = 0;
    }
    fallback () external { // solhint-disable-line
        // fallback function to disallow any other deposits to the contract
        revert();
    }
    function Initialize(address payable _provider, address payable _consumer, uint _feePercent, 
    uint256 _blockNum) public payable onlyAuthorityNode  {
        require((_provider != msg.sender) && (_consumer != msg.sender));
        provider = _provider;
        consumer = _consumer;
        feePercent = _feePercent;
        blockNumber = _blockNum;
        EscrowStatus = EscrowState.initialized;

        EscrowAccountLedger[provider] = 0;
        EscrowAccountLedger[consumer] = 0;
    }
    function DepositInEscrowByConsumer() public payable checkBlockNumber onlyConsumer {
        EscrowAccountLedger[consumer] = SafeMath.add(EscrowAccountLedger[consumer], msg.value);
        deposits.push(msg.value);
        escrowCharge += msg.value;
        EscrowStatus = EscrowState.consumerDeposited;
        emit Deposit(msg.sender, msg.value); // solhint-disable-line
    }
    function ApproveEscrow() public {
        if (msg.sender == provider) {
            providerApproval = true;
        } else if (msg.sender == consumer) {
            consumerApproval = true;
        }
        if (providerApproval && consumerApproval) {
            EscrowStatus = EscrowState.serviceApproved;
            fee();
            EscrowPayout();
            emit ServicePayment(block.number, address(this).balance); // solhint-disable-line
        }
    }
    function CancelEscrow() public checkBlockNumber {
        if (msg.sender == provider) {
            providerCancel = true;
        } else if (msg.sender == consumer) {
            consumerCancel = true;
        }
        if (providerCancel && consumerCancel) {
            EscrowStatus = EscrowState.escrowCancelled;
            refund();
        }
    }
    function EndEscrow() public ifApprovedOrCancelled onlyAuthorityNode {
        DestructEscrow();
    }
    function DestructEscrow() internal {
        selfdestruct(authorityNode);
    }
    function EscrowPayout() private {
        EscrowAccountLedger[consumer] = SafeMath.sub(EscrowAccountLedger[consumer],
        address(this).balance);
        EscrowAccountLedger[provider] = SafeMath.add(EscrowAccountLedger[provider],
        address(this).balance);
        EscrowStatus = EscrowState.escrowComplete;
        providerAmount = address(this).balance;
        provider.transfer(address(this).balance);
    }
    function fee() private {
        uint totalFee = address(this).balance * (feePercent / 100);
        feeAmount = totalFee;
        authorityNode.transfer(totalFee);
    }
    function refund() private {
        consumer.transfer(address(this).balance);
    }
}
