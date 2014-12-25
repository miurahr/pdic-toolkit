#========================================================================
#
# PDIC::Data.pm
#
# Copyright (c) 2002 Tsutomu Kuroda <tkrd@mail.com> All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
#========================================================================

package PDIC::Data;

require 5.004;

use strict;
use warnings;
use vars qw(@ISA $VERSION $DEBUG);

$VERSION = '1.12_b'; # $Date: 2002/02/24 11:29:00 $
$DEBUG = 0;

use PDIC::Header;
use PDIC::Index;

use Carp;

#------------------------------------------------------------------------
#
# new($file_handle, $pdic_header_object)
#
# Create a new PDIC::Data object.
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
#
#------------------------------------------------------------------------

sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    
    $self->{FILE_HANDLE} = shift;
    $self->{OBJ_HEADER} = shift;
    
    $self->{CURRENT_DATA_BLOCK_NUMBER} = 0;
    
    return $self;
}

#------------------------------------------------------------------------
#
# get_current_data_block_number()
#
#
#------------------------------------------------------------------------

sub get_current_data_block_number {
    my $self = shift;
    return $self->{CURRENT_DATA_BLOCK_NUMBER};
}

#------------------------------------------------------------------------
#
# set_current_data_block_number($number)
#
#
#------------------------------------------------------------------------

sub set_current_data_block_number {
    my $self = shift;
    my $number = shift;
    
    if (not defined $number) {
        croak('The first argument is not defined.');
    }
    
    $self->{CURRENT_DATA_BLOCK_NUMBER} = $number;
}

#------------------------------------------------------------------------
#
# get_data_section($data_block_number)
#
# returns a ARRAY REF of HASH REFs that hold every field of each entry
#   of a particular data block.
#
# $data_block_number
#                 : From this we can calculate the position of the data 
#                   block on the disk, which can be caluculated as:
#                     header_size + extheader + block_size * index_block
#                     + block_size * data_block_number
#
# * The returned HASH REF has following properties:
#
#   headword      : dictionary headword
#   definition    : definition of translation of the headword
#   example       : example of usage of the headword
#   pronunciation : pronunciation of the headword
#   level         : 0-15
#   marked        : marked flag
#   revised       : revised flag
#   extended      : extended flag
#                   (if this headword has example or pronunciation field)
#
#------------------------------------------------------------------------

sub get_data_section {
    my $self = shift;
    my $data_block_number = shift;
    
    my $result = {};
    
    my $fh = $self->{FILE_HANDLE};
    my $header = $self->{OBJ_HEADER};
    
    my $position = $header->get('header_size') + $header->get('extheader')
        + $header->get('block_size') * $header->get('index_block')
        + $header->get('block_size') * $data_block_number;
    
    my $input;
    sysseek($fh, $position, 0);
    sysread($fh, $input, 2) or croak("Can't get data block length.");
    
    my $block_length = unpack('S', $input);
    my $use_long_field_length;
    if ($block_length == 0) {
        return;
    }
    elsif ($block_length >= 0x800) {
        $block_length = $block_length - 0x800;
        $use_long_field_length = 1;
    }
    else {
        $block_length = $block_length;
        $use_long_field_length = 0;
    }
    
    my $data_block;
    sysseek($fh, $position + 2, 0);
    sysread($fh, $data_block, $header->get('block_size') * $block_length - 2)
        or croak("Can't sysread data block.");
    
    $result = [];
    my $offset = 0;
    my $prev_headword;
    
    LOOP1: {
        my $entry_data_size;
        my $entry_data;
        
        my $entry = {};
        
        if ($use_long_field_length) {
            $entry_data_size = unpack('L', substr($data_block, $offset, 4));
            $offset += 4;
        }
        else {
            $entry_data_size = unpack('S', substr($data_block, $offset, 2));
            $offset += 2;
        }
        
        if ($entry_data_size == 0) { last LOOP1; }
        
        my $overlap_length = unpack('C', substr($data_block, $offset, 1));
        $offset += 1;
        
        $entry_data = substr($data_block, $offset, $entry_data_size);
        $offset += $entry_data_size;
        
        $entry_data =~ s/^([^\x00]+)\x00//
            or croak(sprintf("Dictionary is broken. DBN: %04x, Pos: %04x",
            $data_block_number, $position));
        
        if ($overlap_length > 0) {
            $prev_headword = $entry->{headword} = substr($prev_headword, 0, $overlap_length) . $1;
        }
        else {
            $prev_headword = $entry->{headword} = $1;
        }
        
        $entry_data =~ s/^[\x00-\xff]//;
        my $attribute = unpack('C', $&);
        
        $entry->{level} = $attribute & 0x0f;
        $entry->{extended} = ($attribute & 0x10 ? 1 : 0);
        $entry->{marked} = ($attribute & 0x20 ? 1 : 0);
        $entry->{revised} = ($attribute & 0x40 ? 1 : 0);
        
        $entry->{example} = '';
        $entry->{pronunciation} = '';
        $entry->{link} = '';
        
        if ($entry->{extended} == 1) {
            $entry_data =~ s/^([^\x00]*)\x00//;
            $entry->{definition} = $1;
            
            LOOP2: {
                $entry_data =~ s/^[\x00-\xff]//;
                my $attribute = unpack('C', $&);
                if ($attribute & 0x80) { # End fo Field Data
                    last LOOP2;
                }
                
                my $type;
                if (($attribute & 0x0f) == 0x01) {
                    $type = 'example';
                }
                elsif (($attribute & 0x0f) == 0x02) {
                    $type = 'pronunciation';
                }
                elsif (($attribute & 0x0f) == 0x04) {
                    $type = 'link';
                }
		else {
                    $type = 'undefined';
                }
                
                if ($attribute & 0x10) { # Binary Data
                    my $size;
                    if ($use_long_field_length) {
                        $size = unpack('L', substr($entry_data, 0, 4));
                        $entry->{$type} = substr($entry_data, 4, $size);
                        $entry_data = substr($entry_data, $size + 4);
                    }
                    else {
                        $size = unpack('S', substr($entry_data, 0, 2));
                        $entry->{$type} = substr($entry_data, 2, $size);
                        $entry_data = substr($entry_data, $size + 2);
                    }
                }
                else {
                    $entry_data =~ s/^([^\x00]+)\x00//;
                    $entry->{$type} = $1;
                }
            }
        }
        else {
            $entry->{definition} = $entry_data;
        }
        
        push(@$result, $entry);
        
        redo LOOP1;
    }
    
    return $result;
}

