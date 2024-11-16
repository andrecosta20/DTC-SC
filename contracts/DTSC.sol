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
  }

  function ConfirmResult(bool result) OnlyDP public {
    require(DPs[msg.sender].status == DPStatus.DPDeposited, "Invalid status.");
    if (result) {
      emit successfulTrading(msg.sender);
      DPs[msg.sender].status = DPStatus.SuccessfulTrading;
      settlepayment(msg.sender);
    } else {
      emit unsuccessfulTrading(msg.sender);
      DPs[msg.sender].status = DPStatus.Unsatisfied;
      emit DTCArbitrationThroughDTCSC(msg.sender, "DTC is involved in dispute arbitration.");
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
    } else {
      emit DPWrong(DP, "DP is Wrong.");
      DPs[DP].status = DPStatus.DPIsWrong;
      settlepayment(DP);
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
}
