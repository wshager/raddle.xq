xquery version "3.0";

module namespace op="http://www.w3.org/2005/xpath-functions/op";

declare function op:add($a as numeric, $b as numeric) as numeric {
    $a + $b
};

declare function op:greater-than($a,$b){
    $a > $b
};