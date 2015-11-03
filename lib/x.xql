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