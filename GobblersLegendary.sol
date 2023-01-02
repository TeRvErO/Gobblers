// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

/// @notice A generic interface for a contract which properly accepts ERC721 tokens.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC721.sol)
abstract contract ERC721TokenReceiver {
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external virtual returns (bytes4) {
        return ERC721TokenReceiver.onERC721Received.selector;
    }
}

interface IERC20 {
    function balanceOf(address) external view returns (uint);
    function approve(address, uint256) external;
    function transferFrom(address, address, uint256) external;
    function transfer(address, uint256) external;
}

interface IGobblers {
    struct LegendaryGobblerAuctionData {
        uint128 startPrice;
        uint128 numSold;
    }
    function mintFromGoo(uint256 maxPrice, bool useVirtual) external returns (uint);
    function mintLegendaryGobbler(uint256[] calldata gobblerIds) external returns (uint);
    function gooBalance(address user) view external returns(uint256);
    function transferFrom(address, address, uint256) external;
    function setApprovalForAll(address operator, bool _approved) external;
    function balanceOf(address) external view returns (uint);
    function mintStart() external view returns (uint256);
    function numMintedFromGoo() external view returns (uint256);
    function getVRGDAPrice(int256 timeSinceStart, uint256 sold) external view returns (uint256);
    function legendaryGobblerAuctionData() external view returns(LegendaryGobblerAuctionData memory);
    function LEGENDARY_AUCTION_INTERVAL() external view returns (uint256);
}

/// @dev Takes an integer amount of seconds and converts it to a wad amount of days.
/// @dev Will not revert on overflow, only use where overflow is not possible.
/// @dev Not meant for negative second amounts, it assumes x is positive.
function toDaysWadUnsafe(uint256 x) pure returns (int256 r) {
    /// @solidity memory-safe-assembly
    assembly {
        // Multiply x by 1e18 and then divide it by 86400.
        r := div(mul(x, 1000000000000000000), 86400)
    }
}

contract Owned {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner, "!owner");
        _;
    }
}

contract MintLegendary is Owned, ERC721TokenReceiver {
    address public dao = 0xA848A2F4d6E21c6C4154c78b155bB04B4C14a3Bd;
    IGobblers constant public gobblers = IGobblers(0x60bb1e2AA1c9ACAfB4d34F71585D7e959f387769);
    IERC20 constant public goo = IERC20(0x600000000a36F3cD48407e35eB7C5c910dc1f7a8);
    uint256 public nextLegendaryPrice = 69;

    constructor() {}

    // @notice Mint legendary Gobbler NFT by burning gobblers
    // @param amountGobblers The amount of Gobblers to mint from all available GOO
    // @param gobblerIds Ids of Gobblers to be burned
    function mint(uint256 amountGobblers, uint256[] calldata gobblerIds) public {
        require(gobblerIds.length == nextLegendaryPrice, "Unsufficient gobblers");
        require(costGoo(amountGobblers) <= goo.balanceOf(dao), "Unsufficient GOO");
        uint256 nextNumMintedFromGoo = gobblers.numMintedFromGoo() + amountGobblers;
        uint256 numTriggerLegendary = (gobblers.legendaryGobblerAuctionData().numSold + 1) * gobblers.LEGENDARY_AUCTION_INTERVAL();
        require(nextNumMintedFromGoo == numTriggerLegendary, "Unsufficient amountGobblers");
        uint256 balanceGobblers = gobblers.balanceOf(dao);
        // =================================
        // Transfer GOO and NFTs to this contract
        // =================================
        goo.transferFrom(dao, address(this), goo.balanceOf(dao));
        for (uint8 i = 0; i < gobblerIds.length; ++i)
            gobblers.transferFrom(dao, address(this), gobblerIds[i]);
        // =================================
        // Mint amountGobblers Gobblers from GOO
        // =================================
        uint[] memory newGobblers = new uint[](amountGobblers);
        goo.approve(address(gobblers), type(uint256).max);
        for (uint8 i = 0; i < amountGobblers; ++i)
            // useVirtual = false because GOO is real ERC20 
            newGobblers[i] = gobblers.mintFromGoo(type(uint256).max, false); 
        // =================================
        // Mint Legendary NFT by burning gobblerIds
        // =================================
        uint256 idLegendary = gobblers.mintLegendaryGobbler(gobblerIds);
        // =================================
        // Withdraw result: Legendary NFT, remaining GOO and new Gobblers
        // =================================
        gobblers.transferFrom(address(this), dao, idLegendary);
        goo.transfer(dao, goo.balanceOf(address(this)));
        for (uint8 i = 0; i < newGobblers.length; ++i)
            gobblers.transferFrom(address(this), dao, newGobblers[i]);
        // final check
        require(gobblers.balanceOf(dao) == balanceGobblers - nextLegendaryPrice + newGobblers.length + 1, "Something wrong");
    }

    // @notice Update legendary price to reuse this contract
    function updateNextLegendaryPrice(uint256 price) public onlyOwner {
        nextLegendaryPrice = price;
    }

    // @notice Get GOO cost of minting amountGobblers
    // @param amountGobblers The amount of Gobblers
    function costGoo(uint256 amountGobblers) public view returns (uint256 cost) {
        uint256 timeSinceStart = block.timestamp - gobblers.mintStart();
        for (uint8 i = 0; i < amountGobblers; ++i)
            cost += gobblers.getVRGDAPrice(toDaysWadUnsafe(timeSinceStart), gobblers.numMintedFromGoo() + i);
    }

    // @notice Withdraw ERC721/ERC20 tokens by owner. For ERC20 tokenId is amount to withdraw
    function withdrawToken(address contract_address, address recipient, uint256 tokenId) public onlyOwner {
        IGobblers(contract_address).transferFrom(address(this), recipient, tokenId);
    }
}