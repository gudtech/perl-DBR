# the contents of this file are Copyright (c) 2009-2011 Daniel Norman
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

package DBR::Util::Date;
use strict;

#use Date::Parse ();
use Time::ParseDate ();

sub to_unixtime {
    my ($value) = @_;

    # Ok... so Date::Parse is kinda cool and all, except for the fact that it breaks horribly on
    # Non DST-specific timezone prefixes, like PT, MT, CT, ET. Treats them all like GMT.
    # Even strptime freaks out on it. What gives Graham?
    # P.S. glass house here throwing stones, but try adding a comment or two.

    #my $uxtime = Date::Parse::str2time($value);

    # parsedate truncates the h/m/s when the value is iso8601 with timezones
    # e.g., 2017-09-22T11:24:41-06:00 or 2017-09-22T11:24:41Z
    # However, it properly parses if a space is inserted between the seconds and timezone
    $value =~ s/([+-]\d{2}:?\d{2})$/ $1/;
    $value =~ s/Z$/ Z/;

    return Time::ParseDate::parsedate($value);
}

1;
