package MY::Filter;
use utf8;

sub filter {
    my $entry = shift;
    
    if  ($entry->{level} >= 3) {
        return 1;
    }
    else {
        return 0;
    }
}

1;
