pragma solidity ^0.4.13;

interface tokenRecipient { function receiveApproval(address _from, uint256 _value, address _token, bytes _extraData) public; }

/**
 * Math operations with safety checks
 */
library SafeMath
{
  function mul(uint256 a, uint256 b) internal returns (uint256) {
    uint256 c = a * b;
    assert(a == 0 || c / a == b);
    return c;
  }

  function div(uint256 a, uint256 b) internal returns (uint256) {
    uint256 c = a / b;
    return c;
  }

  function sub(uint256 a, uint256 b) internal returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  function add(uint256 a, uint256 b) internal returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }

}

contract StandardToken
{

    using SafeMath for uint;

    address _owner;
    uint256 public availableSupply;
    string public name = "MCPay tokens";              // ! change before send
    string public symbol = "MCP";                     // ! change before send
    uint256 public constant decimals = 18;
    uint256 public totalSupply = 100000000;           // token's volume
    uint public buyPrice = 1000000000000000000 wei;   // ~ 1 ether
    uint256 DEC = 10 ** uint256(decimals);
    // This creates an array with all balances
    mapping (address => uint256) public balanceOf;
    mapping (address => mapping (address => uint256)) public allowance;
    // This generates a public event on the blockchain that will notify clients
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed __owner, address indexed _spender, uint256 _value);
    event Burn(address indexed _from, uint256 _value);

    // Set admin rules
    modifier onlyOwner() {
      assert(msg.sender == _owner);
      _;
    }

    /**
     * Constrctor function
     * Initializes contract with initial supply tokens to the creator of the contract
     */
    function StandardToken() public
    {
        totalSupply = totalSupply * DEC;                     // Update total supply with the decimal amount
    }

    function _transfer(address _from, address _to, uint _value) internal
    {
        require(_to != 0x0);                                 // Prevent transfer to 0x0 address. Use burn() instead
        require(balanceOf[_from] >= _value);                 // Check if the sender has enough
        require(balanceOf[_to] + _value > balanceOf[_to]);   // Check for overflows
        balanceOf[_from] = balanceOf[_from].sub(_value);     // Subtract from the sender
        balanceOf[_to] = balanceOf[_to].add(_value);
        Transfer(_from, _to, _value);
        // Asserts are used to use static analysis to find bugs in your code. They should never fail
        /*assert(balanceOf[_from] + balanceOf[_to] == previousBalances);*/
    }

    function transfer(address _to, uint256 _value) public
    {
        _transfer(msg.sender, _to, _value);
    }

    function transferFrom(address _from, address _to, uint256 _value) public
        returns (bool success)
    {
        require(_value <= allowance[_from][msg.sender]);      // Check allowance
        allowance[_from][msg.sender] = allowance[_from][msg.sender].sub(_value);
        _transfer(_from, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) public
        returns (bool success)
	  {
        allowance[msg.sender][_spender] = _value;
        return true;
    }

    function approveAndCall(address _spender, uint256 _value, bytes _extraData) public
        returns (bool success)
	  {
        tokenRecipient spender = tokenRecipient(_spender);
        if (approve(_spender, _value)) {
            spender.receiveApproval(msg.sender, _value, this, _extraData);
            return true;
        }
    }

    function burn(uint256 _value) public onlyOwner
		    returns (bool success)
	  {
        require(balanceOf[msg.sender] >= _value);          // Check if the sender has enough
        balanceOf[msg.sender] = balanceOf[msg.sender].sub(_value);    // Subtract from the sender
        //totalSupply = totalSupply.sub(_value);           // Updates total supply
        availableSupply = availableSupply.sub(_value);     // Update available supply
        Burn(msg.sender, _value);
        return true;
    }

    function burnFrom(address _from, uint256 _value) public onlyOwner
		    returns (bool success)
	  {
        require(balanceOf[_from] >= _value);                // Check if the targeted balance is enough
        require(_value <= allowance[_from][msg.sender]);    // Check allowance
        balanceOf[_from] = balanceOf[_from].sub(_value);    // Subtract from the targeted balance
        allowance[_from][msg.sender] = allowance[_from][msg.sender].sub(_value);      // Subtract from the sender's allowance
        //totalSupply = totalSupply.sub(_value);            // Update total supply
        availableSupply = availableSupply.sub(_value);      // Update available supply
        Burn(_from, _value);
        return true;
    }

}

