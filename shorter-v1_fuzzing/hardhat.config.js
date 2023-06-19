// hardhat.config.js
require('hardhat-deploy');
require('hardhat-deploy-ethers');
require('hardhat-gas-reporter');
require('@nomiclabs/hardhat-ethers');
require('@nomiclabs/hardhat-waffle'); 
require('hardhat-contract-sizer');
require('dotenv').config();

const ACCOUNTS_HD = {
	mnemonic: 'test test test test test test test test test test test junk',
};

task('accounts', 'Prints the list of accounts', async () => {
	const accounts = await ethers.getSigners();

	for (const account of accounts) {
		console.log(account.address);
	}
});

task('blockNumber', 'Prints the current block number', async (_, { ethers }) => {
	await ethers.provider.getBlockNumber().then((blockNumber) => {
		console.log('Current block number: ' + blockNumber);
	});
});

module.exports = {
	solidity: {
		version: '0.6.12',
		settings: {
			optimizer: {
				enabled: true,
				runs: 200
			},
		},
	},
	paths: {
		deploy: 'scripts',
		deployments: 'deployments',
	},
	mocha: {
		timeout: 800000,
		enableTimeouts: false,
	},
	contractSizer: {
		alphaSort: true,
		runOnCompile: true,
		disambiguatePaths: false,
	},
};
