pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin-4/contracts/token/ERC20/ERC20.sol";

interface IStrategy {
    function harvest() external;
}

contract BeefyStargateZapTest is Test {

    IStrategy public strategy;
    
    function setUp()  public {
        strategy = IStrategy(0x5b66B327Ae1313CFcFe373Eba192A801a85A97D0);
    }

    function test_harvest() public {
        strategy.harvest();
    }

}