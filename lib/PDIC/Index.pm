#========================================================================
#
# PDIC::Index.pm
#
# Copyright (c) 2002 Tsutomu Kuroda <tkrd@mail.com> All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
#========================================================================

package PDIC::Index;

require 5.004;

use strict;
use warnings;
use vars qw(@ISA $VERSION $DEBUG);

$VERSION = '1.13_a'; # $Date: 2002/02/23 10:48:00 $
$DEBUG = 0;

use PDIC::Header;

use Carp;

#------------------------------------------------------------------------
#
# new($file_handle, $pdic_header_object)
#
# Create a new PDIC::Index object.
#
# $file_handle        : IO REF for a PDIC data file handler.
# $pdic_header_object : PDIC::Header object.
#
# * $pdic_header_object has following properties among others:
#
#   header_size   : The size of header section (256).
#   extheader     : The size of extheader section (0).
#   block_size    : The size of each data block of index section (256).
#   index_block   : The number of data blocks of index section.
#   index_blk_bit : When 0, each index block has short (16bit) block number.
#                   When 1, each index block has long (32bit) block number.
#
#------------------------------------------------------------------------

sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    
    $self->{FILE_HANDLE} = shift;
    $self->{HEADER_OBJ} = shift;
    
    $self->{INDICES} = [];
    $self->{OCCUPIED_INDEX_PART_SIZE} = 4;
    
    return $self;
}

#------------------------------------------------------------------------
#
# load()
#
# Load index data from $self->{FILE_HANDLE}
#
#------------------------------------------------------------------------

sub load {
    my $self = shift;
    
    my $fh = $self->{FILE_HANDLE};
    my $header = $self->{HEADER_OBJ};
    
    my $position = $header->get('header_size') + $header->get('extheader');
    my $size = $header->get('block_size') * $header->get('index_block');
    
    my $index_data;
    sysseek($fh, $position, 0);
    sysread($fh, $index_data, $size) or croak("Can't sysread index.");
    
    $self->{INDICES} = [];
    
    LOOP: {
        my $length;
        my $template;
        if ($header->get('index_blkbit') == 0) {
            $length = 2;
            $template = 'S';
        }
        else {
            $length = 4;
            $template = 'L';
        }
        
        $index_data =~ /\G([\x00-\xff]{$length})([^\x00]+)\x00/g or last LOOP;
        push(@{$self->{INDICES}}, {
            headword => $2, data_block_number => unpack($template, $1) });
        
        redo LOOP;
    }
    
    return $self;
}

#------------------------------------------------------------------------
#
# add_index()
#
# Add index HASH REF
#
#------------------------------------------------------------------------

sub add_index {
    my $self = shift;
    my $headword = shift;
    my $data_block_number = shift;
    
    push(@{$self->{INDICES}}, {
        headword => $headword,
        data_block_number => $data_block_number,
    }
         );
    
    my $header = $self->{HEADER_OBJ};
    
    if ($header->get('index_blkbit') == 0) {
        $self->{OCCUPIED_INDEX_PART_SIZE} += 2 + length($headword) + 1;
    }
    else {
        $self->{OCCUPIED_INDEX_PART_SIZE} += 4 + length($headword) + 1;
    }
    
    my $size = $header->get('block_size') * $header->get('index_block');
    if ($self->{OCCUPIED_INDEX_PART_SIZE} > $size) {
        croak("Index part is full. [$self->{OCCUPIED_INDEX_PART_SIZE}/$size]");
    }
}

#------------------------------------------------------------------------
#
# get_num_indices()
#
#------------------------------------------------------------------------

sub get_num_indices {
    my $self = shift;
    
    @{$self->{INDICES}} + 0;
}

#------------------------------------------------------------------------
#
# prepare()
#
# Write null data to the index area of dictionary file
#
#------------------------------------------------------------------------

sub prepare {
    my $self = shift;
    
    my $fh = $self->{FILE_HANDLE};
    
    sysseek($fh, 0x100, 0);
    
    my $header = $self->{HEADER_OBJ};
    my $size = $header->get('block_size') * $header->get('index_block');
    
    syswrite($fh, "\x00" x $size);
}

#------------------------------------------------------------------------
#
# save()
#
# Save index data to the index area of dictionary file
#
#------------------------------------------------------------------------

sub save {
    my $self = shift;
    
    my $header = $self->{HEADER_OBJ};
    
    my $fh = $self->{FILE_HANDLE};
    sysseek($fh, 0x100, 0);
    
    my $index;
    foreach $index (@{$self->{INDICES}}) {
        my $template;
        if ($header->get('index_blkbit') == 0) {
            $template = "SZ*";
        }
        else {
            $template = "LZ*";
        }
        syswrite($fh, pack($template,
            $index->{data_block_number}, $index->{headword}));
    }
    
    syswrite($fh, "\x00" x 4);
}

1;
