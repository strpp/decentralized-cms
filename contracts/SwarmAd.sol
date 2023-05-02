// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./SwarmAdGovernor.sol";
import "../node_modules/@openzeppelin/contracts/utils/Address.sol";
import "../node_modules/@openzeppelin/contracts/access/AccessControl.sol";

contract SwarmAd is AccessControl {
  
  /// @notice List of Ethereum account of registered users
  address[] public eList;

  /// @notice It contains a list of Ehthereum Account who asked for membership and its votation is pending
  address[] public waitingList;

  /// @notice It contains PID from all products
  bytes32[] public productList;

  /// @notice Mapping between Ethereum address and Enterprise object
  mapping(address=>Enterprise) public eStructs; 

  /// @notice Mapping between Product PID and Product object
  mapping(bytes32 => Product) public productStructs; //mapping between product and pid

  /// @notice Mapping between Ethereum address and Enterprise object while its votation is pending 
  mapping(address=>Enterprise) public waitingListStructs;

  /// @notice Mapping an Ethereum address to its liked product, save the last time he call the function
  mapping(address=>bytes32) private superlike;
  mapping(address=>uint256) private superlikeTimelock;

  /// @notice Access Control
  address private governor;
  address private rewarder;
  bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");
  bytes32 public constant ENTERPRISE_ROLE = keccak256("ENTERPRISE_ROLE");

  constructor() {
    governor = address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xd6), bytes1(0x94), msg.sender, bytes1(0x03))))));
    rewarder = address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xd6), bytes1(0x94), msg.sender, bytes1(0x04))))));
    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _setupRole(GOVERNOR_ROLE, governor);    
  }

  struct Enterprise{
    string eName;
    string eMail;
    address eAddress;
    string profileImageHash; /*CID provided by Swarm when uploaded */
    uint indexEList; //position in eList
    uint indexWaitingList;
    bytes32[] enterprisePidList; //contains all product identifiers
  }

  struct Product{
    bytes32 pid;
    address enterprise;
    string productName;
    string productImageHash; //CID provided by Swarm when uploaded
    string productDescription;
    uint productPriceInWei;
    uint indexProductStructs;
    uint indexEnterprisePidList;
  }

  event newEnterpriseInWaitingList(address owner);
  event moveFromWaitingList(address owner);

  /// @notice  Check if an address is registered in the platform, must have for performing access control
  /// @param a Enterprise Ethereum Address to check 
  /// @return boolean
  function isRegistered(address a) public view returns(bool){
    if(eList.length==0) return false;
    return (eList[eStructs[a].indexEList]==a);
  }

  /// @notice  Check if an address is registered in the platform, must have for performing access control
  /// @param a Enterprise Ethereum Address to check 
  /// @return boolean
  function isInWaitingList(address a) public view returns(bool){
    if(waitingList.length==0) return false;
    return (waitingList[waitingListStructs[a].indexWaitingList]==a);
  }
  
  /// @notice Create a new enterprise
  /// @param name Enterprise name
  /// @param mail Enterprise email
  /// @param imgHash Image reference to retrieve the file from Swarm 
  function createEnterprise(string memory name, string memory mail, string memory imgHash) public{
    require(!isRegistered(msg.sender));

    if(eList.length<1){
      eList.push(msg.sender);
      Enterprise storage e = eStructs[msg.sender];
      e.eName = name; e.eMail = mail; e.profileImageHash = imgHash; e.indexEList = eList.length-1; e.indexWaitingList = 0;
      _grantRole(ENTERPRISE_ROLE, msg.sender);
    }
    else{
      waitingList.push(msg.sender);
      Enterprise storage e = waitingListStructs[msg.sender];
      e.eName = name; e.eMail = mail; e.profileImageHash = imgHash; e.indexEList = 0; e.indexWaitingList = waitingList.length -1;
      emit newEnterpriseInWaitingList(msg.sender);
      bytes[] memory transferCalldata = new bytes[](1);
      transferCalldata[0] = abi.encodePacked(bytes4(keccak256('moveEnterprise(address)')), // function signature
                            abi.encode(msg.sender) //function arguments
                            );
      SwarmAdGovernor(governor).createPoll(address(this), transferCalldata, "Accept new user");
    }   
  }

  /// @notice Remove a registered enterprise 
  function removeEnterpriseFromSwarmAd() public onlyRole(ENTERPRISE_ROLE){
    bytes32 [] memory pidToDelete = eStructs[msg.sender].enterprisePidList;
    for(uint i=0; i<pidToDelete.length; i++){
        removeProductByPid(pidToDelete[i]);
    }

    //pop from eList
    for(uint i = eStructs[msg.sender].indexEList; i < eList.length-1; i++){
      eStructs[msg.sender].indexEList--; //update pointer
      eList[i]=eList[i+1];   
    }
    eList.pop();
    renounceRole(ENTERPRISE_ROLE, msg.sender);
    delete eStructs[msg.sender];
  }

    /// @notice Remove a registered enterprise 
  function governorRemoveEnterprise(address a) public onlyRole(GOVERNOR_ROLE){
    bytes32 [] memory pidToDelete = eStructs[a].enterprisePidList;
    for(uint i=0; i<pidToDelete.length; i++){
        governorRemoveProductByPid(pidToDelete[i]);
    }

    //pop from eList
    for(uint i = eStructs[a].indexEList; i < eList.length-1; i++){
      eStructs[a].indexEList--; //update pointer
      eList[i]=eList[i+1];   
    }
    eList.pop();
    revokeRole(ENTERPRISE_ROLE, a);
    delete eStructs[a];
  }

  /// @notice Remove enterprise from waiting list
  function removeEnterpriseFromWaitingList(address a) public onlyRole(GOVERNOR_ROLE) {
    for(uint i = waitingListStructs[a].indexWaitingList; i < waitingList.length-1; i++){
      waitingListStructs[a].indexWaitingList--; //update pointer
      waitingList[i]=waitingList[i+1];   
    }
    waitingList.pop();
    delete waitingListStructs[msg.sender];
  }

  /// @notice Move from waiting list to SwarmAd list
  function moveEnterprise(address a) public onlyRole(GOVERNOR_ROLE){
    eList.push(a);
    _grantRole(ENTERPRISE_ROLE, a);
    Enterprise storage e = eStructs[a];
    e.eName = waitingListStructs[a].eName; 
    e.eMail = waitingListStructs[a].eMail; 
    e.profileImageHash = waitingListStructs[a].profileImageHash; 
    e.indexEList = eList.length-1; 
    e.indexWaitingList = 0;
    removeEnterpriseFromWaitingList(a);
    emit moveFromWaitingList(a);
  }

  /// @notice Retrieve an enterprise
  /// @param a Enterprise address
  /// @return eName enterprise name
  /// @return eMail enterprise mail
  /// @return imgHash enterprise reference in Swarm
  //get an Enterprise by address
  function getEnterprise(address a) public view returns(string memory eName, string memory eMail, string memory imgHash){
    return(eStructs[a].eName, eStructs[a].eMail, eStructs[a].profileImageHash);
  }

  /// @notice Retrieve an enterprise product list
  /// @param a Enterprise address
  /// @return enterprisePidList
  function getProductListFromEnterprise(address a)public view returns(bytes32 [] memory enterprisePidList) {
    return (eStructs[a].enterprisePidList);    
  }

  /// @notice Update an enterprise image
  /// @param newImageHash new reference to a file saved in Swarm
  function updateEProfilePicture(string memory newImageHash) public onlyRole(ENTERPRISE_ROLE){
    eStructs[msg.sender].profileImageHash = newImageHash;
  }

  /// @notice Update an enterprise mail
  /// @param newMail new mail to change
  function updateEMail(string memory newMail) public onlyRole(ENTERPRISE_ROLE){
    eStructs[msg.sender].eMail = newMail;
  }

  /// @notice Update an enterprise name
  /// @param newName name to change
  function updateEName(string memory newName) public onlyRole(ENTERPRISE_ROLE){
    eStructs[msg.sender].eName = newName;
  }

  /// @notice Create a new product
  /// @param name product name
  /// @param img Swarm reference to an image
  /// @param description literal description of an item
  /// @param price item price expressed in wei
  function createNewProduct(
    string memory name, 
    string memory img, 
    string memory description, 
    uint price) public onlyRole(ENTERPRISE_ROLE){
    bytes32 pid = keccak256(abi.encodePacked(eStructs[msg.sender].eAddress, name, block.timestamp));
    Product memory p = Product(
                              pid, msg.sender, name, img, description, price, 
                              productList.length, 
                              eStructs[msg.sender].enterprisePidList.length 
                        );
    productStructs[pid]=p;
    productList.push(pid);
    eStructs[msg.sender].enterprisePidList.push(pid);
  }

  /// @notice Get a product py pid
  function getProductByPid(bytes32 pid) public view returns(
    string memory productName, 
    string memory productImageHash, 
    string memory productDescription, 
    uint productPriceInWei, 
    address enterprise
    ){
    Product memory p = productStructs[pid];
    return(p.productName, p.productImageHash, p.productDescription, p.productPriceInWei, p.enterprise);
  }

    /// @notice Get a product enterpirse py pid
  function getProductNameByPid(bytes32 pid) public view returns(string memory productName){
    Product memory p = productStructs[pid];
    return p.productName;
  }

  /// @notice Get a product enterpirse py pid
  function getProductEnterpriseByPid(bytes32 pid) public view returns(address enterprise){
    Product memory p = productStructs[pid];
    return p.enterprise;
  }

  /// @notice Remove product from global list of product and from enterprise list
  function removeProductByPid(bytes32 pid) public onlyRole(ENTERPRISE_ROLE){
    require(msg.sender == productStructs[pid].enterprise, "Caller is not owner");

    //delete from enterprise
    for(uint i = productStructs[pid].indexEnterprisePidList; i < eStructs[msg.sender].enterprisePidList.length-1; i++){
      eStructs[msg.sender].enterprisePidList[i] = eStructs[msg.sender].enterprisePidList[i+1];      
    }
    eStructs[msg.sender].enterprisePidList.pop();

    //delete from global
    for(uint i = productStructs[pid].indexProductStructs; i < productList.length-1; i++){
      productList[i] = productList[i+1];      
    }
    productList.pop();

    //delete from global mapping
    delete productStructs[pid];
  }

  /// @notice Remove product from global list of product and from enterprise list
  function governorRemoveProductByPid(bytes32 pid) public onlyRole(GOVERNOR_ROLE){
    address e =  productStructs[pid].enterprise;
    //delete from enterprise
    for(uint i = productStructs[pid].indexEnterprisePidList; i < eStructs[e].enterprisePidList.length-1; i++){
      eStructs[e].enterprisePidList[i] = eStructs[e].enterprisePidList[i+1];      
    }
    eStructs[e].enterprisePidList.pop();

    //delete from global
    for(uint i = productStructs[pid].indexProductStructs; i < productList.length-1; i++){
      productList[i] = productList[i+1];      
    }
    productList.pop();

    //delete from global mapping
    delete productStructs[pid];
  }

  /// @notice Update product name
  /// @param pid to select the product
  /// @param newName name to change the old one
  function updateProductNameByPid(bytes32 pid, string memory newName) public onlyRole(ENTERPRISE_ROLE){
    require(msg.sender == productStructs[pid].enterprise, "Caller is not owner");
    productStructs[pid].productName = newName;
  }

  /// @notice Update product price
  /// @param pid to select the product
  /// @param newPrice price to change the old one
  function updateProductPriceByPid(bytes32 pid, uint newPrice) public onlyRole(ENTERPRISE_ROLE){
    require(msg.sender == productStructs[pid].enterprise, "Caller is not owner");
    productStructs[pid].productPriceInWei = newPrice;
  }

  /// @notice Update product descriptiom
  /// @param pid to select the product
  /// @param newDescription description to change the old one
  function updateProductDescpritionByPid(bytes32 pid, string memory newDescription) public  onlyRole(ENTERPRISE_ROLE){
    require(msg.sender == productStructs[pid].enterprise, "Caller is not owner");
    productStructs[pid].productDescription = newDescription;
  }

  /// @notice Update product image hash
  /// @param pid to select the product
  /// @param newImageHash Swarm reference to change the old one
  function updateProductImageHashByPid(bytes32 pid, string memory newImageHash) public  onlyRole(ENTERPRISE_ROLE){
    require(msg.sender == productStructs[pid].enterprise, "Caller is not owner");
    productStructs[pid].productImageHash = newImageHash;
  }

  /// @notice Retrieve Ethereum addresses of all registered enterprises
  function getEList() public view returns(address  [] memory){
    return eList;
  }

  /// @notice Retrieve Ethereum addresses of enterprises in waiting list
  function getWaitingList() public view returns(address  [] memory){
    return waitingList;
  }

  /// @notice Retrieve all products
  function getProductList() public view returns(bytes32 [] memory){
    return productList;
  }

  /// @notice Superlike a product
  /// @param pid to select the product
  function assignSuperlike(bytes32 pid) public onlyRole(ENTERPRISE_ROLE){
    require(productStructs[pid].enterprise != address(0)); //check item exists
    require(productStructs[pid].enterprise != msg.sender); //check owner is not caller
    uint256 differenceTimestamp = SafeMath.sub(block.timestamp, superlikeTimelock[msg.sender]);
    uint256 differenceInDays  = SafeMath.div(SafeMath.div(SafeMath.div(differenceTimestamp, 60), 60), 24);
    require(differenceInDays > 0, "time difference is not enough");
    superlike[msg.sender] = pid;
    superlikeTimelock[msg.sender] = block.timestamp;
    SwarmAdRewarder(rewarder).addRPsToAccount(msg.sender, 5);
  }
}
