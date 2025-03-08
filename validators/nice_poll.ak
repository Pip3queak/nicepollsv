// Imports
use aiken/collection/dict
use aiken/collection/list
use cardano/address.{Script}
use cardano/assets.{PolicyId, Value}
use cardano/script_context.{ScriptContext, Spending}
use cardano/transaction.{OutputReference, Transaction}
use nicepoll_types.{Datum, Poll, PollDatum, Redeemer, VoterRecord, nicepoll_token}

// Validator for NicePoll
validator nice_poll {
  // Spending logic for poll creation, voting, and distribution
  spend(datum: Datum, redeemer: Redeemer, own_ref: OutputReference, ctx: ScriptContext) {
    let ScriptContext { info: script_purpose, transaction: tx, .. } = ctx
    let now = tx.time_range.start

    when script_purpose is {
      Spending { .. } -> {
        let datum_poll = datum
        expect PollDatum(poll) = datum_poll
        match redeemer {
          Create {
            expect tx.inputs.len() == 1 //"Poll already exists"
            expect poll.options |> list.length >= 2 //"At least 2 options required"
            expect poll.start_date <= poll.end_date //"Invalid dates"
            expect tx.outputs |> list.any(out.datum == datum) //"Poll not created"
            True
          }
          Vote(option, amount) {
            expect now >= poll.start_date && now <= poll.end_date // "Poll not active"
            expect poll.options |> list.has(option)// "Invalid option"
            when poll.fixed_amount is {
              Some(fixed) -> expect amount == fixed // "Incorrect vote amount"
              None -> expect amount > 0 // "Amount must be positive"
            }
            let voter = tx.signatories[0]
            when poll.max_votes is {
              Some(max) -> {
                let current = poll.voter_records |> dict.get(voter) |> option.map(vr.amount) |> option.unwrap_or(0)
                expect current + amount <= max // "Exceeds max votes"
              }
              None -> True
            }
            let new_votes = poll.votes |> dict.insert(option, poll.votes |> dict.get(option) |> option.unwrap_or(0) + amount)
            let new_record = VoterRecord { option, amount }
            let new_voter_records = poll.voter_records |> dict.insert(voter, new_record)
            let new_total_spent = poll.total_spent + amount
            let new_poll = Poll { votes: new_votes, voter_records: new_voter_records, total_spent: new_total_spent, ..poll }
            expect tx.outputs |> list.any(|out| out.datum == PollDatum(new_poll)) // "Votes not updated"
            let spent_value = tx.value_spent_by(own_ref.script_hash)
            expect spent_value.lovelace >= amount || spent_value |> assets.get(nicepoll_token) >= amount // "Insufficient payment"
            True
          }
          Distribute => {
            expect now > poll.end_date // "Poll not ended"
            let winner_pair = poll.votes |> dict.to_pairs |> list.fold(
              |acc, pair| if pair.second > acc.second { pair } else { acc },
              Pair(poll.options[0], 0)
            )
            let winner = winner_pair.first
            let winning_amount = winner_pair.second
            expect winning_amount > 0 // "No winning votes"
            let losing_amount = poll.votes |> dict.to_pairs |> list.fold(
              |acc, pair| if pair.first != winner { acc + pair.second } else { acc },
              0
            )
            when poll.reward_redistribution is {
              True -> {
                let reward_per_vote = losing_amount / winning_amount
                let winners = poll.voter_records |> dict.to_pairs |> list.filter(|pair| pair.second.option == winner)
                expect tx.outputs |> list.all(|out| {
                  let addr = out.address
                  let winner_record = winners |> list.find(|pair| pair.first == addr)
                  when winner_record is {
                    Some(pair) -> {
                      let expected_reward = pair.second.amount * reward_per_vote
                      out.value.lovelace >= expected_reward || out.value |> assets.get(nicepoll_token) >= expected_reward
                    }
                    None -> True
                  }
                }) // "Invalid reward distribution"
                True
              }
              False -> {
                expect tx.outputs |> list.length == 0 // "Poll should terminate"
                True
              }
            }
          }
        }
      }
      _ -> fail
    }
  }

  // Minting logic for NicePoll Token (placeholder)
  mint(_redeemer: Data, policy_id: PolicyId, tx: Transaction) {
    expect policy_id == nicepoll_token, "Invalid policy ID"
    // Placeholder: Define minting/burning rules if needed
    todo @"mint and burn NicePoll Tokens"
  }

  // Fail for all other script purposes
  else(_ctx: ScriptContext) {
    fail
  }
}
