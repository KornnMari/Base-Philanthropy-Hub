// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

contract AuraPhilanthropyHub {
    struct Campaign {
        address payable creator;
        uint256 goalWei;
        uint256 raisedWei;
        bool isActive;
        bytes32 purposeHash;
    }

    address payable public immutable hubAdmin;
    string public hubDescriptor;
    uint256 public platformFeeBps; // 200 = 2%
    uint256 public campaignCounter;
    uint256 public accumulatedFees;
    bool public isHubHalted;

    mapping(uint256 => Campaign) public campaigns;

    event CampaignLaunched(uint256 indexed campaignId, address indexed creator, uint256 goal);
    event CampaignCanceled(uint256 indexed campaignId);
    event DonationReceived(uint256 indexed campaignId, address indexed donor, uint256 amount);
    event TreasuryDeposited(address indexed funder, uint256 amount);
    event ReservesDrained(address indexed admin, uint256 amount);
    event FeesGathered(address indexed admin, uint256 amount);
    event HubHaltToggled(bool isHalted);
    event DescriptorUpdated(string newDescriptor);
    event FundsWithdrawn(uint256 indexed campaignId, uint256 netAmount);

    modifier onlyAdmin() {
        require(msg.sender == hubAdmin, "AuraCharity: Access denied");
        _;
    }

    modifier whenNotHalted() {
        require(!isHubHalted, "AuraCharity: Hub is halted");
        _;
    }

    constructor() {
        hubAdmin = payable(msg.sender);
        hubDescriptor = "Aura Base Philanthropy Hub v1";
        platformFeeBps = 200; // 2%
        isHubHalted = false;
    }

    // 1. cancelFundraiser
    function cancelFundraiser(uint256 campaignId) external {
        Campaign storage c = campaigns[campaignId];
        require(campaignId > 0 && campaignId <= campaignCounter, "AuraCharity: Invalid ID");
        require(msg.sender == c.creator || msg.sender == hubAdmin, "AuraCharity: Unauthorized");
        require(c.isActive, "AuraCharity: Already inactive");

        c.isActive = false;
        emit CampaignCanceled(campaignId);
    }

    // 2. depositHubTreasury
    function depositHubTreasury() external payable whenNotHalted {
        require(msg.value > 0, "AuraCharity: Zero deposit");
        accumulatedFees += msg.value;
        emit TreasuryDeposited(msg.sender, msg.value);
    }

    // 3. donateToCampaign
    function donateToCampaign(uint256 campaignId) external payable whenNotHalted {
        Campaign storage c = campaigns[campaignId];
        require(campaignId > 0 && campaignId <= campaignCounter, "AuraCharity: Invalid ID");
        require(c.isActive, "AuraCharity: Campaign inactive");
        require(msg.value > 0, "AuraCharity: Zero donation");

        c.raisedWei += msg.value;
        emit DonationReceived(campaignId, msg.sender, msg.value);
    }

    // 4. drainHubReserves
    function drainHubReserves() external onlyAdmin {
        uint256 balance = address(this).balance;
        require(balance > 0, "AuraCharity: Zero balance");

        accumulatedFees = 0;
        (bool sent, ) = hubAdmin.call{value: balance}("");
        require(sent, "AuraCharity: Sweep failed");

        emit ReservesDrained(hubAdmin, balance);
    }

    // 5. gatherPlatformFees
    function gatherPlatformFees() external onlyAdmin {
        uint256 amount = accumulatedFees;
        require(amount > 0, "AuraCharity: Zero fees");

        accumulatedFees = 0;
        (bool sent, ) = hubAdmin.call{value: amount}("");
        require(sent, "AuraCharity: Harvest failed");

        emit FeesGathered(hubAdmin, amount);
    }

    // 6. haltDonationHub
    function haltDonationHub(bool isHalted) external onlyAdmin {
        isHubHalted = isHalted;
        emit HubHaltToggled(isHalted);
    }

    // 7. launchFundraiser
    function launchFundraiser(uint256 goalWei, bytes32 purposeHash) external whenNotHalted returns (uint256) {
        require(goalWei > 0, "AuraCharity: Zero goal");

        campaignCounter++;
        campaigns[campaignCounter] = Campaign({
            creator: payable(msg.sender),
            goalWei: goalWei,
            raisedWei: 0,
            isActive: true,
            purposeHash: purposeHash
        });

        emit CampaignLaunched(campaignCounter, msg.sender, goalWei);
        return campaignCounter;
    }

    // 8. updateHubDescriptor
    function updateHubDescriptor(string calldata newDescriptor) external onlyAdmin {
        require(bytes(newDescriptor).length > 0, "AuraCharity: Empty string");
        hubDescriptor = newDescriptor;
        emit DescriptorUpdated(newDescriptor);
    }

    // 9. withdrawCampaignFunds
    function withdrawCampaignFunds(uint256 campaignId) external {
        Campaign storage c = campaigns[campaignId];
        require(campaignId > 0 && campaignId <= campaignCounter, "AuraCharity: Invalid ID");
        require(msg.sender == c.creator, "AuraCharity: Unauthorized");
        require(c.isActive, "AuraCharity: Campaign inactive");
        require(c.raisedWei > 0, "AuraCharity: No funds to withdraw");

        uint256 totalRaised = c.raisedWei;
        c.raisedWei = 0;
        c.isActive = false; 

        uint256 fee = (totalRaised * platformFeeBps) / 10000;
        uint256 netPayout = totalRaised - fee;
        
        accumulatedFees += fee;

        (bool sent, ) = c.creator.call{value: netPayout}("");
        require(sent, "AuraCharity: Transfer failed");

        emit FundsWithdrawn(campaignId, netPayout);
    }
}