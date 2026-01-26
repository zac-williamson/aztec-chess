
use aztec::macros::aztec;
    use fog_of_war_chess::{empty_game_state, GameState, move, MoveData, MoveHashes, UserState};

mod foo {
fn to_u32(x: Field) -> u32 {
    x.assert_max_bit_size::<32>();
    x as u32
}
}

fn pack_game_state(state: GameState) -> Field {
    // game_ended = bool
    // move_count = field
    // roundmpcstate = RoundState<64, 2>;
    // =
    // round_number = u32
    // user_encrypt_secret_hashes: [Field; 2]
    // user_mask_secret_hashes  = [Field; 2]
    // previous_output_states = [UserOutputState<64, 2>; 2]
    // = ciphertext = [Field; 128]
    // = mask_commitments = [Point; 64] = [Field; 128]
    // user_updated_mask_commitments: [[Point; NumEntries]; NumParticipants] = [Field; 128]


    // OOOOK so what do we need here.
    // We need a way of taking a single UserOutputState and updating a game


    // 
    0
}

#[aztec]
pub contract BobToken {
    use aztec::{
        macros::{functions::{external, initializer, only_self}, storage::storage, events::event},
        messages::message_delivery::MessageDelivery,
        protocol_types::address::AztecAddress,
        state_vars::{Map, Owned},
        state_vars::public_mutable::PublicMutable,
    };
use poseidon::poseidon2::Poseidon2::hash as poseidon2;
    use balance_set::BalanceSet;
    use fog_of_war_chess::{
        consume_opponent_move_and_update_game_state as consume_opponent_move_and_update_game_state_inner,
        move_for_contract, RoundMpcState, empty_game_state, GameState, move, MoveData, MoveHashes, UserState};
    use fog_of_war_chess::piece::{PieceData, Pieces};
    use fog_of_war_chess::validate_move::validate_move_and_update_board_state;

    use dep::aztec::protocol_types::{
        traits::{Deserialize, Packable, Serialize}
    };
use mpclib::selective_disclosure::selective_disclosure::{RoundState, UserOutputState};

    use aztec::macros::internals_functions_generation::abi_attributes::abi_utility;
use dep::aztec::oracle::debug_log::{ debug_log, debug_log_format };

   
/*
GameState
    pub game_ended: bool,
    pub move_count: Field,
    pub mpc_state: RoundMpcState,
*/

/*
pub struct RoundState<let NumEntries: u32, let NumParticipants: u32> {
    pub round_number: u32,
    pub user_encrypt_secret_hashes: [Field; NumParticipants],
    pub user_mask_secret_hashes: [Field; NumParticipants],
    pub previous_output_states: [UserOutputState<NumEntries, NumParticipants>; NumParticipants],
}
*/

/*
pub struct UserOutputState<let NumEntries: u32, let NumParticipants: u32> {
    ciphertext: Ciphertext<NumEntries>,
    mask_commitments: [Point; NumEntries],
    user_updated_mask_commitments: [[Point; NumEntries]; NumParticipants],
}
*/

/*
pub struct Ciphertext<let N: u32> {
    data: [Field; N * 2],
}
*/


#[event]
struct MoveEvent {
    state: UserOutputState<64, 2>
}

#[storage]
struct Storage<Context> {
    game_counter: PublicMutable<u32, Context>,
    game_secret_hashes: Map<u32, PublicMutable<[Field; 4], Context>, Context>,
    game_hashes: Map<u32, PublicMutable<Field, Context>, Context>,
    // Giggle's admin address
    owner: PublicMutable<AztecAddress, Context>,
    // Public balances - visible for transparency
    public_balances: Map<AztecAddress, PublicMutable<u64, Context>, Context>,
    // Private balances - only the owner can see these
    private_balances: Owned<BalanceSet<Context>, Context>,
}



#[external("utility")]
unconstrained fn __empty_game_state() -> GameState {
    GameState::default()
}

#[external("utility")]
unconstrained fn __empty_white_state() -> UserState {
    let u = UserState::default();
    u.initialize(0)
}

#[external("utility")]
unconstrained fn __empty_black_state() -> UserState {
    let u = UserState::default();
    u.initialize(1)
}

#[external("utility")]
unconstrained fn __commit_to_user_secrets(
    game_state: GameState,
    encrypt_secret: Field,
    mask_secret: Field,
    player_id: Field,
) -> GameState {
    let mut updated = game_state;

    let secret_hashes = [poseidon2([encrypt_secret, -1], 2), poseidon2([mask_secret, -1], 2)];
player_id.assert_max_bit_size::<32>();
let id = player_id as u32;
    updated.mpc_state.user_encrypt_secret_hashes[id] = secret_hashes[0];
    updated.mpc_state.user_mask_secret_hashes[id] = secret_hashes[1];
    updated
}


#[external("utility")]
unconstrained fn __create_move(x1: Field, y1: Field, x2: Field, y2: Field) -> MoveData {
    MoveData { x1, y1, x2, y2 }
}


#[external("utility")]
unconstrained fn __consume_opponent_move_and_update_game_state(
    input_state: GameState,
    user_state: UserState,
    player_id: Field,
) -> UserState {
    consume_opponent_move_and_update_game_state_inner(input_state, user_state, player_id)
}


#[external("utility")]
unconstrained fn update_user_state_from_move(
    is_first_two_moves: bool,
    _user_state: UserState,
    move_data: MoveData,
    player_id: Field,
) -> UserState {
    let mut user_state = _user_state;
    if (is_first_two_moves) {
        user_state = UserState::initialize(user_state, player_id);
    }
    let starting_piece = user_state.game_state[(move_data.x1 + move_data.y1 * 8) as u32];
    // let ending_piece = user_state.game_state[move_data.x2 + move_data.y2 * 8];
    let starting_piece_data: PieceData =
        PieceData { id: starting_piece.id, x: move_data.x1, y: move_data.y1, exists: 1 };
    let ending_piece_data: PieceData =
        PieceData { id: starting_piece.id, x: move_data.x2, y: move_data.y2, exists: 1 };

    let existing_end_piece = user_state.game_state[(move_data.x2 + move_data.y2 * 8) as u32];
    let mut game_ended = false;
    if ((existing_end_piece.id == Pieces::KING) & (existing_end_piece.player_id != player_id)) {
        game_ended = true;
    }

    user_state.game_state = validate_move_and_update_board_state(
        user_state.game_state,
        starting_piece_data,
        ending_piece_data,
        player_id,
    );
    user_state
}

// #[external("private")]
// fn compressState(foo: GameState) -> Field
// {
//     let x = foo.pack();
//     x[0]
// }

#[initializer]
#[external("public")]
fn setup() {
    // Giggle becomes the owner who can mint mental health tokens
    self.storage.owner.write(self.msg_sender().unwrap());

}

#[external("public")]
#[only_self]
fn _deduct_public_balance(owner: AztecAddress, amount: u64) {
    let balance = self.storage.public_balances.at(owner).read();
    assert(balance >= amount, "Insufficient public BOB tokens");
    self.storage.public_balances.at(owner).write(balance - amount);
}

#[external("private")]
fn public_to_private(amount: u64) {
    let sender = self.msg_sender().unwrap();
    // This will enqueue a public function to deduct from public balance
    self.enqueue_self._deduct_public_balance(sender, amount);
    // Add to private balance
    self.storage.private_balances.at(sender).add(amount as u128).deliver(
        MessageDelivery.CONSTRAINED_ONCHAIN,
    );
}

#[external("private")]
fn transfer_private(to: AztecAddress, amount: u64) {
    let sender = self.msg_sender().unwrap();
    // Spend sender's notes (consumes existing notes)
    self.storage.private_balances.at(sender).sub(amount as u128).deliver(
        MessageDelivery.CONSTRAINED_ONCHAIN,
    );
    // Create new notes for recipient
    self.storage.private_balances.at(to).add(amount as u128).deliver(
        MessageDelivery.CONSTRAINED_ONCHAIN,
    );
}

#[external("public")]
#[only_self]
fn _assert_is_owner(address: AztecAddress) {
    assert_eq(address, self.storage.owner.read(), "Only Giggle can mint BOB tokens");
}

#[external("private")]
fn private_to_public(amount: u64) {
    let sender = self.msg_sender().unwrap();
    // Remove from private balance
    self.storage.private_balances.at(sender).sub(amount as u128).deliver(
        MessageDelivery.CONSTRAINED_ONCHAIN,
    );
    // Enqueue public credit
    self.enqueue_self._credit_public_balance(sender, amount);
}

#[external("private")]
fn create_game_private(user_secret: Field, user_mask: Field, password: Field) {

    let mut game_state: GameState = empty_game_state();
    game_state = game_state.commit_to_user_secrets(user_secret, user_mask, 0);
    let mut password_hash = poseidon2([password], 1);
    if (password == 0)
    {
        password_hash = 0;
    }
    self.enqueue_self.create_game_public([game_state.mpc_state.user_encrypt_secret_hashes[0], game_state.mpc_state.user_mask_secret_hashes[0]], password_hash);
  //  commit_to_user_secrets
}

#[external("public")]
#[only_self]
fn create_game_public(user_secret_hashes: [Field; 2], password_hash: Field) {
    let game_id: u32= self.storage.game_counter.read();
    self.storage.game_hashes.at(game_id).write(0);
    self.storage.game_secret_hashes.at(game_id).write([user_secret_hashes[0], user_secret_hashes[1], password_hash, 0]);
    self.storage.game_counter.write(game_id + 1);
  // self.storage.game_hashes
}


    // user_state: UserState,
    // move_data: MoveData,


#[external("private")]
fn args_hash_err(user_state: UserState) {
    assert(user_state.encrypt_secret != 12345);
}


#[external("private")]
fn make_move_white_private(game_id: u32,game_state: GameState,user_state: UserState,move_data: MoveData) {

    // let old_round_game_state: RoundMpcState = RoundMpcState::deserialize(serialized_game_state);

    // let old_game_state = GameState{
    //     game_ended: false,
    //     move_count: move_count, // ???
    //     mpc_state: old_round_game_state
    // };
    let state_hash = game_state.hash();

    debug_log_format("input game state secret/mask hashes: {0}, {1}, {2}, {3}", [
        game_state.mpc_state.user_encrypt_secret_hashes[0], 
        game_state.mpc_state.user_encrypt_secret_hashes[1],
    game_state.mpc_state.user_mask_secret_hashes[0],
    game_state.mpc_state.user_mask_secret_hashes[1]]);
    debug_log_format("state hash: {0}, {1}, {2}, {3}", [state_hash]);

// debug_log_format("user encrypt secret hashes: {0}, {1}", [old_game_state.mpc_state.user_encrypt_secret_hashes[0], old_game_state.mpc_state.user_encrypt_secret_hashes[1]]);
// debug_log_format("user mask secret hashes: {0}, {1}", [old_game_state.mpc_state.user_mask_secret_hashes[0], old_game_state.mpc_state.user_mask_secret_hashes[1]]);

    // let foo = poseidon2([user_state.encrypt_secret, -1], 2);
    // let bar = poseidon2([user_state.mask_secret, -1], 2);
    // debug_log_format("reconstructed secret/mask hashes: {0}, {1}", [foo, bar]);

    let move_result = move_for_contract::<0>(state_hash, game_state, user_state, move_data);
    let user_output_state = move_result.0;
    let move_hashes = move_result.1;


    let starting_hash: Field = move_hashes.input_game_state;
    let ending_hash = move_hashes.output_game_state;

//  let broadcast_output_state: [Field; 512] = user_output_state.serialize();

   self.enqueue_self.make_move_white_public(game_id, state_hash, ending_hash,user_output_state);

   // let new_game_hash = 
    // // ok so we need a few things
    // // 1: start with the current game state hash
    // // 2: 
    // let mut game_state: GameState = empty_game_state();
    // game_state = game_state.commit_to_user_secrets(user_secret, user_mask, 0);
    // let mut password_hash = poseidon2([password], 1);
    // if (password == 0)
    // {
    //     password_hash = 0;
    // }
  //  self.enqueue_self.create_game_public([game_state.mpc_state.user_encrypt_secret_hashes[0], game_state.mpc_state.user_mask_secret_hashes[0]], password_hash);
  //  commit_to_user_secrets
}

#[external("public")]
#[only_self]
fn make_move_white_public(
    game_id: u32,
    initial_hash: Field,
    final_hash: Field,
    state: UserOutputState<64, 2>
) {

     let game_hash = self.storage.game_hashes.at(game_id).read();

     assert(initial_hash != final_hash);
    assert(game_hash != 0);
    assert(game_hash == initial_hash);

    self.storage.game_hashes.at(game_id).write(final_hash);
    self.emit(MoveEvent{ state });
 //    self.context.emit_public_log(serialized_user_data);
    // 1. load up game
    // 2. check hashes match
    // 3. update
    // 4. emit event
}

#[external("private")]
fn test_user_output_state(
    state: UserOutputState<64, 2>
) {


    assert(state.hash() != 0);
 //    self.context.emit_public_log(serialized_user_data);
    // 1. load up game
    // 2. check hashes match
    // 3. update
    // 4. emit event
}

#[external("private")]
fn join_game_private(game_id: u32, user_secret: Field, user_mask: Field, white_secret_hashes: [Field; 2], password: Field) {

    
    let mut game_state: GameState = empty_game_state();
    // Field; 1031

    game_state = game_state.commit_to_user_secrets(user_secret, user_mask, 1);
   game_state.mpc_state.user_encrypt_secret_hashes[0] = white_secret_hashes[0];
   game_state.mpc_state.user_mask_secret_hashes[0] = white_secret_hashes[1];
    let mut password_hash = poseidon2([password], 1);
    if (password == 0)
    {
        password_hash = 0;
    }
  let game_hash = game_state.hash();
    debug_log_format("black user secret/mask: {0}, {1}", [user_secret, user_mask]);
    debug_log_format("input game state secret/mask hashes: {0}, {1}, {2}, {3}", [
        game_state.mpc_state.user_encrypt_secret_hashes[0], 
        game_state.mpc_state.user_encrypt_secret_hashes[1],
    game_state.mpc_state.user_mask_secret_hashes[0],
    game_state.mpc_state.user_mask_secret_hashes[1]]);
    debug_log_format("state hash: {0}, {1}, {2}, {3}", [game_hash]);

    self.enqueue_self.join_game_public(game_id, game_hash, [game_state.mpc_state.user_encrypt_secret_hashes[0], game_state.mpc_state.user_mask_secret_hashes[0]], password_hash);
  //  commit_to_user_secrets
}

#[external("public")]
#[only_self]
fn join_game_public(game_id: u32, game_hash: Field, user_secret_hashes: [Field; 2], password_hash: Field) {

    let secret_hashes: [Field; 4] = self.storage.game_secret_hashes.at(game_id).read();
    assert(secret_hashes[0] != 0);
    assert(secret_hashes[1] != 0);
    assert(secret_hashes[3] == 0); // only games that have not started will have the second player mask secret hash blank
    assert(secret_hashes[2] == password_hash);

    self.storage.game_secret_hashes.at(game_id).write([secret_hashes[0], secret_hashes[1], user_secret_hashes[0], user_secret_hashes[1]]);

    self.storage.game_hashes.at(game_id).write(game_hash);    
    // event we emit = serialized user output state + round???

    // we recreate game state from following:

    // as private inputs we have the player's UserOutputState and opponent's UserOutputState (retrieved from event)
   // let mut game_state: GameState = empty_game_state();
    // game_state = game_state.commit_to_user_secrets(user_secret, user_mask, 0);
    // let mut password_hash = poseidon2([password], 1);
    // if (password == 0)
    // {
    //     password_hash = 0;
    // }
    // self.enqueue_self.create_game_public([game_state.mpc_state.user_encrypt_secret_hashes[0], game_state.mpc_state.user_mask_secret_hashes[0]], password_hash);
  //  commit_to_user_secrets
}


#[external("public")]
#[only_self]
fn _credit_public_balance(owner: AztecAddress, amount: u64) {
    let balance = self.storage.public_balances.at(owner).read();
    self.storage.public_balances.at(owner).write(balance + amount);
}

#[external("private")]
fn mint_private(employee: AztecAddress, amount: u64) {
    // Enqueue ownership check (will revert if not Giggle)
    self.enqueue_self._assert_is_owner(self.msg_sender().unwrap());

    // If check passes, mint tokens privately
    self.storage.private_balances.at(employee).add(amount as u128).deliver(
        MessageDelivery.CONSTRAINED_ONCHAIN,
    );
}

#[external("utility")]
unconstrained fn private_balance_of(owner: AztecAddress) -> pub u128 {
    self.storage.private_balances.at(owner).balance_of()
}

#[external("utility")]
unconstrained fn public_balance_of(owner: AztecAddress) -> pub u64 {
    self.storage.public_balances.at(owner).read()
}

#[external("public")]
fn mint_public(employee: AztecAddress, amount: u64) {
    // Only Giggle can mint tokens
    assert_eq(self.msg_sender().unwrap(), self.storage.owner.read(), "Only Giggle can mint BOB tokens");

    // Add tokens to employee's public balance
    let current_balance = self.storage.public_balances.at(employee).read();
    self.storage.public_balances.at(employee).write(current_balance + amount);
}

#[external("public")]
fn transfer_public(to: AztecAddress, amount: u64) {
    let sender = self.msg_sender().unwrap();
    let sender_balance = self.storage.public_balances.at(sender).read();
    assert(sender_balance >= amount, "Insufficient BOB tokens");

    // Deduct from sender
    self.storage.public_balances.at(sender).write(sender_balance - amount);

    // Add to recipient
    let recipient_balance = self.storage.public_balances.at(to).read();
    self.storage.public_balances.at(to).write(recipient_balance + amount);
}

#[external("public")]
fn transfer_ownership(new_owner: AztecAddress) {
    assert_eq(self.msg_sender().unwrap(), self.storage.owner.read(), "Only current admin can transfer ownership");
    self.storage.owner.write(new_owner);
}
}