// For Move coding conventions, see
// https://docs.sui.io/concepts/sui-move-concepts/conventions

module sui_voting::sui_voting;

use sui::clock::Clock;
use sui::table::{Self, Table};

/// Abort codes
const E_INVALID_OPTION: u64 = 0;
const E_ALREADY_VOTED: u64 = 1;
const E_VOTING_EXPIRED: u64 = 2;

/// Shared voting object
/// - yes_votes / no_votes: counts for the two options
/// - voted: map voter_address -> option (0/1) to enforce one vote per address and allow auditing
/// - expired_at: unix timestamp in milliseconds
public struct Voting has key {
    id: UID,
    yes_votes: u64,
    no_votes: u64,
    voted: Table<address, u8>,
    expired_at: u64,
}

/// Create + share Voting as a Shared Object
entry fun create(expired_at: u64, ctx: &mut TxContext) {
    let voting = Voting {
        id: object::new(ctx),
        yes_votes: 0,
        no_votes: 0,
        voted: table::new(ctx),
        expired_at,
    };
    transfer::share_object(voting);
}

/// Vote for option YES/1 or NO/0
/// - each address can vote only once
#[allow(unused_mut_parameter)]
entry fun vote(v: &mut Voting, option: u8, clock: &Clock, ctx: &mut TxContext) {
    // validate expiry
    assert!(!is_expired(v, clock), E_VOTING_EXPIRED);

    // Only 2 options
    assert!(option == 0 || option == 1, E_INVALID_OPTION);

    let voter = tx_context::sender(ctx);

    // Each address can vote only once
    assert!(!has_voted(v, voter), E_ALREADY_VOTED);

    // Update counts
    if (option == 1) {
        v.yes_votes = v.yes_votes + 1;
    } else {
        v.no_votes = v.no_votes + 1;
    };

    // Record voter -> option (on-chain)
    table::add(&mut v.voted, voter, option);
}

/// On-chain readable results
public fun get_results(v: &Voting): (u64, u64) {
    (v.yes_votes, v.no_votes)
}

/// Check if an address has voted
public fun has_voted(v: &Voting, addr: address): bool {
    table::contains(&v.voted, addr)
}

/// Check if voting has expired
public fun is_expired(v: &Voting, clock: &Clock): bool {
    let current_time = clock.timestamp_ms();
    current_time >= v.expired_at
}

/// Get the option voted by an address (if any)
public fun get_voter_option(v: &Voting, addr: address): option::Option<u8> {
    if (table::contains(&v.voted, addr)) {
        option::some(*table::borrow(&v.voted, addr))
    } else {
        option::none<u8>()
    }
}
