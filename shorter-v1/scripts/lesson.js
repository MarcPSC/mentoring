const hre = require("hardhat");
const { ethers } = require("hardhat");
const { ContractFactory, Contract, utils, BigNumber } = require("ethers");
// const { ethers, artifacts } from 'hardhat';

async function main() {
  await hre.run('compile');

const [savior, wethWallet, usdtWallet, user1, user2, user3] = await ethers.getSigners();


  const FixedPoint96 = await ethers.getContractFactory("FixedPoint96");
  const fixedpoint96 = await FixedPoint96.connect(savior).deploy();
  await fixedpoint96.deployed();

  const TickMath = await ethers.getContractFactory("TickMath");
  const tickmath = await TickMath.connect(savior).deploy();
  await tickmath.deployed();

  const LiquidityAmounts = await ethers.getContractFactory("LiquidityAmounts");
  const liquidityamounts = await LiquidityAmounts.connect(savior).deploy();
  await liquidityamounts.deployed();

  const OracleLibrary = await ethers.getContractFactory("OracleLibrary");
  const oraclelibrary = await OracleLibrary.connect(savior).deploy();
  await oraclelibrary.deployed();

  const PermitLibrary = await ethers.getContractFactory("PermitLibrary");
  const permitlibrary = await PermitLibrary.connect(savior).deploy();
  await permitlibrary.deployed();

  const FullMath = await ethers.getContractFactory("FullMath");
  const fullmath = await FullMath.connect(savior).deploy();
  await fullmath.deployed();

  const Path = await ethers.getContractFactory("Path");
  const path = await Path.connect(savior).deploy();
  await path.deployed();

  const BytesLib = await ethers.getContractFactory("BytesLib");
  const byteslib = await BytesLib.connect(savior).deploy();
  await byteslib.deployed();

  const AllyLibrary = await ethers.getContractFactory("AllyLibrary");
  const allylibrary = await AllyLibrary.connect(savior).deploy();
  await allylibrary.deployed();

  const BoringMath = await ethers.getContractFactory("BoringMath");
  const boringmath = await BoringMath.connect(savior).deploy();
  await boringmath.deployed();

  const Ownable = await ethers.getContractFactory("Ownable");
  const ownable = await Ownable.connect(savior).deploy();
  await ownable.deployed();

  const Whitelistable = await ethers.getContractFactory("Whitelistable");
  const whitelistable = await Whitelistable.connect(savior).deploy();
  await whitelistable.deployed();

  const EnumerableMap = await ethers.getContractFactory("EnumerableMap");
  const enumerablemap = await EnumerableMap.connect(savior).deploy();
  await enumerablemap.deployed();

  const Pausable = await ethers.getContractFactory("contracts/util/Pausable.sol:Pausable");
  const pausable = await Pausable.connect(savior).deploy();
  await pausable.deployed();

  const TradingRewardModelImpl = await ethers.getContractFactory("TradingRewardModelImpl");
  const tradingrewardmodelimpl = await TradingRewardModelImpl.connect(savior).deploy(savior.address);
  await tradingrewardmodelimpl.deployed();

  const FarmingRewardModelImpl = await ethers.getContractFactory("FarmingRewardModelImpl");
  const farmingrewardmodelimpl = await FarmingRewardModelImpl.connect(savior).deploy(savior.address);
  await farmingrewardmodelimpl.deployed();

  const IpistrTokenImpl = await ethers.getContractFactory("IpistrTokenImpl");
  const ipistrtokenimpl = await IpistrTokenImpl.connect(savior).deploy(savior.address);
  await ipistrtokenimpl.deployed();

  const CommitteeImpl = await ethers.getContractFactory("CommitteeImpl");
  const committeeimpl = await CommitteeImpl.connect(savior).deploy(savior.address);
  await committeeimpl.deployed();

  const TreasuryImpl = await ethers.getContractFactory("TreasuryImpl");
  const treasuryimpl = await TreasuryImpl.connect(savior).deploy(savior.address);
  await treasuryimpl.deployed();

  const VaultButlerImpl = await ethers.getContractFactory("VaultButlerImpl");
  const vaultbutlerimpl = await VaultButlerImpl.connect(savior).deploy(savior.address);
  await vaultbutlerimpl.deployed();

  const FarmingImpl = await ethers.getContractFactory("FarmingImpl");
  const farmingimpl = await FarmingImpl.connect(savior).deploy(savior.address);
  await farmingimpl.deployed();

  const PoolGuardianImpl = await ethers.getContractFactory("PoolGuardianImpl", {
      libraries: {
        AllyLibrary: allylibrary.address
    },
  });
  const poolguardianimpl = await PoolGuardianImpl.connect(savior).deploy(savior.address);
  await poolguardianimpl.deployed();

  const GovRewardModelImpl = await ethers.getContractFactory("GovRewardModelImpl");
  const govrewardmodelimpl = await GovRewardModelImpl.connect(savior).deploy(savior.address);
  await govrewardmodelimpl.deployed();

  const VoteRewardModelImpl = await ethers.getContractFactory("VoteRewardModelImpl");
  const voterewardmodelimpl = await VoteRewardModelImpl.connect(savior).deploy(savior.address);
  await voterewardmodelimpl.deployed();

  const PoolRewardModelImpl = await ethers.getContractFactory("PoolRewardModelImpl");
  const poolrewardmodelimpl = await PoolRewardModelImpl.connect(savior).deploy(savior.address);
  await poolrewardmodelimpl.deployed();

  const InterestRateModelImpl = await ethers.getContractFactory("InterestRateModelImpl");
  const interestratemodelimpl = await InterestRateModelImpl.connect(savior).deploy(savior.address);
  await interestratemodelimpl.deployed();

  const TradingHubImpl = await ethers.getContractFactory("TradingHubImpl");
  const tradinghubimpl = await TradingHubImpl.connect(savior).deploy(savior.address);
  await tradinghubimpl.deployed();

  const AuctionHallImpl = await ethers.getContractFactory("AuctionHallImpl");
  const auctionhallimpl = await AuctionHallImpl.connect(savior).deploy(savior.address);
  await auctionhallimpl.deployed();

  const ShorterBone = await ethers.getContractFactory("ShorterBone");
  const shorterbone = await ShorterBone.connect(savior).deploy(savior.address);
  await shorterbone.deployed();

  const FarmingStorage = await ethers.getContractFactory("FarmingStorage");
  const farmingstorage = await FarmingStorage.connect(savior).deploy();
  await farmingstorage.deployed();

  const AresStorage = await ethers.getContractFactory("AresStorage");
  const aresstorage = await AresStorage.connect(savior).deploy();
  await aresstorage.deployed();

  const VaultStorage = await ethers.getContractFactory("VaultStorage");
  const vaultstorage = await VaultStorage.connect(savior).deploy();
  await vaultstorage.deployed();

  const PrometheusStorage = await ethers.getContractFactory("PrometheusStorage");
  const prometheusstorage = await PrometheusStorage.connect(savior).deploy();
  await prometheusstorage.deployed();

  const GaiaStorage = await ethers.getContractFactory("GaiaStorage");
  const gaiastorage = await GaiaStorage.connect(savior).deploy();
  await gaiastorage.deployed();

  const PoolStateStorage = await ethers.getContractFactory("PoolStateStorage");
  const poolstatestorage = await PoolStateStorage.connect(savior).deploy();
  await poolstatestorage.deployed();

  const TokenStorage = await ethers.getContractFactory("TokenStorage");
  const tokenstorage = await TokenStorage.connect(savior).deploy();
  await tokenstorage.deployed();

  const TheiaStorage = await ethers.getContractFactory("TheiaStorage");
  const theiastorage = await TheiaStorage.connect(savior).deploy();
  await theiastorage.deployed();

  const TradingStorage = await ethers.getContractFactory("TradingStorage");
  const tradingstorage = await TradingStorage.connect(savior).deploy();
  await tradingstorage.deployed();

  const ThemisStorage = await ethers.getContractFactory("ThemisStorage");
  const themisstorage = await ThemisStorage.connect(savior).deploy();
  await themisstorage.deployed();

  const PoolStorage = await ethers.getContractFactory("PoolStorage");
  const poolstorage = await PoolStorage.connect(savior).deploy();
  await poolstorage.deployed();

  const WrappedTokenStorage = await ethers.getContractFactory("WrappedTokenStorage");
  const wrappedtokenstorage = await WrappedTokenStorage.connect(savior).deploy();
  await wrappedtokenstorage.deployed();

  const TreasuryStorage = await ethers.getContractFactory("TreasuryStorage");
  const treasurystorage = await TreasuryStorage.connect(savior).deploy();
  await treasurystorage.deployed();

  const PoolRewardModelStorage = await ethers.getContractFactory("PoolRewardModelStorage");
  const poolrewardmodelstorage = await PoolRewardModelStorage.connect(savior).deploy();
  await poolrewardmodelstorage.deployed();

  const InterestRateModelStorage = await ethers.getContractFactory("InterestRateModelStorage");
  const interestratemodelstorage = await InterestRateModelStorage.connect(savior).deploy();
  await interestratemodelstorage.deployed();

  const VoteRewardModelStorage = await ethers.getContractFactory("VoteRewardModelStorage");
  const voterewardmodelstorage = await VoteRewardModelStorage.connect(savior).deploy();
  await voterewardmodelstorage.deployed();

  const FarmingRewardModelStorage = await ethers.getContractFactory("FarmingRewardModelStorage");
  const farmingrewardmodelstorage = await FarmingRewardModelStorage.connect(savior).deploy();
  await farmingrewardmodelstorage.deployed();

  const GovRewardModelStorage = await ethers.getContractFactory("GovRewardModelStorage");
  const govrewardmodelstorage = await GovRewardModelStorage.connect(savior).deploy();
  await govrewardmodelstorage.deployed();

  const TradingRewardModelStorage = await ethers.getContractFactory("TradingRewardModelStorage");
  const tradingrewardmodelstorage = await TradingRewardModelStorage.connect(savior).deploy();
  await tradingrewardmodelstorage.deployed();

  const AuctionStorage = await ethers.getContractFactory("AuctionStorage");
  const auctionstorage = await AuctionStorage.connect(savior).deploy();
  await auctionstorage.deployed();

  const CommitteStorage = await ethers.getContractFactory("CommitteStorage");
  const committestorage = await CommitteStorage.connect(savior).deploy();
  await committestorage.deployed();

  const TitanCoreStorage = await ethers.getContractFactory("TitanCoreStorage");
  const titancorestorage = await TitanCoreStorage.connect(savior).deploy();
  await titancorestorage.deployed();

  const PriceOracle = await ethers.getContractFactory("PriceOracle");
  const priceoracle = await PriceOracle.connect(savior).deploy(savior.address);
  await priceoracle.deployed();

  const ShorterFactory = await ethers.getContractFactory("ShorterFactory");
  const shorterfactory = await ShorterFactory.connect(savior).deploy(savior.address);
  await shorterfactory.deployed();

  const EIP712Domain = await ethers.getContractFactory("EIP712Domain");
  const eip712domain = await EIP712Domain.connect(savior).deploy();
  await eip712domain.deployed();

  const ERC20 = await ethers.getContractFactory("contracts/tokens/ERC20.sol:ERC20");
  const erc20 = await ERC20.connect(savior).deploy();
  await erc20.deployed();

  const ChainSchema = await ethers.getContractFactory("ChainSchema");
  const chainschema = await ChainSchema.connect(savior).deploy(savior.address);
  await chainschema.deployed();

  const Affinity = await ethers.getContractFactory("Affinity");
  const affinity = await Affinity.connect(savior).deploy(savior.address);
  await affinity.deployed();

  const DexCenter = await ethers.getContractFactory("DexCenter");
  const dexcenter = await DexCenter.connect(savior).deploy(savior.address);
  await dexcenter.deployed();

  const Rescuable = await ethers.getContractFactory("Rescuable");
  const rescuable = await Rescuable.connect(savior).deploy(committeeimpl.address);
  await rescuable.deployed();

  const WrappedTokenImpl = await ethers.getContractFactory("WrappedTokenImpl");
  const wrappedtokenimpl = await WrappedTokenImpl.connect(savior).deploy();
  await wrappedtokenimpl.deployed();

  const WrapRouter = await ethers.getContractFactory("WrapRouter");
  const wraprouter = await WrapRouter.connect(savior).deploy(poolguardianimpl.address, wrappedtokenimpl.address);
  await wraprouter.deployed();

  const WrappedToken = await ethers.getContractFactory("WrappedToken");
  const wrappedtoken = await WrappedToken.connect(savior).deploy(wrappedtokenimpl.address, savior.address);
  await wrappedtoken.deployed();

  const GrandetieImpl = await ethers.getContractFactory("GrandetieImpl");
  const grandetieimpl = await GrandetieImpl.connect(savior).deploy(committeeimpl.address);
  await grandetieimpl.deployed();

  const Grandetie = await ethers.getContractFactory("Grandetie");
  const grandetie = await Grandetie.connect(savior).deploy(grandetieimpl.address, savior.address, committeeimpl.address);
  await grandetie.deployed();

  const PoolGarner = await ethers.getContractFactory("PoolGarner", {
      libraries: {
        AllyLibrary: allylibrary.address
    },
  });
  const poolgarner = await PoolGarner.connect(savior).deploy(savior.address);
  await poolgarner.deployed();

  const UniClassDexCenter = await ethers.getContractFactory("UniClassDexCenter");
  const uniclassdexcenter = await UniClassDexCenter.connect(savior).deploy(savior.address);
  await uniclassdexcenter.deployed();

  const BaseDexCenter = await ethers.getContractFactory("BaseDexCenter");
  const basedexcenter = await BaseDexCenter.connect(savior).deploy(savior.address);
  await basedexcenter.deployed();

  const PoolRewardModel = await ethers.getContractFactory("PoolRewardModel");
  const poolrewardmodel = await PoolRewardModel.connect(savior).deploy(savior.address, poolrewardmodelimpl.address);
  await poolrewardmodel.deployed();

  const FarmingRewardModel = await ethers.getContractFactory("FarmingRewardModel");
  const farmingrewardmodel = await FarmingRewardModel.connect(savior).deploy(savior.address, farmingrewardmodelimpl.address);
  await farmingrewardmodel.deployed();

  const PoolScatter = await ethers.getContractFactory("PoolScatter");
  const poolscatter = await PoolScatter.connect(savior).deploy(savior.address);
  await poolscatter.deployed();

  const IpistrToken = await ethers.getContractFactory("IpistrToken");
  const ipistrtoken = await IpistrToken.connect(savior).deploy(savior.address, ipistrtokenimpl.address);
  await ipistrtoken.deployed();

  const Committee = await ethers.getContractFactory("Committee");
  const committee = await Committee.connect(savior).deploy(savior.address, committeeimpl.address);
  await committee.deployed();

  const TradingRewardModel = await ethers.getContractFactory("TradingRewardModel");
  const tradingrewardmodel = await TradingRewardModel.connect(savior).deploy(savior.address, tradingrewardmodelimpl.address);
  await tradingrewardmodel.deployed();

  const VoteRewardModel = await ethers.getContractFactory("VoteRewardModel");
  const voterewardmodel = await VoteRewardModel.connect(savior).deploy(savior.address, voterewardmodelimpl.address);
  await voterewardmodel.deployed();

  const InterestRateModel = await ethers.getContractFactory("InterestRateModel");
  const interestratemodel = await InterestRateModel.connect(savior).deploy(savior.address, interestratemodelimpl.address);
  await interestratemodel.deployed();

  const GovRewardModel = await ethers.getContractFactory("GovRewardModel");
  const govrewardmodel = await GovRewardModel.connect(savior).deploy(savior.address, govrewardmodelimpl.address);
  await govrewardmodel.deployed();
  

}

