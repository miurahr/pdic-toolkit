#========================================================================
#
# PDIC::Writer.pm
#
# Copyright (c) 2002 Tsutomu Kuroda <tkrd@mail.com> All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
#========================================================================

package PDIC::Writer;

require 5.004;

use strict;
use warnings;
use vars qw(@ISA $VERSION $DEBUG);
use open IN => ':raw', OUT => ':raw';

$VERSION = '1.13'; # $Date: 2002/02/23 00:00:00 $
$DEBUG = 0;

use PDIC::Header;
use PDIC::Index;
use PDIC::Data;

use Carp;

#------------------------------------------------------------------------
#
# new($filename, $num_entry, $average_headword_length)
#
# Creates a new PDIC::Writer object.
#
# $filename                : The name of .dic file to be created.
# $num_entry               : The number of entries of dictionary.
# $average_headword_length : The average length of headwords.
#
#------------------------------------------------------------------------

sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    
    my $f = shift;
    if (not defined $f) {
        croak("The first argument is not given or defined.")
    }
    elsif (ref $f) {
        if (ref $f eq 'IO::Handle') {
            $self->{FH} = $f;
        }
        else {
            croak("The first argument must be a filename or IO::Handle object.");
        }
    }
    else {
        open(IN, "> $f") or croak("Can't open '$f'.");
        $self->{FH} = *IN{IO};
    }
    
    $self->{NUM_ENTRIES} = shift;
    $self->{AVERAGE_HEADWORD_LENGTH} = shift;
    
    if (not defined $self->{NUM_ENTRIES}) {
        croak("Second argument is not defined.");
    }
    
    if (not defined $self->{AVERAGE_HEADWORD_LENGTH}) {
        croak("Third argument is not defined.");
    }
    
    $self->{DEBUG} = $DEBUG;
    $self->{INDEX_BLKBIT} = 0;
    $self->{QUEUE} = [];
    $self->{NUM_PROCESSED_ENTRIES} = 0;
    $self->{SUM_REMAINDER} = 0;
    $self->{STANDARD_NUM_ENTRIES_PER_DATA_SECTION} = 16;
    $self->{ENTRY_COUNT} = 0;
    $self->{PREV_HEADWORD} = '';
    
    # Minimum Value of 'STANDARD_NUM_ENTRIES_PER_SECTION'.
    # Must be greater than $self->{S} + 2.
    $self->{Q} = 16;
    
    # The headwords that have longer length than R will not be
    # included in the indices if possible.
    $self->{R} = int($self->{AVERAGE_HEADWORD_LENGTH} * 1.5);
    
    # You could improve the storage rate with a greater value.
    $self->{S} = 6;
    
    # You can reduce the size of dictionary size with a greater
    # value.
    $self->{Z} = 1 / 3;
    
    return $self;
}

#------------------------------------------------------------------------
#
# set_constant()
#
# Sets constants that controls the behaviour of PDIC::Writer object.
#
#------------------------------------------------------------------------

sub set_constant {
    my $self = shift;
    my $name = shift;
    my $value = shift;
    
    if (not defined $name) {
        croak("First argument is not defined.");
    }
    if (not defined $value) {
        croak("Second argument is not defined.");
    }
    
    if (not $value =~ /^\d+(\.\d+)?$/) {
        croak("Second argument must be a number.");
    }
    
    if ($name eq 'Q') {
        if ($value < $self->{S} + 2) {
            croak("Q should be an interger greater than S($self->{S}) + 2.");
        }
        if ($value !~ /^\d+$/) {
            croak("Q should be an interger.");
        }
    }
    elsif ($name eq 'R') {
        if ($value <= 1) {
            croak("R should be greater than 1.");
        }
    }
    elsif ($name eq 'S') {
        if ($value <= 1) {
            croak("R should be zero or an integer greater than zero.");
        }
    }
    elsif ($name eq 'Z') {
        if ($value <= 0 or $value >= 1) {
            croak("Z should be greater than 0 and smaller than 1.");
        }
    }
	else {
            croak("Constant $name cannot be set.");
        }
    
    $self->{$name} = $value;
}

