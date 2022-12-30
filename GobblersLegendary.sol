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
}

interface IGobblers {
    function mintFromGoo(uint256 maxPrice, bool useVirtual) external returns (uint);
    function mintLegendaryGobbler(uint256[] calldata gobblerIds) external returns (uint);
    function gooBalance(address user) view external returns(uint256);
    function transferFrom(address, address, uint256) external;
    function setApprovalForAll(address operator, bool _approved) external;
    function balanceOf(address) external view returns (uint);
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
    address public dao;
    IGobblers constant public gobblers = IGobblers(0x60bb1e2AA1c9ACAfB4d34F71585D7e959f387769);
    IERC20 constant public goo = IERC20(0x600000000a36F3cD48407e35eB7C5c910dc1f7a8);
    uint256 public nextLegendaryPrice = 69;

    constructor(address _dao) {
        dao = _dao;
    }

    // @notice Update legendary price to reuse this contract
    function updateNextLegendaryPrice(uint256 price) public onlyOwner {
        nextLegendaryPrice = price;
    }

    // @notice Mint legendary Gobbler NFT by burning gobblers
    // @param amountGobblers The amount of Gobblers to mint from all available GOO
    // @param gobblerIds Ids of Gobblers to be burned
    function mint(uint256 amountGobblers, uint256[] calldata gobblerIds) public {
        require(gobblerIds.length == nextLegendaryPrice, "Unsufficient gobblers");
        uint256 startingBalance = gobblers.balanceOf(dao);
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
            newGobblers[i] = gobblers.mintFromGoo(type(uint256).max, false); // useVirtual = false because 
GOO is real ERC20 
        // =================================
        // Mint Legendary NFT by burning gobblerIds
        // =================================
        uint256 idLegendary = gobblers.mintLegendaryGobbler(gobblerIds);
        // =================================
        // Withdraw result: Legendary NFT, remaining GOO and new Gobblers
        // =================================
        gobblers.transferFrom(address(this), dao, idLegendary);
        goo.transferFrom(address(this), dao, goo.balanceOf(address(this)));
        for (uint8 i = 0; i < newGobblers.length; ++i)
            gobblers.transferFrom(address(this), dao, newGobblers[i]);
        // final check
        require(gobblers.balanceOf(dao) == startingBalance - nextLegendaryPrice + newGobblers.length + 1, 
"Something wrong");
    }

    // @notice Withdraw ERC721/ERC20 tokens by owner. For ERC20 tokenId is amount to withdraw
    function withdrawToken(address contract_address, address recipient, uint256 tokenId) public onlyOwner {
        IGobblers(contract_address).transferFrom(address(this), recipient, tokenId);
    }
}