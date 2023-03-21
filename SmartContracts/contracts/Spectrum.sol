// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

// Make spectrum upgradable
contract Spectrum {

    enum StationState {
        Installed,
        Monitored,
        UnderMaintenance,
        Dismantled, // Keep historic record of power station
        Online
    }

    enum GenerationType {
        Solar,
        Geothermal,
        Wind,
        Biomass,
        Biofuels,
        Hydropower,
        Electricity,
        Nuclear,
        Coal,
        Lignite,
        NaturalGas,
        Diesel,
        Hydrocarbon
    }

    struct Coordinates {
        uint256 lat;
        uint256 long;
    }

    struct PowerStation {
        Coordinates location;

        uint256 installedCapacity;
        uint256 sellCapacity;
        uint256 targetReserveCapacity;

        uint256 pricePerMW;

        uint256 timeCreated;
        uint256 lastUpdated;

        GenerationType generationType;
        StationState state;

        // Ownership (changeable)
        address organization;       // map organiztion back to string name
    }

    struct StationRecord {
        uint256 reportDate; 
        string report; // this could either be a string or uri
    }

    uint256 private stationId = 0; // counter for station ids

    // map station id to station struct
    // use sql server for indexing / ownership / filtering
    mapping(uint256 => PowerStation) private powerStations;

    // map station hash to station service record array
    mapping(uint256 => StationRecord[]) private serviceRecords;

    mapping(address => bool) private whitelist;

    // contract owner
    address private _contractOwner;

    // Events
    event StationStateChanged(uint256 _stationId, StationState _stationState);
    event StationOwnerChanged(uint256 _stationId, address _newOwner);

    event StationCreated(uint256 _stationId);

    event StationSellCapacityChanged(uint256 _stationId,uint256 _newSellCapacity);
    event BuyStationCapacity(uint256 _stationId, uint256 _capacityBought);

    event StationTargetReserveCapacityChanged(uint256 _stationId, uint256 _newtargetReserveCapacity);

    event NewServiceEntry(uint256 _stationId,uint256 _entrySize);

    event WhiteListUpdated(address _newAddress,bool _status);

    constructor() {
        _contractOwner = msg.sender;
    }

    // Modifiers
    modifier onlyContractOwner() {
        require(_contractOwner == msg.sender,"Your not contract owner");
        _;
    }

    modifier onlyStationOwner(uint256 _stationId) {
        require(powerStations[_stationId].organization != msg.sender,"Your are not station owner");
        _;
    }

    modifier isSenderWhiteListed() {
        //require(whitelist[msg.sender] == 0,"Sender not white listed");
        require(whitelist[msg.sender],"Sender not white listed");
        _;
    }

    function getOwner()
    public
    view
    returns(address)
    {
        return(_contractOwner);
    }

    /**
     * @dev get array of stations 
     * 
     * param _startStationId starting index of stations
     * param _amountOfStations amount of stations to populate return array
     *
     * array of PowerStations
     */
    function getStations(uint256 _startStationIndex,uint256 _amountOfStations)
    public 
    view
    returns(PowerStation[] memory)
    {
        require(_startStationIndex < stationId,"Station start index cannot surpass station amount");
        require(_amountOfStations != 0,"Station amount cannot be zero");

        uint256 newIndex = 0;

        PowerStation[] memory tempList = new PowerStation[](_amountOfStations);

        for(uint i = 0;i < _amountOfStations; i++){
            tempList[newIndex] = powerStations[_startStationIndex + i];
            newIndex += 1;
        }
        return (tempList);
    }

    /**
     * @dev allows contract owner to whitelist address
     */
    function setWhiteList(address _account, bool _isWhiteListed)
    public
    onlyContractOwner()
    {
        whitelist[_account] = _isWhiteListed;
        emit WhiteListUpdated(_account,_isWhiteListed);
    }


    /**
     * @dev allows contract owner to whitelist address
     *
     */
    function isWhiteListed(address _account)
    public
    view
    returns(bool)
    {
        return(whitelist[_account]);
    }

    /**
     * @dev amount of service records for given station
     */
    function getRecordCount(uint256 _stationId)
    public
    view
    returns(uint256)
    {
        return(serviceRecords[_stationId].length);
    }

    /**
     * @dev get amount of array of station records
     */
    function getStationAmount()
    public
    view 
    returns(uint256)
    {
        return(stationId);
    }

/************** Station Creation ***************/

    /**
     * @dev allows contract owner to add a new power stations
     * 
     * Could add whitelist of verified address for adding power stations
     */
    function addStation(
                        uint256 _lat, 
                        uint256 _long,
                        uint256 _installCapacity,
                        uint256 _sellCapacity,
                        uint256 _pricePerMW,
                        GenerationType _generationType,
                        StationState _state
                        )
    public
    isSenderWhiteListed()
    {
        // Set station coordinates
        Coordinates memory coordinates;
        coordinates.lat = _lat;
        coordinates.long = _long;

        // Set power station
        PowerStation memory ps;
        ps.location = coordinates;
        ps.installedCapacity = _installCapacity;
        ps.pricePerMW = _pricePerMW;
        ps.sellCapacity = _sellCapacity;
        ps.timeCreated = block.timestamp;
        ps.lastUpdated = block.timestamp;
        ps.generationType = _generationType;
        ps.state = _state;
        ps.organization = msg.sender;

        // create power station id -> hash of power station
        // bytes32 powerStationHash = keccak256(abi.encode(ps));
        powerStations[stationId] = ps;
        stationId += 1;
        // emit station created event
        emit StationCreated(stationId);
    }

    /************** Station Capacity ***************/

    /**
     * @dev allows station ownership to be change
     *
     */
    function updateStationSellCapacity(
                                        uint256 _stationId,
                                        uint256 _newCapacity
                                      )
    public
    onlyStationOwner(_stationId)
    {
        // get power station
        PowerStation memory ps = powerStations[_stationId];
        ps.sellCapacity = _newCapacity;
        ps.lastUpdated = block.timestamp;
        powerStations[_stationId] = ps;
        emit StationSellCapacityChanged(_stationId,_newCapacity);
    }

    /**
     * @dev allows station capacity to be bought
     *
     * Note Ideally buy capacity would only be used buy trusted entities
     */
    function buyCapacity(uint256 _stationId, uint256 _amount)
    public
    payable
    {
        PowerStation memory ps = powerStations[_stationId];

        require(ps.sellCapacity > _amount,"Amount exceeds station sell capacity");
        uint256 buyAmount = ps.pricePerMW * _amount;
        require(msg.value >= buyAmount, "Invalid Balance");
        // owner can not buy there own supply
        require(ps.organization != msg.sender,"Not station owner");
        
        ps.sellCapacity -= _amount; // reverts if underflow 
        ps.lastUpdated = block.timestamp;
        powerStations[_stationId] = ps; // important to before tranfering

        (bool sent, bytes memory data) = ps.organization.call{value:buyAmount}("");
        require(sent, "Failed to send Ether");

        emit BuyStationCapacity(_stationId, _amount);
    }

    /**
     * @dev allows station reserve to be change from contract owner
     * Look at docs for additional infomation on this mechanism
     * Could add incetive on keeping to reserve capacity
     */
    function targetReserveCapacity(uint256 _stationId, uint256 _newRate)
    public
    onlyStationOwner(_stationId)
    {
        PowerStation memory ps = powerStations[_stationId];
        ps.targetReserveCapacity = _newRate;
        ps.lastUpdated = block.timestamp; // update timestamp
        powerStations[_stationId] = ps;

        emit StationTargetReserveCapacityChanged(_stationId, _newRate);
    }

    /*************** Station Service Entry ****************/

    /**
     * @dev allows station reports to be documented on-chain
     *
     */
    function newServiceEntry(uint256 _stationId, string memory reportId)
    public
    onlyStationOwner(_stationId)
    {
        StationRecord memory sr;
        sr.report = reportId;
        sr.reportDate = block.timestamp; // add timestamp 

        serviceRecords[_stationId].push(sr);
        // emit new service event
        emit NewServiceEntry(_stationId, serviceRecords[_stationId].length);
    }

    /**
     * @dev get array of station records
     * 
     */
    function getRecords(uint256 _stationId,uint256 _startRecordIndex, uint256 _amountOfStations)
    public
    view 
    returns(StationRecord[] memory)
    {

        require(serviceRecords[_stationId].length >= _amountOfStations, "Start index cannot surpass record amount");

        uint256 newIndex = 0;
        StationRecord[] memory tempList = new StationRecord[](_amountOfStations);

        for(uint i = 0;i < _amountOfStations; i++){
            tempList[newIndex] = serviceRecords[_stationId][_startRecordIndex + i];
            newIndex += 1;
        }
        return (tempList);
    }
    
    /*************** Station State/Ownership ****************/

    /**
     * @dev allows station ownership to be change
     */
    function changeStationOwner(uint256 _stationId, address _newOwner)
    public
    onlyStationOwner(_stationId)
    {
        PowerStation memory ps = powerStations[_stationId];
        ps.organization = _newOwner;
        ps.lastUpdated = block.timestamp;
        powerStations[_stationId] = ps;
        // emit station owner change
        emit StationOwnerChanged(_stationId,_newOwner);
    }


    /**
     * @dev allows station ownership to be change 
     */
    function changeStationState(uint256 _stationId, StationState _newState)
    public
    onlyStationOwner(_stationId)
    {
        PowerStation memory ps = powerStations[_stationId];
        ps.state = _newState;
        ps.lastUpdated = block.timestamp;
        powerStations[_stationId] = ps;
        emit StationStateChanged(_stationId,_newState);
    }
}