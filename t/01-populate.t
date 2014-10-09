#!/usr/bin/env perl
use strict;
use warnings;

use Test::More;

BEGIN {
    use constant GW => 'Graph::Weighted';
    use_ok GW;
};

my $weight_dataset = [
    [], [[]],             # No nodes
    [ [ 0 ], ],           # 1 node, no edges
    [ [ 1, 0, ],          # 2 nodes of "self-edges"
      [ 0, 1, ], ],
    [ [ 0, 1, 2, 0, 0, ],    # 0 talks to 1 once and 2 twice (weight 3)
      [ 1, 0, 3, 0, 0, ],    # 1 talks to 0 once and 2 thrice (weight 4)
      [ 2, 3, 0, 0, 0, ],    # 2 talks to 0 twice and 1 thrice (weight 5)
      [ 0, 0, 1, 0, 0, ],    # 3 talks to 2 once (weight 1)
      [ 0, 0, 0, 0, 0, ], ], # 4 talks to no-one (weight 0)
];

diag 'Test weight LoL...';
my $n = 0;
for my $data (@$weight_dataset) {
    my $g = eval { Graph::Weighted->new() };
    isa_ok $g, GW, "weight $n";
    # Populate the graph.
    eval { $g->populate($data) };
    print $@ if $@;
    ok !$@, "populate weight data $n";
    # Know vertex weights.
    my $g_weight = 0;
    for my $vertex ($g->vertices()) {
        my $v_weight = $g->get_weight($vertex);
        $g_weight += $v_weight;
        # Know edge weights.
        for my $neighbor ($g->neighbors($vertex)) {
            next unless $g->has_edge($vertex, $neighbor);
            my $ew = $g->get_weight([$vertex, $neighbor]);
            ok $ew, "edge weight ($vertex, $neighbor): $ew";
        }
    }
    my $w = _weight_of($data);
    is $g_weight, $w, "vertex weight: $g_weight = $w";

    $n++;
}

my $magnitude_dataset = [
    [],                   # No nodes
    [ [ 0 ], ],           # 1 node, no edges
    [ [ 1, 0, ],          # 2 nodes w=1,1 of self-edges
      [ 0, 1, ], ],
    [ [ 0, 2, 1, 0, 0, ], # 5 nodes w=3,4,5,1,0
      [ 3, 0, 1, 0, 0, ],
      [ 3, 2, 0, 0, 0, ],
      [ 0, 0, 1, 0, 0, ],
      [ 1, 1, 1, 1, 0, ], ],
];

diag 'Test magnitude LoL...';
$n = 0;
for my $data (@$magnitude_dataset) {
    my $g = eval { Graph::Weighted->new() };
    isa_ok $g, GW, "magnitude $n";
    eval { $g->populate($data, 'magnitude') };
    print $@ if $@;
    ok !$@, "populate magnitude data $n";
    my $g_weight = 0;
    # Know vertex weights.
    for my $vertex ($g->vertices()) {
        my $v_weight = $g->get_attr($vertex, 'magnitude');
        $g_weight += $v_weight;
        # Know edge weights.
        for my $neighbor ($g->neighbors($vertex)) {
            next unless $g->has_edge($vertex, $neighbor);
            my $ew = $g->get_weight([$vertex, $neighbor], 'magnitude');
            ok $ew, "edge magnitude ($vertex, $neighbor): $ew";
        }
    }
    my $w = _weight_of($data);
    is $g_weight, $w, "magnitude: $g_weight = $w";
    $n++;
}

diag 'Test both weight and magnitude LoL...';
{
    my $g = eval { Graph::Weighted->new() };
    isa_ok $g, GW, 'weight and magnitude';
    eval { $g->populate($weight_dataset->[-1]) };
    print $@ if $@;
    ok !$@, 'populate weight data';
    my $g_weight = 0;
    for my $vertex ($g->vertices()) {
        my $v_weight = $g->get_weight($vertex);
        $g_weight += $v_weight;
    }
    my $w = _weight_of($weight_dataset->[-1]);
    is $g_weight, $w, "weight: $g_weight = $w";

    eval { $g->populate($magnitude_dataset->[-1], 'magnitude') };
    print $@ if $@;
    ok !$@, 'populate magnitude data';
    $g_weight = 0;
    for my $vertex ($g->vertices()) {
        my $v_weight = $g->get_attr($vertex, 'magnitude');
        $g_weight += $v_weight;
    }
    $w = _weight_of($magnitude_dataset->[-1]);
    is $g_weight, $w, "magnitude: $g_weight = $w";

    for my $e ($g->edges) {
        my $w = $g->get_weight($e, 'weight') || 0;
        my $m = $g->get_weight($e, 'magnitude') || 0;
        ok defined($w) && defined($m), "edge attributes: @$e = $w, $m";
    }
}

$weight_dataset = [
    {}, # No nodes
    { a => {} }, # 1 node, no edges
    { a => {a => 1}, b => {b => 1} }, # 2 nodes of self-edges
    # Same as LoL above but with alpha key names:
    { a => {b=>2,c=>1}, b => {a=>3,c=>1}, c => {a=>3,b=>2}, d => {c=>1}, e => {a=>1,b=>1,c=>1,d=>1} },
    { a => 123, b => 321, c => {a => 0.4, b => 0.6} }, # Terminal values
];
diag 'Test weight HoH...';
for my $data (@$weight_dataset) {
    my $g = eval { Graph::Weighted->new() };
    isa_ok $g, GW, "weight $n";
    eval { $g->populate($data) };
    print $@ if $@;
    ok !$@, "populate weight data $n";
    my $g_weight = 0;
    for my $vertex ($g->vertices()) {
        my $v_weight = $g->get_weight($vertex);
        $g_weight += $v_weight;
    }
    my $w = _weight_of($data);
    is $g_weight, $w, "weight: $g_weight = $w";
    $n++;
}

done_testing();

# Return total sum of a 2D numeric value data structure.
sub _weight_of {
    my $data = shift;
    my $weight = 0;
    if (ref $data eq 'ARRAY') {
        for my $i (@$data) {
            $weight += $_ for @$i;
        }
    }
    elsif (ref $data eq 'HASH') {
        for my $i (values %$data) {
            if (ref $i eq 'HASH') {
                $weight += $_ for values %$i;
            }
            else { # We are probably on a terminal (literal) value.
                $weight += $i;
            }
        }
    }
    return $weight;
}