#------------------------------------------------------------------------
#
# use_huge_dictionary()
#
# Sets INDEX_BLKBIT to 1.
#
# * You should call this when the size of dictionary will exceed 16 MB.
#
#------------------------------------------------------------------------

sub use_huge_dictionary {
    my $self = shift;
    $self->{INDEX_BLKBIT} = 1;
}

#------------------------------------------------------------------------
#
# set_debug_mode()
#
# Sets $self->{DEBUG} = 1
#
#------------------------------------------------------------------------

sub set_debug_mode {
    my $self = shift;
    $self->{DEBUG} = 1;
}

#------------------------------------------------------------------------
#
# prepare()
#
# Prepares dictionary file
#
#------------------------------------------------------------------------

sub prepare {
    my $self = shift;
    
    my $z = int($self->{NUM_ENTRIES} ** $self->{Z}) + 1;
    
    if ($z < $self->{Q}) {
        $z = $self->{Q};
    }
    
    $self->{STANDARD_NUM_ENTRIES_PER_DATA_SECTION} = $z;
    
    # Estimated Number of Indices
    my $y = int($self->{NUM_ENTRIES} / $z * 1.2) + 1;
    
    # Calculate the required number of index blocks.
    my $k = $self->{AVERAGE_HEADWORD_LENGTH};
    my $b = ($self->{INDEX_BLKBIT} ? 4 : 2);
    my $index_part_size = ($k + $b + 1) * $y + 4;
    my $num_index_blocks = int($index_part_size / 256) + 2;
    
    my $obj_header = $self->{OBJ_HEADER} = new PDIC::Header($self->{FH});
    
    $obj_header->set('index_block', $num_index_blocks);
    $obj_header->set('index_blkbit', $b);
    $obj_header->save();
    
    $self->{OBJ_INDEX} = new PDIC::Index($self->{FH}, $obj_header);
    $self->{OBJ_INDEX}->prepare();
    
    $self->{OBJ_DATA} = new PDIC::Data($self->{FH}, $obj_header);
}

#------------------------------------------------------------------------
#
# add_entry($entry)
#
# Add a dictionary entry
#
# $entry : HASH REF
#
#------------------------------------------------------------------------

sub add_entry {
    my $self = shift;
    my $entry = shift;
    
    $self->{ENTRY_COUNT}++;
    
    foreach my $property (qw{ headword definition example pronunciation
        level marked revised extended }) {
        if (not defined $entry->{$property}) {
            croak("The $property of the entry [$self->{ENTRY_COUNT}] " .
                  "is not defined.");
        }
    }
    
    unless ($entry->{headword} gt $self->{PREV_HEADWORD}) {
        croak("The headword of the entry [$self->{ENTRY_COUNT}] is " .
              "not stringwise greater than that of the previous entry." .
              "(THIS:$entry->{headword} PREV:$self->{PREV_HEADWORD})");
    }
    
    my $queue = $self->{QUEUE};
    
    push(@$queue, $entry);
    
    if (@$queue >= $self->{STANDARD_NUM_ENTRIES_PER_DATA_SECTION} + 3) {
        $self->_process_queue();
        $self->_adjust_ratio();
    }
}

#------------------------------------------------------------------------
#
# finish()
#
# Writes data sections using all entries in the queue and updates header
# and index areas of the dictionary file.
#
#------------------------------------------------------------------------

sub finish {
    my $self = shift;
    
    my $queue = $self->{QUEUE};
    
    while (@$queue) {
        $self->_process_queue();
    }
    
    my $obj_header = $self->{OBJ_HEADER};
    my $obj_index = $self->{OBJ_INDEX};
    my $obj_data = $self->{OBJ_DATA};
    
    $obj_header->set('nword', $self->{NUM_PROCESSED_ENTRIES});
    $obj_header->set('nindex2', $obj_index->get_num_indices());
    $obj_header->set('nblock2', $obj_data->get_current_data_block_number());
    
    $obj_header->save();
    $obj_index->save();
    
    print STDERR " [finished]\n" if $self->{DEBUG};
}

