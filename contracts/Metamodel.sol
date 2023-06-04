// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import "@openzeppelin/contracts/access/AccessControl.sol";
// import "hardhat/console.sol";

library Uint8Model {

    struct PetriNet {
        Place[] places;
        Transition[] transitions;
    }

    struct Transition {
        uint8 offset;
        uint8 action;
        uint8 role;
        int8[] guard;
        int8[] delta;
    }

    struct Place {
        uint8 offset;
        int8 initial;
        int8 capacity;
    }

    struct Response {
        int8[] output;
        uint8 action;
        uint8 role;
        uint8 multiple;
        bool ok;
    }

}

interface Uint8ModelFactory {
    function declaration() external returns (Uint8Model.PetriNet memory);
}

abstract contract MetamodelUint8  {

    Uint8Model.Place[] internal places;
    Uint8Model.Transition[] internal transitions;

    function cell(int8 initial, int8 capacity) public returns (Uint8Model.Place memory) {
        Uint8Model.Place memory p =  Uint8Model.Place(uint8(places.length), initial, capacity);
        places.push(p);
        return p;
    }

    function fn(uint8 vectorSize, uint8 action, uint8 role) public returns (Uint8Model.Transition memory) {
        Uint8Model.Transition memory t = Uint8Model.Transition(uint8(transitions.length), action, role, new int8[](vectorSize), new int8[](vectorSize));
        transitions.push(t);
        return t;
    }

    function txn(uint8 weight, Uint8Model.Place memory p, Uint8Model.Transition memory t) public {
        transitions[t.offset].delta[p.offset] = 0-int8(weight);
    }

    function txn(uint8 weight, Uint8Model.Transition memory t, Uint8Model.Place memory p) public {
        transitions[t.offset].delta[p.offset] = int8(weight);
    }

    function guard(uint8 weight, Uint8Model.Place memory p, Uint8Model.Transition memory t) public {
        transitions[t.offset].guard[p.offset] = 0-int8(weight);
    }

}

// REVIEW visual model design in JS:
// https://pflow.dev/chainlink2023/tictactoe/
contract TicTacToeModel is MetamodelUint8, Uint8ModelFactory {

    enum Roles{ X, O, HALT }

    enum Properties {
        _00, _01, _02,
        _10, _11, _12,
        _20, _21, _22,
        SIZE
    }

    enum Actions {
        // x moves
        X00, X01, X02,
        X10, X11, X12,
        X20, X21, X22,
        // O moves
        O00, O01, O02,
        O10, O11, O12,
        O20, O21, O22,
        HALT
    }

    function addMove(Properties prop, Actions action, Roles role) internal {
        if (role >= Roles.HALT) {
            revert("Invalid role");
        }
        if (action >= Actions.HALT) {
            revert("Invalid action");
        }
        txn(1, places[uint8(prop)], fn(uint8(Properties.SIZE), uint8(action), uint8(role)));
    }

    constructor() {
        cell(1, 1); // _00
        cell(1, 1); // _01
        cell(1, 1); // _02

        cell(1, 1); // _10
        cell(1, 1); // _11
        cell(1, 1); // _12

        cell(1, 1); // _20
        cell(1, 1); // _21
        cell(1, 1); // _22

        addMove(Properties._00, Actions.X00, Roles.X);
        addMove(Properties._01, Actions.X01, Roles.X);
        addMove(Properties._02, Actions.X02, Roles.X);

        addMove(Properties._10, Actions.X10, Roles.X);
        addMove(Properties._11, Actions.X11, Roles.X);
        addMove(Properties._12, Actions.X12, Roles.X);

        addMove(Properties._20, Actions.X20, Roles.X);
        addMove(Properties._21, Actions.X21, Roles.X);
        addMove(Properties._22, Actions.X22, Roles.X);

        addMove(Properties._00, Actions.O00, Roles.O);
        addMove(Properties._01, Actions.O01, Roles.O);
        addMove(Properties._02, Actions.O02, Roles.O);

        addMove(Properties._10, Actions.O10, Roles.O);
        addMove(Properties._11, Actions.O11, Roles.O);
        addMove(Properties._12, Actions.O12, Roles.O);

        addMove(Properties._20, Actions.O20, Roles.O);
        addMove(Properties._21, Actions.O21, Roles.O);
        addMove(Properties._22, Actions.O22, Roles.O);
    }

    function declaration() public view returns (Uint8Model.PetriNet memory) {
        return Uint8Model.PetriNet(places, transitions);
    }

}

