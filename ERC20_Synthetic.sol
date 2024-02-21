// SPDX-License-Identifier: MIT

/*

Contract to issue synthetics via the ERC20 standard
Template primarily used for stable tokens of USD, EUR, GBP 


*/

pragma solidity ^0.8.20;
 
import "./node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "./node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";  
import "./node_modules/@openzeppelin/contracts/utils/math/SafeMath.sol";
import {IERC20} from "./node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";


using SafeMath for uint; 

interface ISynfYToken is IERC20 {

  function contractStateReturn() external view returns (string memory);
  function mint_synfy(string memory csymbol, uint256 mult)  external payable returns (bool);
  function mint_synfy_cheap(address mintTo, string memory csymbol, uint256 amount) external returns (bool);
  function mint_synfy_bare(address mintTo, uint256 amount) external returns (bool);

}

// Oracle used to hold onchain prices of primarily 3 currencies
contract SynfYOracle {

  uint public ethUsdPrice;
  uint public ethEurPrice;
  uint public ethGBPPrice;

  constructor() {
    //holds fixed assets 
    ethUsdPrice = 1; 
    ethEurPrice = 1; 
    ethGBPPrice = 1; 

  }

}


contract SynfYToken is ERC20, Ownable, SynfYOracle, ISynfYToken {
	 

  event logMint(address mintTo, address msgsender, string csymbol, uint256 amount);
  event performBaseTransaction_Do(address indexed exchange, address indexed _from);
  event priceUpdate(uint256 indexed price, uint256 indexed assetid);

  string private contractState = "";  
  address initialOwner = msg.sender;
  uint public balanceReceived;


  
  constructor(string memory csymbol, uint256 premintamount, string memory name_, string memory symbol_) 
  ERC20(name_, symbol_)
  Ownable(msg.sender) public {
    
    
      initialOwner = msg.sender;
      //no supply cap, initial supply set to 1bn to owner 
      premintamount = premintamount* (10**18);
      mint_synfy_cheap(initialOwner, csymbol, premintamount);
      
  }

  // gets USD price from internal Oracle
  function getPrice() public view returns(uint) {  

      return ethUsdPrice;

  }

  // sets USD price from internal Oracle
  function updatePrice(uint _newPrice) public onlyOwner {

      ethUsdPrice = _newPrice;
      emit priceUpdate(ethUsdPrice, 0);

  }

  // gets EUR price from internal Oracle
  function getPriceethEurPrice() public view returns(uint) {  

      return ethEurPrice;
  }

   // sets EUR price from internal Oracle
  function updatePriceethEurPrice(uint _newPrice) public onlyOwner {

      ethEurPrice = _newPrice;
      emit priceUpdate(ethUsdPrice, 1);

  }

  // gets GBP price from internal Oracle
  function getPriceethGBPPrice() public view returns(uint) {  

      return ethGBPPrice;

  }

   // sets GBP price from internal Oracle
  function updatePriceethGBPPrice(uint _newPrice) public onlyOwner {

      ethGBPPrice = _newPrice;
      emit priceUpdate(ethUsdPrice, 2);

  }

  // mints ERC20 token of type 
  function mint_synfy(string memory csymbol, uint256 mult) public payable returns (bool status) {

      require(msg.value > 0);

      uint256 amountomint = SafeMath.mul(msg.value, mult);

      payable(initialOwner).transfer(msg.value); 

      _mint(initialOwner, amountomint); 
      emit logMint(initialOwner, msg.sender, csymbol, amountomint);
      return true;

  }

  // mints ERC20 token of type via use of Oracle price. 
  function mint_synfy_oracle(address mintTo, uint256 currency) external payable returns (bool status) {

      require(msg.value > 0);

      uint256 amountomint = SafeMath.mul(msg.value, getPrice());
      string memory csymbol = "USD";

      if (currency == 1 ){
        amountomint = SafeMath.mul(msg.value, getPriceethEurPrice());
        csymbol = "EUR";
      }

      if (currency ==  2){
        amountomint = SafeMath.mul(msg.value, getPriceethGBPPrice()); 
        csymbol = "GBP";
      }


      payable(initialOwner).transfer(msg.value);

      _mint(mintTo, amountomint); 

      emit logMint(mintTo, msg.sender, csymbol, amountomint);

      return true;

  }

  // mints ERC20 token, minimal gas fee
  function mint_synfy_cheap(address mintTo, string memory csymbol, uint256 amount) public onlyOwner returns (bool status) {

      _mint(mintTo, amount); 

      emit logMint(mintTo, msg.sender, csymbol, amount);
      return true;
  }

  // mints ERC20 token, stub function
  function mint_synfy_bare(address mintTo, uint256 amount) public onlyOwner returns (bool status) {

      _mint(mintTo, amount);
      return true;

  }

  // takes a payment 
  function performbasetransaction(address exchange) external payable {
    
    payable(exchange).transfer(msg.value);
    emit performBaseTransaction_Do(exchange, msg.sender);
    
  }

  // burns token 
  function burn(address account, uint256 amount) public onlyOwner {

      _burn(account, amount);

  }

  // burns token via null address
  function removeToken(address account, uint256 amount) public onlyOwner {

      _transfer(account, address(0x0), amount);

  }

  // recycles token back to contract owner, used typically on sale of asset
  function removeTokenRecycle(address account, uint256 amount) public onlyOwner {

      _transfer(account, initialOwner, amount);
    
  }

  // tracks contract balance 
  function receiveMoney() public payable {

      balanceReceived += msg.value;

  }

  // returns contract balance
  function getBalance() public view returns(uint) {

      return address(this).balance;

  }

  // withdraws money from contract to owner. To supply offchain market liquidity. 
  function withdrawMoney(uint256 amountToWithdraw) public onlyOwner{

      uint256 balanceCurrent = address(this).balance;
      require(balanceCurrent > 0, "Nothing to withdraw; contract balance empty");
      require(amountToWithdraw <= balanceCurrent, "Trying to withdraw more then balance");
      
      if (amountToWithdraw <= balanceCurrent){
        address payable to = payable(initialOwner);
        to.transfer(amountToWithdraw);
      }

  }

  // to store any useful contract data or state onchain 
  function contractStateUpdate(string memory _contractState) public onlyOwner {

      contractState = _contractState;

  }

  
  // returns any useful contract information or state currently onchain
  function contractStateReturn() external view override returns (string memory) {

      return contractState;

  }



}
