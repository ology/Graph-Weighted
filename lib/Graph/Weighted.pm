package Graph::Weighted;

# ABSTRACT: A weighted graph implementation

our $VERSION = '0.55';

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
    [ [ 0, 1, 2, 0, 0 ], # Vertex 0 with 2 edges of weight 3
      [ 1, 0, 3, 0, 0 ], #    "   1      2 "               4
      [ 2, 3, 0, 0, 0 ], #    "   2      2 "               5
      [ 0, 0, 1, 0, 0 ], #    "   3      1 "               1
      [ 0, 0, 0, 0, 0 ], #    "   4      0 "               0
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

 my ($heaviest, $lightest) = $gw->span();

 my $gw = Graph::Weighted->new();
 my $attr = 'probability';
 $gw->populate(
    {
        0 => { 1 => 0.4, 3 => 0.6 }, # Vertex 0 with 2 edges of weight 1
        1 => { 0 => 0.3, 2 => 0.7 }, # Vertex 1 "    2 "
        2 => { 0 => 0.5, 2 => 0.5 }, # Vertex 2 "    2 "
        3 => { 0 => 0.2, 1 => 0.8 }, # Vertex 3 "    2 "
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

  my $gw = Graph::Weighted->new;

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

  $gw->populate($matrix);
  $gw->populate(\@vectors);
  $gw->populate(\@vectors, $attribute);
  $gw->populate(\%data_points, $attribute);

Populate a graph with weighted nodes.

For arguments, the data can be a numeric value ("terminal node"), an arrayref
of numeric vectors, a C<Math::MatrixReal> object, or a hashref of numeric edge
values.  The C<attribute> is an optional string name, with the default "weight."

Examples of C<data> in array reference form:

  []      1 vertex with no edges.
  [0]     1 vertex and 1 edge to node 0 having weight of 0.
  [1]     1 vertex and 1 edge to node 0 weight 1.
  [0,1]   2 vertices and 2 edges having edge weights 0,1 and vertex weight 1.
  [0,1,9] 3 vertices and 3 edges having edge weights 0,1,9 and vertex weight 10.

Multiple attributes may be applied to a graph, thereby layering and increasing
the overall dimension.

=cut

sub populate {
    my ($self, $data, $attr) = @_;
    warn "populate(): $data\n" if $DEBUG;

    # Set the default attribute.
    $attr ||= $WEIGHT;

    # What type of data are we given?
    my $data_ref = ref $data;

    if ($data_ref eq 'ARRAY' || $data_ref eq 'Math::Matrix') {
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

        warn "Edge: $vertex -($w)-> $n\n" if $DEBUG;
        $self->set_edge_attribute($vertex, $n, $attr, $w);

        # Tally the weight of the vertex.
        $vertex_weight += $w;
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

            warn "Edge: $vertex -($w)-> $n\n" if $DEBUG;
            $self->set_edge_attribute($vertex, $n, $attr, $w);

            # Tally the weight of the vertex.
            $vertex_weight += $w;
        }
    }
    else {
        $vertex_weight = $neighbors;
    }

    # Set the weight of the graph node.
    warn "Vertex $vertex $attr = $vertex_weight\n" if $DEBUG;
    $self->set_vertex_attribute($vertex, $attr, $vertex_weight);
}

=head2 get_weight()

  $w = $gw->get_weight($vertex);
  $w = $gw->get_weight([$vertex, $neighbor]);

Return the weight for the vertex or edge.

A vertex is a numeric value.  An edge is an array reference with 2 elements.
If no value is found, zero is returned.

=cut

sub get_weight {
    my $self = shift;
    return $self->get_attr(@_);
}

=head2 get_attr()

  $w = $gw->get_attr($vertex, $attribute);
  $w = $gw->get_attr(\@edge, $attribute);

Return the named attribute value for the vertex or edge.

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

=head2 span()

 my ($lightest, $heaviest) = $gw->span();
 my ($lightest, $heaviest) = $gw->span($attr);

Return the span of lightest to heaviest vertices.

=cut

sub span {
    my ($self, $attr) = @_;

    my $mass = {};
    for my $vertex ( $self->vertices ) {
        $mass->{$vertex} = $self->get_attr($vertex, $attr);
    }

    my ($smallest, $biggest);
    for my $vertex ( keys %$mass ) {
        my $current = $mass->{$vertex};
        if ( !defined $smallest || $smallest > $current ) {
            $smallest = $current;
        }
        if ( !defined $biggest || $biggest < $current ) {
            $biggest = $current;
        }
    }

    my ($lightest, $heaviest) = ([], []);
    for my $vertex ( keys %$mass ) {
        push @$lightest, $vertex if $mass->{$vertex} == $smallest;
        push @$heaviest, $vertex if $mass->{$vertex} == $biggest;
    }

    return $lightest, $heaviest;
}

=head2 path_attr()

 my $weight = $gw->path_attr(\@vertices);
 my $weight = $gw->path_attr(\@vertices, $attr);

Return the summed weight (or given attribute) of the path edges.

=cut

sub path_attr {
    my ($self, $path, $attr) = @_;

    return unless $self->has_path( @$path );

    my $path_attr = 0;

    for my $i ( 0 .. @$path - 2 ) {
        $path_attr += $self->get_attr( [ $path->[$i], $path->[ $i + 1 ] ] );
    }

    return $path_attr;
}

1;
__END__

=head1 TO DO

Find the total weight beneath a node.

=head1 SEE ALSO

L<Graph>

The F<eg/*> and F<t/*> file sources.

=cut