contract TicTacToe is AccessControl {
    uint256 internal gameId = 0;
    uint8 internal sequence = 0;
    Uint8ModelFactory internal model = new TicTacToeModel();

    int8[] public state = new int8[](9);

    event Action(uint256 gameId, uint8 seq, uint8 txnId, uint8 multiple, uint8 role, uint when);

    bytes32 public constant PLAYER_X = keccak256("PLAYER_X");
    bytes32 public constant PLAYER_O = keccak256("PLAYER_O");

    constructor(address p0, address p1) {
        _grantRole(PLAYER_X, p0);
        _grantRole(PLAYER_O, p1);
        resetGame(TicTacToeModel.Roles.HALT);
    }

    function resetGame(TicTacToeModel.Roles role) private {
        Uint8Model.Place[] memory places = model.declaration().places;
        for (uint8 i = 0; i < state.length; i++) {
            state[places[i].offset] = places[i].initial;
        }
        sequence = 0;
        gameId++;
        emit Action(gameId, sequence, uint8(TicTacToeModel.Actions.HALT), uint8(role), 1, block.timestamp);
    }

    function fire(uint8 txnId, uint8 role) private returns (Uint8Model.Response memory) {
        Uint8Model.Transition memory t = model.declaration().transitions[txnId];
        if (txnId != t.offset) {
            revert("Invalid action index");
        }
        if (t.role != role) {
            revert("Role assertion failed");
        }
        for (uint8 i = 0; i < t.delta.length; i++) {
            if (t.delta[i] != 0) {
                state[i] += t.delta[i];
                if (state[i] < 0) {
                    revert("Invalid state");
                }
            }
        }
        sequence++;
        return Uint8Model.Response(state, t.action, t.role, 1, true);
    }

    function turnTest() public view  {
        if (sequence % 2 == 0) { // alternate X and O
            require(hasRole(PLAYER_X, msg.sender), "Not your turn");
        } else {
            require(hasRole(PLAYER_O, msg.sender), "Not your turn");
        }
    }

    function move(TicTacToeModel.Actions action) private {
        Uint8Model.Response memory t;
        if (sequence % 2 == 0) { // alternate X and O
            t = fire(uint8(action), uint8(TicTacToeModel.Roles.X));
        } else {
            t = fire(uint8(action), uint8(TicTacToeModel.Roles.O));
        }
        if (t.ok) {
            emit Action(gameId, sequence, uint8(action), t.role, 1, block.timestamp);
        }
    }

    function resetX() public onlyRole(PLAYER_X) {
        resetGame(TicTacToeModel.Roles.X);
    }

    function resetO() public onlyRole(PLAYER_O) {
        resetGame(TicTacToeModel.Roles.O);
    }

    function X00() public onlyRole(PLAYER_X) {
        move(TicTacToeModel.Actions.X00);
    }

    function X01() public onlyRole(PLAYER_X) {
        move(TicTacToeModel.Actions.X01);
    }

    function X02() public onlyRole(PLAYER_X) {
        move(TicTacToeModel.Actions.X02);
    }

    function X10() public onlyRole(PLAYER_X) {
        move(TicTacToeModel.Actions.X10);
    }

    function X11() public onlyRole(PLAYER_X) {
        move(TicTacToeModel.Actions.X11);
    }

    function X12() public onlyRole(PLAYER_X) {
        move(TicTacToeModel.Actions.X12);
    }

    function X20() public onlyRole(PLAYER_X) {
        move(TicTacToeModel.Actions.X20);
    }

    function X21() public onlyRole(PLAYER_X) {
        move(TicTacToeModel.Actions.X21);
    }

    function X22() public onlyRole(PLAYER_X) {
        move(TicTacToeModel.Actions.X22);
    }

    function O00() public onlyRole(PLAYER_O) {
        move(TicTacToeModel.Actions.O00);
    }

    function O01() public onlyRole(PLAYER_O) {
        move(TicTacToeModel.Actions.O01);
    }

    function O02() public onlyRole(PLAYER_O) {
        move(TicTacToeModel.Actions.O02);
    }

    function O10() public onlyRole(PLAYER_O) {
        move(TicTacToeModel.Actions.O10);
    }

    function O11() public onlyRole(PLAYER_O) {
        move(TicTacToeModel.Actions.O11);
    }

    function O12() public onlyRole(PLAYER_O) {
        move(TicTacToeModel.Actions.O12);
    }

    function O20() public onlyRole(PLAYER_O) {
        move(TicTacToeModel.Actions.O20);
    }

    function O21() public onlyRole(PLAYER_O) {
        move(TicTacToeModel.Actions.O21);
    }

    function O22() public onlyRole(PLAYER_O) {
        move(TicTacToeModel.Actions.O22);
    }

}