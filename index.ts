import { BobTokenContract } from "./artifacts/BobToken.js";
import { AztecAddress } from "@aztec/aztec.js/addresses";
import { createAztecNodeClient } from "@aztec/aztec.js/node";
import { getInitialTestAccountsData } from "@aztec/accounts/testing";
import { TestWallet } from "@aztec/test-wallet/server";
import { openTmpStore } from "@aztec/kv-store/lmdb";

// export async function initGameState() {
//   try {
//     let gameState = await empty_game_state();
//     let whiteState = await empty_white_state();
//     let blackState = await empty_black_state();

//     // NOTE: in a real game these secrets should be random and not shared.
//     whiteState.encrypt_secret = "1";
//     whiteState.mask_secret = "2";
//     blackState.encrypt_secret = "3";
//     blackState.mask_secret = "4";
//     let whiteEncryptSecret = "1";
//     let whiteMaskSecret = "2";
//     let blackEncryptSecret = "3";
//     let blackMaskSecret = "4";
//     gameState = await commit_to_user_secrets(
//       gameState,
//       whiteEncryptSecret,
//       whiteMaskSecret,
//       "0" // 0 = white
//     );
//     gameState = await commit_to_user_secrets(
//       gameState,
//       blackEncryptSecret,
//       blackMaskSecret,
//       "1" // 1 = black
//     );

//     return { gameState, whiteState, blackState };
//   } catch (e) {
//     console.log("error? ", e);
//   }
// }

// at the top of your file
async function getBalances(
  contract: BobTokenContract,
  aliceAddress: AztecAddress,
  bobAddress: AztecAddress,
) {
  Promise.all([
    contract.methods
      .public_balance_of(aliceAddress)
      .simulate({ from: aliceAddress }),
    contract.methods
      .private_balance_of(aliceAddress)
      .simulate({ from: aliceAddress }),
    contract.methods
      .public_balance_of(bobAddress)
      .simulate({ from: bobAddress }),
    contract.methods
      .private_balance_of(bobAddress)
      .simulate({ from: bobAddress }),
  ]).then(
    ([
      alicePublicBalance,
      alicePrivateBalance,
      bobPublicBalance,
      bobPrivateBalance,
    ]) => {
      console.log(
        `📊 Alice has ${alicePublicBalance} public BOB tokens and ${alicePrivateBalance} private BOB tokens`,
      );
      console.log(
        `📊 Bob's Clinic has ${bobPublicBalance} public BOB tokens and ${bobPrivateBalance} private BOB tokens`,
      );
    },
  );
}

async function main() {
  // Connect to local network
  const node = createAztecNodeClient("http://localhost:8080");

  const store = await openTmpStore();

  const wallet = await TestWallet.create(node);

  const [giggleWalletData, aliceWalletData, bobClinicWalletData] =
    await getInitialTestAccountsData();
  const giggleAccount = await wallet.createSchnorrAccount(
    giggleWalletData.secret,
    giggleWalletData.salt,
  );
  const aliceAccount = await wallet.createSchnorrAccount(
    aliceWalletData.secret,
    aliceWalletData.salt,
  );
  const bobClinicAccount = await wallet.createSchnorrAccount(
    bobClinicWalletData.secret,
    bobClinicWalletData.salt,
  );

  const giggleAddress = (await giggleAccount.getAccount()).getAddress();
  const aliceAddress = (await aliceAccount.getAccount()).getAddress();
  const bobClinicAddress = (await bobClinicAccount.getAccount()).getAddress();

  const bobToken = await BobTokenContract.deploy(wallet)
    .send({ from: giggleAddress })
    .deployed();

  let whiteState = await bobToken.methods
    .__empty_white_state()
    .simulate({ from: giggleAddress });
  console.log("white state ", whiteState);

  console.log("about to call method that errors?");
  await bobToken.methods
    .args_hash_err(whiteState)
    .send({ from: giggleAddress })
    .wait();

  console.log("creating game state");
  let gameState = await bobToken.methods
    .__empty_game_state()
    .simulate({ from: giggleAddress });

  let blackState = await bobToken.methods
    .__empty_black_state()
    .simulate({ from: giggleAddress });
  console.log("black state");

  // NOTE: in a real game these secrets should be random and not shared.
  whiteState.encrypt_secret = 1;
  whiteState.mask_secret = 2;
  blackState.encrypt_secret = 3;
  blackState.mask_secret = 4;
  let whiteEncryptSecret = 1;
  let whiteMaskSecret = 2;
  let blackEncryptSecret = 3;
  let blackMaskSecret = 4;
  console.log("commit to white secrets");

  console.log("game state? ", gameState);
  gameState = await bobToken.methods
    .__commit_to_user_secrets(
      gameState,
      whiteEncryptSecret,
      whiteMaskSecret,
      0, // 0 = white
    )
    .simulate({ from: giggleAddress });
  console.log("commit to black secrets");
  gameState = await bobToken.methods
    .__commit_to_user_secrets(
      gameState,
      blackEncryptSecret,
      blackMaskSecret,
      1, // 1 = black
    )
    .simulate({ from: giggleAddress });

  // at this point we sort of have an initial state we can play with?
  console.log("game state? ", gameState);

  console.log(
    "secret hashes? ",
    gameState.mpc_state.user_encrypt_secret_hashes,
  );

  //   console.log("white state secrets ", whiteState.)
  let move = await bobToken.methods
    .__create_move(0, 1, 0, 3)
    .simulate({ from: giggleAddress });

  let new_user_state = await bobToken.methods
    .update_user_state_from_move(true, whiteState, move, 0)
    .simulate({ from: giggleAddress });

  console.log("new user state = ", new_user_state);

  await bobToken.methods
    .create_game_private(1, 2, 3)
    .send({ from: giggleAddress })
    .wait();

  await bobToken.methods
    .join_game_private(0, 4, 5, 3)
    .send({ from: aliceAddress })
    .wait();

  //         const logs = await aztecNode.getPublicLogs({ txHash: receipt.txHash });
  // const rawFields = logs.logs[0].log.getEmittedFields(); // Fr[]
  console.log(" move hash?");
  await bobToken.methods
    .mint_public(aliceAddress, 100n)
    .send({ from: giggleAddress })
    .wait();

  await bobToken.methods
    .transfer_public(bobClinicAddress, 10n)
    .send({ from: aliceAddress })
    .wait();

  // ...etc
  await bobToken.methods
    .mint_public(aliceAddress, 100n)
    .send({ from: giggleAddress })
    .wait();
  await getBalances(bobToken, aliceAddress, bobClinicAddress);

  await bobToken.methods
    .transfer_public(bobClinicAddress, 10n)
    .send({ from: aliceAddress })
    .wait();
  await getBalances(bobToken, aliceAddress, bobClinicAddress);

  await bobToken.methods
    .public_to_private(90n)
    .send({ from: aliceAddress })
    .wait();
  await getBalances(bobToken, aliceAddress, bobClinicAddress);

  await bobToken.methods
    .transfer_private(bobClinicAddress, 50n)
    .send({ from: aliceAddress })
    .wait();
  await getBalances(bobToken, aliceAddress, bobClinicAddress);

  await bobToken.methods
    .private_to_public(10n)
    .send({ from: aliceAddress })
    .wait();
  await getBalances(bobToken, aliceAddress, bobClinicAddress);

  await bobToken.methods
    .mint_private(aliceAddress, 100n)
    .send({ from: giggleAddress })
    .wait();
  await getBalances(bobToken, aliceAddress, bobClinicAddress);
}

main().catch(console.error);