#------------------------------------------------------------------------
#
# get_stat()
#
# Returns a HASH REF that has some statistical data.
#
#------------------------------------------------------------------------

sub get_stat {
    my $self = shift;
    my $obj_header = $self->{OBJ_HEADER};
    my $obj_index = $self->{OBJ_INDEX};
    
    my $stat = {};
    
    $stat->{num_entries} = $obj_header->{nword};
    $stat->{num_index_blocks} = $obj_header->{index_block};
    $stat->{num_data_blocks} = $obj_header->{nblock2};
    $stat->{data_part_size} = $obj_header->{nblock2} * 256;
    $stat->{sum_remainder} = $self->{SUM_REMAINDER};
    
    if ($obj_header->{nblock2} > 1) {
        $stat->{storage_rate} =
        1 - $self->{SUM_REMAINDER} / ($obj_header->{nblock2} * 256);
    }
    else {
        $stat->{storage_rate} = 0;
    }
    
    return $stat;
}

#------------------------------------------------------------------------
#
# _process_queue()
#
# (inner) Processes entry queue
#
#------------------------------------------------------------------------

sub _process_queue {
    my $self = shift;
    
    my $queue = $self->{QUEUE};
    
    my @expr = ();
    my $data_length = 0;
    my $min_remainder = 255;
    my $min_remainder_index;
    
    my $obj_index = $self->{OBJ_INDEX};
    my $obj_data = $self->{OBJ_DATA};
    
    my $i = 0;
    
    {
        my($expr, $is_long) = $obj_data->get_inner_expression($queue->[$i]);
        if ($is_long) {
            if (@expr) {
                $obj_index->add_index($queue->[0]{headword},
                                      $obj_data->get_current_data_block_number());
                $obj_data->write_data_section(\@expr, 0);
                $self->{NUM_PROCESSED_ENTRIES} += @$expr;
                $self->{SUM_REMAINDER} += 256 - ($data_length + 4) % 256;
            }
            
            $obj_index->add_index($queue->[0]{headword},
                                  $obj_data->get_current_data_block_number());
            $obj_data->write_data_section($expr, 1);
            
            $self->{NUM_PROCESSED_ENTRIES} += 1;
            $self->{SUM_REMAINDER} += 256 - (length($expr) + 6) % 256;
            splice(@$queue, 0, $i + 1);
            
            return;
        }
        else {
            push(@expr, $expr);
            $data_length += length($expr);
            
            if ($i == $#{$queue}) {
                last;
            }
            
            if (length($queue->[$i + 1]{headword}) > $self->{R}) {
                $i++;
                redo;
            }
            
            if ($i + 1 >= $self->{STANDARD_NUM_ENTRIES_PER_DATA_SECTION} - $self->{S} and
                $i + 1 <= $self->{STANDARD_NUM_ENTRIES_PER_DATA_SECTION} + $self->{S}) {
                my $remainder = 256 - ($data_length + 4) % 256;
                if ($remainder < $min_remainder) {
                    $min_remainder = $remainder;
                    $min_remainder_index = $i;
                }
            }
            
            $i++;
            redo;
        }
    }
    
    if (not defined $min_remainder_index) {
        $min_remainder_index = $#expr;
        $min_remainder = 256 - ($data_length + 4) % 256;
    }
    
    $self->{SUM_REMAINDER} += $min_remainder;
    
    splice(@expr, $min_remainder_index + 1);
    $obj_index->add_index($queue->[0]{headword},
                          $obj_data->get_current_data_block_number());
    $obj_data->write_data_section(\@expr, 0);
    $self->{NUM_PROCESSED_ENTRIES} += @expr;
    splice(@$queue, 0, $min_remainder_index + 1);
    
    return;
}

