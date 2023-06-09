var Spectrum = artifacts.require('Spectrum');


contract('Power Factory Test', function(accounts) {

    var spectrum;

    const contractOwner = accounts[0];
    const organization = accounts[1];
    const organizationTwo = accounts[2]
    const buyer = accounts[3];

    // station variables
    // [0] == 1 negative coord
    // [1] index of the decimal
    const lat = 1
    const long = 2

    // [0] is the index of decimal
    const installCapacity = 260000  // 600.00
    const sellCapactiy = 240000     // 40.00
    const pricePerMW = 5          // 5.0
    const generationType = 2        // wind
    const state = 1

    // Get power stations
    const startIndex = 0;
    const amountOfStations = 1;

    const stationId = 0

    beforeEach(async () => {
        spectrum = await Spectrum.new({from:contractOwner});
    })

    it('Testing whitelisting', async function() {

        let isWhiteListed = await spectrum.isWhiteListed(organization);
        assert.equal(isWhiteListed,false,"Organization should not be whitelisted.");

        await spectrum.setWhiteList(organization,{from:contractOwner});
        var logData;
        await spectrum.getPastEvents('WhiteListUpdated', {
            fromBlock: 0,
            toBlock: 'latest'
        }, (error, events) => { console.log(events,error); })
        .then((events) => {
            let log = web3.eth.abi.decodeLog([
            {
                type: 'address',
                name: '_newAddress',
                indexed: false
            },{
                type: 'bool',
                name: '_status',
                indexed: false
            }],events[0].raw.data)
            logData = log;
        });

        assert.equal(logData['0'],organization, "Incorrect address registered");

        let isWhiteListedAfter = await spectrum.isWhiteListed(organization);
        assert.equal(isWhiteListedAfter,true,"Organization should be whitelisted after setting");
    })
    
    it('Testing station creation', async function() {
        await spectrum.setWhiteList(organization,{from:contractOwner});
        
        const stationAmountBefore = await spectrum.getStationAmount();
        assert.equal(stationAmountBefore,0,"Incorrect station amount before creation");

        await spectrum.addStation(lat,long,installCapacity,sellCapactiy,pricePerMW,generationType,state,{from:organization});
        var seconds = Math.round(Date.now() / 1000);

        const stationAmountAfter = await spectrum.getStationAmount();
        assert.equal(stationAmountAfter,1,"Incorrect station amount after creation");

        const stations = await spectrum.getStations(startIndex,amountOfStations,{from:organization});

        assert.equal(stations[0].location.lat,lat,"Incorrect lat");
        assert.equal(stations[0].location.long,long,"Incorrect long ");
        assert.equal(stations[0].installedCapacity,installCapacity,"Incorrect install capacity");
        assert.equal(stations[0].sellCapacity,sellCapactiy,"Incorrect sell capacity");
        assert.equal(stations[0].targetReserveCapacity,0,"Incorrect target reserve capacity");
        assert.equal(stations[0].pricePerMW,pricePerMW,"Incorrect price per meg watt");
        assert.equal(stations[0].timeCreated,seconds,"Incorrect time created");
        assert.equal(stations[0].generationType,generationType,"Incorrect generation type");
        assert.equal(stations[0].state,state,"Incorrect state");
        assert.equal(stations[0].organization,organization,"Incorrect Organization");
    })
   
    it("Testing station capacity", async function() {
        // Whitelist and create station
        await spectrum.setWhiteList(organization,{from:contractOwner});
        await spectrum.addStation(lat,long,installCapacity,sellCapactiy,pricePerMW,generationType,state,{from:organization});
        
        const newRate = 4000 // MW

        await spectrum.targetReserveCapacity(stationId,newRate,{from:organization});
        
        let stations = await spectrum.getStations(startIndex,amountOfStations,{from:organization});

        assert.equal(stations[0].targetReserveCapacity,newRate,"Incorrect Target rate");

    })

    it("Testing station sell capacity", async function() {
        await spectrum.setWhiteList(organization,{from:contractOwner});
        await spectrum.addStation(lat,long,installCapacity,sellCapactiy,pricePerMW,generationType,state,{from:organization});
        
        const _newSellCapacity = 500
       
        await spectrum.updateStationSellCapacity(stationId,_newSellCapacity,{from:organization});

        let stations = await spectrum.getStations(startIndex,amountOfStations,{from:organization});

        assert.equal(stations[0].sellCapacity,_newSellCapacity,"Incorrect Target sell capacity");
    })


    it("Testing station buy capacity", async function() {
        await spectrum.setWhiteList(organization,{from:contractOwner});
        await spectrum.addStation(lat,long,installCapacity,sellCapactiy,pricePerMW,generationType,state,{from:organization});

        const surcharge = web3.utils.toWei("2",'ether');
        await spectrum.setSurcharge(stationId,surcharge,{from:contractOwner});

        // ignore exchange rate between ether and power 
        const amountOfEmergy = 1 // 10 MW only whole numbers 
        const diff = sellCapactiy - amountOfEmergy;

        let buyerBalanceBefore = await web3.eth.getBalance(buyer);

        let ethAmount = web3.utils.toWei("20", 'ether'); // beyond the scope of supplychain

        await spectrum.buyCapacity(stationId,amountOfEmergy,{from:buyer, value:ethAmount});
        let stations = await spectrum.getStations(startIndex,amountOfStations,{from:organization});
        
        let buyerBalanceAfter = await web3.eth.getBalance(buyer);

        let organizationBalance = await web3.eth.getBalance(organization);

        // default balance 100
        assert.notEqual(organizationBalance, 100,"Incorrect organization balance");

        assert.notEqual(buyerBalanceBefore, buyerBalanceAfter, "Incorrect buyer balance");

        assert.equal(stations[0].sellCapacity, diff ,"Incorrect sell capacity");
    })

    it("Testing station service entry", async function() {
        await spectrum.setWhiteList(organization,{from:contractOwner});
        await spectrum.addStation(lat,long,installCapacity,sellCapactiy,pricePerMW,generationType,state,{from:organization});

        const reportUrl = "http://report"

        await spectrum.newServiceEntry(stationId,reportUrl,{from:organization});

        const recordCount = await spectrum.getRecordCount(stationId);
        assert.equal(recordCount,1,"Station record is incorrect");

        const startIndex = 0;
        const amount = 1;
        var seconds = Math.round(Date.now() / 1000);
        
        const records = await spectrum.getRecords(stationId,startIndex,amount);
        assert.equal(records[0].reportDate,seconds,"Incorrect report time");
        assert.equal(records[0].report,reportUrl,"Incorrect report url");
    })

    it("Testing station change ownership", async function() {
        await spectrum.setWhiteList(organization,{from:contractOwner});
        await spectrum.addStation(lat,long,installCapacity,sellCapactiy,pricePerMW,generationType,state,{from:organization});

        const stations = await spectrum.getStations(startIndex,amountOfStations,{from:organization});
        assert.equal(stations[0].organization, organization, "Incorrect Station Owner");

        await spectrum.changeStationOwner(stationId,organizationTwo,{from:organization});
        const stationsTwo = await spectrum.getStations(startIndex,amountOfStations,{from:organization});
        assert.equal(stationsTwo[0].organization,organizationTwo,"Incorrect Organization Two");
    })
    
    it("Testing station change state", async function() {
        await spectrum.setWhiteList(organization,{from:contractOwner});
        await spectrum.addStation(lat,long,installCapacity,sellCapactiy,pricePerMW,generationType,state,{from:organization});

        const stations = await spectrum.getStations(startIndex,amountOfStations,{from:organization});
        console.log(stations);

        assert.equal(stations[0].state, 1, "Incorrect Organization");
        await spectrum.changeStationState(stationId,1,{from:organization})

        const stationsOne = await spectrum.getStations(startIndex,amountOfStations,{from:organization});
        console.log(stationsOne);

        assert.equal(stationsOne[0].organization, organizationTwo, "Incorrect Organization Two");
    })
})