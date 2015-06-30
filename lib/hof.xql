xquery version "3.1";

module namespace hof="http://lagua.nl/lib/hof";

declare function hof:unfold($init, $unspool, $cond, $r) {
    if($cond($init)) then
        $r
    else
        hof:unfold($unspool($init), $unspool, $cond, array:append($r, $init))
};