#------------------------------------------------------------------------
#
# _adjust_ratio()
#
# (inner)
#
#------------------------------------------------------------------------

sub _adjust_ratio {
    my $self = shift;
    
    my $r = $self->{NUM_PROCESSED_ENTRIES} / $self->{NUM_ENTRIES};
    
    my $obj_header = $self->{OBJ_HEADER};
    my $obj_index = $self->{OBJ_INDEX};
    
    my $s = $obj_index->{OCCUPIED_INDEX_PART_SIZE} /
        ($obj_header->{index_block} * 256);
    
    my $balancer;
    
    if ($r > 0.05) {
        my $ratio = $s / $r;
        if ($ratio >= 1.20) {
            $balancer = 3;
        }
        elsif ($ratio >= 1.10) {
            $balancer = 2;
        }
        elsif ($ratio >= 0.95) {
            $balancer = 1;
        }
        elsif ($ratio >= 0.90) {
            $balancer = 0;
        }
        elsif ($ratio >= 0.85) {
            $balancer = -1;
        }
        elsif ($ratio >= 0.70) {
            $balancer = -2;
        }
        else {
            $balancer = -3;
        }
        
        printf STDERR
            ("%1.2f %02d ", $ratio,
             $self->{STANDARD_NUM_ENTRIES_PER_DATA_SECTION})
                if $self->{DEBUG};
    }
    else {
        $balancer = 0;
    }
    
    $self->{STANDARD_NUM_ENTRIES_PER_DATA_SECTION} += $balancer;
    
    if ($self->{STANDARD_NUM_ENTRIES_PER_DATA_SECTION} < $self->{Q}) {
        $self->{STANDARD_NUM_ENTRIES_PER_DATA_SECTION} = $self->{Q};
    }
}

1;

__END__

=head1 NAME

PDIC::Writer - A Perl module for creating PDIC (.dic) file

=head1 SYNOPSIS

 use PDIC::Writer;
 
 # Create a PDIC file called 'sample.dic', which has 100 entries
 # and headwords with a length of 10 bytes on average.
 my $writer = new PDIC::Writer('sample.dic', 100, 10);
 
 $writer->prepare();
 
 my $entry = {
     headword => 'apple',
     pronunciation => '',
     definition => 'firm round fruit with a central core',
     example => 'An apple a day keeps a doctor away',
     level => 3,
     marked => 0,
     revised => 0,
 };
 
 $writer->add_entry($entry);
 
 $writer->finish();

=head1 DESCRIPTION

The C<PDIC::Writer> module for creating a C<.dic> file of PDIC,
a Win32 electronic dictionary application developed by TaN 
<sgm00353@nifty.ne.jp>.

=head1 CONSTRUCTOR

=over 4

=item new( FILENAME, NUM_ENTRIES, AVERAGE_HEADWORD_LENGTH)

FILENAME is the name of PDIC file to be created. NUM_ENTRIES is 
the number of dictionary entries. AVERAGE_HEADWORD_LENGTH is the
average length of headwords.

=back

=head1 METHODS

=over 4

=item prepare

This method opens the C<.dic> file and initializes it.

=item add_entry( ENTRY )

This method adds an entry to the dictionary. ENTRY is a hash ref,
which has following keys: C<headword, pronunciation, definition,
example, level, marked, revised>.

C<headword>, C<pronunciation>, C<definition> and C<example> are 
strings. C<level> is a number between 0 and 15. C<marked> and 
C<revised> are 0 or 1.

Entries are stored in a queue and are written down to the file 
periodically.

=item finish

This method writes down entries in the queue to the C<.dic> file,
updates the header and indices, and closes the C<.dic> file.

=back

=head1 COPYRIGHT

Copyright 2002 Tsutomu Kuroda.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
