pragma solidity ^0.5.16;

contract DTSC {
  address payable public dtc;
  address payable public ds;
  address payable public dp;
  enum DTSCStatus { WaitingforDP, Aborted }
  DTSCStatus public status;
  enum DPStatus { DPDeposited, SuccessfulTrading, Unsatisfied, DPIsWrong, TradingCompleted, Refunded }
  uint public numberOfDPs;
  uint public numberOfSuccessfulSales;
  uint public deposit;
  uint public dataprice;

  struct Purchaser {
    DPStatus status;
  }

  mapping(address => Purchaser) public DPs;
  mapping(address => uint) public ratings;

  // Estrutura para rastrear transações
  struct Transaction {
    address purchaser;
    address supplier;
    uint value;
    string status; // Exemplo: "Successful", "Refunded", "Disputed"
  }

  Transaction[] public transactions; // Lista de transações

  modifier DPCost() {
    require(msg.value == dataprice + deposit, "Incorrect value sent.");
    _;
  }

  modifier OnlyDTC() {
    require(msg.sender == dtc, "Only DTC can perform this action.");
    _;
  }

  modifier OnlyDS() {
    require(msg.sender == ds, "Only DS can perform this action.");
    _;
  }

  modifier OnlyDP() {
    require(msg.sender == dp, "Only DP can perform this action.");
    _;
  }

  modifier DSCost() {
    require(msg.value == deposit, "Incorrect deposit value.");
    _;
  }

  // Novo construtor para configurar dinamicamente os endereços
  constructor(
    address payable _dtc,
    address payable _ds,
    address payable _dp
  ) public {
    dtc = _dtc;
    ds = _ds;
    dp = _dp;
    status = DTSCStatus.WaitingforDP;
    deposit = 3 ether;
    dataprice = 2 ether;
    numberOfDPs = 0;
    numberOfSuccessfulSales = 0;
  }

  function rateUser(address user, uint score) public { // Adicionado
        require(score <= 5, "Max rating is 5.");
        ratings[user] = (ratings[user] + score) / 2;
    }
  
  event DSDeposited(string info, address DS);
  event DPDepositedandPaid(address DP, string info);
  event successfulTrading(address DP);
  event unsuccessfulTrading(address DP);
  event DTCArbitrationThroughDTCSC(address DP, string info);
  event DPRight(address DP, string info);
  event DPWrong(address DP, string info);
  event refundDone(address DP);
  event paymentSettled(address DP, string info);
  event RefundBasedOnDPRequest(string info, address DP);

  // Função para rastrear transações
  function recordTransaction(
    address _purchaser,
    address _supplier,
    uint _value,
    string memory _status
  ) internal {
    transactions.push(Transaction({
      purchaser: _purchaser,
      supplier: _supplier,
      value: _value,
      status: _status
    }));
  }

  function RequestSellData() OnlyDS DSCost public payable {
    emit DSDeposited("Selling data", ds);
  }

  function RequestGetData() OnlyDP DPCost public payable {
    require(status == DTSCStatus.WaitingforDP, "Invalid status.");
    DPs[msg.sender].status = DPStatus.DPDeposited;
    emit DPDepositedandPaid(msg.sender, "DP deposited and paid for data resource");
    numberOfDPs++;
  }

  function refund() OnlyDP public {
    require(DPs[msg.sender].status == DPStatus.DPDeposited, "Refund not allowed.");
    uint x = deposit + dataprice;
    msg.sender.transfer(x);
    DPs[msg.sender].status = DPStatus.Refunded;
    emit RefundBasedOnDPRequest("DP has been refunded", msg.sender);

    // Registro da transação
    recordTransaction(msg.sender, ds, x, "Refunded");
  }

  function ConfirmResult(bool result) OnlyDP public {
    require(DPs[msg.sender].status == DPStatus.DPDeposited, "Invalid status.");
    if (result) {
      emit successfulTrading(msg.sender);
      DPs[msg.sender].status = DPStatus.SuccessfulTrading;
      settlepayment(msg.sender);

      // Registro da transação
      recordTransaction(msg.sender, ds, dataprice + deposit, "Successful");
    } else {
      emit unsuccessfulTrading(msg.sender);
      DPs[msg.sender].status = DPStatus.Unsatisfied;
      emit DTCArbitrationThroughDTCSC(msg.sender, "DTC is involved in dispute arbitration.");

      // Registro da transação
      recordTransaction(msg.sender, ds, dataprice + deposit, "Disputed");
    }
  }

  function SettleDisputeAndPayment(address payable DP, bool result) OnlyDTC public {
    require(DPs[DP].status == DPStatus.Unsatisfied, "Invalid status.");
    if (result) {
      emit DPRight(DP, "DP should be refunded");
      DP.transfer(dataprice + deposit);
      dtc.transfer(deposit);
      emit refundDone(DP);
      DPs[DP].status = DPStatus.TradingCompleted;

      // Registro da transação
      recordTransaction(DP, ds, dataprice + deposit, "Refunded");
    } else {
      emit DPWrong(DP, "DP is Wrong.");
      DPs[DP].status = DPStatus.DPIsWrong;
      settlepayment(DP);

      // Registro da transação
      recordTransaction(DP, ds, dataprice + deposit, "Settled");
    }
  }

  function settlepayment(address payable DP) internal {
    require(
      DPs[DP].status == DPStatus.SuccessfulTrading || DPs[DP].status == DPStatus.DPIsWrong,
      "Invalid status."
    );
    uint x = dataprice / 2;
    uint dsincome = deposit + x;
    ds.transfer(dsincome);
    dtc.transfer(x);
    DP.transfer(deposit);
    emit paymentSettled(DP, "Payment settled");
    DPs[DP].status = DPStatus.TradingCompleted;
  }

  // Recuperar transações
  function getTransaction(uint index) public view returns (address, address, uint, string memory) {
    Transaction memory txn = transactions[index];
    return (txn.purchaser, txn.supplier, txn.value, txn.status);
  }
}
