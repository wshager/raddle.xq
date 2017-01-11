xquery version "3.1";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

declare namespace hof="http://lagua.nl/lib/hof";

declare function hof:unfold($init, $unspool, $cond) {
    hof:unfold($init, $unspool, $cond, ())
};

declare function hof:unfold($init, $unspool, $cond, $r) {
    if($cond($init)) then
        $r
    else
        hof:unfold($unspool($init), $unspool, $cond, ($r, $init))
};

declare function hof:unfold($init, $unspool, $cond, $r, $appender) {
    if($cond($init)) then
        $r
    else
        hof:unfold($unspool($init), $unspool, $cond, $appender($r, $init), $appender)
};

declare function hof:unfold($init, $unspool, $cond, $r, $appender, $transformer) {
    if($cond($init)) then
        $r
    else
        hof:unfold($unspool($init), $unspool, $cond, $appender($r, $init, $transformer),$appender, $transformer)
};

declare function hof:group-by($in,$grouper,$processor) {
    let $map := hof:unfold(
        $in,
        tail#1,
        empty#1,
        map:new(),
        function($map, $init, $transformer){
            let $val := head($init)
            let $key := $transformer($val)
            return
            map:put($map,$key,
                if(map:contains($map,$key)) then
                    ($map($key),$val)
                else
                    $val)
        },
        $grouper)
    return map:for-each-entry($map, function($k,$v){
        $processor($v,$k)
    })
};


let $seed := hof:unfold(1,function($n){
    $n + 1
},function($n) {
    $n eq 20
},(),
function($a,$b){
    ($a,concat(string-join($a),codepoints-to-string(70 + $b)))
})

let $ret := hof:group-by($seed,function($n){
    string-length($n)
},function($group,$key){
    element group {
        attribute key { $key },
        $group ! element entry { . }
    }
})

return $ret
