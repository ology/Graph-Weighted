package Graph::Weighted;
# ABSTRACT: A weighted graph implementation

our $VERSION = '0.5301';

use warnings;
use strict;

use base qw(Graph);

use constant DEBUG  => 0;
use constant WEIGHT => 'weight';

=head1 NAME

Graph::Weighted - A weighted graph implementation

=head1 SYNOPSIS

  use Graph::Weighted;

  # Vertex 0 has 5 edges of weight 3 units. The edges to nodes 1 and 2
  # each weigh 1 and 2 units, respectively.
  $g->populate([
    [ 0, 1, 2, 0, 0 ], # V 0
    [ 1, 0, 3, 0, 0 ], # V 1
    [ 2, 3, 0, 0, 0 ], # V 2
    [ 0, 0, 1, 0, 0 ], # One lonely edge weighing one lonely unit.
    [ 0, 0, 0, 0, 0 ], # V 4 weighs nothing.
  ]);

  my $attr = 'magnitude';
  # Vertex 0 has 2 edges (1,3) of magnitude (4,6).
  $g->populate({
      0 => { 1 => 4, 3 => 6 },
      1 => { 0 => 3, 2 => 7 },
      2 => 8, # Terminal value
      3 => 9, # Terminal value
    },
    $attr
  );

  # Show each (numeric) vertex.
  for my $v (sort { $a <=> $b } $g->vertices) {
    printf "vertex: %s weight=%.2f, %s=%.2f\n",
        $v,    $g->get_weight($v),
        $attr, $g->get_attr($v, $attr);
    # TODO Skip ...what? Why?
    next if $g->neighbors($v) == 1;
    # Show each (numeric) edge.
    for my $n (sort { $a <=> $b } $g->neighbors($v)) {
        printf "\tedge to: %s weight=%.2f, %s=%.2f\n",
            $n,    $g->get_weight([$v, $n]),
            $attr, $g->get_attr([$v, $n], $attr);
    }
  }

=head1 DESCRIPTION

A C<Graph::Weighted> object is a subclass of the L<Graph> module with the added
benefit of built-in, multiple layers of weighted attributes.  As such, all of
the L<Graph> methods may be used as documented.

=head1 METHODS

=head2 new()

Return a new C<Graph::Weighted> object.

Please see L<Graph> for the myriad possible constructor arguments.

=cut

sub new {
    my $class = shift;
    my $self = $class->SUPER::new();
    bless $self, $class;
    return $self;
}

=head2 populate()

  $g->populate(\@vectors)
  $g->populate(\@vectors, $attribute)
  $g->populate(\%data_points, $attribute)
  $g->populate($data, $attribute, \&vertex_method, \&edge_method)

Populate a graph with weighted nodes.

For arguments, the data can be a numeric value ("terminal node"), an arrayref
of numeric vectors or a hashref of numeric edge values.  The C<attribute> is
an optional string name, of default "weight."  The C<vertex_method> and
C<edge_method> are optional code-references giving alternate weighting
functions.

Examples of C<data> in array reference form, using the default C<vertex> and
C<edge> methods:

  []      No edges.
  [0]     1 vertex and 1 edge to node 0 having weight of 0.
  [1]     1 vertex and 1 edge to node 0 weight 1.
  [0,1]   2 vertices and 2 edges having edge weights 0,1 and vertex weight 1.
  [0,1,9] 3 vertices and 3 edges having edge weights 0,1,9 and vertex weight 10.

An edge weight of zero can mean anything you wish.  If weights are seen as
conversation among associates, "In the same room" might be a good analogy.

The C<attribute> is named 'weight' by default, but can be anything you like.
Multiple attributes may be applied to a graph, thereby layering node values.

The default vertex weighting function (C<vertex_method>) is a simple sum of
the neighbor weights.  An alternative may be provided and should accept the
current node weight, current weight total and the attribute as arguments to
update.  For example:

  sub vertex_weight_function {
    my ($current_node_weight, $current_weight_total, $attribute);
    return $current_node_weight / $current_weight_total;
  }

The default edge weighting function (C<edge_method>) simply returns the value in
the node's neighbor position.  An alternative may be provided, as a subroutine
reference, which should accept the current edge weight and the attribute to
update.  For example:

  sub edge_weight_function {
    my ($weight, $attribute);
    return $current_weight_total / $current_node_weight;
  }

=cut

sub populate {
    my ($self, $data, $attr, $vertex_method, $edge_method) = @_;
    warn "populate(): $data\n" if DEBUG;

    # Set the default attribute.
    $attr ||= WEIGHT;

    # What type of data are we given?
    my $data_ref = ref $data;

    if ($data_ref eq 'ARRAY') {
        my $vertex = 0; # Initial vertex id.
        for my $neighbors (@$data) {
            warn "Neighbors of $vertex: [@$neighbors]\n" if DEBUG;
            $self->_add_weighted_edges_from_array(
                $vertex, $neighbors, $attr, $vertex_method, $edge_method
            );
            $vertex++; # Move on to the next vertex...
        }
    }
    elsif ($data_ref eq 'HASH') {
        for my $vertex (keys %$data) {
            warn "Neighbors of $vertex: [", join(' ', values %{$data->{$vertex}}), "]\n" if DEBUG && ref $vertex;
            $self->_add_weighted_edges_from_hash(
                $vertex, $data->{$vertex}, $attr, $vertex_method, $edge_method
            );
        }
    }
    else {
        warn "Unknown data type: $data\n";
    }
}

