const hre = require("hardhat");

async function main() {
    console.log("🌟 Deploying LuminaProtocol (Fixed Version)...");
    
    const network = hre.network.name;
    console.log("Network:", network);
    
    const mailboxAddresses = {
        baseSepolia: "0x6966b0E55883d49BFB24539356a2f8A673E02039",
        sepolia: "0xfFAEF09B3cd11D9b20d1a19bECca54EEC2884766"
    };
    
    const mailboxAddress = mailboxAddresses[network];
    if (!mailboxAddress) {
        throw new Error(`No mailbox for network: ${network}`);
    }
    
    console.log("Using Mailbox:", mailboxAddress);
    
    
    const LuminaProtocol = await hre.ethers.getContractFactory("LuminaProtocol");
    const contract = await LuminaProtocol.deploy(mailboxAddress);
    
    await contract.deployed();
    
    console.log("✅ LuminaProtocol (Fixed) deployed to:", contract.address);
    console.log("🔗 Mailbox:", mailboxAddress);
    console.log("🌐 Network:", network);
    
    if (network === "baseSepolia") {
        console.log("\n🌟 BASE SEPOLIA FIXED CONTRACT DEPLOYED");
        console.log("💫 This is your new source contract");
        console.log("📍 Contract Address:", contract.address);
    } else if (network === "sepolia") {
        console.log("\n🌟 ETHEREUM SEPOLIA FIXED CONTRACT DEPLOYED");
        console.log("💫 This is your new destination contract");
        console.log("📍 Contract Address:", contract.address);
    }
    
    console.log("\n💡 Domain IDs for cross-chain messaging:");
    console.log("Base Sepolia Domain: 84532");
    console.log("Ethereum Sepolia Domain: 11155111");
    
    console.log("\n🔧 Next steps:");
    console.log("1. Deploy to both networks");
    console.log("2. Configure cross-chain contracts using setCrossChainContract()");
    console.log("3. Update frontend with new addresses");
    console.log("4. Test the fixed cross-chain confirmation!");
    
    console.log("\n📝 Remember to save this address for cross-chain setup!");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("❌ Deployment failed:", error);
        process.exit(1);
    });