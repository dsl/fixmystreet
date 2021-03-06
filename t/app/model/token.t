#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 45;

use FixMyStreet;
use FixMyStreet::App;
use mySociety::AuthToken;
use mySociety::DBHandle 'dbh';

# set things up so that code using mySociety::DBHandle is happy
FixMyStreet->configure_mysociety_dbhandle();

# NOTE - remember that you need to explicitly dbh()->commit after making
# database changes with the mySociety::* modules.

# create a token using DBIC and check we can read it using AuthToken, and vice
# versa

my %tests = (
    nested_hash => { foo => 'bar', and => [ 'baz', 'bundy' ] },
    array  => [ 'foo', 'bar' ],
    scalar => 123,
);

my $token_rs = FixMyStreet::App->model('DB::Token');

# create using DBIC
foreach my $test_data_name ( sort keys %tests ) {
    my $test_data = $tests{$test_data_name};

    pass "--- testing DBIC create using '$test_data_name'";

    my $dbic_token =
      $token_rs->create( { scope => 'testing', data => $test_data } );
    my $token = $dbic_token->token;
    ok $token, "stored token '$token'";

    is_deeply $dbic_token->data, $test_data, "data stored correctly using DBIC";

    # read back using DBIC
    is_deeply $token_rs->find( { token => $token, scope => 'testing' } )->data,
      $test_data,
      "data read back correctly with DBIC";

    # read back using mySociety::AuthToken
    is_deeply mySociety::AuthToken::retrieve( 'testing', $token ),
      $test_data, "data read back correctly with m::AT";

    # delete token
    ok $dbic_token->delete, "delete token";

    is $token_rs->find( { token => $token, scope => 'testing' } ),
      undef,
      "token gone for DBIC";

    # read back using mySociety::AuthToken
    is mySociety::AuthToken::retrieve( 'testing', $token ),
      undef, "token gone with m::AT";

}

# create using m::AT
foreach my $test_data_name ( sort keys %tests ) {
    my $test_data = $tests{$test_data_name};

    pass "--- testing m::AT create using '$test_data_name'";

    my $token = mySociety::AuthToken::store( 'testing', $test_data );
    dbh->commit();
    ok $token, "stored token '$token'";

    # read back using DBIC
    is_deeply $token_rs->find( { token => $token, scope => 'testing' } )->data,
      $test_data,
      "data read back correctly with DBIC";

    # read back using mySociety::AuthToken
    is_deeply mySociety::AuthToken::retrieve( 'testing', $token ),
      $test_data, "data read back correctly with m::AT";

    # delete token
    ok mySociety::AuthToken::destroy( 'testing', $token ), "destroy token";
    dbh->commit();

    is $token_rs->find( { token => $token, scope => 'testing' } ),
      undef,
      "token gone for DBIC";

    # read back using mySociety::AuthToken
    is mySociety::AuthToken::retrieve( 'testing', $token ),
      undef, "token gone with m::AT";

}