sub _add_weighted_edges_from_array {
    my ($self, $vertex, $neighbors, $attr, $vertex_method, $edge_method) = @_;
    warn "add_weighted_edges(): $vertex, $neighbors, $attr\n" if DEBUG;

    # Initial vertex weight
    my $vertex_weight = 0;

    # Make nodes and edges.
    for my $n (0 .. @$neighbors - 1) {
        my $w = $neighbors->[$n]; # Weight of the edge to the neighbor.
        next unless $w; # TODO Skip zero weight nodes if requested?

        # Add a node-node edge to the graph.
        $self->add_edge($vertex, $n);

        # Set the weight of the edge.
        my $edge_weight = _compute_edge_weight($w, $attr, $edge_method);
        warn "Edge: $vertex -($edge_weight)-> $n\n" if DEBUG;
        $self->set_edge_attribute($vertex, $n, $attr, $edge_weight);

        # Tally the weight of the vertex.
        $vertex_weight = _compute_vertex_weight($w, $vertex_weight, $attr, $vertex_method);
    }

    # Set the weight of the graph node.
    warn "Vertex $vertex $attr = $vertex_weight\n" if DEBUG;
    $self->set_vertex_attribute($vertex, $attr, $vertex_weight);
}

sub _add_weighted_edges_from_hash {
    my ($self, $vertex, $neighbors, $attr, $method) = @_;
    warn "add_weighted_edges(): $vertex, $neighbors, $attr\n" if DEBUG;

    # Initial vertex weight
    my $vertex_weight = 0;

    # Handle terminal nodes.
    if (ref $neighbors) {
        # Make nodes and edges.
        for my $n (keys %$neighbors) {
            my $w = $neighbors->{$n}; # Weight of the edge to the neighbor.

            # Add a node-node edge to the graph.
            $self->add_edge($vertex, $n);

            # Set the weight of the edge.
            my $edge_weight = _compute_edge_weight($w, $attr, $method);
            warn "Edge: $vertex -($edge_weight)-> $n\n" if DEBUG;
            $self->set_edge_attribute($vertex, $n, $attr, $edge_weight);

            # Tally the weight of the vertex.
            $vertex_weight = _compute_vertex_weight($w, $vertex_weight, $attr, $method);
        }
    }
    else {
        $vertex_weight = $neighbors;
    }

    # Set the weight of the graph node.
    warn "Vertex $vertex $attr = $vertex_weight\n" if DEBUG;
    $self->set_vertex_attribute($vertex, $attr, $vertex_weight);
}

sub _compute_edge_weight {
    my ($weight, $attr, $method) = @_;
    warn "compute_edge_weight(): $attr $weight\n" if DEBUG;

    # Call the weight function if one is given.
    return $method->($weight, $attr) if $method and ref $method eq 'CODE';

    # Increment the current value by the node weight if no weight function is given.
    return $weight;
}

sub _compute_vertex_weight {
    my ($weight, $current, $attr, $method) = @_;
    warn "compute_vertex_weight(): $attr $weight, $current\n" if DEBUG;

    # Call the weight function if one is given.
    return $method->($weight, $current, $attr) if $method and ref $method eq 'CODE';

    # Increment the current value by the node weight if no weight function is given.
    return $weight + $current;
}

=head2 get_weight()

  $w = $g->get_weight($vertex);
  $w = $g->get_weight(\@edge);

Return the weight for the vertex or edge.

A vertex is a numeric value.  An edge is an array reference with 2 elements.
If no value is found, zero is returned.

=cut

sub get_weight {
    my $self = shift;
    return $self->get_attr(@_);
}

=head2 get_attr()

  $w = $g->get_attr($vertex, $attribute);
  $w = $g->get_attr(\@edge, $attribute);

Return the named attribute value for the vertex or edge or zero.

=cut

sub get_attr {
    my ($self, $v, $attr) = @_;
    die 'ERROR: No vertex given to get_attr()' unless defined $v;

    # Default to weight.
    $attr ||= WEIGHT;
    warn "get_attr($v, $attr)\n" if DEBUG;

    # Return the edge attribute if given a list.
    return $self->get_edge_attribute(@$v, $attr) || 0 if ref $v eq 'ARRAY';

    # Return the vertex attribute if given a scalar.
    return $self->get_vertex_attribute($v, $attr) || 0;
}

1;
__END__

=head1 TO DO

Accept hashrefs and C<Matrix::*> objects instead of just LoLs.  

L<Statistics::Descriptive::Weighted> must be investigates...

Find the heaviest and lightest nodes.

Find the total weight beneath a node.

=head1 SEE ALSO

L<Graph>

The F<eg/> and F<t/*> sources.

=head1 AUTHOR

Gene Boggs, E<lt>gene@cpan.orgE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright 2003-2012 Gene Boggs

This program is free software; you can redistribute it and/or modify it under
the terms of either: the GNU General Public License as published by the Free
Software Foundation; or the Artistic License.

=cut
