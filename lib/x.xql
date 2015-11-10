xquery version "3.0";

module namespace x="http://raddle.org/x";

declare function x:call($fn,$a) {
    $fn($a)
};

declare function x:call($fn,$a,$b) {
    $fn($a,$b)
};

declare function x:call($fn,$a,$b,$c) {
    $fn($a,$b,$c)
};

declare function x:seqx($in,$a) {
    ($in,$a($in))
};


declare function x:seqx($in,$a,$b) {
    ($in,$a($in),$b($in))
};

declare function x:seqx($in,$a,$b,$c) {
    ($in,$a($in),$b($in),$c($in))
};