// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IMailbox {
    function dispatch(
        uint32 destinationDomain,
        bytes32 recipient,
        bytes calldata messageBody
    ) external payable returns (bytes32);
}

/// @title Lumina Protocol Fixed 
contract LuminaProtocol is ERC721, Ownable {
    using Strings for uint256;
    
    IMailbox public immutable mailbox;
    uint256 private _tokenIds;
    uint256 public constant MAX_MESSAGE_LENGTH = 280;
    uint256 public constant MIN_GAS_PAYMENT = 0.0001 ether;
    
    bool private _locked;
    
    modifier nonReentrant() {
        require(!_locked, "ReentrancyGuard: reentrant call");
        _locked = true;
        _;
        _locked = false;
    }
    
    struct LuminousMessage {
        address sender;
        string content;
        uint256 timestamp;
        string resonance;
        bytes32 essence;
        bool crossChainConfirmed;
        uint256 nftTokenId;
        uint32 destinationDomain;
        uint32 originDomain;  
    }
    
    struct LuminousNFT {
        uint256 messageId;
        string resonance;
        uint256 timestamp;
        bytes32 essence;
        bool isCommemorative;
    }
    
    
    struct ConfirmationMessage {
        bytes32 originalEssence;
        uint256 nftTokenId;
        bool confirmed;
    }
    
    mapping(uint256 => LuminousMessage) public messages;
    mapping(uint256 => LuminousNFT) public luminousNFTs;
    mapping(bytes32 => bool) public illuminated;
    mapping(bytes32 => uint256) public essenceToMessageId;
    mapping(string => uint256) public resonanceCount;
    mapping(uint32 => bytes32) public crossChainContracts; 
    uint256 public messageCount;
    
    event LightSent(
        uint256 indexed messageId, 
        address indexed sender, 
        string content, 
        string resonance,
        uint32 destinationDomain
    );
    event LightReceived(
        uint256 indexed messageId, 
        address indexed sender, 
        bytes32 essence
    );
    event CommemorativeNFTMinted(
        uint256 indexed tokenId, 
        uint256 indexed messageId, 
        address indexed recipient,
        string resonance
    );
    event CrossChainConfirmed(
        bytes32 indexed essence,
        uint256 indexed messageId
    );
    
    error LightAlreadyExists();
    error MessageTooLong();
    error InsufficientGasPayment();
    error OnlyMailboxAllowed();
    error TokenNotFound();
    error InvalidResonance();
    
    constructor(address _mailbox) ERC721("Lumina Commemorative", "LUMINA") Ownable(msg.sender) {
        if (_mailbox == address(0)) revert InvalidResonance();
        mailbox = IMailbox(_mailbox);
        _tokenIds = 0;
        _locked = false;
    }
    
    /// @notice 
    function setCrossChainContract(uint32 domain, bytes32 contractAddress) external onlyOwner {
        crossChainContracts[domain] = contractAddress;
    }
    
    /// @notice Send a luminous message across chains
    function illuminate(
        uint32 destinationDomain,
        bytes32 recipient,
        string calldata content,
        string calldata resonance
    ) external payable nonReentrant {
        if (bytes(content).length > MAX_MESSAGE_LENGTH) revert MessageTooLong();
        if (msg.value < MIN_GAS_PAYMENT) revert InsufficientGasPayment();
        if (bytes(resonance).length == 0) revert InvalidResonance();
        
        bytes32 essence = keccak256(abi.encodePacked(
            msg.sender,
            content,
            block.timestamp,
            resonance,
            messageCount,
            block.chainid
        ));
        
        if (illuminated[essence]) revert LightAlreadyExists();
        
        // Store message
        messages[messageCount] = LuminousMessage({
            sender: msg.sender,
            content: content,
            timestamp: block.timestamp,
            resonance: resonance,
            essence: essence,
            crossChainConfirmed: false,
            nftTokenId: 0,
            destinationDomain: destinationDomain,
            originDomain: uint32(block.chainid)
        });
        
        illuminated[essence] = true;
        essenceToMessageId[essence] = messageCount;
        resonanceCount[resonance]++;
        
        bytes memory messageBody = abi.encode(messages[messageCount]);
        
        mailbox.dispatch{value: msg.value}(
            destinationDomain,
            recipient,
            messageBody
        );
        
        emit LightSent(messageCount, msg.sender, content, resonance, destinationDomain);
        
        messageCount++;
    }
    
    /// @notice Handle incoming cross-chain messages
    function handle(
        uint32 originDomain,
        bytes32 sender,
        bytes calldata body
    ) external nonReentrant {
        if (msg.sender != address(mailbox)) revert OnlyMailboxAllowed();
        
        
        try this.decodeConfirmation(body) returns (ConfirmationMessage memory confirmation) {
            
            _handleConfirmation(confirmation);
            return;
        } catch {
            
        }
        
        
        LuminousMessage memory receivedMessage = abi.decode(body, (LuminousMessage));
        
        if (!illuminated[receivedMessage.essence]) {
            
            messages[messageCount] = receivedMessage;
            illuminated[receivedMessage.essence] = true;
            essenceToMessageId[receivedMessage.essence] = messageCount;
            resonanceCount[receivedMessage.resonance]++;
            
            
            _mintCommemorativeNFT(receivedMessage.sender, messageCount);
            
            emit LightReceived(messageCount, receivedMessage.sender, receivedMessage.essence);
            
            
            _sendConfirmation(receivedMessage, messageCount);
            
            messageCount++;
        }
    }
    
    /// @notice 
    function decodeConfirmation(bytes calldata body) external pure returns (ConfirmationMessage memory) {
        return abi.decode(body, (ConfirmationMessage));
    }
    
    /// @notice 
    function _handleConfirmation(ConfirmationMessage memory confirmation) internal {
        if (!illuminated[confirmation.originalEssence]) return;
        
        uint256 originalMessageId = essenceToMessageId[confirmation.originalEssence];
        LuminousMessage storage originalMessage = messages[originalMessageId];
        
        if (!originalMessage.crossChainConfirmed && confirmation.confirmed) {
            originalMessage.crossChainConfirmed = true;
            emit CrossChainConfirmed(confirmation.originalEssence, originalMessageId);
        }
    }
    
    /// @notice 发送确认消息到源链
    function _sendConfirmation(LuminousMessage memory originalMessage, uint256 newMessageId) internal {
        bytes32 sourceContract = crossChainContracts[originalMessage.originDomain];
        if (sourceContract == bytes32(0)) return; // 没有配置源链合约地址
        
        ConfirmationMessage memory confirmation = ConfirmationMessage({
            originalEssence: originalMessage.essence,
            nftTokenId: _tokenIds, // 当前铸造的NFT ID
            confirmed: true
        });
        
        bytes memory confirmationBody = abi.encode(confirmation);
        
        // 使用较少的gas发送确认
        try mailbox.dispatch{value: 0.0001 ether}(
            originalMessage.originDomain,
            sourceContract,
            confirmationBody
        ) {
            // 确认发送成功
        } catch {
            // 确认发送失败，但不影响NFT铸造
        }
    }
    
    /// @notice Mint commemorative NFT
    function _mintCommemorativeNFT(address recipient, uint256 messageId) internal {
        _tokenIds++;
        uint256 newTokenId = _tokenIds;
        
        messages[messageId].nftTokenId = newTokenId;
        
        luminousNFTs[newTokenId] = LuminousNFT({
            messageId: messageId,
            resonance: messages[messageId].resonance,
            timestamp: messages[messageId].timestamp,
            essence: messages[messageId].essence,
            isCommemorative: true
        });
        
        _safeMint(recipient, newTokenId);
        
        emit CommemorativeNFTMinted(newTokenId, messageId, recipient, messages[messageId].resonance);
    }
    
    /// @notice Simple token URI - external metadata
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        if (ownerOf(tokenId) == address(0)) revert TokenNotFound();
        
        LuminousNFT memory nft = luminousNFTs[tokenId];
        
        string memory json = string(abi.encodePacked(
            '{"name": "Lumina Commemorative #', tokenId.toString(), '",',
            '"description": "A commemorative NFT for cross-chain luminous message transmission.",',
            '"attributes": [',
            '{"trait_type": "Resonance", "value": "', nft.resonance, '"},',
            '{"trait_type": "Type", "value": "Commemorative"},',
            '{"trait_type": "Timestamp", "value": ', nft.timestamp.toString(), '}',
            ']}'
        ));
        
        return string(abi.encodePacked(
            "data:application/json;base64,",
            Base64.encode(bytes(json))
        ));
    }
    
    /// @notice Get all messages
    function getAllLights() external view returns (LuminousMessage[] memory) {
        LuminousMessage[] memory allMessages = new LuminousMessage[](messageCount);
        for (uint256 i = 0; i < messageCount; i++) {
            allMessages[i] = messages[i];
        }
        return allMessages;
    }
    
    /// @notice Get user's NFTs
    function getUserNFTs(address user) external view returns (uint256[] memory) {
        uint256 balance = balanceOf(user);
        if (balance == 0) return new uint256[](0);
        
        uint256[] memory tokenIds = new uint256[](balance);
        uint256 index = 0;
        
        for (uint256 i = 1; i <= _tokenIds && index < balance; i++) {
            try this.ownerOf(i) returns (address owner) {
                if (owner == user) {
                    tokenIds[index] = i;
                    index++;
                }
            } catch {
                continue;
            }
        }
        
        return tokenIds;
    }
    
    /// @notice Get total supply
    function totalSupply() external view returns (uint256) {
        return _tokenIds;
    }
    
    /// @notice Emergency withdraw (owner only)
    function emergencyWithdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
    
    /// @notice Check if message is confirmed
    function isMessageConfirmed(uint256 messageId) external view returns (bool) {
        return messages[messageId].crossChainConfirmed;
    }
    
    /// @notice 添加gas费用到合约 (owner only)
    function addGas() external payable onlyOwner {
        // 用于确保合约有足够ETH发送确认消息
    }
}