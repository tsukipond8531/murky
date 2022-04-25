pragma solidity 0.8.13;

import "../../src/Merkle.sol";
import "forge-std/Test.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";
import "openzeppelin-contracts/contracts/utils/Strings.sol";
import "forge-std/console.sol";
import "./utils/Strings2.sol";

contract DifferentialTests is Test {
    using Strings for uint;
    using Strings2 for bytes;
    // Contracts (to be migrated to libraries)
    Merkle m;
    bytes32[100] data;

    function setUp() public {
        m = new Merkle();
    }
    
    function testMerkleRootMatchesJSImplementation() public {
        // Run the reference implementation in javascript
        string[] memory runJsInputs = new string[](6);
        runJsInputs[0] = 'npm';
        runJsInputs[1] = '--prefix';
        runJsInputs[2] = 'differential_testing/scripts/';
        runJsInputs[3] = '--silent';
        runJsInputs[4] = 'run';
        runJsInputs[5] = 'generate-root';
        bytes memory jsResult = vm.ffi(runJsInputs);
        bytes32 jsGeneratedRoot = abi.decode(jsResult, (bytes32));

        // Read in the file generated by the reference implementation 
        string[] memory loadJsDataInputs = new string[](2);
        loadJsDataInputs[0] = "cat";
        loadJsDataInputs[1] = "differential_testing/data/input";
        bytes memory loadResult =  vm.ffi(loadJsDataInputs);
        data  = abi.decode(loadResult, (bytes32[100]));

        // Calculate root using Murky
        bytes32 murkyGeneratedRoot = m.getRoot(_getData());
        assertEq(murkyGeneratedRoot, jsGeneratedRoot);
    }

    /// @notice For questions on the argument name, see: https://en.wikipedia.org/wiki/Toronto_Maple_leaves
    function testMerkleRootMatchesJSImplementationFuzzed(bytes32[] memory leafs) public {
        vm.assume(leafs.length > 1);
        bytes memory packed = abi.encodePacked(leafs);
        string[] memory runJsInputs = new string[](8);

        // build ffi command string
        runJsInputs[0] = 'npm';
        runJsInputs[1] = '--prefix';
        runJsInputs[2] = 'differential_testing/scripts/';
        runJsInputs[3] = '--silent';
        runJsInputs[4] = 'run';
        runJsInputs[5] = 'generate-root-cli';
        runJsInputs[6] = leafs.length.toString();
        runJsInputs[7] = packed.toHexString();

        // run and captures output
        bytes memory jsResult = vm.ffi(runJsInputs);
        bytes32 jsGeneratedRoot = abi.decode(jsResult, (bytes32));
        
        // Calculate root using Murky
        bytes32 murkyGeneratedRoot = m.getRoot(leafs);
        assertEq(murkyGeneratedRoot, jsGeneratedRoot);
    }

    function testCompatabilityOpenZeppelinProver(bytes32[] memory _data, uint256 node) public {
        vm.assume(_data.length > 1);
        vm.assume(node < _data.length);
        bytes32 root = m.getRoot(_data);
        bytes32[] memory proof = m.getProof(_data, node);
        bytes32 valueToProve = _data[node];
        bool murkyVerified = m.verifyProof(root, proof, valueToProve);
        bool ozVerified = MerkleProof.verify(proof, root, valueToProve);
        assertTrue(murkyVerified == ozVerified);
    }

    function _getData() public view returns (bytes32[] memory) {
        bytes32[] memory _data = new bytes32[](data.length);
        uint length = data.length;
        for (uint i = 0; i < length; ++i) {
            _data[i] = data[i];
        }
        return _data;
    }
}