async function noFungibleUniswap(owner, nftDescriptor, weth) {
  const linkedBytecode = linkLibraries(
    {
      bytecode: artifacts.NonfungibleTokenPositionDescriptor.bytecode,
      linkReferences: {
        "NFTDescriptor.sol": {
          NFTDescriptor: [
            {
              length: 20,
              start: 1681,
            },
          ],
        },
      },
    },
    {
      NFTDescriptor: nftDescriptor.address,
    }
  );

  NonfungibleTokenPositionDescriptor = new ContractFactory(artifacts.NonfungibleTokenPositionDescriptor.abi, linkedBytecode, owner);

  const nativeCurrencyLabelBytes = utils.formatBytes32String('WETH')
  nonfungibleTokenPositionDescriptor = await NonfungibleTokenPositionDescriptor.deploy(weth.address, nativeCurrencyLabelBytes);

  NonfungiblePositionManager = new ContractFactory(artifacts.NonfungiblePositionManager.abi, artifacts.NonfungiblePositionManager.bytecode, owner);
  nonfungiblePositionManager = await NonfungiblePositionManager.deploy(factory.address, weth.address, nonfungibleTokenPositionDescriptor.address);

  return nonfungiblePositionManager;
}

async function deployPool(token0, token1, fee, price, nonfungiblePositionManager) {
  const [owner] = await ethers.getSigners();
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