#------------------------------------------------------------------------
#
# get_inner_expression($entry)
#
# Get the inner expression of an entry in the data section
#
# $entry : HASH REF
#
#------------------------------------------------------------------------

sub get_inner_expression {
    my $self = shift;
    my $entry = shift;
    my $last_entry = shift;
    
    my $overlap_length;
    my $headword;
    if (defined $last_entry) {
        my $i = 1;
        my $len = length($entry->{headword});
        LOOP: {
            my $fore = substr($entry->{headword}, 0, $i);
            if ($fore eq substr($last_entry->{headword}, 0, $i)) {
                if ($i < $len) {
                    $i++;
                    redo LOOP;
                }
                else {
                    $overlap_length = $i;
                    last LOOP;
                }
            }
            else {
                $overlap_length = $i - 1;
                last LOOP;
            }
        }
        $headword = substr($entry->{headword}, $overlap_length);
    }
    else {
        $overlap_length = 0;
        $headword = $entry->{headword};
    }
    
    my $attribute =
        (($entry->{extended} ? 1 : 0) * 0x10) +
        (($entry->{marked} ? 1 : 0) * 0x20) +
        (($entry->{revised} ? 1 : 0) * 0x40) +
        $entry->{level};
    
    my $expr;
    my $is_long;
    if (not $entry->{extended}) {
        my $len = length($headword) + length($entry->{definition}) + 2;
        
        if ($len > 64 * 1024) {
            $expr = pack('L', $len);
            $is_long = 1;
        }
        else {
            $expr = pack('S', $len);
            $is_long = 0;
        }
        
        $expr .= pack('CZ*Ca*', $overlap_length, $headword, $attribute, $entry->{definition});
    }
    else {
        my $len = length($headword) + length($entry->{definition}) + 4;
        if ($entry->{example} ne '') {
            $len += length($entry->{example}) + 2;
        }
        if ($entry->{pronunciation} ne '') {
            $len += length($entry->{pronunciation}) + 2;
        }
        
        if ($len > 64 * 1024) {
            $expr = pack('L', $len);
            $is_long = 1;
        }
        else {
            $expr = pack('S', $len);
            $is_long = 0;
        }
        
        $expr .= pack('CZ*CZ*', $overlap_length, $headword, $attribute, $entry->{definition});
        
        if ($entry->{example} ne '') {
            $expr .= pack('CZ*', 0x01, $entry->{example});
        }
        if ($entry->{pronunciation} ne '') {
            $expr .= pack('CZ*', 0x02, $entry->{pronunciation});
        }
        
        $expr .= pack('C', 0x80);
    }
    
    return ($expr, $is_long);
}

#------------------------------------------------------------------------
#
# write_data_section()
#
# Write data section
#
#------------------------------------------------------------------------

sub write_data_section {
    my $self = shift;
    my $expr = shift;
    my $is_long = shift;
    
    my $data = join('', @$expr);
    
    if ($is_long) {
        $data .= "\x00" x 4;
    }
    else {
        $data .= "\x00" x 2;
    }
    
    my $num_blocks = int((length($data) + 2) / 256) + 1;
    my $null_paddings = 256 - (length($data) + 2) % 256;
    
    my $fh = $self->{FILE_HANDLE};
    
    sysseek($fh, 0, 2) or die();
    syswrite($fh, pack("S", $num_blocks)) or die();
    syswrite($fh, $data);
    syswrite($fh, "\x00" x $null_paddings);
    
    $self->{CURRENT_DATA_BLOCK_NUMBER} += $num_blocks;
}

1;
