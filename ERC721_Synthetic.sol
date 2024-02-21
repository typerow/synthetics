
// SPDX-License-Identifier: MIT

/*


Contract to issue synthetics via the ERC721 standard

*/

pragma solidity ^0.8.20;

import "./node_modules/@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
//Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
import "./node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "./node_modules/@openzeppelin/contracts/utils/Counters.sol";
import "./node_modules/@openzeppelin/contracts/utils/math/SafeMath.sol";

using SafeMath for uint; 

// Oracle used to hold onchain prices of USD and assets
contract SynfYOracle {

  uint public ethUsdPrice;
  //holds 1000 assets
  uint[1000] public assetPrices;

  constructor() {

    ethUsdPrice = 1;

  }

}


contract SynfY is ERC721URIStorage, Ownable, SynfYOracle {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

	event transfer_Do(address indexed _from, address indexed _to, uint256 indexed _tokenId);
    event logOwner(uint256 indexed _tokenId, address indexed owner);
	event performBaseTransaction_Do(address indexed exchange, address indexed _from);
    event withdrawMoney_Do(uint256 indexed amountToWithdraw, address indexed initialOwner);
    event priceUpdate(uint256 indexed price, uint256 indexed assetid);

	
	mapping (uint256 => uint256) public tokenIdToPrice;
	mapping(uint256 => address) internal idToOwner;

	string public _name;
	string public _symbol;
	string public contractname;
	string public contractsymbol;
    uint public balanceReceived;
	uint256 nextTokenId;
    string private contractState = "";  
    address initialOwner = msg.sender;

	constructor(string memory name_, string memory symbol_)
        ERC721(name_, symbol_)
        Ownable(initialOwner)
    {

        initialOwner = msg.sender;

    }
	
    // gets specific token price
	 function getprice(uint256 _tokenId) public view returns (uint256)
    {

		uint256 price = tokenIdToPrice[_tokenId];
        return price;

    }

    // gets USD price from internal Oracle
    function getPriceUsd() public view returns(uint) {  

        return ethUsdPrice;

    }

    // sets USD price from internal Oracle
    function updatePriceUsd(uint _newPrice) public onlyOwner {

        ethUsdPrice = _newPrice;
        emit priceUpdate(ethUsdPrice, 0);
    }

    // gets asset price via index from internal Oracle
    function getPriceAssets(uint assetindex) public view returns(uint) { 

        require(assetindex >= 0);
        require(assetindex <= 10000);
        return assetPrices[assetindex];

    }

    // sets asset prices via index from internal Oracle
    function updatePriceAssets(uint[] memory _newPrices) public onlyOwner {

        uint len = assetPrices.length;
        require(len >= 0);
        require(len <= 10000);

        for (uint i=1; i<len; i++) {
            assetPrices[i] = _newPrices[i];
            emit priceUpdate(_newPrices[i], i);
        }
    }


    /*
    Open to all, however tokenURI must show a JSON mapping to a tokenURI<->OrderID within the hlayer module.
    Without tokenURI<->OrderID JSON, the token is invalid and can not be sold back to market. See https://synfy.io/docs 
    Set open to all, to allow any contributor or stakeholder to mint after calling SynfY Web API to transact and generate an tokenURI<->OrderID.
    */
    function mint721(address recipient, string memory tokenURI, uint256 quantity, uint256 issafe)
        internal returns (uint256)
    {
        uint256 newItemId;

        require(quantity > 0);
        //max quantity per order
        require(quantity <= 10000000);

        if (quantity > 1){

            for (uint256 i; i < quantity; i++) {

                _tokenIds.increment();
                 newItemId = _tokenIds.current();
                if (issafe == 1){
                    _safeMint(recipient, newItemId, '');
                }else {
                    _mint(recipient, newItemId);	
                }
                _setTokenURI(newItemId, tokenURI);
                idToOwner[newItemId] = recipient;
             

            }
            return newItemId;

        }else {


            _tokenIds.increment();

             newItemId = _tokenIds.current();
            _mint(recipient, newItemId);
            _setTokenURI(newItemId, tokenURI);
            idToOwner[newItemId] = recipient;

            return newItemId;

        }
    }
	
    // takes payment and mints tokens
	function mint721WithPurchase(address recipient, string memory tokenURI, address seller, uint256 issafe, uint256 quantity) external payable
       returns (uint256) 
    {

        require(msg.value > 0);

		payable(seller).transfer(msg.value); 

        uint256 newItemId = mint721(recipient, tokenURI, quantity, issafe);
	
        return newItemId;

    }

    // takes payment and transfers tokens
	function PurchaseWithInternalTransfer(address recipient, uint256 _tokenId, address seller, uint256 issafe) external payable onlyOwner
    {
   
		payable(seller).transfer(msg.value); 
	
		if (issafe == 1){
			safeTransferFrom(seller,recipient,_tokenId, '');
		}else {
			transferFrom(seller,recipient,_tokenId);
		}
        idToOwner[_tokenId] = recipient;
		emit transfer_Do(recipient, seller, _tokenId);
	
    }
	
    // takes a payment 
	function performbasetransaction(address exchange) external payable
	{
		
		payable(exchange).transfer(msg.value);
		emit performBaseTransaction_Do(exchange, msg.sender);
		
	}
	
	// transfers a token
	function transfer_do(address _to, uint256 _tokenId) public onlyOwner {

        transferFrom(idToOwner[_tokenId],_to,_tokenId);
        idToOwner[_tokenId] = _to;
        emit transfer_Do(msg.sender, _to, _tokenId);
	}

    // burns token 
    function burn(uint256 tokenId) public onlyOwner {

        idToOwner[tokenId] = initialOwner;
        _burn(tokenId);

    }

    // burns token via null address
    function removeToken(uint256 tokenId) public onlyOwner {

        _transfer(ownerOf(tokenId), address(0x0), tokenId);
        idToOwner[tokenId] = address(0x0);

    }

    // recycles token back to contract owner, used typically on sale of asset
    function removeTokenRecycle(uint256 tokenId,address _to) public onlyOwner {

        _transfer(ownerOf(tokenId), _to, tokenId);
        idToOwner[tokenId] = _to;
        
    }

    // returns the owner of token
    function checkOwner(uint256 _tokenId) public returns (address) {

        address owner = idToOwner[_tokenId];

        emit logOwner(_tokenId, owner);

        return owner;

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
    function withdrawMoney(uint256 amountToWithdraw) public onlyOwner {

        uint256 balanceCurrent = address(this).balance;
        require(balanceCurrent > 0, "Nothing to withdraw; contract balance empty");
        require(amountToWithdraw <= balanceCurrent, "Trying to withdraw more then balance");

        if (amountToWithdraw <= balanceCurrent){
            address payable to = payable(initialOwner);
            to.transfer(amountToWithdraw);
            emit withdrawMoney_Do(amountToWithdraw, initialOwner);
        }

    }

    // to store any useful contract data onchain
    function contractStateUpdate(string memory _contractState) public onlyOwner {

        contractState = _contractState;
    }

    // returns any useful contract information or state currently onchain
    function contractStateReturn() external view returns (string memory) {

        return contractState;

    }


	
}