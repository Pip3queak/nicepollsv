// Imports for type definitions
use aiken/collection/dict
use aiken/collection/list
use cardano/address.{Address}
use cardano/assets.{PolicyId}

// Define the NicePoll Token PolicyId (placeholder; replace with actual ID)
pub const nicepoll_token: PolicyId = PolicyId(#"deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef")

// Poll struct to store poll state
pub type Poll {
  creator: Address,                  // Poll creator's address
  question: ByteArray,              // Poll question
  options: List<ByteArray>,         // Voting options
  votes: dict.Dict<ByteArray, Int>, // Total tokens spent per option
  voter_records: dict.Dict<Address, VoterRecord>, // Individual voter contributions
  total_spent: Int,                 // Total ADA or NicePoll Tokens spent
  start_date: Int,                  // POSIX time (milliseconds)
  end_date: Int,                    // POSIX time (milliseconds)
  fixed_amount: Option<Int>,        // Fixed amount per vote (optional)
  max_votes: Option<Int>,           // Max votes per voter (optional)
  multiple_options: Bool,           // Allow voting on multiple options
  reward_redistribution: Bool       // Enable reward redistribution
}

// Record of a voter's contribution
pub type VoterRecord {
  option: ByteArray,                // Option voted for
  amount: Int                       // Amount spent
}

// Datum to store on-chain state
pub type Datum {
  PollDatum(Poll)                   // Wraps the Poll struct
}

// Redeemer to specify actions
pub type Redeemer {
  Create                            // Create a new poll
  Vote(ByteArray, Int)              // Vote for an option with an amount
  Distribute                        // Distribute rewards after poll ends
}
