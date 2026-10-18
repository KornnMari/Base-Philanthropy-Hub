// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;
interface IAuraPhilanthropyHub {
    function donateToCampaign(uint256 campaignId) external payable;
    function launchFundraiser(uint256 goalWei, bytes32 purposeHash) external returns (uint256);
}