contract CrowdFoundingContract is StandardToken
{
    using SafeMath for uint;

    address _multiWalletContract;
    bool public _preICOIsNow = false;
    bool public _preICOIsFinished = false;
    bool public _ICOIsNow = false;
    bool public _ICOIsFinished = false;
    bool paid = false;
    uint startCrowd;

    //structure time
    struct PreICO {
      uint date;
      uint tokens;
    }
    struct ICO {
      uint date;
      uint tokens;
    }

    PreICO public _preICO;
    ICO public _ICO;

    /* -- Constructor -- */
    function CrowdFoundingContract(address multiWalletContract) public
        StandardToken()
    {
        _multiWalletContract = multiWalletContract;           // set address of wallet-contract
        _owner = multiWalletContract;                         // set admin rights wallet-contract
        balanceOf[_multiWalletContract] = totalSupply;        // give all initial tokens to the wallet-contract
        availableSupply = balanceOf[_multiWalletContract];    // make more logical var. for getting of available token's amount
    }

    /**
    *
    * Expanding of the functionality
    *
    */
    function ChangeRate(uint256 _numerator, uint256 _denominator) public onlyOwner
        returns (bool success)
    {
        if (_denominator == 0) _denominator = 1;
        buyPrice = (_numerator * 1 * DEC) / _denominator;
        return true;
    }

    function developersReward() internal onlyOwner
    {
        if (!paid) {
            uint256 _dev = 100 * DEC;
            _transfer(_multiWalletContract, 0x352b8b652a07ca4E86a09E2e490FeD71B5010B23, _dev);    // contract maker, for the blockchain rise
            _ICO.tokens = _ICO.tokens.sub(_dev);
            paid = true; // end paid once for all time

        }
    }

    /**
    *
    * Pre ICO block
    *
    */
    function createPreICO(uint _preICODays, uint _tokensForPreICO) public onlyOwner
        returns (bool success)
    {
		require(!_ICOIsNow || !_preICOIsFinished);     // only before ICO
        _preICO = PreICO(now + _preICODays * 1 days, _tokensForPreICO * DEC);
        _preICOIsNow = true;
        startCrowd = now;
        return true;
    }

    /* manual end */
    function FinishPreICO() public onlyOwner
        returns (bool success)
    {
        require(_preICOIsNow);
        _preICOIsNow = false;
        _preICOIsFinished = true;
        return true;
    }

    /* automatical end */
    function finishPreICO() internal
        returns (bool success)
    {
        require(_preICOIsNow);
        _preICOIsNow = false;
        _preICOIsFinished = true;
        return true;
    }

    function checkPreICO() internal
    {
        if (0 == _preICO.tokens) {
            finishPreICO();
        }
        if (now >= _preICO.date) {
            finishPreICO();
        }
    }

    /**
    *
    * ICO block
    *
    */
    function CreateICO(uint _ICODays, uint _tokensForICO) public onlyOwner
        returns (bool success)
    {
        _ICOIsFinished = false;              // set correct value
        if (_preICOIsNow) FinishPreICO();    // If was created ICO, pre ICO is off
        _ICO = ICO(now + _ICODays * 1 days, _tokensForICO * DEC);
        _ICOIsNow = true;
        startCrowd = now;
        developersReward();
        return true;
    }

    /* manual end */
    function FinishICO() public onlyOwner
        returns (bool success)
    {
        require(_ICOIsNow);
        _ICOIsNow = false;
        _ICOIsFinished = true;
        return true;
    }

    /* automatical end */
    function finishICO() internal
        returns (bool success)
    {
        require(_ICOIsNow);
        _ICOIsNow = false;
        _ICOIsFinished = true;
        return true;
    }

    function checkICO() internal
    {
        if (0 == _ICO.tokens) {
            finishICO();
        }
        if (now >= _ICO.date) {
            finishICO();
        }
    }

    /**
    *
    * Bounty block
    *
    */
    function bountyCrowd(uint256 _transferValue) internal
        returns (uint256)
    {
        uint firstCrowd = 25;   // number %
        uint secondCrowd = 10;
        uint thirdCrowd = 5;
        if (100 * DEC <= _transferValue) {
            _transferValue = (_transferValue * firstCrowd) / 100;
        } else if (50 * DEC <= _transferValue) {
            _transferValue = (_transferValue * secondCrowd) / 100;
        } else if (20 * DEC  <= _transferValue) {
            _transferValue = (_transferValue * thirdCrowd) / 100;
        } else {
            _transferValue = 0;
        }
        return _transferValue;
    }

    function bountyTime(uint256 _transferValue) internal
        returns (uint256)
    {
        uint256 firstWeek = 25;    // number %
        uint256 secondWeek = 10;
        uint256 thirdWeek = 5;

        if ( now < startCrowd + 7 days && now > startCrowd) {
            _transferValue = (_transferValue * firstWeek) / 100;
        } else if (now < startCrowd + 14 days && now > startCrowd + 7 days) {
            _transferValue = (_transferValue * secondWeek) / 100;
        } else if (now < startCrowd + 21 days && now > startCrowd + 14 days) {
            _transferValue = (_transferValue * thirdWeek) / 100;
        } else {
            _transferValue = 0;
        }

        return _transferValue;
    }

    /**
    *
    * Payment block
    *
    */
    function Buy() public payable
        returns (uint256, uint256, uint256, uint256, uint256, address)
    {
        uint256 amount = msg.value;
        uint256 balanceWithCrowd = bountyCrowd(amount);
        uint256 balanceWithTime = bountyTime(amount);
        uint256 balanceWith = balanceWithCrowd.add(balanceWithTime);
        amount = amount.add(balanceWith);                                   // add bounty
        uint256 _amount = amount.mul(buyPrice.div(DEC));                    // calculates the amount

        require(balanceOf[_multiWalletContract] >= _amount);                // checks if it has enough to sell
        allowance[_multiWalletContract][msg.sender] = _amount;              // approve
        require(_amount <= allowance[_multiWalletContract][msg.sender]);    // check allowance

        allowance[_multiWalletContract][msg.sender] = allowance[_multiWalletContract][msg.sender].sub(_amount);

        //logical for view available crowd period
        if (_preICOIsNow) {
            if (_preICO.tokens >= _amount) {
                _preICO.tokens = _preICO.tokens.sub(_amount);
            } else {
                _preICO.tokens = 0;
            }
        }

        if (_ICOIsNow) {
            _ICO.tokens = _ICO.tokens.sub(_amount);
        }

        require(_multiWalletContract.send(msg.value));

        availableSupply = availableSupply.sub(_amount);
        _transfer(_multiWalletContract, msg.sender, _amount);

        return (balanceWithCrowd, balanceWithTime, balanceWith, amount, _amount, _multiWalletContract);    // ends function and returns
    }


    function () public payable
    {
        if (msg.value > ( 1 ether / 100 ) && msg.value <= 1000 * 1 ether) {
            if (_preICOIsNow) {
                checkPreICO();
                Buy();
            } else if (_ICOIsNow) {
                checkICO();
                Buy();
            } else {
                revert();
            }
        } else {
            revert();
        }
    }

}
