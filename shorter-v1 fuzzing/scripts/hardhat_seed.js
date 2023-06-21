const hre = require("hardhat");
const { ethers } = require("hardhat");
// const { ethers, artifacts } from 'hardhat';

async function main() {
  await hre.run('compile');

  const [wallet] = await ethers.getSigners();
 
  const FixedPoint96 = await ethers.getContractFactory("FixedPoint96");
  const fixedpoint96 = await FixedPoint96.deploy();
  await fixedpoint96.deployed();
 
  const TickMath = await ethers.getContractFactory("TickMath");
  const tickmath = await TickMath.deploy();
  await tickmath.deployed();
 
  const LiquidityAmounts = await ethers.getContractFactory("LiquidityAmounts");
  const liquidityamounts = await LiquidityAmounts.deploy();
  await liquidityamounts.deployed();
 
  const OracleLibrary = await ethers.getContractFactory("OracleLibrary");
  const oraclelibrary = await OracleLibrary.deploy();
  await oraclelibrary.deployed();
 
  const PermitLibrary = await ethers.getContractFactory("PermitLibrary");
  const permitlibrary = await PermitLibrary.deploy();
  await permitlibrary.deployed();
 
  const FullMath = await ethers.getContractFactory("FullMath");
  const fullmath = await FullMath.deploy();
  await fullmath.deployed();
 
  const Path = await ethers.getContractFactory("Path");
  const path = await Path.deploy();
  await path.deployed();
 
  const BytesLib = await ethers.getContractFactory("BytesLib");
  const byteslib = await BytesLib.deploy();
  await byteslib.deployed();
 
  const AllyLibrary = await ethers.getContractFactory("AllyLibrary");
  const allylibrary = await AllyLibrary.deploy();
  await allylibrary.deployed();
 
  const BoringMath = await ethers.getContractFactory("BoringMath");
  const boringmath = await BoringMath.deploy();
  await boringmath.deployed();
 
  const Ownable = await ethers.getContractFactory("Ownable");
  const ownable = await Ownable.deploy();
  await ownable.deployed();
 
  const Whitelistable = await ethers.getContractFactory("Whitelistable");
  const whitelistable = await Whitelistable.deploy();
  await whitelistable.deployed();
 
  const EnumerableMap = await ethers.getContractFactory("EnumerableMap");
  const enumerablemap = await EnumerableMap.deploy();
  await enumerablemap.deployed();
 
  const Pausable = await ethers.getContractFactory("contracts/util/Pausable.sol:Pausable");
  const pausable = await Pausable.deploy();
  await pausable.deployed();

  const TradingRewardModelImpl = await ethers.getContractFactory("TradingRewardModelImpl");
  const tradingrewardmodelimpl = await TradingRewardModelImpl.deploy(wallet.address);
  await tradingrewardmodelimpl.deployed();
 
  const FarmingRewardModelImpl = await ethers.getContractFactory("FarmingRewardModelImpl");
  const farmingrewardmodelimpl = await FarmingRewardModelImpl.deploy(wallet.address);
  await farmingrewardmodelimpl.deployed();
 
  const IpistrTokenImpl = await ethers.getContractFactory("IpistrTokenImpl");
  const ipistrtokenimpl = await IpistrTokenImpl.deploy(wallet.address);
  await ipistrtokenimpl.deployed();
 
  const CommitteeImpl = await ethers.getContractFactory("CommitteeImpl");
  const committeeimpl = await CommitteeImpl.deploy(wallet.address);
  await committeeimpl.deployed();
 
  const TreasuryImpl = await ethers.getContractFactory("TreasuryImpl");
  const treasuryimpl = await TreasuryImpl.deploy(wallet.address);
  await treasuryimpl.deployed();
 
  const VaultButlerImpl = await ethers.getContractFactory("VaultButlerImpl");
  const vaultbutlerimpl = await VaultButlerImpl.deploy(wallet.address);
  await vaultbutlerimpl.deployed();
 
  const FarmingImpl = await ethers.getContractFactory("FarmingImpl");
  const farmingimpl = await FarmingImpl.deploy(wallet.address);
  await farmingimpl.deployed();
 
  const PoolGuardianImpl = await ethers.getContractFactory("PoolGuardianImpl", {
      libraries: {
        AllyLibrary: allylibrary.address
    },
  });
  const poolguardianimpl = await PoolGuardianImpl.deploy(wallet.address);
  await poolguardianimpl.deployed();
 
  const GovRewardModelImpl = await ethers.getContractFactory("GovRewardModelImpl");
  const govrewardmodelimpl = await GovRewardModelImpl.deploy(wallet.address);
  await govrewardmodelimpl.deployed();
 
  const VoteRewardModelImpl = await ethers.getContractFactory("VoteRewardModelImpl");
  const voterewardmodelimpl = await VoteRewardModelImpl.deploy(wallet.address);
  await voterewardmodelimpl.deployed();
 
  const PoolRewardModelImpl = await ethers.getContractFactory("PoolRewardModelImpl");
  const poolrewardmodelimpl = await PoolRewardModelImpl.deploy(wallet.address);
  await poolrewardmodelimpl.deployed();
 
  const InterestRateModelImpl = await ethers.getContractFactory("InterestRateModelImpl");
  const interestratemodelimpl = await InterestRateModelImpl.deploy(wallet.address);
  await interestratemodelimpl.deployed();
 
  const TradingHubImpl = await ethers.getContractFactory("TradingHubImpl");
  const tradinghubimpl = await TradingHubImpl.deploy(wallet.address);
  await tradinghubimpl.deployed();
 
  const AuctionHallImpl = await ethers.getContractFactory("AuctionHallImpl");
  const auctionhallimpl = await AuctionHallImpl.deploy(wallet.address);
  await auctionhallimpl.deployed();
 
  const ShorterBone = await ethers.getContractFactory("ShorterBone");
  const shorterbone = await ShorterBone.deploy(wallet.address);
  await shorterbone.deployed();
 
  const FarmingStorage = await ethers.getContractFactory("FarmingStorage");
  const farmingstorage = await FarmingStorage.deploy();
  await farmingstorage.deployed();
 
  const AresStorage = await ethers.getContractFactory("AresStorage");
  const aresstorage = await AresStorage.deploy();
  await aresstorage.deployed();
 
  const VaultStorage = await ethers.getContractFactory("VaultStorage");
  const vaultstorage = await VaultStorage.deploy();
  await vaultstorage.deployed();
 
  const PrometheusStorage = await ethers.getContractFactory("PrometheusStorage");
  const prometheusstorage = await PrometheusStorage.deploy();
  await prometheusstorage.deployed();
 
  const GaiaStorage = await ethers.getContractFactory("GaiaStorage");
  const gaiastorage = await GaiaStorage.deploy();
  await gaiastorage.deployed();
 
  const PoolStateStorage = await ethers.getContractFactory("PoolStateStorage");
  const poolstatestorage = await PoolStateStorage.deploy();
  await poolstatestorage.deployed();
 
  const TokenStorage = await ethers.getContractFactory("TokenStorage");
  const tokenstorage = await TokenStorage.deploy();
  await tokenstorage.deployed();
 
  const TheiaStorage = await ethers.getContractFactory("TheiaStorage");
  const theiastorage = await TheiaStorage.deploy();
  await theiastorage.deployed();
 
  const TradingStorage = await ethers.getContractFactory("TradingStorage");
  const tradingstorage = await TradingStorage.deploy();
  await tradingstorage.deployed();
 
  const ThemisStorage = await ethers.getContractFactory("ThemisStorage");
  const themisstorage = await ThemisStorage.deploy();
  await themisstorage.deployed();
 
  const PoolStorage = await ethers.getContractFactory("PoolStorage");
  const poolstorage = await PoolStorage.deploy();
  await poolstorage.deployed();
 
  const WrappedTokenStorage = await ethers.getContractFactory("WrappedTokenStorage");
  const wrappedtokenstorage = await WrappedTokenStorage.deploy();
  await wrappedtokenstorage.deployed();
 
  const TreasuryStorage = await ethers.getContractFactory("TreasuryStorage");
  const treasurystorage = await TreasuryStorage.deploy();
  await treasurystorage.deployed();
 
  const PoolRewardModelStorage = await ethers.getContractFactory("PoolRewardModelStorage");
  const poolrewardmodelstorage = await PoolRewardModelStorage.deploy();
  await poolrewardmodelstorage.deployed();
 
  const InterestRateModelStorage = await ethers.getContractFactory("InterestRateModelStorage");
  const interestratemodelstorage = await InterestRateModelStorage.deploy();
  await interestratemodelstorage.deployed();
 
  const VoteRewardModelStorage = await ethers.getContractFactory("VoteRewardModelStorage");
  const voterewardmodelstorage = await VoteRewardModelStorage.deploy();
  await voterewardmodelstorage.deployed();
 
  const FarmingRewardModelStorage = await ethers.getContractFactory("FarmingRewardModelStorage");
  const farmingrewardmodelstorage = await FarmingRewardModelStorage.deploy();
  await farmingrewardmodelstorage.deployed();
 
  const GovRewardModelStorage = await ethers.getContractFactory("GovRewardModelStorage");
  const govrewardmodelstorage = await GovRewardModelStorage.deploy();
  await govrewardmodelstorage.deployed();
 
  const TradingRewardModelStorage = await ethers.getContractFactory("TradingRewardModelStorage");
  const tradingrewardmodelstorage = await TradingRewardModelStorage.deploy();
  await tradingrewardmodelstorage.deployed();
 
  const AuctionStorage = await ethers.getContractFactory("AuctionStorage");
  const auctionstorage = await AuctionStorage.deploy();
  await auctionstorage.deployed();
 
  const CommitteStorage = await ethers.getContractFactory("CommitteStorage");
  const committestorage = await CommitteStorage.deploy();
  await committestorage.deployed();
 
  const TitanCoreStorage = await ethers.getContractFactory("TitanCoreStorage");
  const titancorestorage = await TitanCoreStorage.deploy();
  await titancorestorage.deployed();
 
  const PriceOracle = await ethers.getContractFactory("PriceOracle");
  const priceoracle = await PriceOracle.deploy(wallet.address);
  await priceoracle.deployed();
 
  const ShorterFactory = await ethers.getContractFactory("ShorterFactory");
  const shorterfactory = await ShorterFactory.deploy(wallet.address);
  await shorterfactory.deployed();
 
  const EIP712Domain = await ethers.getContractFactory("EIP712Domain");
  const eip712domain = await EIP712Domain.deploy();
  await eip712domain.deployed();
 
  const ERC20 = await ethers.getContractFactory("ERC20");
  const erc20 = await ERC20.deploy();
  await erc20.deployed();
 
  const ChainSchema = await ethers.getContractFactory("ChainSchema");
  const chainschema = await ChainSchema.deploy(wallet.address);
  await chainschema.deployed();
 
  const Affinity = await ethers.getContractFactory("Affinity");
  const affinity = await Affinity.deploy(wallet.address);
  await affinity.deployed();
 
  const DexCenter = await ethers.getContractFactory("DexCenter");
  const dexcenter = await DexCenter.deploy(wallet.address);
  await dexcenter.deployed();
 
  const Rescuable = await ethers.getContractFactory("Rescuable");
  const rescuable = await Rescuable.deploy(committeeimpl.address);
  await rescuable.deployed();
 
  const WrappedTokenImpl = await ethers.getContractFactory("WrappedTokenImpl");
  const wrappedtokenimpl = await WrappedTokenImpl.deploy();
  await wrappedtokenimpl.deployed();
 
  const WrapRouter = await ethers.getContractFactory("WrapRouter");
  const wraprouter = await WrapRouter.deploy(poolguardianimpl.address, wrappedtokenimpl.address);
  await wraprouter.deployed();
 
  const WrappedToken = await ethers.getContractFactory("WrappedToken");
  const wrappedtoken = await WrappedToken.deploy(wrappedtokenimpl.address, wallet.address);
  await wrappedtoken.deployed();
 
  const GrandetieImpl = await ethers.getContractFactory("GrandetieImpl");
  const grandetieimpl = await GrandetieImpl.deploy(committeeimpl.address);
  await grandetieimpl.deployed();
 
  const Grandetie = await ethers.getContractFactory("Grandetie");
  const grandetie = await Grandetie.deploy(grandetieimpl.address, wallet.address, committeeimpl.address);
  await grandetie.deployed();
 
  const PoolGarner = await ethers.getContractFactory("PoolGarner", {
      libraries: {
        AllyLibrary: allylibrary.address
    },
  });
  const poolgarner = await PoolGarner.deploy(wallet.address);
  await poolgarner.deployed();
 
  const UniClassDexCenter = await ethers.getContractFactory("UniClassDexCenter");
  const uniclassdexcenter = await UniClassDexCenter.deploy(wallet.address);
  await uniclassdexcenter.deployed();
 
  const BaseDexCenter = await ethers.getContractFactory("BaseDexCenter");
  const basedexcenter = await BaseDexCenter.deploy(wallet.address);
  await basedexcenter.deployed();
 
  const PoolRewardModel = await ethers.getContractFactory("PoolRewardModel");
  const poolrewardmodel = await PoolRewardModel.deploy(wallet.address, poolrewardmodelimpl.address);
  await poolrewardmodel.deployed();
 
  const FarmingRewardModel = await ethers.getContractFactory("FarmingRewardModel");
  const farmingrewardmodel = await FarmingRewardModel.deploy(wallet.address, farmingrewardmodelimpl.address);
  await farmingrewardmodel.deployed();
 
  const PoolScatter = await ethers.getContractFactory("PoolScatter");
  const poolscatter = await PoolScatter.deploy(wallet.address);
  await poolscatter.deployed();
 
  const IpistrToken = await ethers.getContractFactory("IpistrToken");
  const ipistrtoken = await IpistrToken.deploy(wallet.address, ipistrtokenimpl.address);
  await ipistrtoken.deployed();
 
  const Committee = await ethers.getContractFactory("Committee");
  const committee = await Committee.deploy(wallet.address, committeeimpl.address);
  await committee.deployed();
 
  const TradingRewardModel = await ethers.getContractFactory("TradingRewardModel");
  const tradingrewardmodel = await TradingRewardModel.deploy(wallet.address, tradingrewardmodelimpl.address);
  await tradingrewardmodel.deployed();
 
  const VoteRewardModel = await ethers.getContractFactory("VoteRewardModel");
  const voterewardmodel = await VoteRewardModel.deploy(wallet.address, voterewardmodelimpl.address);
  await voterewardmodel.deployed();
 
  const InterestRateModel = await ethers.getContractFactory("InterestRateModel");
  const interestratemodel = await InterestRateModel.deploy(wallet.address, interestratemodelimpl.address);
  await interestratemodel.deployed();
 
  const GovRewardModel = await ethers.getContractFactory("GovRewardModel");
  const govrewardmodel = await GovRewardModel.deploy(wallet.address, govrewardmodelimpl.address);
  await govrewardmodel.deployed();
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
