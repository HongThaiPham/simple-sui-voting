/*
#[test_only]
module sui_voting::sui_voting_tests;
// uncomment this line to import the module
// use sui_voting::sui_voting;

#[error(code = 0)]
const ENotImplemented: vector<u8> = b"Not Implemented";

#[test]
fun test_sui_voting() {
    // pass
}

#[test, expected_failure(abort_code = ::sui_voting::sui_voting_tests::ENotImplemented)]
fun test_sui_voting_fail() {
    abort ENotImplemented
}
*/

#[test_only]
module sui_voting::sui_voting_tests;

use sui::clock::{Self, Clock};
use sui::test_scenario::{Self as ts, Scenario};
use sui_voting::sui_voting::{Self, Voting};

// Test addresses
const ADMIN: address = @0xAD;
const VOTER1: address = @0x1;
const VOTER2: address = @0x2;
const VOTER3: address = @0x3;

// Helper function to create a clock for testing
fun create_clock(scenario: &mut Scenario): Clock {
    clock::create_for_testing(ts::ctx(scenario))
}

// Helper function to advance clock time
fun advance_clock(clock: &mut Clock, time_ms: u64) {
    clock::increment_for_testing(clock, time_ms);
}

#[test]
fun test_create_voting() {
    let mut scenario = ts::begin(ADMIN);

    // Create voting with expiry in 1 hour (3600000 ms)
    let expired_at = 3600000;

    ts::next_tx(&mut scenario, ADMIN);
    {
        sui_voting::create(expired_at, ts::ctx(&mut scenario));
    };

    // Verify voting object was created and shared
    ts::next_tx(&mut scenario, ADMIN);
    {
        let voting = ts::take_shared<Voting>(&scenario);
        let (yes, no) = sui_voting::get_results(&voting);

        assert!(yes == 0, 0);
        assert!(no == 0, 1);

        ts::return_shared(voting);
    };

    ts::end(scenario);
}

#[test]
fun test_vote_yes() {
    let mut scenario = ts::begin(ADMIN);

    // Create voting
    ts::next_tx(&mut scenario, ADMIN);
    {
        sui_voting::create(3600000, ts::ctx(&mut scenario));
    };

    // Create clock
    ts::next_tx(&mut scenario, ADMIN);
    let clock = create_clock(&mut scenario);

    // Vote YES (option = 1)
    ts::next_tx(&mut scenario, VOTER1);
    {
        let mut voting = ts::take_shared<Voting>(&scenario);

        sui_voting::vote(&mut voting, 1, &clock, ts::ctx(&mut scenario));

        let (yes, no) = sui_voting::get_results(&voting);
        assert!(yes == 1, 0);
        assert!(no == 0, 1);
        assert!(sui_voting::has_voted(&voting, VOTER1), 2);

        ts::return_shared(voting);
    };

    clock::destroy_for_testing(clock);
    ts::end(scenario);
}

#[test]
fun test_vote_no() {
    let mut scenario = ts::begin(ADMIN);

    // Create voting
    ts::next_tx(&mut scenario, ADMIN);
    {
        sui_voting::create(3600000, ts::ctx(&mut scenario));
    };

    // Create clock
    ts::next_tx(&mut scenario, ADMIN);
    let clock = create_clock(&mut scenario);

    // Vote NO (option = 0)
    ts::next_tx(&mut scenario, VOTER1);
    {
        let mut voting = ts::take_shared<Voting>(&scenario);

        sui_voting::vote(&mut voting, 0, &clock, ts::ctx(&mut scenario));

        let (yes, no) = sui_voting::get_results(&voting);
        assert!(yes == 0, 0);
        assert!(no == 1, 1);
        assert!(sui_voting::has_voted(&voting, VOTER1), 2);

        ts::return_shared(voting);
    };

    clock::destroy_for_testing(clock);
    ts::end(scenario);
}

#[test]
fun test_multiple_voters() {
    let mut scenario = ts::begin(ADMIN);

    // Create voting
    ts::next_tx(&mut scenario, ADMIN);
    {
        sui_voting::create(3600000, ts::ctx(&mut scenario));
    };

    // Create clock
    ts::next_tx(&mut scenario, ADMIN);
    let clock = create_clock(&mut scenario);

    // VOTER1 votes YES
    ts::next_tx(&mut scenario, VOTER1);
    {
        let mut voting = ts::take_shared<Voting>(&scenario);
        sui_voting::vote(&mut voting, 1, &clock, ts::ctx(&mut scenario));
        ts::return_shared(voting);
    };

    // VOTER2 votes YES
    ts::next_tx(&mut scenario, VOTER2);
    {
        let mut voting = ts::take_shared<Voting>(&scenario);
        sui_voting::vote(&mut voting, 1, &clock, ts::ctx(&mut scenario));
        ts::return_shared(voting);
    };

    // VOTER3 votes NO
    ts::next_tx(&mut scenario, VOTER3);
    {
        let mut voting = ts::take_shared<Voting>(&scenario);
        sui_voting::vote(&mut voting, 0, &clock, ts::ctx(&mut scenario));

        let (yes, no) = sui_voting::get_results(&voting);
        assert!(yes == 2, 0);
        assert!(no == 1, 1);

        assert!(sui_voting::has_voted(&voting, VOTER1), 2);
        assert!(sui_voting::has_voted(&voting, VOTER2), 3);
        assert!(sui_voting::has_voted(&voting, VOTER3), 4);

        ts::return_shared(voting);
    };

    clock::destroy_for_testing(clock);
    ts::end(scenario);
}

