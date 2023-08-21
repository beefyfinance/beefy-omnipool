pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {TransmutationVelocimeter} from "../../contracts/TransmutationVelocimeter.sol";
import {ISolidlyRouter} from "../../contracts/interfaces/ISolidlyRouter.sol";
import {IBeefyVault} from "../../contracts/interfaces/IBeefyVault.sol";
import {IBalancerVault} from "../../contracts/interfaces/IBalancerVault.sol";
import {IBeefyZap} from "../../contracts/interfaces/IBeefyZap.sol";
import {ISolidlyRouter} from "../../contracts/interfaces/ISolidlyRouter.sol";
import {IOToken} from "../../contracts/interfaces/IOToken.sol";

contract TransmutationVelocimeterTest is Test {
    IOToken constant oToken = IOToken(0x762eb51D2e779EeEc9B239FFB0B2eC8262848f3E);
    address constant underlying = 0xd386a121991E51Eab5e3433Bf5B1cF4C8884b47a;
    address constant paymentToken = 0x4200000000000000000000000000000000000006;
    address constant flashPool = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    address constant router = 0xE11b93B61f6291d35c5a2beA0A9fF169080160cF;
    address constant treasury = 0x8930443140811D84Efe6CB4E9A5B9da02E6832F6;
    address constant native = 0x4200000000000000000000000000000000000006;
    address constant want = 0x9BA0F14512Ee29AbdbE2E5eA27a5D5836ef97F40;
    address constant partner = 0xfA89A4C7F79Dc4111c116a0f01061F4a7D9fAb73;
    address constant zap = 0x5d2EF803D6e255eF4D1c66762CBc8845051B54dB;

    TransmutationVelocimeter transmuteContract;

    address user = 0x8930443140811D84Efe6CB4E9A5B9da02E6832F6;
    uint256 slippage = .80 ether;

    function routes() internal pure returns(
        ISolidlyRouter.Routes[] memory oTokenToUnderlyingPath,
        ISolidlyRouter.Routes[] memory underlyingToPaymentTokenPath,
        ISolidlyRouter.Routes[] memory underlyingToWantPath,
        ISolidlyRouter.Routes[] memory paymentTokenToUnderlying
    ) {
        oTokenToUnderlyingPath = new ISolidlyRouter.Routes[](1);
        oTokenToUnderlyingPath[0] = ISolidlyRouter.Routes(address(oToken), address(underlying), false);

        underlyingToPaymentTokenPath = new ISolidlyRouter.Routes[](1);
        underlyingToPaymentTokenPath[0] = ISolidlyRouter.Routes(address(underlying), paymentToken, false);

        underlyingToWantPath = new ISolidlyRouter.Routes[](1);
        underlyingToWantPath[0] = ISolidlyRouter.Routes(paymentToken, native, false);

        paymentTokenToUnderlying = new ISolidlyRouter.Routes[](1);
        paymentTokenToUnderlying[0] = ISolidlyRouter.Routes(native, underlying, false);
    }

    function setUp() public {
        transmuteContract = new TransmutationVelocimeter();
        startContract();
    }

    function startContract() public {
        (
            ISolidlyRouter.Routes[] memory otokenToUnderlying, 
            ISolidlyRouter.Routes[] memory underlyingToPaymentToken, 
            ISolidlyRouter.Routes[] memory wantPath,
            ISolidlyRouter.Routes[] memory underlyingPath
        ) = routes();

        transmuteContract.initialize(
            IERC20(underlying),
            oToken,
            IERC20(paymentToken),
            IBalancerVault(flashPool),
            native,
            ISolidlyRouter(router),
            treasury,
            IBeefyZap(zap),
            otokenToUnderlying,
            underlyingToPaymentToken
        );

        transmuteContract.setPartner(partner);
        transmuteContract.setProtocolFee(2e16, 1e16);
        transmuteContract.toggleWantApproval(native, true);
        transmuteContract.addWantToken(want, wantPath, true);
        transmuteContract.addWantToken(underlying, underlyingPath, false);
    }

    function test_transmuteToNative() public {
        vm.startPrank(user);
        deal(address(oToken), user, 10 ether);
        IERC20(address(oToken)).approve(address(transmuteContract), 10 ether);
        uint256 amountOut = transmuteContract.getAmountOut(native, 1 ether);
        //console.log(amountOut);
        uint256 minAmountOut = amountOut * slippage / 1 ether;
        //console.log(minAmountOut);
        uint256 wantAmount = transmuteContract.transmute(native, 1 ether, minAmountOut);
        console.log(wantAmount);
        vm.stopPrank();
    }

    function test_transmuteToUnderlying() public {
        vm.startPrank(user);
        deal(address(oToken), user, 10 ether);
        IERC20(address(oToken)).approve(address(transmuteContract), 10 ether);
        uint256 amountOut = transmuteContract.getAmountOut(underlying, 1 ether);
        uint256 minAmountOut = amountOut * slippage / 1 ether;
        uint256 wantAmount = transmuteContract.transmute(underlying, 1 ether, minAmountOut);
        console.log(wantAmount);
        vm.stopPrank();
    }

    function test_transmuteToMooToken() public {
        vm.startPrank(user);
        deal(address(oToken), user, 10 ether);
        IERC20(address(oToken)).approve(address(transmuteContract), 10 ether);
        uint256 amountOut = transmuteContract.getAmountOut(want, 1 ether);
        uint256 minAmountOut = amountOut * slippage / 1 ether;
        uint256 wantAmount = transmuteContract.transmute(want, 1 ether, minAmountOut);
        console.log(wantAmount);
        vm.stopPrank();
    }
}
