use strict;
use warnings;

use VA;

my $app = VA->apply_default_middlewares(VA->psgi_app);
$app;