#[test]
fun test_get_voter_option() {
    let mut scenario = ts::begin(ADMIN);

    // Create voting
    ts::next_tx(&mut scenario, ADMIN);
    {
        sui_voting::create(3600000, ts::ctx(&mut scenario));
    };

    // Create clock
    ts::next_tx(&mut scenario, ADMIN);
    let clock = create_clock(&mut scenario);

    // VOTER1 votes YES
    ts::next_tx(&mut scenario, VOTER1);
    {
        let mut voting = ts::take_shared<Voting>(&scenario);
        sui_voting::vote(&mut voting, 1, &clock, ts::ctx(&mut scenario));
        ts::return_shared(voting);
    };

    // VOTER2 votes NO
    ts::next_tx(&mut scenario, VOTER2);
    {
        let mut voting = ts::take_shared<Voting>(&scenario);
        sui_voting::vote(&mut voting, 0, &clock, ts::ctx(&mut scenario));

        // Check voter options
        let voter1_option = sui_voting::get_voter_option(&voting, VOTER1);
        assert!(voter1_option.is_some(), 0);
        assert!(*voter1_option.borrow() == 1, 1);

        let voter2_option = sui_voting::get_voter_option(&voting, VOTER2);
        assert!(voter2_option.is_some(), 2);
        assert!(*voter2_option.borrow() == 0, 3);

        let voter3_option = sui_voting::get_voter_option(&voting, VOTER3);
        assert!(voter3_option.is_none(), 4);

        ts::return_shared(voting);
    };

    clock::destroy_for_testing(clock);
    ts::end(scenario);
}

#[test]
fun test_is_expired() {
    let mut scenario = ts::begin(ADMIN);

    // Create voting that expires at 1000ms
    ts::next_tx(&mut scenario, ADMIN);
    {
        sui_voting::create(1000, ts::ctx(&mut scenario));
    };

    // Create clock at time 0
    ts::next_tx(&mut scenario, ADMIN);
    let mut clock = create_clock(&mut scenario);

    ts::next_tx(&mut scenario, ADMIN);
    {
        let voting = ts::take_shared<Voting>(&scenario);

        // Not expired yet
        assert!(!sui_voting::is_expired(&voting, &clock), 0);

        ts::return_shared(voting);
    };

    // Advance time to 1000ms (exactly at expiry)
    advance_clock(&mut clock, 1000);

    ts::next_tx(&mut scenario, ADMIN);
    {
        let voting = ts::take_shared<Voting>(&scenario);

        // Should be expired now
        assert!(sui_voting::is_expired(&voting, &clock), 1);

        ts::return_shared(voting);
    };

    clock::destroy_for_testing(clock);
    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = ::sui_voting::sui_voting::E_INVALID_OPTION)]
fun test_vote_invalid_option() {
    let mut scenario = ts::begin(ADMIN);

    // Create voting
    ts::next_tx(&mut scenario, ADMIN);
    {
        sui_voting::create(3600000, ts::ctx(&mut scenario));
    };

    // Create clock
    ts::next_tx(&mut scenario, ADMIN);
    let clock = create_clock(&mut scenario);

    // Try to vote with invalid option (2)
    ts::next_tx(&mut scenario, VOTER1);
    {
        let mut voting = ts::take_shared<Voting>(&scenario);
        sui_voting::vote(&mut voting, 2, &clock, ts::ctx(&mut scenario));
        ts::return_shared(voting);
    };

    clock::destroy_for_testing(clock);
    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = ::sui_voting::sui_voting::E_ALREADY_VOTED)]
fun test_vote_twice() {
    let mut scenario = ts::begin(ADMIN);

    // Create voting
    ts::next_tx(&mut scenario, ADMIN);
    {
        sui_voting::create(3600000, ts::ctx(&mut scenario));
    };

    // Create clock
    ts::next_tx(&mut scenario, ADMIN);
    let clock = create_clock(&mut scenario);

    // First vote - should succeed
    ts::next_tx(&mut scenario, VOTER1);
    {
        let mut voting = ts::take_shared<Voting>(&scenario);
        sui_voting::vote(&mut voting, 1, &clock, ts::ctx(&mut scenario));
        ts::return_shared(voting);
    };

    // Second vote - should fail
    ts::next_tx(&mut scenario, VOTER1);
    {
        let mut voting = ts::take_shared<Voting>(&scenario);
        sui_voting::vote(&mut voting, 0, &clock, ts::ctx(&mut scenario));
        ts::return_shared(voting);
    };

    clock::destroy_for_testing(clock);
    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = ::sui_voting::sui_voting::E_VOTING_EXPIRED)]
fun test_vote_after_expired() {
    let mut scenario = ts::begin(ADMIN);

    // Create voting that expires at 1000ms
    ts::next_tx(&mut scenario, ADMIN);
    {
        sui_voting::create(1000, ts::ctx(&mut scenario));
    };

    // Create clock
    ts::next_tx(&mut scenario, ADMIN);
    let mut clock = create_clock(&mut scenario);

    // Advance time past expiry
    advance_clock(&mut clock, 2000);

    // Try to vote after expiry - should fail
    ts::next_tx(&mut scenario, VOTER1);
    {
        let mut voting = ts::take_shared<Voting>(&scenario);
        sui_voting::vote(&mut voting, 1, &clock, ts::ctx(&mut scenario));
        ts::return_shared(voting);
    };

    clock::destroy_for_testing(clock);
    ts::end(scenario);
}
