// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract LiskGarden {

    // ============================================
    // BAGIAN 1: ENUM & STRUCT
    // ============================================

    enum GrowthStage {
        SEED,
        SPROUT,
        GROWING,
        BLOOMING
    }

    struct Plant {
        uint256 id;
        address owner;
        GrowthStage stage;
        uint256 plantedDate;
        uint256 lastWatered;
        uint8 waterLevel;
        bool exists;
        bool isDead;
    }

    // ============================================
    // BAGIAN 2: STATE VARIABLES
    // ============================================

    mapping(uint256 => Plant) public plants;
    mapping(address => uint256[]) public userPlants;
    uint256 public plantCounter;
    address public owner;
    bool private locked; // ReentrancyGuard

    // ============================================
    // BAGIAN 3: CONSTANTS (Game Parameters)
    // ============================================

    uint256 public constant PLANT_PRICE = 0.001 ether;
    uint256 public constant HARVEST_REWARD = 0.0015 ether; // DIPERBAIKI: Lebih kecil dari PLANT_PRICE
    uint256 public constant STAGE_DURATION = 1 minutes;
    uint256 public constant WATER_DEPLETION_TIME = 30 seconds;
    uint8 public constant WATER_DEPLETION_RATE = 2;

    // ============================================
    // BAGIAN 4: EVENTS
    // ============================================

    event PlantSeeded(address indexed owner, uint256 indexed plantId);
    event PlantWatered(uint256 indexed plantId, uint8 newWaterLevel);
    event PlantHarvested(uint256 indexed plantId, address indexed owner, uint256 reward);
    event StageAdvanced(uint256 indexed plantId, GrowthStage newStage);
    event PlantDied(uint256 indexed plantId);

    // ============================================
    // BAGIAN 5: MODIFIERS
    // ============================================

    modifier nonReentrant() {
        require(!locked, "ReentrancyGuard: reentrant call");
        locked = true;
        _;
        locked = false;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Bukan owner");
        _;
    }

    // ============================================
    // BAGIAN 6: CONSTRUCTOR
    // ============================================

    constructor() {
        owner = msg.sender;
    }

    // ============================================
    // BAGIAN 7: PLANT SEED
    // ============================================

    function plantSeed() external payable returns (uint256) {
        require(msg.value >= PLANT_PRICE, "Harga tanam kurang");

        plantCounter++;
        uint256 plantId = plantCounter;

        plants[plantId] = Plant({
            id: plantId,
            owner: msg.sender,
            stage: GrowthStage.SEED,
            plantedDate: block.timestamp,
            lastWatered: block.timestamp,
            waterLevel: 100,
            exists: true,
            isDead: false
        });

        userPlants[msg.sender].push(plantId);

        emit PlantSeeded(msg.sender, plantId);

        return plantId;
    }

    // ============================================
    // BAGIAN 8: WATER SYSTEM
    // ============================================

    function calculateWaterLevel(uint256 plantId) public view returns (uint8) {
        Plant storage plant = plants[plantId];

        if (!plant.exists || plant.isDead) {
            return 0;
        }

        uint256 timeSinceWatered = block.timestamp - plant.lastWatered;
        uint256 depletionIntervals = timeSinceWatered / WATER_DEPLETION_TIME;
        uint256 waterLost = depletionIntervals * WATER_DEPLETION_RATE;

        if (waterLost >= plant.waterLevel) {
            return 0;
        }

        return plant.waterLevel - uint8(waterLost);
    }

    function updateWaterLevel(uint256 plantId) internal {
        Plant storage plant = plants[plantId];

        uint8 currentWater = calculateWaterLevel(plantId);
        plant.waterLevel = currentWater;

        if (currentWater == 0 && !plant.isDead) {
            plant.isDead = true;
            emit PlantDied(plantId);
        }
    }

    function waterPlant(uint256 plantId) external {
        Plant storage plant = plants[plantId];

        require(plant.exists, "Tanaman tidak ada");
        require(plant.owner == msg.sender, "Bukan pemilik");
        require(!plant.isDead, "Tanaman mati");

        plant.waterLevel = 100;
        plant.lastWatered = block.timestamp;

        emit PlantWatered(plantId, 100);

        updatePlantStage(plantId);
    }

    // ============================================
    // BAGIAN 9: STAGE & HARVEST
    // ============================================

    function updatePlantStage(uint256 plantId) public {
        Plant storage plant = plants[plantId];

        require(plant.exists, "Tanaman tidak ada");

        updateWaterLevel(plantId);
        if (plant.isDead) return;

        uint256 timeSincePlanted = block.timestamp - plant.plantedDate;
        GrowthStage oldStage = plant.stage;

        if (timeSincePlanted >= STAGE_DURATION * 3) {
            plant.stage = GrowthStage.BLOOMING;
        } else if (timeSincePlanted >= STAGE_DURATION * 2) {
            plant.stage = GrowthStage.GROWING;
        } else if (timeSincePlanted >= STAGE_DURATION) {
            plant.stage = GrowthStage.SPROUT;
        }

        if (plant.stage != oldStage) {
            emit StageAdvanced(plantId, plant.stage);
        }
    }

    function harvestPlant(uint256 plantId) external nonReentrant {
        Plant storage plant = plants[plantId];

        require(plant.exists, "Tanaman tidak ada");
        require(plant.owner == msg.sender, "Bukan pemilik");
        require(!plant.isDead, "Tanaman mati");

        updatePlantStage(plantId);

        require(plant.stage == GrowthStage.BLOOMING, "Belum siap panen");
        require(address(this).balance >= HARVEST_REWARD, "Saldo contract tidak cukup");

        // CEI Pattern: Checks, Effects, Interactions
        // Effects: Update state SEBELUM transfer
        plant.exists = false;
        
        emit PlantHarvested(plantId, msg.sender, HARVEST_REWARD);

        // Interactions: Transfer di akhir
        (bool success, ) = msg.sender.call{value: HARVEST_REWARD}("");
        require(success, "Transfer gagal");
    }

    // ============================================
    // BAGIAN 10: HELPER FUNCTIONS
    // ============================================

    function getPlant(uint256 plantId) external view returns (Plant memory) {
        Plant memory plant = plants[plantId];
        plant.waterLevel = calculateWaterLevel(plantId);
        return plant;
    }

    function getUserPlants(address user) external view returns (uint256[] memory) {
        return userPlants[user];
    }

    // DIPERBAIKI: Mengembalikan hanya tanaman yang masih exists
    function getActiveUserPlants(address user) external view returns (uint256[] memory) {
        uint256[] memory allPlants = userPlants[user];
        uint256 activeCount = 0;

        // Hitung jumlah tanaman aktif
        for (uint256 i = 0; i < allPlants.length; i++) {
            if (plants[allPlants[i]].exists) {
                activeCount++;
            }
        }

        // Buat array baru dengan tanaman aktif saja
        uint256[] memory activePlants = new uint256[](activeCount);
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < allPlants.length; i++) {
            if (plants[allPlants[i]].exists) {
                activePlants[currentIndex] = allPlants[i];
                currentIndex++;
            }
        }

        return activePlants;
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "Tidak ada saldo");
        
        (bool success, ) = owner.call{value: balance}("");
        require(success, "Transfer gagal");
    }

    receive() external payable {}
}
