// SPDX-License-Identifier: MIT
//WOOF protocol
pragma solidity ^0.8.0;

// Define ERC20 token standard interface
interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);  

    function name() external view returns (string memory);                    
    function symbol() external view returns (string memory);                  
    function decimals() external view returns (uint8);                       
    function totalSupply() external view returns (uint256);                   
    function balanceOf(address account) external view returns (uint256);      
    function transfer(address recipient, uint256 amount) external returns (bool); 
}

contract ExchangeToken is IERC20 {
    string private _name;              
    string private _symbol;            
    uint8 private _decimals;           
    uint256 private _totalSupply;      
    address public owner;              
    uint256 public basePrice;          
    uint256 public k;                  
    bool public paused;                

    mapping(address => uint256) private _balances;  

    event TokensPurchased(address indexed buyer, uint256 tokenAmount, uint256 taoAmount); 
    event TokensSold(address indexed seller, uint256 tokenAmount, uint256 taoAmount);      
    event BasePriceChanged(uint256 oldPrice, uint256 newPrice); 
    event PriceAdjustmentChanged(uint256 oldK, uint256 newK);  
    event Debug(string message, address from, address to, uint256 amount); 
    modifier onlyOwner() {
        require(msg.sender == owner, "Admin only"); 
        _;
    }
    
    modifier whenNotPaused() {
        require(!paused, "Paused");  
        _;
    }

    constructor(
        string memory tokenName,
        string memory tokenSymbol,
        uint8 tokenDecimals,
        uint256 initialSupply,
        uint256 initialBasePrice,
        uint256 priceAdjustment
    ) {
        require(initialSupply > 0, "Initial supply must be > 0");
        require(initialBasePrice > 0, "Initial base price must be > 0");

        _name = tokenName;
        _symbol = tokenSymbol;
        _decimals = tokenDecimals;
        basePrice = initialBasePrice;
        k = priceAdjustment;
        owner = msg.sender;

        _totalSupply = initialSupply * (10 ** uint256(tokenDecimals));
        _balances[address(this)] = _totalSupply; 
        emit Transfer(address(0), address(this), _totalSupply);
    }
    

    function name() public view override returns (string memory) { return _name; }
    function symbol() public view override returns (string memory) { return _symbol; }
    function decimals() public view override returns (uint8) { return _decimals; }
    function totalSupply() public view override returns (uint256) { return _totalSupply; }
    function balanceOf(address account) public view override returns (uint256) { return _balances[account]; }
    
  
    function getCurrentPrice() public view returns (uint256) {
        uint256 soldTokens = _totalSupply - _balances[address(this)];  
        uint256 adjustment = (basePrice * k * soldTokens) / (_totalSupply * 1e18);
        return basePrice + adjustment;  
    }
    

    receive() external payable whenNotPaused {
        require(msg.value > 0, "Send TAO to purchase tokens");

        uint256 currentPrice = getCurrentPrice();
        uint256 tokenAmount = (msg.value * (10 ** uint256(_decimals))) / currentPrice;
        require(tokenAmount > 0, "Token amount too small");
        require(_balances[address(this)] >= tokenAmount, "Insufficient contract token balance");

        _balances[address(this)] -= tokenAmount; 
        _balances[msg.sender] += tokenAmount; 

        emit TokensPurchased(msg.sender, tokenAmount, msg.value); 
        emit Transfer(address(this), msg.sender, tokenAmount); 
    }


    function transfer(address recipient, uint256 amount) public override whenNotPaused returns (bool) {
        require(recipient != address(0), "Cannot transfer to zero address");
        require(_balances[msg.sender] >= amount, "Insufficient balance");

   
        if (recipient == address(this)) { 
            uint256 currentPrice = getCurrentPrice();
            uint256 taoAmount = (amount * currentPrice) / (10 ** uint256(_decimals)); 
            require(address(this).balance >= taoAmount, "Contract has insufficient TAO balance");

     
            emit Debug("Trying to send TAO", msg.sender, recipient, taoAmount);

      
            (bool success, ) = msg.sender.call{value: taoAmount}("");
            require(success, "TAO transfer failed"); 

          
            emit Debug("TAO sent successfully", msg.sender, recipient, taoAmount); 

        
            _balances[msg.sender] -= amount;
            _balances[address(this)] += amount;

            emit TokensSold(msg.sender, amount, taoAmount);
            emit Transfer(msg.sender, address(this), amount); 
            return true;
        }
        
    
        _balances[msg.sender] -= amount;
        _balances[recipient] += amount;
        emit Transfer(msg.sender, recipient, amount);
        return true;
    }
    
  
    function withdrawTAO() public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No TAO to withdraw");
        (bool success, ) = owner.call{value: balance}("");
        require(success, "Transfer failed");
    }
    

    function setBasePrice(uint256 newBasePrice) public onlyOwner {
        require(newBasePrice > 0, "Price must be > 0");
        uint256 oldPrice = basePrice;
        basePrice = newBasePrice;  
        emit BasePriceChanged(oldPrice, newBasePrice);  
    }
    
   
    function setPriceAdjustment(uint256 newK) public onlyOwner {
        uint256 oldK = k;
        k = newK;  
        emit PriceAdjustmentChanged(oldK, newK);  
    }
    
   
    function pause() external onlyOwner {
        paused = true;
    }

  
    function unpause() external onlyOwner {
        paused = false;
    }
}