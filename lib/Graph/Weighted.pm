package Graph::Weighted;

# ABSTRACT: A weighted graph implementation

our $VERSION = '0.54';

use warnings;
use strict;

use parent qw(Graph);

use Readonly;
Readonly my $DEBUG  => 0;
Readonly my $WEIGHT => 'weight';

=head1 SYNOPSIS

 use Graph::Weighted;

 my $gw = Graph::Weighted->new();
 $gw->populate(
    [ [ 0, 1, 2, 0, 0 ], # Vertex 0 with 5 edges of weight 3
      [ 1, 0, 3, 0, 0 ], #    "   1        "               4
      [ 2, 3, 0, 0, 0 ], #    "   2        "               5
      [ 0, 0, 1, 0, 0 ], #    "   3        "               1
      [ 0, 0, 0, 0, 0 ], #    "   4        "               0
    ]
 );
 for my $vertex (sort { $a <=> $b } $gw->vertices) {
    warn sprintf "vertex: %s weight=%.2f\n",
        $vertex, $gw->get_weight($vertex);
    for my $neighbor (sort { $a <=> $b } $gw->neighbors($vertex)) {
        warn sprintf "\tedge to: %s weight=%.2f\n",
            $neighbor, $gw->get_weight([$vertex, $neighbor]);
    }
 }

 my $gw = Graph::Weighted->new();
 my $attr = 'probability';
 $gw->populate(
    {
        0 => { 1 => 0.4, 3 => 0.6 },
        1 => { 0 => 0.3, 2 => 0.7 },
    },
    $attr
 );
 for my $vertex (sort { $a <=> $b } $gw->vertices) {
    warn sprintf "vertex: %s %s=%.2f\n",
        $vertex, $attr, $gw->get_attr($vertex, $attr);
    for my $neighbor (sort { $a <=> $b } $gw->neighbors($vertex)) {
        warn sprintf "\tedge to: %s %s=%.2f\n",
            $neighbor, $attr, $gw->get_attr([$vertex, $neighbor], $attr);
    }
 }

=head1 DESCRIPTION

A C<Graph::Weighted> object is a subclass of the L<Graph> module with 
attribute handling.  As such, all of the L<Graph> methods may be used
as documented, but with the addition of custom weighting.

=head1 METHODS

=head2 new()

  my $g = Graph::Weighted->new;

Return a new C<Graph::Weighted> object.

Please see L<Graph> for the possible constructor arguments.

=cut

sub new {
    my $class = shift;
    my $self = $class->SUPER::new();
    bless $self, $class;
    return $self;
}

=head2 populate()

  $g->populate(\@vectors);
  $g->populate(\@vectors, $attribute);
  $g->populate(\%data_points, $attribute);

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
conversation among associates, "In the same room" might be a good analogy, a
value of zero would mean "no conversation."

The C<attribute> is named 'weight' by default, but can be anything you like.
Multiple attributes may be applied to a graph, thereby layering increasing the
overall dimension.

=cut

sub populate {
    my ($self, $data, $attr) = @_;
    warn "populate(): $data\n" if $DEBUG;

    # Set the default attribute.
    $attr ||= $WEIGHT;

    # What type of data are we given?
    my $data_ref = ref $data;

    if ($data_ref eq 'ARRAY') {
        my $vertex = 0; # Initial vertex id.
        for my $neighbors (@$data) {
            warn "Neighbors of $vertex: [@$neighbors]\n" if $DEBUG;
            $self->_add_weighted_edges_from_array(
                $vertex, $neighbors, $attr
            );
            $vertex++; # Move on to the next vertex...
        }
    }
    elsif ($data_ref eq 'HASH') {
        for my $vertex (keys %$data) {
            warn "Neighbors of $vertex: [", join(' ', values %{$data->{$vertex}}), "]\n" if $DEBUG && ref $vertex;
            $self->_add_weighted_edges_from_hash(
                $vertex, $data->{$vertex}, $attr
            );
        }
    }
    else {
        warn "Unknown data type: $data\n";
    }
}

sub _add_weighted_edges_from_array {
    my ($self, $vertex, $neighbors, $attr) = @_;
    warn "add_weighted_edges(): $vertex, $neighbors, $attr\n" if $DEBUG;

    # Initial vertex weight
    my $vertex_weight = 0;

    # Make nodes and edges.
    for my $n (0 .. @$neighbors - 1) {
        my $w = $neighbors->[$n]; # Weight of the edge to the neighbor.
        next unless $w; # TODO Skip zero weight nodes if requested?

        # Add a node-node edge to the graph.
        $self->add_edge($vertex, $n);

        # Set the weight of the edge.
        my $edge_weight = _compute_edge_weight($w, $attr);
        warn "Edge: $vertex -($edge_weight)-> $n\n" if $DEBUG;
        $self->set_edge_attribute($vertex, $n, $attr, $edge_weight);

        # Tally the weight of the vertex.
        $vertex_weight = _compute_vertex_weight($w, $vertex_weight, $attr);
    }

    # Set the weight of the graph node.
    warn "Vertex $vertex $attr = $vertex_weight\n" if $DEBUG;
    $self->set_vertex_attribute($vertex, $attr, $vertex_weight);
}

sub _add_weighted_edges_from_hash {
    my ($self, $vertex, $neighbors, $attr) = @_;
    warn "add_weighted_edges(): $vertex, $neighbors, $attr\n" if $DEBUG;

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
            my $edge_weight = _compute_edge_weight($w, $attr);
            warn "Edge: $vertex -($edge_weight)-> $n\n" if $DEBUG;
            $self->set_edge_attribute($vertex, $n, $attr, $edge_weight);

            # Tally the weight of the vertex.
            $vertex_weight = _compute_vertex_weight($w, $vertex_weight, $attr);
        }
    }
    else {
        $vertex_weight = $neighbors;
    }

    # Set the weight of the graph node.
    warn "Vertex $vertex $attr = $vertex_weight\n" if $DEBUG;
    $self->set_vertex_attribute($vertex, $attr, $vertex_weight);
}

sub _compute_edge_weight {
    my ($weight, $attr) = @_;
    warn "compute_edge_weight(): $attr $weight\n" if $DEBUG;

    # Increment the current value by the node weight if no weight function is given.
    return $weight;
}

sub _compute_vertex_weight {
    my ($weight, $current, $attr) = @_;
    warn "compute_vertex_weight(): $attr $weight, $current\n" if $DEBUG;

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
    $attr ||= $WEIGHT;
    warn "get_attr($v, $attr)\n" if $DEBUG;

    # Return the edge attribute if given a list.
    return $self->get_edge_attribute(@$v, $attr) || 0 if ref $v eq 'ARRAY';

    # Return the vertex attribute if given a scalar.
    return $self->get_vertex_attribute($v, $attr) || 0;
}

1;
__END__

=head1 TO DO

Accept C<Matrix::*> objects.  

Find the heaviest and lightest nodes and edges?

Find the total weight beneath and above a node.

=head1 SEE ALSO

L<Graph>

The F<eg/*> and F<t/*> file sources.

=cut
