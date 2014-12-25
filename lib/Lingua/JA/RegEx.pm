#========================================================================
#
# Lingua::JA::RegEx.pm
#
# Copyright (c) 2002 Tsutomu Kuroda <tkrd@mail.com> All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
#========================================================================

package Lingua::JA::RegEx;

use strict;
use vars qw(@ISA $VERSION $DEBUG);

$VERSION = '1.00'; # $Date: 2002/01/19 01:12:00 $
$DEBUG = 0;

use Carp;

use vars qw($RE_SJIS $RE_EUC);

$RE_SJIS = '[\x81-\x9f\xe0-\xfc][\x40-\x7e\x80-\xfc]';
$RE_EUC  = '[\xa1-\xfe][\xa1-\xfe]|\x8e[\xa1-\xdf]';

#######################################################################
#
# CONSTRUCTOR
#
#######################################################################

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {};
    bless $self, $class;
    $self->{CODE} = (shift eq 'sjis') ? 'sjis' : 'euc';
    $self->{REGEX} = undef;
    $self->{MATCH} = undef;
    $self->{PREMATCH} = undef;
    $self->{POSTMATCH} = undef;
    $self->{BUFFERS} = [];
    $self->{ERROR_MESSAGE} = undef;
    if ($self->{CODE} eq 'sjis') {
        $self->{_REGEX1} = qr{ \G (.*?) ( \. | $RE_SJIS ) }x;
        $self->{_REGEX2} = qr{ (?: (\\.) | \$([&`\']|[1-9]\d*) | ($RE_SJIS) ) }x;
    }
    else {
        $self->{_REGEX1} = qr{ \G (.*?) ($RE_EUC | \. ) }x;
        $self->{_REGEX2} = qr{ (?: (\\.) | \$([&`\']|[1-9]\d*) ) }x;
    }
    return $self;
}

#######################################################################
#
# set($jregex, $options)
#
# $jregex  : Regular expression that may include Japanese characters.
# $options : undef or [ismx]*
#
#######################################################################

sub set {
    my $self = shift;
    my $jregex = shift;
    my $options = shift;
    
    if (defined $options) {
        my @ill = ($options =~ /[^ismx]/g);
        if (@ill) {
            croak("Illegal options: " . join(', ', @ill));
        }
    }
    else {
        $options = '';
    }
    
    my $len = length($jregex);
    my $regex = '';
    
    LOOP: {
        my $pos = defined pos($jregex) ? pos($jregex) : 0;
        
        if ($pos == $len) {
            last LOOP;
        }
        
        $jregex =~ /$self->{_REGEX1}/sg;
        
        if (not defined pos($jregex)) {
            $regex .= substr($jregex, $pos);
            last LOOP;
        }
        
        $regex .= $1;
        my $char = $2;
        
        if ($char eq '.') {
            if ($self->{CODE} eq 'sjis') {
                $regex .= "(?:$RE_SJIS|.)";
            }
            else {
                $regex .= "(?:$RE_EUC|.)";
            }
        }
        else {
            $char =~ s/./sprintf('\x%02x', ord($&))/eg;
            $jregex =~ /\G[*+?\{]?/g;
            if ($& eq '') {
                $regex .= $char;
            }
            else {
                $regex .= "(?:$char)$&";
            }
        }
        
        redo LOOP;
    }
    
    eval {
        '' =~ /$regex/;
    };
    
    if ($@) {
        my $errmsg = $@;
        $errmsg =~ s/\\x([4-9a-f][0-9a-f])/pack('C', hex($1))/ge;
        croak($errmsg);
    }
    else {
        if ($self->{CODE} eq 'sjis') {
            $self->{REGEX} = qr/ (?$options) (\G (?: $RE_SJIS | . | \n ) *? ) ($regex) /x;
        }
        else {
            $self->{REGEX} = qr/ (?$options) (\G (?: $RE_EUC | . | \n ) *? ) ($regex) /x;
        }
        return 1;
    }
}


#######################################################################
#
# match($string, $options)
#
# $string  : A reference to a string
# $options : undef or [cg]+
#   c : (continue)
#   g : (global)
#
#######################################################################

sub match {
    my $self = shift;
    my $string = shift;
    my $options = shift;
    
    if (not defined $string) {
        croak('The first argument is not defined.');
    }
    elsif (ref($string) ne 'SCALAR') {
        croak('The first argument must be a scalar ref.');
    }
    
    if (defined $options) {
        my @ill = ($options =~ /[^cg]/);
        if (@ill) {
            croak("Illegal options: " . join(', ', @ill));
        }
    }
    else {
        $options = '';
    }
    
    if (not defined $self->{REGEX}) {
        croak('Regular expression has not been set.');
    }
    
    if ($$string =~ m/$self->{REGEX}/gc) {
        $self->{PREMATCH} = $1;
        $self->{MATCH} = $2;
        $self->{POSTMATCH} = substr($$string, pos($$string));
        $self->{BUFFERS} = [ $2 ];
        
        # $+[1] holds the offset of the start of the substring matched by the first subpattern.
        # $-[1] holds the offset of the end of the substring matched by the first subpattern.
        for (my $i = 0; $i <= $#+ - 3; $i++) {
            push(@{$self->{BUFFERS}}, substr($$string, $-[$i + 3], $+[$i + 3] - $-[$i + 3]));
        }
        
        unless ($options =~ /g/) {
            undef pos($$string);
        }
        
        return 1;
    }
    else {
        unless ($options =~ /c/) {
            undef pos($$string);
        }
        
        return 0;
    }
}

#######################################################################
#
# replace
#
# $string  : A reference to a string
# $replace : A string, a SCALAR ref or a CODE ref
# $options : undef or 'g'
#
#######################################################################

sub replace {
    my $self = shift;
    my $string = shift;
    my $replace = shift;
    my $options = shift;
    
    if (not defined $string) {
        croak('The first argument is not defined.');
    }
    elsif (ref($string) ne 'SCALAR') {
        croak('The first argument must be a scalar ref.');
    }
    
    if (not defined $replace) {
        croak('The second argument is not defined.');
    }
    elsif (ref($replace) and ref($replace) ne 'SCALAR' and ref($replace) ne 'CODE') {
        croak('The second argument must be a scalar, a scalar ref or a code ref.');
    }
    
    if (defined $options) {
        my @ill = ($options =~ /[^g]/);
        if (@ill) {
            croak("Illegal options: " . join(', ', @ill));
        }
    }
    else {
        $options = '';
    }
    
    if (not defined $self->{REGEX}) {
        croak('Regular expression has not been set.');
    }
    
    my $result = '';
    my $counter = 0;
    
    LOOP: {
        my $pos = (defined pos($$string)) ? pos($$string) : 0;
        if ($$string =~ m/$self->{REGEX}/g) {
            $counter++;
            $result .= substr($$string, $pos, length($1));
            
            my $m = {
                PREMATCH => $1,
                MATCH => $2,
                POSTMATCH => substr($$string, pos($$string)),
                BUFFERS => [ $2 ],
            };
            
            # $+[1] holds the offset of the start of the substring matched by the first subpattern.
            # $-[1] holds the offset of the end of the substring matched by the first subpattern.
            for (my $i = 0; $i <= $#+ - 3; $i++) {
                push(@{$m->{BUFFERS}}, substr($$string, $-[$i + 3], $+[$i + 3] - $-[$i + 3]));
            }
            
            if (ref $replace eq 'CODE') {
                $result .= &$replace($m);
            }
            else {
                $result .= $self->_replace($replace, $m);
            }
            if ($options =~ /g/) {
                redo LOOP;
            }
            else {
                $result .= $';
            }
        }
        else {
            $result .= substr($$string, $pos);
        }
    }
    
    $$string = $result;
    return $counter;
}

#######################################################################
#
# PRIVATE METHOD
#
# _replace($string, $m);
#
#######################################################################

sub _replace {
    my $self = shift;
    my $string = shift;
    my $m = shift;
    
    my $result = (ref $string) ? $$string : $string;
    
    $result =~ s{
        $self->{_REGEX2}
    }{
        if (defined $1) { $1; }
        elsif (defined $2) {
            if ($2 eq '&') { $m->{MATCH}; }
            elsif ($2 eq '`') { $m->{PREMATCH}; }
            elsif ($2 eq "'") { $m->{POSTMATCH}; }
            elsif (defined $m->{BUFFERS}[$2]) { $m->{BUFFERS}[$2]; }
            else { $2; }
        }
        elsif (defined $3) { $3; }
        else { '' };
    }xseg;
    
    return $result;
}


#######################################################################
#
# is_set
#
#######################################################################

sub is_set {
    my $self = shift;
    return (defined $self->{REGEX}) ? 1 : 0;
}


#######################################################################
#
# error_message
#
#######################################################################

sub error_message {
    my $self = shift;
    return $self->{ERROR_MESSAGE};
}

1;

__END__

=head1 NAME

Lingua::JA::RegEx - Japanese-friendly regular expression


=head1 SYNOPSIS

 use Lingua::JA::RegEx;
 
 my $re = new Lingua::JA::RegEx 'sjis';
 
 $re->set("^$japanese_word");
 
 while($re->match(\$text, 'g')) {
     print $re->{MATCH};
 }
 
 $re->replace(\$text, '($&)', 'g');
 print $text;

=head1 DESCRIPTION

Japanese is expressed in double byte codes on computers, because it
has more characters than 256. This makes writing regular expressions
that contain Japanese characters rather complicated matter.

For example, a character "\x93\x82", which represents the Tang dynasty
of China, could be matched a pair of characters "\x89\x93\x82\xa2",
which means 'far way'. So, you must isolate this character by writing
"(:?\x93\x82)".

To make matters worse, many characters contains metacharacters as the
second byte (in case of Shift-JIS). A character "\x8b\x5c", which means
'deceive', must be escaped in regular expressions.

With Lingua::JA::Regex, you can write regular expressions in Japanese
without bothering about isolation or escaping.

=head1 CONSTRUCTOR

=over 4

=item new( [CODE] )

Creates a regular expression object for CODE, which must be 'sjis' or
'euc'. If CODE is omitterd, 'euc' is assumed.

=back

=head1 METHODS

=over 4

=item set(REGEX, [MODIFIERS])

REGEX is a regular expression written in Japanese. When X, Y and Z are
double byte characters, you can write as 'X*Y' instead of '(?:X)*Y'.
You do not have to escape metacharacters that can be found as the
second byte of Japanese characters of Shift JIS code.

It returns 1 if the regular expression was successfully evaluated,
otherwise it returns 0.

If given, MODIFIERS alter the way this regular expression is used by
Perl. MODIFIERS is a combination of one or more letters from 'i', 'm',
's' and 'x'. See perlre man page for details.

If the pattern evaluation failed, you can get the error message with
C<$re-error_messageE<gt>{}> method. You may get bizarre error message
when your original regular expression has hex char expressions like
as '\x80'. You can avoid this by writing as '\x{80}'.

=item match(SCALARREF, [OPTIONS])

Searches the pattern set by C<set()> method against the string that
SCALARREF refers. Returns 1 for success, 0 for failure.

If successful, C<match> method sets C<MATCH>, C<PREMATCH> and C<POSTMATCH>
properties of the object, which are equivalent to C<$&>, C<$`> and C<$'>
varialbes. You can refer to these properties as C<$re-E<gt>{MATCH}>,
C<$re-E<gt>{PREMATCH}> and C<$re-E<gt>{POSTMATCH}>.

The substrings matched by the subpatterns are held in C<BUFFERS> as an
array reference, like as ($&, $1, $2, $3, ...).

When given, OPTIONS must be C<'g'> or C<'gc'> whose meanings are identical
with those of C<m//>. See perlop man page for details.

Note that this method always returns a boolean value even if it is used
in the list context. This behavior is different from that of C<m//>.

=item replace(SCALARREF, REPLACE, [OPTIONS])

Replaces the pattern set by C<set()> method within the string refered by
SCALARREF with REPLACE after evaluation.

REPLACE can be scalar ref or code ref.

If REPLACE is a scalar ref, the matched string is replaced by the string
refered by REPLACE.

If REPLACE is a code ref, C<replace()> method calls this subroutine,
which takes a hash ref that has the C<MATCH>, C<PREMATCH>, C<POSTMATCH>
and C<BUFFERS> properties and returns a string;

OPTIONS must be C<'g'> or omitted.


=item is_set()

Returns 1 if the C<set()> method has been called successfully, otherwise
returns 0;


=item error_message();

Returns the error message of the last failed C<set()> call.

=back

=head1 AUTHOR

Tsutomu Kuroda <tkrd@mail.com>

=head1 COPYRIGHT

Copyright (c) 2002 Tsutomu Kuroda <tkrd@mail.com> All rights reserved.
This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
